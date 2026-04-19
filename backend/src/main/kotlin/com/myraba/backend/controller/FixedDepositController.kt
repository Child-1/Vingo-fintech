package com.myraba.backend.controller

import com.myraba.backend.model.FixedDeposit
import com.myraba.backend.model.FixedDepositStatus
import com.myraba.backend.model.Transaction
import com.myraba.backend.model.TransactionType
import com.myraba.backend.model.User
import com.myraba.backend.repository.FixedDepositRepository
import com.myraba.backend.repository.TransactionRepository
import com.myraba.backend.repository.WalletRepository
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import java.math.BigDecimal
import java.math.RoundingMode
import java.time.LocalDateTime

data class CreateDepositRequest(
    val amount: BigDecimal,
    val termDays: Int,   // 30 | 90 | 180 | 365
)

@RestController
@RequestMapping("/api/fixed-deposits")
class FixedDepositController(
    private val depositRepo: FixedDepositRepository,
    private val walletRepo: WalletRepository,
    private val txRepo: TransactionRepository,
) {
    companion object {
        // Annual interest rates per term
        val RATES = mapOf(30 to 8.0, 90 to 10.0, 180 to 12.0, 365 to 15.0)
    }

    @GetMapping
    fun list(auth: Authentication): ResponseEntity<Any> {
        val user = auth.principal as User
        val deposits = depositRepo.findByUserOrderByCreatedAtDesc(user)
        return ResponseEntity.ok(mapOf("deposits" to deposits.map { it.toDto() }))
    }

    @PostMapping
    fun create(@RequestBody req: CreateDepositRequest, auth: Authentication): ResponseEntity<Any> {
        val user = auth.principal as User
        val rate = RATES[req.termDays]
            ?: throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Term must be 30, 90, 180, or 365 days")
        if (req.amount < BigDecimal("1000"))
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Minimum deposit is ₦1,000")

        val wallet = walletRepo.findByUserVingHandle(user.myrabaHandle)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Wallet not found")
        if (wallet.balance < req.amount)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Insufficient wallet balance")

        // Deduct from wallet
        wallet.balance = wallet.balance.subtract(req.amount)
        walletRepo.save(wallet)

        // Calculate return: simple interest = P * r * t/365
        val interest = req.amount
            .multiply(BigDecimal(rate / 100))
            .multiply(BigDecimal(req.termDays).divide(BigDecimal(365), 8, RoundingMode.HALF_UP))
        val expectedReturn = req.amount.add(interest).setScale(4, RoundingMode.HALF_UP)

        val deposit = depositRepo.save(FixedDeposit(
            user = user,
            amount = req.amount,
            termDays = req.termDays,
            interestRate = BigDecimal(rate),
            expectedReturn = expectedReturn,
            maturesAt = LocalDateTime.now().plusDays(req.termDays.toLong()),
        ))

        // Record debit transaction
        txRepo.save(Transaction(
            senderWallet = wallet,
            receiverWallet = null,
            amount = req.amount,
            type = TransactionType.WITHDRAWAL,
            status = "SUCCESS",
            description = "Fixed deposit locked for ${req.termDays} days",
        ))

        return ResponseEntity.status(HttpStatus.CREATED).body(deposit.toDto())
    }

    @PostMapping("/{id}/withdraw")
    fun withdraw(@PathVariable id: Long, auth: Authentication): ResponseEntity<Any> {
        val user = auth.principal as User
        val deposit = depositRepo.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "Deposit not found")
        }
        if (deposit.user.id != user.id)
            throw ResponseStatusException(HttpStatus.FORBIDDEN, "Not your deposit")
        if (deposit.status != FixedDepositStatus.MATURED)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Deposit has not matured yet")

        val wallet = walletRepo.findByUserVingHandle(user.myrabaHandle)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Wallet not found")

        wallet.balance = wallet.balance.add(deposit.expectedReturn)
        walletRepo.save(wallet)

        deposit.status = FixedDepositStatus.WITHDRAWN
        deposit.withdrawnAt = LocalDateTime.now()
        depositRepo.save(deposit)

        txRepo.save(Transaction(
            senderWallet = null,
            receiverWallet = wallet,
            amount = deposit.expectedReturn,
            type = TransactionType.TRANSFER,
            status = "SUCCESS",
            description = "Fixed deposit matured — principal + interest credited",
        ))

        return ResponseEntity.ok(mapOf("message" to "₦${deposit.expectedReturn} credited to your wallet"))
    }

    private fun FixedDeposit.toDto() = mapOf(
        "id"             to id,
        "amount"         to amount,
        "termDays"       to termDays,
        "interestRate"   to interestRate,
        "expectedReturn" to expectedReturn,
        "interest"       to expectedReturn.subtract(amount),
        "status"         to status.name,
        "createdAt"      to createdAt,
        "maturesAt"      to maturesAt,
        "maturedAt"      to maturedAt,
        "withdrawnAt"    to withdrawnAt,
        "daysRemaining"  to if (status == FixedDepositStatus.ACTIVE)
            java.time.temporal.ChronoUnit.DAYS.between(LocalDateTime.now(), maturesAt).coerceAtLeast(0)
        else 0,
    )
}
