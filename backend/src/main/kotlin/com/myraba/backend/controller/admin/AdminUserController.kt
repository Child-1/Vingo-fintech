package com.myraba.backend.controller.admin

import com.myraba.backend.model.User
import com.myraba.backend.model.UserRole
import com.myraba.backend.model.UserStatus
import com.myraba.backend.repository.UserRepository
import com.myraba.backend.repository.WalletRepository
import com.myraba.backend.service.AuditLogService
import org.springframework.data.domain.PageRequest
import org.springframework.data.domain.Sort
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import java.time.LocalDateTime

@RestController
@RequestMapping("/api/admin/users")
@PreAuthorize("hasAnyRole('STAFF', 'ADMIN', 'SUPER_ADMIN')")
class AdminUserController(
    private val userRepository: UserRepository,
    private val walletRepository: WalletRepository,
    private val auditLogService: AuditLogService
) {

    data class AdminUserResponse(
        val id: Long,
        val myrabaHandle: String,
        val fullName: String,
        val phone: String?,
        val email: String?,
        val accountNumber: String?,
        val customAccountId: String?,
        val staffId: String?,
        val role: String,
        val kycStatus: String,
        val accountStatus: String,
        val balance: String,
        val createdAt: LocalDateTime
    )

    data class UpdateRoleRequest(val role: String)
    data class UpdateKycRequest(val status: String)
    data class AccountActionRequest(val reason: String = "")

    // ── List / Search ─────────────────────────────────────────────

    @GetMapping
    fun listUsers(
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int,
        @RequestParam(required = false) search: String?,
        @RequestParam(required = false) status: String?,
        @RequestParam(required = false) kycStatus: String?,
        @RequestParam(required = false) role: String?
    ): ResponseEntity<Map<String, Any>> {
        val pageable = PageRequest.of(page, size, Sort.by("createdAt").descending())

        val users = if (!search.isNullOrBlank()) {
            userRepository.searchUsers(search, pageable)
        } else if (!status.isNullOrBlank()) {
            val accountStatus = try { UserStatus.valueOf(status.uppercase()) }
                catch (e: IllegalArgumentException) { throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid status: $status") }
            userRepository.findByAccountStatus(accountStatus, pageable)
        } else {
            userRepository.findAll(pageable)
        }

        var content = users.content
        if (!kycStatus.isNullOrBlank()) content = content.filter { it.kycStatus.equals(kycStatus, ignoreCase = true) }
        if (!role.isNullOrBlank()) content = content.filter { it.role.name.equals(role, ignoreCase = true) }

        return ResponseEntity.ok(mapOf(
            "users" to content.map { it.toAdminResponse() },
            "total" to users.totalElements,
            "page" to page,
            "size" to size
        ))
    }

    @GetMapping("/{id}")
    fun getUser(@PathVariable id: Long): ResponseEntity<AdminUserResponse> {
        val user = userRepository.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "User not found")
        }
        return ResponseEntity.ok(user.toAdminResponse())
    }

    // ── Role Management ───────────────────────────────────────────

    @PutMapping("/{id}/role")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
    fun updateRole(
        @PathVariable id: Long,
        @RequestBody req: UpdateRoleRequest,
        auth: Authentication
    ): ResponseEntity<AdminUserResponse> {
        val user = userRepository.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "User not found")
        }
        val newRole = try { UserRole.valueOf(req.role.uppercase()) }
            catch (e: IllegalArgumentException) { throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid role: ${req.role}") }

        val caller = auth.principal as User
        if (user.role == UserRole.USER) {
            throw ResponseStatusException(HttpStatus.FORBIDDEN, "App users cannot be promoted. Create a staff account separately.")
        }
        if (newRole == UserRole.USER) {
            throw ResponseStatusException(HttpStatus.FORBIDDEN, "Cannot demote a staff account to USER role.")
        }
        if (newRole == UserRole.SUPER_ADMIN && caller.role != UserRole.SUPER_ADMIN) {
            throw ResponseStatusException(HttpStatus.FORBIDDEN, "Only SUPER_ADMIN can assign the SUPER_ADMIN role")
        }

        val oldRole = user.role.name
        user.role = newRole
        val saved = userRepository.save(user)

        auditLogService.log(
            adminHandle = (auth.principal as User).myrabaHandle,
            action = "UPDATE_ROLE",
            targetType = "USER",
            targetId = id.toString(),
            details = "Role changed for @${user.myrabaHandle}",
            previousValue = oldRole,
            newValue = newRole.name
        )
        return ResponseEntity.ok(saved.toAdminResponse())
    }

    // ── KYC Management ────────────────────────────────────────────

    @PutMapping("/{id}/kyc")
    fun updateKycStatus(
        @PathVariable id: Long,
        @RequestBody req: UpdateKycRequest,
        auth: Authentication
    ): ResponseEntity<AdminUserResponse> {
        val validStatuses = setOf("NONE", "PENDING", "APPROVED", "REJECTED")
        if (req.status.uppercase() !in validStatuses) {
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid KYC status: ${req.status}")
        }
        val user = userRepository.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "User not found")
        }
        val oldStatus = user.kycStatus
        user.kycStatus = req.status.uppercase()
        val saved = userRepository.save(user)

        auditLogService.log(
            adminHandle = (auth.principal as User).myrabaHandle,
            action = "UPDATE_KYC",
            targetType = "USER",
            targetId = id.toString(),
            details = "KYC status updated for @${user.myrabaHandle}",
            previousValue = oldStatus,
            newValue = req.status.uppercase()
        )
        return ResponseEntity.ok(saved.toAdminResponse())
    }

    @GetMapping("/kyc/pending")
    fun getPendingKyc(): ResponseEntity<List<AdminUserResponse>> {
        val users = userRepository.findAll()
            .filter { it.kycStatus == "PENDING" }
            .map { it.toAdminResponse() }
        return ResponseEntity.ok(users)
    }

    // ── Account Status: Freeze / Suspend / Activate ───────────────

    @PostMapping("/{id}/freeze")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
    fun freezeAccount(
        @PathVariable id: Long,
        @RequestBody(required = false) req: AccountActionRequest?,
        auth: Authentication
    ): ResponseEntity<AdminUserResponse> {
        return changeAccountStatus(id, UserStatus.FROZEN, "FREEZE_ACCOUNT", req?.reason ?: "", auth)
    }

    @PostMapping("/{id}/suspend")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
    fun suspendAccount(
        @PathVariable id: Long,
        @RequestBody(required = false) req: AccountActionRequest?,
        auth: Authentication
    ): ResponseEntity<AdminUserResponse> {
        return changeAccountStatus(id, UserStatus.SUSPENDED, "SUSPEND_ACCOUNT", req?.reason ?: "", auth)
    }

    @PostMapping("/{id}/activate")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
    fun activateAccount(
        @PathVariable id: Long,
        @RequestBody(required = false) req: AccountActionRequest?,
        auth: Authentication
    ): ResponseEntity<AdminUserResponse> {
        return changeAccountStatus(id, UserStatus.ACTIVE, "ACTIVATE_ACCOUNT", req?.reason ?: "", auth)
    }

    private fun changeAccountStatus(
        id: Long,
        newStatus: UserStatus,
        action: String,
        reason: String,
        auth: Authentication
    ): ResponseEntity<AdminUserResponse> {
        val user = userRepository.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "User not found")
        }
        val oldStatus = user.accountStatus.name
        user.accountStatus = newStatus
        val saved = userRepository.save(user)

        auditLogService.log(
            adminHandle = (auth.principal as User).myrabaHandle,
            action = action,
            targetType = "USER",
            targetId = id.toString(),
            details = "Account ${newStatus.name.lowercase()} for @${user.myrabaHandle}. Reason: $reason",
            previousValue = oldStatus,
            newValue = newStatus.name
        )
        return ResponseEntity.ok(saved.toAdminResponse())
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    fun deleteUser(
        @PathVariable id: Long,
        auth: Authentication
    ): ResponseEntity<Map<String, String>> {
        val user = userRepository.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "User not found")
        }
        val handle = user.myrabaHandle
        userRepository.delete(user)
        auditLogService.log(
            adminHandle = (auth.principal as User).myrabaHandle,
            action = "DELETE_USER",
            targetType = "USER",
            targetId = id.toString(),
            details = "Deleted user @$handle"
        )
        return ResponseEntity.ok(mapOf("message" to "User @$handle deleted successfully"))
    }

    // ── Stats ─────────────────────────────────────────────────────

    @GetMapping("/stats/overview")
    fun getUserStats(): ResponseEntity<Map<String, Any>> {
        return ResponseEntity.ok(mapOf(
            "total" to userRepository.count(),
            "active" to userRepository.countByAccountStatus(UserStatus.ACTIVE),
            "suspended" to userRepository.countByAccountStatus(UserStatus.SUSPENDED),
            "frozen" to userRepository.countByAccountStatus(UserStatus.FROZEN),
            "kycPending" to userRepository.countByKycStatus("PENDING"),
            "kycApproved" to userRepository.countByKycStatus("APPROVED"),
            "kycRejected" to userRepository.countByKycStatus("REJECTED")
        ))
    }

    // ── User growth over time ──────────────────────────────────────

    @GetMapping("/growth")
    fun getUserGrowth(
        @RequestParam(defaultValue = "daily") period: String,
        @RequestParam(defaultValue = "30") count: Int
    ): ResponseEntity<Any> {
        val now = LocalDateTime.now()
        val data = when (period.lowercase()) {
            "hourly" -> (count - 1 downTo 0).map { i ->
                val from = now.minusHours(i.toLong() + 1)
                val to   = now.minusHours(i.toLong())
                mapOf("label" to "${to.hour}:00", "count" to userRepository.countByCreatedAtBetween(from, to))
            }
            "weekly" -> (count - 1 downTo 0).map { i ->
                val from = now.minusWeeks(i.toLong() + 1)
                val to   = now.minusWeeks(i.toLong())
                val label = "W${to.toLocalDate()}"
                mapOf("label" to label, "count" to userRepository.countByCreatedAtBetween(from, to))
            }
            "monthly" -> (count - 1 downTo 0).map { i ->
                val from = now.minusMonths(i.toLong() + 1)
                val to   = now.minusMonths(i.toLong())
                val label = "${from.month.name.take(3)} ${from.year}"
                mapOf("label" to label, "count" to userRepository.countByCreatedAtBetween(from, to))
            }
            "yearly" -> (count - 1 downTo 0).map { i ->
                val from = now.minusYears(i.toLong() + 1)
                val to   = now.minusYears(i.toLong())
                mapOf("label" to from.year.toString(), "count" to userRepository.countByCreatedAtBetween(from, to))
            }
            else -> // daily (default)
                (count - 1 downTo 0).map { i ->
                    val from = now.minusDays(i.toLong() + 1)
                    val to   = now.minusDays(i.toLong())
                    mapOf("label" to from.toLocalDate().toString().substring(5), "count" to userRepository.countByCreatedAtBetween(from, to))
                }
        }
        return ResponseEntity.ok(mapOf("period" to period, "data" to data))
    }

    // ── Helper ────────────────────────────────────────────────────

    private fun User.toAdminResponse(): AdminUserResponse {
        val wallet = walletRepository.findByUserVingHandle(this.myrabaHandle)
        return AdminUserResponse(
            id = this.id,
            myrabaHandle = this.myrabaHandle,
            fullName = this.fullName,
            phone = this.phone,
            email = this.email,
            accountNumber = this.accountNumber,
            customAccountId = this.customAccountId,
            staffId = this.staffId,
            role = this.role.name,
            kycStatus = this.kycStatus,
            accountStatus = this.accountStatus.name,
            balance = wallet?.balance?.toPlainString() ?: "0.00",
            createdAt = this.createdAt
        )
    }
}
