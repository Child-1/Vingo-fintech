package com.myraba.backend.controller.admin

import com.myraba.backend.model.TransactionType
import com.myraba.backend.repository.TransactionRepository
import com.myraba.backend.repository.UserRepository
import com.myraba.backend.repository.WalletRepository
import org.springframework.format.annotation.DateTimeFormat
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import java.math.BigDecimal
import java.time.LocalDateTime

@RestController
@RequestMapping("/api/admin/users/{id}/stats")
@PreAuthorize("hasAnyRole('STAFF', 'ADMIN', 'SUPER_ADMIN')")
class AdminUserStatsController(
    private val userRepository: UserRepository,
    private val walletRepository: WalletRepository,
    private val transactionRepository: TransactionRepository
) {

    @GetMapping
    fun getUserStats(
        @PathVariable id: Long,
        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) from: LocalDateTime?,
        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) to: LocalDateTime?
    ): ResponseEntity<Map<String, Any>> {
        val user = userRepository.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "User not found")
        }
        val wallet = walletRepository.findByUserVingHandle(user.myrabaHandle)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Wallet not found")

        val allTxs = transactionRepository
            .findBySenderWalletOrReceiverWalletOrderByCreatedAtDesc(wallet, wallet)

        val rangeFrom = from ?: LocalDateTime.now().minusYears(1)
        val rangeTo = to ?: LocalDateTime.now()

        val filtered = allTxs.filter { it.createdAt >= rangeFrom && it.createdAt <= rangeTo }

        val sent = filtered.filter { it.senderWallet?.id == wallet.id && it.type == TransactionType.TRANSFER }
        val received = filtered.filter { it.receiverWallet?.id == wallet.id && it.type == TransactionType.TRANSFER }
        val funded = filtered.filter { it.receiverWallet?.id == wallet.id && it.type == TransactionType.FUNDED }
        val adminCredits = filtered.filter { it.receiverWallet?.id == wallet.id && it.type == TransactionType.ADMIN_CREDIT }
        val adminDebits = filtered.filter { it.senderWallet?.id == wallet.id && it.type == TransactionType.ADMIN_DEBIT }

        return ResponseEntity.ok(mapOf(
            "userId" to user.id,
            "myrabaHandle" to user.myrabaHandle,
            "fullName" to user.fullName,
            "accountStatus" to user.accountStatus.name,
            "currentBalance" to (wallet.balance.toPlainString()),
            "period" to mapOf("from" to rangeFrom, "to" to rangeTo),
            "transactions" to mapOf(
                "totalCount" to filtered.size,
                "sentCount" to sent.size,
                "sentVolume" to sent.sumOf { it.amount }.toPlainString(),
                "receivedCount" to received.size,
                "receivedVolume" to received.sumOf { it.amount }.toPlainString(),
                "fundedCount" to funded.size,
                "fundedVolume" to funded.sumOf { it.amount }.toPlainString(),
                "adminCreditCount" to adminCredits.size,
                "adminCreditVolume" to adminCredits.sumOf { it.amount }.toPlainString(),
                "adminDebitCount" to adminDebits.size,
                "adminDebitVolume" to adminDebits.sumOf { it.amount }.toPlainString()
            ),
            "recentTransactions" to filtered.take(10).map { tx ->
                mapOf(
                    "id" to tx.id,
                    "type" to tx.type.name,
                    "amount" to tx.amount.toPlainString(),
                    "status" to tx.status,
                    "description" to tx.description,
                    "createdAt" to tx.createdAt
                )
            }
        ))
    }
}

private fun <T> Iterable<T>.sumOf(selector: (T) -> BigDecimal): BigDecimal {
    var sum = BigDecimal.ZERO
    for (element in this) sum = sum.add(selector(element))
    return sum
}
