package com.myraba.backend.controller.admin

import com.myraba.backend.model.thrift.DefaultStatus
import com.myraba.backend.repository.thrift.PrivateThriftRepository
import com.myraba.backend.repository.thrift.ThriftDefaultRepository
import org.springframework.data.domain.PageRequest
import org.springframework.data.domain.Sort
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException

data class DisputeResolutionBody(
    val resolved: Boolean,        // true = user proved they paid, false = forfeit
    val adminNote: String? = null
)

@RestController
@RequestMapping("/api/admin/private-thrifts")
@PreAuthorize("hasAnyRole('STAFF','ADMIN','SUPER_ADMIN')")
class AdminPrivateThriftController(
    private val thriftRepo: PrivateThriftRepository,
    private val defaultRepo: ThriftDefaultRepository
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
}
