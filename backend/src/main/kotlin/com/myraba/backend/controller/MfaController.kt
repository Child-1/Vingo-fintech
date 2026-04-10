package com.myraba.backend.controller

import com.myraba.backend.model.MfaSecret
import com.myraba.backend.repository.MfaSecretRepository
import com.myraba.backend.repository.UserRepository
import com.myraba.backend.service.AesEncryptionService
import com.myraba.backend.service.AuditLogService
import com.myraba.backend.service.TotpService
import com.myraba.backend.util.JwtUtil
import jakarta.servlet.http.HttpServletRequest
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.security.core.userdetails.UserDetails
import org.springframework.security.core.userdetails.UserDetailsService
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException

data class MfaSetupResponse(val secret: String, val otpauthUri: String, val qrUrl: String)
data class MfaVerifyRequest(val code: String)
data class MfaTokenResponse(val token: String, val myrabaHandle: String, val role: String)

@RestController
@RequestMapping("/auth/mfa")
class MfaController(
    private val totpService: TotpService,
    private val aes: AesEncryptionService,
    private val mfaRepo: MfaSecretRepository,
    private val userRepository: UserRepository,
    private val userDetailsService: UserDetailsService,
    private val jwtUtil: JwtUtil,
    private val auditLogService: AuditLogService,
) {

    /** Step 1 — generate secret and return QR URI. Does NOT enable MFA yet. */
    @PostMapping("/setup")
    fun setup(@AuthenticationPrincipal principal: UserDetails): ResponseEntity<MfaSetupResponse> {
        val user = userRepository.findByVingHandle(principal.username)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "User not found")

        // Regenerate if called again (e.g. user re-scans)
        mfaRepo.findByUserId(user.id)?.let { mfaRepo.delete(it) }

        val secret = totpService.generateSecret()
        mfaRepo.save(MfaSecret(user = user, encryptedSecret = aes.encrypt(secret), enabled = false))

        val uri = totpService.buildOtpAuthUri(secret, user.myrabaHandle)
        // Use a public QR generator API — the secret is in the URL so use only over HTTPS in prod
        val qrUrl = "https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${java.net.URLEncoder.encode(uri, "UTF-8")}"

        return ResponseEntity.ok(MfaSetupResponse(secret = secret, otpauthUri = uri, qrUrl = qrUrl))
    }

    /** Step 2 — confirm a valid TOTP code to activate MFA */
    @PostMapping("/activate")
    fun activate(
        @AuthenticationPrincipal principal: UserDetails,
        @RequestBody body: MfaVerifyRequest,
        httpRequest: HttpServletRequest
    ): ResponseEntity<Map<String, String>> {
        val user = userRepository.findByVingHandle(principal.username)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "User not found")
        val mfa = mfaRepo.findByUserId(user.id)
            ?: throw ResponseStatusException(HttpStatus.BAD_REQUEST, "MFA setup not initiated")

        val secret = aes.decrypt(mfa.encryptedSecret)
        if (!totpService.verify(secret, body.code))
            throw ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid TOTP code")

        mfa.enabled = true
        mfaRepo.save(mfa)
        auditLogService.logUser(user.myrabaHandle, "MFA_ACTIVATED", "USER", user.id.toString(),
            details = "TOTP MFA activated", request = httpRequest)
        return ResponseEntity.ok(mapOf("message" to "MFA activated successfully"))
    }

    /** Step 3 — called after password login when MFA is enabled; returns full JWT on success */
    @PostMapping("/verify")
    fun verify(
        @RequestParam myrabaHandle: String,
        @RequestBody body: MfaVerifyRequest,
    ): ResponseEntity<MfaTokenResponse> {
        val user = userRepository.findByVingHandle(myrabaHandle)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "User not found")
        val mfa = mfaRepo.findByUserId(user.id)
            ?: throw ResponseStatusException(HttpStatus.BAD_REQUEST, "MFA not configured")
        if (!mfa.enabled)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "MFA not enabled")

        val secret = aes.decrypt(mfa.encryptedSecret)
        if (!totpService.verify(secret, body.code))
            throw ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid TOTP code")

        val userDetails = userDetailsService.loadUserByUsername(myrabaHandle)
        val token = jwtUtil.generateToken(userDetails)
        return ResponseEntity.ok(MfaTokenResponse(token = token, myrabaHandle = user.myrabaHandle, role = user.role.name))
    }

    /** Disable MFA (requires valid TOTP to prevent account takeover) */
    @DeleteMapping("/disable")
    fun disable(
        @AuthenticationPrincipal principal: UserDetails,
        @RequestBody body: MfaVerifyRequest,
        httpRequest: HttpServletRequest
    ): ResponseEntity<Map<String, String>> {
        val user = userRepository.findByVingHandle(principal.username)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "User not found")
        val mfa = mfaRepo.findByUserId(user.id)
            ?: throw ResponseStatusException(HttpStatus.BAD_REQUEST, "MFA not configured")

        val secret = aes.decrypt(mfa.encryptedSecret)
        if (!totpService.verify(secret, body.code))
            throw ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid TOTP code")

        mfaRepo.delete(mfa)
        auditLogService.logUser(user.myrabaHandle, "MFA_DISABLED", "USER", user.id.toString(),
            details = "TOTP MFA disabled", request = httpRequest)
        return ResponseEntity.ok(mapOf("message" to "MFA disabled"))
    }
}
