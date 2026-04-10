package com.myraba.backend.controller.admin

import com.myraba.backend.model.Transaction
import com.myraba.backend.model.TransactionType
import com.myraba.backend.model.User
import com.myraba.backend.repository.TransactionRepository
import com.myraba.backend.repository.UserRepository
import com.myraba.backend.repository.WalletRepository
import com.myraba.backend.service.AuditLogService
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.security.core.Authentication
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import java.math.BigDecimal

@RestController
@RequestMapping("/api/admin/balance")
@PreAuthorize("hasRole('SUPER_ADMIN')")
class AdminBalanceController(
    private val userRepository: UserRepository,
    private val walletRepository: WalletRepository,
    private val transactionRepository: TransactionRepository,
    private val auditLogService: AuditLogService
) {

    data class AdjustBalanceRequest(
        val myrabaHandle: String,
        val amount: BigDecimal,   // positive = credit, negative = debit
        val reason: String
    )

    data class AdjustBalanceResponse(
        val myrabaHandle: String,
        val previousBalance: String,
        val adjustment: String,
        val newBalance: String,
        val transactionId: Long,
        val reason: String
    )

    @PostMapping("/adjust")
    @Transactional
    fun adjustBalance(
        @RequestBody req: AdjustBalanceRequest,
        auth: Authentication
    ): ResponseEntity<AdjustBalanceResponse> {
        if (req.amount.compareTo(BigDecimal.ZERO) == 0) {
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Adjustment amount cannot be zero")
        }

        val wallet = walletRepository.findByUserVingHandle(req.myrabaHandle)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Wallet not found for @${req.myrabaHandle}")

        if (req.amount < BigDecimal.ZERO && wallet.balance.add(req.amount) < BigDecimal.ZERO) {
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Debit would result in negative balance")
        }

        val previousBalance = wallet.balance
        wallet.balance = wallet.balance.add(req.amount)
        walletRepository.save(wallet)

        val txType = if (req.amount > BigDecimal.ZERO) TransactionType.ADMIN_CREDIT else TransactionType.ADMIN_DEBIT
        val tx = transactionRepository.save(
            Transaction(
                senderWallet = if (req.amount < BigDecimal.ZERO) wallet else null,
                receiverWallet = if (req.amount > BigDecimal.ZERO) wallet else null,
                amount = req.amount.abs(),
                type = txType,
                description = "Admin adjustment: ${req.reason}",
                status = "SUCCESS"
            )
        )

        auditLogService.log(
            adminHandle = (auth.principal as User).myrabaHandle,
            action = txType.name,
            targetType = "WALLET",
            targetId = wallet.id.toString(),
            details = "Manual ${if (req.amount > BigDecimal.ZERO) "credit" else "debit"} of ₦${req.amount.abs()} for @${req.myrabaHandle}. Reason: ${req.reason}",
            previousValue = previousBalance.toPlainString(),
            newValue = wallet.balance.toPlainString()
        )

        return ResponseEntity.ok(
            AdjustBalanceResponse(
                myrabaHandle = req.myrabaHandle,
                previousBalance = previousBalance.toPlainString(),
                adjustment = req.amount.toPlainString(),
                newBalance = wallet.balance.toPlainString(),
                transactionId = tx.id,
                reason = req.reason
            )
        )
    }
}
