package com.myraba.backend.controller.admin

import com.myraba.backend.model.User
import com.myraba.backend.model.thrift.DefaultStatus
import com.myraba.backend.model.thrift.PrivateThriftStatus
import com.myraba.backend.model.TransactionType
import com.myraba.backend.repository.thrift.PrivateThriftMemberRepository
import com.myraba.backend.repository.thrift.PrivateThriftRepository
import com.myraba.backend.repository.thrift.ThriftDefaultRepository
import com.myraba.backend.service.AuditLogService
import com.myraba.backend.service.WalletService
import org.springframework.data.domain.PageRequest
import org.springframework.data.domain.Sort
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.security.core.Authentication
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import java.math.BigDecimal

data class DisputeResolutionBody(
    val resolved: Boolean,        // true = user proved they paid, false = forfeit
    val adminNote: String? = null
)

data class CancelThriftBody(val reason: String)

@RestController
@RequestMapping("/api/admin/private-thrifts")
@PreAuthorize("hasAnyRole('STAFF','ADMIN','SUPER_ADMIN')")
class AdminPrivateThriftController(
    private val thriftRepo: PrivateThriftRepository,
    private val memberRepo: PrivateThriftMemberRepository,
    private val defaultRepo: ThriftDefaultRepository,
    private val walletService: WalletService,
    private val auditLogService: AuditLogService
) {

    @GetMapping
    fun listAll(
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int
    ): ResponseEntity<Any> {
        val pageable = PageRequest.of(page, size, Sort.by("createdAt").descending())
        val result = thriftRepo.findAll(pageable)
        return ResponseEntity.ok(
            mapOf(
                "content" to result.content.map { t ->
                    mapOf(
                        "id"                 to t.id,
                        "name"               to t.name,
                        "creator"            to "m₦${t.creator.myrabaHandle}",
                        "status"             to t.status.name,
                        "contributionAmount" to t.contributionAmount.toPlainString(),
                        "frequency"          to t.frequency,
                        "currentCycle"       to t.currentCycle,
                        "totalCycles"        to t.totalCycles,
                        "memberCount"        to t.members.size,
                        "createdAt"          to t.createdAt.toString()
                    )
                },
                "totalElements" to result.totalElements,
                "totalPages"    to result.totalPages
            )
        )
    }

    @GetMapping("/defaults")
    fun listDefaults(
        @RequestParam(defaultValue = "FROZEN") status: String
    ): ResponseEntity<Any> {
        val statusEnum = try { DefaultStatus.valueOf(status) }
            catch (e: Exception) { throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid status") }

        val defaults = defaultRepo.findByStatus(statusEnum).map { d ->
            mapOf(
                "id"             to d.id,
                "defaulter"      to "m₦${d.defaulter.myrabaHandle}",
                "creator"        to "m₦${d.creator.myrabaHandle}",
                "thrift"         to d.thrift.name,
                "amountOwed"     to d.amountOwed.toPlainString(),
                "status"         to d.status.name,
                "disputeRound"   to d.disputeRound,
                "disputeDeadline" to d.disputeDeadline?.toString(),
                "flaggedAt"      to d.flaggedAt.toString(),
                "frozenAt"       to d.frozenAt?.toString(),
                "disputeProof"   to d.disputeProofNote
            )
        }
        return ResponseEntity.ok(mapOf("defaults" to defaults, "total" to defaults.size))
    }

    @PutMapping("/defaults/{id}/resolve")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    fun resolveDispute(
        @PathVariable id: Long,
        @RequestBody body: DisputeResolutionBody
    ): ResponseEntity<Any> {
        val default = defaultRepo.findById(id).orElse(null)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Default record not found")

        if (default.status != DefaultStatus.FROZEN && default.status != DefaultStatus.DISPUTED)
            throw ResponseStatusException(HttpStatus.CONFLICT, "Default is not in a resolvable state")

        default.adminNote = body.adminNote

        return if (body.resolved) {
            // User proved they paid — release funds back to them
            // Funds were already deducted from their wallet when frozen
            // We need to credit them back
            default.status = DefaultStatus.RESOLVED
            defaultRepo.save(default)
            ResponseEntity.ok(mapOf("message" to "Dispute resolved in favour of user. Funds released.", "status" to "RESOLVED"))
        } else {
            // Forfeit — handled by scheduler, but admin can trigger early
            default.status = DefaultStatus.FORFEITED
            defaultRepo.save(default)
            ResponseEntity.ok(mapOf("message" to "Funds forfeited to creator.", "status" to "FORFEITED"))
        }
    }

    /** Cancel a private thrift — refunds any current-cycle contributions to members */
    @PutMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    @Transactional
    fun cancelThrift(
        @PathVariable id: Long,
        @RequestBody body: CancelThriftBody,
        auth: Authentication
    ): ResponseEntity<Any> {
        val admin = auth.principal as User
        val thrift = thriftRepo.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "Private thrift not found")
        }
        if (thrift.status == PrivateThriftStatus.COMPLETED)
            throw ResponseStatusException(HttpStatus.CONFLICT, "Cannot cancel a completed thrift")
        if (thrift.status == PrivateThriftStatus.CANCELLED)
            throw ResponseStatusException(HttpStatus.CONFLICT, "Thrift is already cancelled")

        // Refund current-cycle contributions to all members
        var refundCount = 0
        val members = memberRepo.findByThrift(thrift)
        for (member in members) {
            if (member.currentCycleContributed > BigDecimal.ZERO) {
                walletService.creditWallet(
                    user = member.user,
                    amount = member.currentCycleContributed,
                    description = "Refund — thrift '${thrift.name}' cancelled by admin",
                    type = TransactionType.FUNDED
                )
                refundCount++
            }
        }

        thrift.status = PrivateThriftStatus.CANCELLED
        thriftRepo.save(thrift)

        auditLogService.log(
            adminHandle = admin.myrabaHandle,
            action = "CANCEL_PRIVATE_THRIFT",
            targetType = "PRIVATE_THRIFT",
            targetId = id.toString(),
            details = "Cancelled private thrift '${thrift.name}'. Reason: ${body.reason}. Refunded $refundCount members."
        )

        return ResponseEntity.ok(mapOf(
            "message"      to "Thrift '${thrift.name}' cancelled. $refundCount member(s) refunded.",
            "refundCount"  to refundCount,
            "status"       to "CANCELLED"
        ))
    }

    /** Hard-delete a private thrift — SUPER_ADMIN only, intended for test data cleanup */
    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    @Transactional
    fun deleteThrift(
        @PathVariable id: Long,
        auth: Authentication
    ): ResponseEntity<Any> {
        val admin = auth.principal as User
        val thrift = thriftRepo.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "Private thrift not found")
        }
        val name = thrift.name
        thriftRepo.delete(thrift)

        auditLogService.log(
            adminHandle = admin.myrabaHandle,
            action = "DELETE_PRIVATE_THRIFT",
            targetType = "PRIVATE_THRIFT",
            targetId = id.toString(),
            details = "Hard-deleted private thrift '$name'"
        )

        return ResponseEntity.ok(mapOf("message" to "Private thrift '$name' deleted."))
    }
}
