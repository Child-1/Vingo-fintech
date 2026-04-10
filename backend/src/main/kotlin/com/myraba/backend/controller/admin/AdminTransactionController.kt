package com.myraba.backend.controller.admin

import com.myraba.backend.model.Transaction
import com.myraba.backend.model.TransactionType
import com.myraba.backend.model.User
import com.myraba.backend.repository.TransactionRepository
import com.myraba.backend.repository.UserRepository
import com.myraba.backend.repository.WalletRepository
import com.myraba.backend.service.AuditLogService
import org.springframework.data.domain.PageRequest
import org.springframework.data.domain.Sort
import org.springframework.format.annotation.DateTimeFormat
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import java.math.BigDecimal
import java.time.LocalDateTime

@RestController
@RequestMapping("/api/admin/transactions")
@PreAuthorize("hasAnyRole('STAFF', 'ADMIN', 'SUPER_ADMIN')")
class AdminTransactionController(
    private val transactionRepository: TransactionRepository,
    private val userRepository: UserRepository,
    private val walletRepository: WalletRepository,
    private val auditLogService: AuditLogService
) {

    data class AdminTransactionResponse(
        val id: Long,
        val type: String,
        val amount: String,
        val fee: String?,
        val description: String?,
        val senderHandle: String?,
        val receiverHandle: String?,
        val status: String,
        val createdAt: LocalDateTime
    )

    data class ReverseRequest(val reason: String)

    // ── List with full filters ────────────────────────────────────

    @GetMapping
    fun listTransactions(
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int,
        @RequestParam(required = false) type: String?,
        @RequestParam(required = false) status: String?,
        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) from: LocalDateTime?,
        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) to: LocalDateTime?,
        @RequestParam(required = false) minAmount: BigDecimal?,
        @RequestParam(required = false) maxAmount: BigDecimal?
    ): ResponseEntity<Map<String, Any>> {
        val pageable = PageRequest.of(page, size, Sort.by("createdAt").descending())
        val txType = type?.uppercase()?.let { runCatching { TransactionType.valueOf(it) }.getOrNull() }
        val result = transactionRepository.filterTransactions(
            type = txType,
            status = status,
            from = from,
            to = to,
            minAmount = minAmount,
            maxAmount = maxAmount,
            pageable = pageable
        )
        return ResponseEntity.ok(mapOf(
            "transactions" to result.content.map { it.toAdminResponse() },
            "total" to result.totalElements,
            "page" to page,
            "size" to size
        ))
    }

    @GetMapping("/{id}")
    fun getTransaction(@PathVariable id: Long): ResponseEntity<AdminTransactionResponse> {
        val tx = transactionRepository.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "Transaction not found")
        }
        return ResponseEntity.ok(tx.toAdminResponse())
    }

    // ── Reversal ─────────────────────────────────────────────────

    @PostMapping("/{id}/reverse")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
    fun reverseTransaction(
        @PathVariable id: Long,
        @RequestBody req: ReverseRequest,
        auth: Authentication
    ): ResponseEntity<Map<String, Any>> {
        val tx = transactionRepository.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "Transaction not found")
        }

        if (tx.status != "SUCCESS") {
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Only SUCCESS transactions can be reversed")
        }
        if (tx.type !in setOf(TransactionType.TRANSFER, TransactionType.FUNDED, TransactionType.ADMIN_CREDIT)) {
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Only TRANSFER, FUNDED, or ADMIN_CREDIT transactions can be reversed")
        }

        val senderWallet = tx.senderWallet
        val receiverWallet = tx.receiverWallet

        if (senderWallet != null) {
            senderWallet.balance = senderWallet.balance.add(tx.amount)
            walletRepository.save(senderWallet)
        }
        if (receiverWallet != null) {
            if (receiverWallet.balance < tx.amount) {
                throw ResponseStatusException(HttpStatus.CONFLICT, "Receiver has insufficient balance to reverse")
            }
            receiverWallet.balance = receiverWallet.balance.subtract(tx.amount)
            walletRepository.save(receiverWallet)
        }

        val reversalTx = transactionRepository.save(
            Transaction(
                senderWallet = receiverWallet,
                receiverWallet = senderWallet,
                amount = tx.amount,
                type = TransactionType.REVERSAL,
                description = "Reversal of tx#${tx.id}: ${req.reason}",
                status = "SUCCESS"
            )
        )

        auditLogService.log(
            adminHandle = (auth.principal as User).myrabaHandle,
            action = "REVERSE_TRANSACTION",
            targetType = "TRANSACTION",
            targetId = id.toString(),
            details = "Transaction #$id reversed. Reason: ${req.reason}. Reversal tx#${reversalTx.id}",
            previousValue = "status=SUCCESS,amount=${tx.amount}",
            newValue = "REVERSED"
        )

        return ResponseEntity.ok(mapOf(
            "message" to "Transaction #$id reversed successfully",
            "reversalTransactionId" to reversalTx.id,
            "reason" to req.reason
        ))
    }

    // ── Per-user transactions ─────────────────────────────────────

    @GetMapping("/user/{myrabaHandle}")
    fun getUserTransactions(
        @PathVariable myrabaHandle: String,
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "50") size: Int
    ): ResponseEntity<Map<String, Any>> {
        val wallet = walletRepository.findByUserVingHandle(myrabaHandle)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Wallet not found for $myrabaHandle")

        // Filter in-memory for sender/receiver since JPQL OR on joins is complex
        val filtered = transactionRepository
            .findBySenderWalletOrReceiverWalletOrderByCreatedAtDesc(wallet, wallet)
            .drop(page * size).take(size)

        return ResponseEntity.ok(mapOf(
            "transactions" to filtered.map { it.toAdminResponse() },
            "page" to page,
            "size" to size
        ))
    }

    // ── Summary ──────────────────────────────────────────────────

    @GetMapping("/summary")
    fun getSummary(): ResponseEntity<Map<String, Any>> {
        val last24h = LocalDateTime.now().minusDays(1)
        return ResponseEntity.ok(mapOf(
            "totalVolume" to (transactionRepository.sumAllSuccessfulAmounts() ?: BigDecimal.ZERO).toPlainString(),
            "totalFees" to (transactionRepository.sumAllFees() ?: BigDecimal.ZERO).toPlainString(),
            "failedLast24h" to transactionRepository.countFailedSince(last24h),
            "pendingPayouts" to transactionRepository.countByStatusAndType("PENDING", TransactionType.PAYOUT)
        ))
    }

    // ── Audit Log access ─────────────────────────────────────────

    @GetMapping("/{id}/audit")
    fun getTransactionAudit(@PathVariable id: Long): ResponseEntity<Map<String, Any>> {
        transactionRepository.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "Transaction not found")
        }
        return ResponseEntity.ok(mapOf("transactionId" to id, "note" to "Audit trail available at /api/admin/audit?targetType=TRANSACTION&targetId=$id"))
    }

    private fun Transaction.toAdminResponse() = AdminTransactionResponse(
        id = this.id,
        type = this.type.name,
        amount = this.amount.toPlainString(),
        fee = this.fee?.toPlainString(),
        description = this.description,
        senderHandle = this.senderWallet?.user?.myrabaHandle,
        receiverHandle = this.receiverWallet?.user?.myrabaHandle,
        status = this.status,
        createdAt = this.createdAt
    )
}
