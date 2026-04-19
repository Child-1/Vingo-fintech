package com.myraba.backend.controller

import com.myraba.backend.model.DisputeRequest
import com.myraba.backend.model.DisputeStatus
import com.myraba.backend.model.User
import com.myraba.backend.repository.DisputeRepository
import com.myraba.backend.repository.TransactionRepository
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException

data class FileDisputeRequest(
    val transactionId: Long,
    val reason: String,       // WRONG_TRANSFER | DUPLICATE | FRAUD | OTHER
    val description: String,
)

@RestController
@RequestMapping("/api/disputes")
class DisputeController(
    private val disputeRepo: DisputeRepository,
    private val txRepo: TransactionRepository,
) {
    @PostMapping
    fun file(@RequestBody req: FileDisputeRequest, auth: Authentication): ResponseEntity<Any> {
        val user = auth.principal as User
        val tx = txRepo.findById(req.transactionId).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "Transaction not found")
        }
        if (req.description.isBlank())
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Please describe the issue")

        val dispute = disputeRepo.save(DisputeRequest(
            user = user,
            transaction = tx,
            reason = req.reason.uppercase(),
            description = req.description.trim(),
        ))
        return ResponseEntity.status(HttpStatus.CREATED).body(mapOf(
            "id"      to dispute.id,
            "status"  to dispute.status.name,
            "message" to "Dispute filed. Our team will review within 2–3 business days.",
        ))
    }

    @GetMapping("/my")
    fun myDisputes(auth: Authentication): ResponseEntity<Any> {
        val user = auth.principal as User
        val disputes = disputeRepo.findByUserOrderByCreatedAtDesc(user)
        return ResponseEntity.ok(mapOf("disputes" to disputes.map { it.toDto() }))
    }
}

// ── Admin dispute endpoints ────────────────────────────────────────────────────
@RestController
@RequestMapping("/api/admin/disputes")
class AdminDisputeController(private val disputeRepo: DisputeRepository) {

    @GetMapping
    fun list(): ResponseEntity<Any> {
        return ResponseEntity.ok(mapOf("disputes" to disputeRepo.findAllByOrderByCreatedAtDesc().map { it.toDto() }))
    }

    @PutMapping("/{id}")
    fun update(
        @PathVariable id: Long,
        @RequestBody body: Map<String, String>,
        auth: Authentication,
    ): ResponseEntity<Any> {
        val admin = auth.principal as User
        val dispute = disputeRepo.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "Dispute not found")
        }
        body["status"]?.let { dispute.status = DisputeStatus.valueOf(it.uppercase()) }
        body["adminNote"]?.let { dispute.adminNote = it }
        dispute.reviewedBy = admin
        if (dispute.status in listOf(DisputeStatus.RESOLVED, DisputeStatus.REJECTED))
            dispute.resolvedAt = java.time.LocalDateTime.now()
        disputeRepo.save(dispute)
        return ResponseEntity.ok(dispute.toDto())
    }
}

private fun DisputeRequest.toDto() = mapOf(
    "id"            to id,
    "transactionId" to transaction.id,
    "reason"        to reason,
    "description"   to description,
    "status"        to status.name,
    "adminNote"     to adminNote,
    "createdAt"     to createdAt,
    "resolvedAt"    to resolvedAt,
)
