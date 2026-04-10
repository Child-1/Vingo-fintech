package com.myraba.backend.controller

import com.myraba.backend.model.TransactionType
import com.myraba.backend.model.User
import com.myraba.backend.repository.TransactionRepository
import com.myraba.backend.repository.WalletRepository
import com.myraba.backend.service.PointsService
import org.springframework.http.ResponseEntity
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.*
import java.math.BigDecimal
import java.time.LocalDateTime

@RestController
@RequestMapping("/api/wrapped")
class WrappedController(
    private val transactionRepository: TransactionRepository,
    private val walletRepository: WalletRepository,
    private val pointsService: PointsService
) {

    /**
     * GET /api/wrapped/{year}
     * Returns Spotify Wrapped-style yearly stats for the authenticated user.
     */
    @GetMapping("/{year}")
    fun getWrapped(
        authentication: Authentication,
        @PathVariable year: Int
    ): ResponseEntity<Any> {
        val user = authentication.principal as User
        val wallet = walletRepository.findByUserVingHandle(user.myrabaHandle)
            ?: return ResponseEntity.notFound().build()

        val yearStart = LocalDateTime.of(year, 1, 1, 0, 0)
        val yearEnd   = LocalDateTime.of(year, 12, 31, 23, 59, 59)

        val allTx = transactionRepository
            .findBySenderWalletOrReceiverWalletOrderByCreatedAtDesc(wallet, wallet)
            .filter { it.createdAt >= yearStart && it.createdAt <= yearEnd }

        // ── Money sent ──────────────────────────────────────────────
        val sentTx = allTx.filter { it.senderWallet?.id == wallet.id && it.type == TransactionType.TRANSFER }
        val totalSent = sentTx.fold(BigDecimal.ZERO) { acc, tx -> acc.add(tx.amount) }

        // ── Money received ──────────────────────────────────────────
        val receivedTx = allTx.filter { it.receiverWallet?.id == wallet.id && it.type == TransactionType.TRANSFER }
        val totalReceived = receivedTx.fold(BigDecimal.ZERO) { acc, tx -> acc.add(tx.amount) }

        // ── Thrift contributions ────────────────────────────────────
        val thriftTx = allTx.filter { it.type == TransactionType.CONTRIBUTION }
        val totalThrift = thriftTx.fold(BigDecimal.ZERO) { acc, tx -> acc.add(tx.amount) }

        // ── Top recipient (who you sent the most to) ─────────────────
        val topRecipient = sentTx
            .groupBy { it.receiverWallet?.user?.myrabaHandle ?: "unknown" }
            .mapValues { (_, txs) -> txs.fold(BigDecimal.ZERO) { acc, tx -> acc.add(tx.amount) } }
            .maxByOrNull { it.value }
            ?.let { mapOf("myrabaTag" to "m₦${it.key}", "amount" to it.value.toPlainString()) }

        // ── Top sender (who sent you the most) ───────────────────────
        val topSender = receivedTx
            .groupBy { it.senderWallet?.user?.myrabaHandle ?: "unknown" }
            .mapValues { (_, txs) -> txs.fold(BigDecimal.ZERO) { acc, tx -> acc.add(tx.amount) } }
            .maxByOrNull { it.value }
            ?.let { mapOf("myrabaTag" to "m₦${it.key}", "amount" to it.value.toPlainString()) }

        // ── Most active month ────────────────────────────────────────
        val monthlyActivity = allTx
            .groupBy { it.createdAt.monthValue }
            .mapValues { it.value.size }
        val mostActiveMonth = monthlyActivity.maxByOrNull { it.value }
            ?.let { mapOf("month" to monthName(it.key), "transactionCount" to it.value) }

        // ── Biggest single transaction ────────────────────────────────
        val biggestTx = (sentTx + receivedTx).maxByOrNull { it.amount }
            ?.let { tx ->
                val direction = if (tx.senderWallet?.id == wallet.id) "SENT" else "RECEIVED"
                val counterparty = if (direction == "SENT")
                    tx.receiverWallet?.user?.myrabaHandle else tx.senderWallet?.user?.myrabaHandle
                mapOf(
                    "amount"       to tx.amount.toPlainString(),
                    "direction"    to direction,
                    "counterparty" to counterparty?.let { "m₦$it" },
                    "date"         to tx.createdAt.toLocalDate().toString()
                )
            }

        // ── Points ───────────────────────────────────────────────────
        val pointsEarned = pointsService.getYearPoints(user, year)

        // ── Transaction count breakdown ───────────────────────────────
        val totalTransactions = allTx.size
        val uniquePeoplePaidOrReceived = (
            sentTx.mapNotNull { it.receiverWallet?.user?.myrabaHandle } +
            receivedTx.mapNotNull { it.senderWallet?.user?.myrabaHandle }
        ).toSet().size

        return ResponseEntity.ok(
            mapOf(
                "year"                    to year,
                "myrabaTag"                 to "m₦${user.myrabaHandle}",
                "summary" to mapOf(
                    "totalSent"           to totalSent.toPlainString(),
                    "totalReceived"       to totalReceived.toPlainString(),
                    "thriftContributions" to totalThrift.toPlainString(),
                    "totalTransactions"   to totalTransactions,
                    "uniquePeople"        to uniquePeoplePaidOrReceived,
                    "pointsEarned"        to pointsEarned,
                    "pointsValue"         to "₦${"%.2f".format(pointsEarned / 100.0)}"
                ),
                "highlights" to mapOf(
                    "topRecipient"        to topRecipient,
                    "topSender"           to topSender,
                    "mostActiveMonth"     to mostActiveMonth,
                    "biggestTransaction"  to biggestTx
                )
            )
        )
    }

    private fun monthName(month: Int) = when (month) {
        1 -> "January"; 2 -> "February"; 3 -> "March"; 4 -> "April"
        5 -> "May"; 6 -> "June"; 7 -> "July"; 8 -> "August"
        9 -> "September"; 10 -> "October"; 11 -> "November"; else -> "December"
    }
}
