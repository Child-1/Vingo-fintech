package com.myraba.backend.controller.admin

import com.myraba.backend.dto.AdminLoginRequest
import com.myraba.backend.dto.AdminLoginResponse
import com.myraba.backend.dto.CompleteRegistrationRequest
import com.myraba.backend.model.UserRole
import com.myraba.backend.repository.UserRepository
import com.myraba.backend.service.AuditLogService
import com.myraba.backend.util.JwtUtil
import jakarta.servlet.http.HttpServletRequest
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.authentication.AuthenticationManager
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken
import org.springframework.security.core.userdetails.UserDetailsService
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import java.time.LocalDateTime

@RestController
@RequestMapping("/admin/auth")
class AdminAuthController(
    private val userRepository: UserRepository,
    private val authenticationManager: AuthenticationManager,
    private val userDetailsService: UserDetailsService,
    private val jwtUtil: JwtUtil,
    private val passwordEncoder: PasswordEncoder,
    private val auditLogService: AuditLogService,
) {

    @PostMapping("/login")
    fun staffLogin(
        @RequestBody req: AdminLoginRequest,
        httpRequest: HttpServletRequest
    ): ResponseEntity<AdminLoginResponse> {
        val staffId = req.staffId.trim()

        val user = userRepository.findByStaffId(staffId)
            ?: throw ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid Staff ID or password")

        if (user.role == UserRole.USER) {
            throw ResponseStatusException(HttpStatus.FORBIDDEN, "This portal is for staff only.")
        }

        if (!user.staffActivated) {
            throw ResponseStatusException(
                HttpStatus.FORBIDDEN,
                "Account not yet activated. Please complete registration via the invitation link sent to your email."
            )
        }

        if (user.accountStatus.name == "SUSPENDED" || user.accountStatus.name == "FROZEN") {
            throw ResponseStatusException(HttpStatus.FORBIDDEN, "Your account has been suspended. Contact a Super Admin.")
        }

        try {
            authenticationManager.authenticate(
                UsernamePasswordAuthenticationToken(user.myrabaHandle, req.password)
            )
        } catch (e: Exception) {
            auditLogService.log(
                adminHandle = staffId,
                action = "ADMIN_LOGIN_FAILED",
                targetType = "STAFF",
                targetId = user.id.toString(),
                details = "Failed admin login attempt for Staff ID: $staffId"
            )
            throw ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid Staff ID or password")
        }

        val userDetails = userDetailsService.loadUserByUsername(user.myrabaHandle)
        val token = jwtUtil.generateToken(userDetails)

        auditLogService.log(
            adminHandle = user.myrabaHandle,
            action = "ADMIN_LOGIN",
            targetType = "STAFF",
            targetId = user.id.toString(),
            details = "Staff login: $staffId (${user.role.name})"
        )

        return ResponseEntity.ok(
            AdminLoginResponse(
                token = token,
                staffId = user.staffId!!,
                fullName = user.fullName,
                role = user.role.name
            )
        )
    }

    @PostMapping("/complete-registration")
    fun completeRegistration(
        @RequestBody req: CompleteRegistrationRequest,
        httpRequest: HttpServletRequest
    ): ResponseEntity<AdminLoginResponse> {
        if (req.password.length < 8) {
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Password must be at least 8 characters")
        }

        val user = userRepository.findByStaffInviteToken(req.token.trim())
            ?: throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid or expired invitation link")

        if (user.staffInviteTokenExpiry == null || LocalDateTime.now().isAfter(user.staffInviteTokenExpiry)) {
            throw ResponseStatusException(
                HttpStatus.BAD_REQUEST,
                "This invitation link has expired. Ask a Super Admin to resend the invitation."
            )
        }

        user.staffInviteToken = null
        user.staffInviteTokenExpiry = null
        user.staffActivated = true
        user.personalPhone = req.personalPhone?.trim()?.takeIf { it.isNotBlank() }
        user.dateOfBirth = req.dateOfBirth?.trim()?.takeIf { it.isNotBlank() }
        user.address = req.homeAddress?.trim()?.takeIf { it.isNotBlank() }

        val updated = user.copy(passwordHash = passwordEncoder.encode(req.password))
        userRepository.save(updated)

        auditLogService.log(
            adminHandle = user.myrabaHandle,
            action = "STAFF_REGISTRATION_COMPLETED",
            targetType = "STAFF",
            targetId = user.id.toString(),
            details = "Staff member completed registration: ${user.staffId}"
        )

        val userDetails = userDetailsService.loadUserByUsername(user.myrabaHandle)
        val token = jwtUtil.generateToken(userDetails)

        return ResponseEntity.ok(
            AdminLoginResponse(
                token = token,
                staffId = user.staffId!!,
                fullName = user.fullName,
                role = user.role.name
            )
        )
    }
}
