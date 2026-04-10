package com.myraba.backend.controller.admin

import com.myraba.backend.model.User
import com.myraba.backend.model.UserRole
import com.myraba.backend.model.UserStatus
import com.myraba.backend.model.Wallet
import com.myraba.backend.repository.UserRepository
import com.myraba.backend.repository.WalletRepository
import com.myraba.backend.service.AuditLogService
import com.myraba.backend.service.EmailService
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.security.core.Authentication
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import java.security.SecureRandom
import java.time.LocalDateTime

@RestController
@RequestMapping("/api/admin/management/staff")
@PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
class StaffManagementController(
    private val userRepository: UserRepository,
    private val walletRepository: WalletRepository,
    private val passwordEncoder: PasswordEncoder,
    private val auditLogService: AuditLogService,
    private val emailService: EmailService
) {

    data class CreateStaffRequest(
        val fullName: String,
        val email: String,
        val phone: String?,
        val myrabaHandle: String,
        val role: String  // STAFF or ADMIN
    )

    data class StaffResponse(
        val id: Long,
        val myrabaHandle: String,
        val fullName: String,
        val email: String?,
        val phone: String?,
        val role: String,
        val status: String,
        val forcePasswordChange: Boolean,
        val createdAt: LocalDateTime
    )

    @PostMapping
    fun createStaff(
        @RequestBody req: CreateStaffRequest,
        auth: Authentication
    ): ResponseEntity<Map<String, Any>> {
        val caller = auth.principal as User

        val role = try { UserRole.valueOf(req.role.uppercase()) }
            catch (e: IllegalArgumentException) { throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid role: ${req.role}") }

        // Only SUPER_ADMIN can create ADMIN-level staff
        if (role == UserRole.ADMIN && caller.role != UserRole.SUPER_ADMIN) {
            throw ResponseStatusException(HttpStatus.FORBIDDEN, "Only SUPER_ADMIN can create ADMIN accounts")
        }
        if (role == UserRole.SUPER_ADMIN) {
            throw ResponseStatusException(HttpStatus.FORBIDDEN, "Cannot create SUPER_ADMIN accounts via this endpoint")
        }
        if (role == UserRole.USER) {
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Use /auth/register for customer accounts")
        }

        if (userRepository.findByVingHandle(req.myrabaHandle) != null)
            throw ResponseStatusException(HttpStatus.CONFLICT, "Handle already taken: ${req.myrabaHandle}")
        if (userRepository.findByEmail(req.email) != null)
            throw ResponseStatusException(HttpStatus.CONFLICT, "Email already in use")

        val tempPassword = generateTempPassword()
        val accountNumber = (2000000000L + SecureRandom().nextInt(999999999)).toString()

        val staff = User(
            myrabaHandle = req.myrabaHandle,
            passwordHash = passwordEncoder.encode(tempPassword),
            fullName = req.fullName,
            phone = req.phone,
            email = req.email,
            accountNumber = accountNumber,
            role = role,
            kycStatus = "APPROVED",
            forcePasswordChange = true
        )
        val saved = userRepository.save(staff)
        walletRepository.save(Wallet(user = saved))

        emailService.sendStaffWelcome(req.email, req.fullName, req.myrabaHandle, tempPassword, role.name)

        auditLogService.log(
            adminHandle = caller.myrabaHandle,
            action = "CREATE_STAFF",
            targetType = "USER",
            targetId = saved.id.toString(),
            details = "Staff account created: @${saved.myrabaHandle} (${role.name})"
        )

        return ResponseEntity.status(HttpStatus.CREATED).body(mapOf(
            "message" to "Staff account created. Temporary password sent to ${req.email}",
            "myrabaHandle" to saved.myrabaHandle,
            "role" to role.name
        ))
    }

    @GetMapping
    fun listStaff(auth: Authentication): ResponseEntity<List<StaffResponse>> {
        val caller = auth.principal as User
        val visibleRoles = when (caller.role) {
            UserRole.SUPER_ADMIN -> listOf(UserRole.STAFF, UserRole.ADMIN, UserRole.SUPER_ADMIN)
            UserRole.ADMIN       -> listOf(UserRole.STAFF, UserRole.ADMIN)
            else                 -> listOf(UserRole.STAFF)  // STAFF can only see other STAFF
        }
        val staff = userRepository.findAll()
            .filter { it.role in visibleRoles }
            .map { it.toResponse() }
        return ResponseEntity.ok(staff)
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    fun revokeAccess(
        @PathVariable id: Long,
        auth: Authentication
    ): ResponseEntity<Map<String, String>> {
        val caller = auth.principal as User
        val target = userRepository.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "User not found")
        }
        if (target.role == UserRole.SUPER_ADMIN && target.id == caller.id)
            throw ResponseStatusException(HttpStatus.FORBIDDEN, "Cannot revoke your own SUPER_ADMIN access")
        if (target.role == UserRole.USER)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Use user management for customer accounts")

        target.role = UserRole.USER
        target.accountStatus = UserStatus.SUSPENDED
        userRepository.save(target)

        auditLogService.log(
            adminHandle = caller.myrabaHandle,
            action = "REVOKE_STAFF_ACCESS",
            targetType = "USER",
            targetId = id.toString(),
            details = "Staff access revoked for @${target.myrabaHandle}"
        )

        return ResponseEntity.ok(mapOf("message" to "Access revoked for @${target.myrabaHandle}"))
    }

    @PutMapping("/{id}/reset-password")
    fun resetStaffPassword(
        @PathVariable id: Long,
        auth: Authentication
    ): ResponseEntity<Map<String, String>> {
        val caller = auth.principal as User
        val target = userRepository.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "User not found")
        }
        if (target.role == UserRole.USER)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Not a staff account")

        val tempPassword = generateTempPassword()
        target.forcePasswordChange = true
        userRepository.save(target.copy(passwordHash = passwordEncoder.encode(tempPassword)))

        target.email?.let {
            emailService.sendStaffWelcome(it, target.fullName, target.myrabaHandle, tempPassword, target.role.name)
        }

        auditLogService.log(
            adminHandle = caller.myrabaHandle,
            action = "RESET_STAFF_PASSWORD",
            targetType = "USER",
            targetId = id.toString(),
            details = "Password reset for @${target.myrabaHandle}"
        )

        return ResponseEntity.ok(mapOf("message" to "Password reset. New temporary password sent to staff email."))
    }

    private fun generateTempPassword(): String {
        val chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!@#"
        val rng = SecureRandom()
        return (1..12).map { chars[rng.nextInt(chars.length)] }.joinToString("")
    }

    private fun User.toResponse() = StaffResponse(
        id = id, myrabaHandle = myrabaHandle, fullName = fullName,
        email = email, phone = phone, role = role.name,
        status = accountStatus.name, forcePasswordChange = forcePasswordChange,
        createdAt = createdAt
    )
}
