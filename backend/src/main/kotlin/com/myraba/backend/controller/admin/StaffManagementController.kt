package com.myraba.backend.controller.admin

import com.myraba.backend.model.User
import com.myraba.backend.model.UserRole
import com.myraba.backend.model.UserStatus
import com.myraba.backend.repository.UserRepository
import com.myraba.backend.service.AuditLogService
import com.myraba.backend.service.EmailService
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.security.core.Authentication
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import java.time.LocalDateTime
import java.util.UUID

@RestController
@RequestMapping("/api/admin/management/staff")
@PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
class StaffManagementController(
    private val userRepository: UserRepository,
    private val passwordEncoder: PasswordEncoder,
    private val auditLogService: AuditLogService,
    private val emailService: EmailService,
    @Value("\${myraba.admin-frontend-url:http://localhost:5173}") private val adminFrontendUrl: String
) {

    data class CreateStaffRequest(
        val fullName: String,
        val email: String,
        val role: String  // STAFF or ADMIN
    )

    data class StaffResponse(
        val id: Long,
        val staffId: String?,
        val fullName: String,
        val email: String?,
        val personalPhone: String?,
        val role: String,
        val status: String,
        val staffActivated: Boolean,
        val createdAt: LocalDateTime
    )

    @PostMapping
    fun createStaff(
        @RequestBody req: CreateStaffRequest,
        auth: Authentication
    ): ResponseEntity<Map<String, Any>> {
        val caller = auth.principal as User

        val role = try { UserRole.valueOf(req.role.uppercase()) }
            catch (e: IllegalArgumentException) {
                throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid role: ${req.role}")
            }

        if (role == UserRole.ADMIN && caller.role != UserRole.SUPER_ADMIN) {
            throw ResponseStatusException(HttpStatus.FORBIDDEN, "Only SUPER_ADMIN can create ADMIN accounts")
        }
        if (role == UserRole.SUPER_ADMIN) {
            throw ResponseStatusException(HttpStatus.FORBIDDEN, "Cannot create SUPER_ADMIN accounts via this endpoint")
        }
        if (role == UserRole.USER) {
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Use /auth/register for customer accounts")
        }

        val email = req.email.trim().lowercase()
        if (userRepository.findByEmail(email) != null) {
            throw ResponseStatusException(HttpStatus.CONFLICT, "Email already in use")
        }

        val staffId = generateStaffId(role)
        val inviteToken = UUID.randomUUID().toString()
        val inviteExpiry = LocalDateTime.now().plusHours(72)

        // Auto-generate an internal myrabaHandle — staff never see or use this
        val handle = generateInternalHandle(req.fullName)

        val staff = User(
            myrabaHandle = handle,
            passwordHash = passwordEncoder.encode(UUID.randomUUID().toString()), // random, unusable until registration
            fullName = req.fullName.trim(),
            email = email,
            role = role,
            kycStatus = "APPROVED",
            staffId = staffId,
            staffInviteToken = inviteToken,
            staffInviteTokenExpiry = inviteExpiry,
            staffActivated = false
        )
        val saved = userRepository.save(staff)

        val inviteLink = "$adminFrontendUrl/complete-registration?token=$inviteToken"
        emailService.sendStaffInvitation(email, req.fullName.trim(), staffId, inviteLink, role.name)

        auditLogService.log(
            adminHandle = caller.myrabaHandle,
            action = "CREATE_STAFF",
            targetType = "STAFF",
            targetId = saved.id.toString(),
            details = "Staff account created: $staffId — ${req.fullName} (${role.name}) — invite sent to $email"
        )

        return ResponseEntity.status(HttpStatus.CREATED).body(mapOf(
            "message" to "Invitation sent to $email. Staff ID: $staffId",
            "staffId" to staffId,
            "role" to role.name
        ))
    }

    @GetMapping
    fun listStaff(auth: Authentication): ResponseEntity<List<StaffResponse>> {
        val caller = auth.principal as User
        val visibleRoles = when (caller.role) {
            UserRole.SUPER_ADMIN -> listOf(UserRole.STAFF, UserRole.ADMIN, UserRole.SUPER_ADMIN)
            UserRole.ADMIN       -> listOf(UserRole.STAFF, UserRole.ADMIN)
            else                 -> listOf(UserRole.STAFF)
        }
        val staff = userRepository.findAll()
            .filter { it.role in visibleRoles }
            .map { it.toResponse() }
        return ResponseEntity.ok(staff)
    }

    @PostMapping("/{id}/resend-invite")
    fun resendInvite(
        @PathVariable id: Long,
        auth: Authentication
    ): ResponseEntity<Map<String, String>> {
        val caller = auth.principal as User
        val target = userRepository.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "Staff not found")
        }
        if (target.role == UserRole.USER) {
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Not a staff account")
        }
        if (target.staffActivated) {
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Staff member has already completed registration")
        }

        val inviteToken = UUID.randomUUID().toString()
        target.staffInviteToken = inviteToken
        target.staffInviteTokenExpiry = LocalDateTime.now().plusHours(72)
        userRepository.save(target)

        val inviteLink = "$adminFrontendUrl/complete-registration?token=$inviteToken"
        target.email?.let {
            emailService.sendStaffInvitation(it, target.fullName, target.staffId ?: "N/A", inviteLink, target.role.name)
        }

        auditLogService.log(
            adminHandle = caller.myrabaHandle,
            action = "RESEND_STAFF_INVITE",
            targetType = "STAFF",
            targetId = id.toString(),
            details = "Invitation resent for ${target.staffId}"
        )

        return ResponseEntity.ok(mapOf("message" to "Invitation resent to ${target.email}"))
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    fun revokeAccess(
        @PathVariable id: Long,
        auth: Authentication
    ): ResponseEntity<Map<String, String>> {
        val caller = auth.principal as User
        val target = userRepository.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "Staff not found")
        }
        if (target.role == UserRole.SUPER_ADMIN && target.id == caller.id) {
            throw ResponseStatusException(HttpStatus.FORBIDDEN, "Cannot revoke your own SUPER_ADMIN access")
        }
        if (target.role == UserRole.USER) {
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Use user management for customer accounts")
        }

        // Suspend without touching the role — keeps audit trail clean
        target.accountStatus = UserStatus.SUSPENDED
        userRepository.save(target)

        auditLogService.log(
            adminHandle = caller.myrabaHandle,
            action = "REVOKE_STAFF_ACCESS",
            targetType = "STAFF",
            targetId = id.toString(),
            details = "Staff access revoked for ${target.staffId} (${target.fullName})"
        )

        return ResponseEntity.ok(mapOf("message" to "Access revoked for ${target.staffId}"))
    }

    private fun generateStaffId(role: UserRole): String {
        val year = LocalDateTime.now().year
        val prefix = if (role == UserRole.ADMIN || role == UserRole.SUPER_ADMIN) "ADM" else "STF"
        val staffRoles = listOf(UserRole.STAFF, UserRole.ADMIN, UserRole.SUPER_ADMIN)
        val count = userRepository.findAll().count { it.role in staffRoles } + 1
        var candidate = "$prefix-$year-${count.toString().padStart(3, '0')}"
        // ensure uniqueness
        var suffix = count
        while (userRepository.findByStaffId(candidate) != null) {
            suffix++
            candidate = "$prefix-$year-${suffix.toString().padStart(3, '0')}"
        }
        return candidate
    }

    private fun generateInternalHandle(fullName: String): String {
        val base = fullName.trim().lowercase()
            .replace(Regex("[^a-z0-9]"), "")
            .take(10)
            .ifBlank { "staff" }
        val chars = "abcdefghjkmnpqrstuvwxyz23456789"
        var candidate: String
        do {
            val suffix = (1..6).map { chars.random() }.joinToString("")
            candidate = "staff_${base}_$suffix"
        } while (userRepository.findByVingHandle(candidate) != null)
        return candidate
    }

    private fun User.toResponse() = StaffResponse(
        id = id,
        staffId = staffId,
        fullName = fullName,
        email = email,
        personalPhone = personalPhone,
        role = role.name,
        status = accountStatus.name,
        staffActivated = staffActivated,
        createdAt = createdAt
    )
}
