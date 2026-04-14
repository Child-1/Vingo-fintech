package com.myraba.backend.controller

import com.myraba.backend.dto.UserResponse
import com.myraba.backend.dto.toResponse
import com.myraba.backend.model.User
import com.myraba.backend.repository.UserRepository
import com.myraba.backend.repository.WalletRepository
import com.myraba.backend.service.AuditLogService
import jakarta.servlet.http.HttpServletRequest
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.Authentication
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException

@RestController
@RequestMapping("/api/users")
class UserController(
    private val userRepository: UserRepository,
    private val walletRepository: WalletRepository,
    private val passwordEncoder: PasswordEncoder,
    private val auditLogService: AuditLogService,
) {

    @GetMapping("/{id}")
    fun getUserById(@PathVariable id: Long): ResponseEntity<UserResponse> {
        val user = userRepository.findById(id).orElse(null)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "User not found")
        val wallet = walletRepository.findByUserVingHandle(user.myrabaHandle)!!
        return ResponseEntity.ok(user.toResponse(wallet.balance.toPlainString()))
    }

    @GetMapping("/me")
    fun getMyProfile(authentication: Authentication): ResponseEntity<UserResponse> {
        val user = authentication.principal as User
        val wallet = walletRepository.findByUserVingHandle(user.myrabaHandle)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Wallet not found")
        return ResponseEntity.ok(user.toResponse(wallet.balance.toPlainString()))
    }

    @GetMapping("/handle/{myrabaHandle}")
    fun getUserByHandle(@PathVariable myrabaHandle: String): ResponseEntity<UserResponse> {
        val user = userRepository.findByVingHandle(myrabaHandle)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "User not found with handle: $myrabaHandle")
        val wallet = walletRepository.findByUserVingHandle(myrabaHandle)!!
        return ResponseEntity.ok(user.toResponse(wallet.balance.toPlainString()))
    }

    @PutMapping("/{id}")
    fun updateUser(
        @PathVariable id: Long,
        @RequestBody updatedUser: User,
        auth: Authentication,
        httpRequest: HttpServletRequest
    ): ResponseEntity<UserResponse> {
        val existingUser = userRepository.findById(id).orElse(null)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "User not found")

        existingUser.fullName = updatedUser.fullName
        existingUser.phone = updatedUser.phone
        existingUser.email = updatedUser.email

        val savedUser = userRepository.save(existingUser)
        val actor = auth.principal as User
        auditLogService.logUser(actor.myrabaHandle, "PROFILE_UPDATE", "USER", id.toString(),
            details = "Updated profile fields", request = httpRequest)
        val wallet = walletRepository.findByUserVingHandle(savedUser.myrabaHandle)!!
        return ResponseEntity.ok(savedUser.toResponse(wallet.balance.toPlainString()))
    }

    data class UpdateProfileRequest(
        val fullName: String?,
        val phone: String?,
        val email: String?,
        val address: String?,
        val customAccountId: String?
    )

    @PutMapping("/me")
    fun updateMyProfile(
        @RequestBody req: UpdateProfileRequest,
        auth: Authentication,
        httpRequest: HttpServletRequest
    ): ResponseEntity<UserResponse> {
        val principal = auth.principal as User
        // Reload fresh from DB — the JWT principal can be stale after a previous update in the same session
        val user = userRepository.findById(principal.id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "User not found")
        }
        if (!req.fullName.isNullOrBlank()) user.fullName = req.fullName
        if (!req.phone.isNullOrBlank()) {
            val existing = userRepository.findByPhone(req.phone)
            if (existing != null && existing.id != user.id)
                throw ResponseStatusException(HttpStatus.CONFLICT, "Phone number already in use")
            user.phone = req.phone
        }
        if (!req.email.isNullOrBlank()) {
            val existing = userRepository.findByEmail(req.email)
            if (existing != null && existing.id != user.id)
                throw ResponseStatusException(HttpStatus.CONFLICT, "Email already in use")
            user.email = req.email
        }
        if (!req.address.isNullOrBlank()) user.address = req.address
        if (!req.customAccountId.isNullOrBlank()) {
            val existing = userRepository.findByCustomAccountId(req.customAccountId)
            if (existing != null && existing.id != user.id)
                throw ResponseStatusException(HttpStatus.CONFLICT, "Custom ID already in use")
            user.customAccountId = req.customAccountId
        }
        val saved = userRepository.save(user)
        auditLogService.logUser(user.myrabaHandle, "PROFILE_UPDATE", "USER", user.id.toString(),
            details = "Self profile update", request = httpRequest)
        val wallet = walletRepository.findByUserVingHandle(saved.myrabaHandle)!!
        return ResponseEntity.ok(saved.toResponse(wallet.balance.toPlainString()))
    }

    data class ChangePasswordRequest(val currentPassword: String, val newPassword: String)

    @PostMapping("/me/change-password")
    fun changePassword(
        @RequestBody req: ChangePasswordRequest,
        auth: Authentication,
        httpRequest: HttpServletRequest
    ): ResponseEntity<Map<String, String>> {
        val user = auth.principal as User
        if (!passwordEncoder.matches(req.currentPassword, user.passwordHash))
            throw ResponseStatusException(HttpStatus.UNAUTHORIZED, "Current password is incorrect")
        if (req.newPassword.length < 8)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "New password must be at least 8 characters")

        user.forcePasswordChange = false
        val updated = user.copy(passwordHash = passwordEncoder.encode(req.newPassword))
        userRepository.save(updated)
        auditLogService.logUser(user.myrabaHandle, "PASSWORD_CHANGE", "USER", user.id.toString(),
            details = "Password changed successfully", request = httpRequest)
        return ResponseEntity.ok(mapOf("message" to "Password changed successfully"))
    }
}
