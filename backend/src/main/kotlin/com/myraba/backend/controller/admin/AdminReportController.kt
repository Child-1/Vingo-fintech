package com.myraba.backend.controller.admin

import com.myraba.backend.repository.TransactionRepository
import com.myraba.backend.repository.UserRepository
import com.myraba.backend.repository.WalletRepository
import org.springframework.format.annotation.DateTimeFormat
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.web.bind.annotation.*
import java.math.BigDecimal
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

@RestController
@RequestMapping("/api/admin/reports")
@PreAuthorize("hasAnyRole('STAFF', 'ADMIN', 'SUPER_ADMIN')")
class AdminReportController(
    private val transactionRepository: TransactionRepository,
    private val userRepository: UserRepository,
    private val walletRepository: WalletRepository
) {

    // ── Daily summary ─────────────────────────────────────────────

    @GetMapping("/daily")
    fun getDailySummary(
        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) date: LocalDate?
    ): ResponseEntity<Map<String, Any>> {
        val day = date ?: LocalDate.now()
        val from = day.atStartOfDay()
        val to = day.plusDays(1).atStartOfDay()

        return ResponseEntity.ok(buildPeriodReport("daily", day.toString(), from, to))
    }

    // ── Monthly summary ───────────────────────────────────────────

    @GetMapping("/monthly")
    fun getMonthlySummary(
        @RequestParam(required = false) year: Int?,
        @RequestParam(required = false) month: Int?
    ): ResponseEntity<Map<String, Any>> {
        val now = LocalDate.now()
        val y = year ?: now.year
        val m = month ?: now.monthValue
        val startOfMonth = LocalDate.of(y, m, 1)
        val from = startOfMonth.atStartOfDay()
        val to = startOfMonth.plusMonths(1).atStartOfDay()
        val label = "${y}-${m.toString().padStart(2, '0')}"

        return ResponseEntity.ok(buildPeriodReport("monthly", label, from, to))
    }

    // ── Date range summary ────────────────────────────────────────

    @GetMapping("/range")
    fun getRangeSummary(
        @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) from: LocalDateTime,
        @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) to: LocalDateTime
    ): ResponseEntity<Map<String, Any>> {
        return ResponseEntity.ok(buildPeriodReport("range", "$from to $to", from, to))
    }

    // ── 30-day daily breakdown ────────────────────────────────────

    @GetMapping("/daily-breakdown")
    fun getDailyBreakdown(
        @RequestParam(defaultValue = "30") days: Int
    ): ResponseEntity<Map<String, Any>> {
        val from = LocalDateTime.now().minusDays(days.toLong())
        val formatter = DateTimeFormatter.ISO_LOCAL_DATE

        // Build a map of date → stats
        val dailyData = mutableListOf<Map<String, Any>>()
        var cursor = from.toLocalDate()
        val today = LocalDate.now()

        while (!cursor.isAfter(today)) {
            val dayFrom = cursor.atStartOfDay()
            val dayTo = cursor.plusDays(1).atStartOfDay()
            dailyData.add(mapOf(
                "date" to cursor.format(formatter),
                "volume" to (transactionRepository.sumSuccessfulAmountsBetween(dayFrom, dayTo) ?: BigDecimal.ZERO).toPlainString(),
                "count" to transactionRepository.countSuccessfulBetween(dayFrom, dayTo),
                "fees" to (transactionRepository.sumFeesBetween(dayFrom, dayTo) ?: BigDecimal.ZERO).toPlainString()
            ))
            cursor = cursor.plusDays(1)
        }

        return ResponseEntity.ok(mapOf(
            "days" to days,
            "from" to from,
            "to" to LocalDateTime.now(),
            "data" to dailyData
        ))
    }

    // ── Platform totals ───────────────────────────────────────────

    @GetMapping("/totals")
    fun getPlatformTotals(): ResponseEntity<Map<String, Any>> {
        return ResponseEntity.ok(mapOf(
            "allTimeVolume" to (transactionRepository.sumAllSuccessfulAmounts() ?: BigDecimal.ZERO).toPlainString(),
            "allTimeFees" to (transactionRepository.sumAllFees() ?: BigDecimal.ZERO).toPlainString(),
            "systemLiquidity" to (walletRepository.sumAllBalances() ?: BigDecimal.ZERO).toPlainString(),
            "totalUsers" to userRepository.count(),
            "generatedAt" to LocalDateTime.now()
        ))
    }

    // ── Helper ────────────────────────────────────────────────────

    private fun buildPeriodReport(
        periodType: String,
        label: String,
        from: LocalDateTime,
        to: LocalDateTime
    ): Map<String, Any> {
        val volume = transactionRepository.sumSuccessfulAmountsBetween(from, to) ?: BigDecimal.ZERO
        val fees = transactionRepository.sumFeesBetween(from, to) ?: BigDecimal.ZERO
        val totalTx = transactionRepository.countBetween(from, to)
        val successTx = transactionRepository.countSuccessfulBetween(from, to)
        val newUsers = userRepository.countByCreatedAtAfter(from)

        return mapOf(
            "periodType" to periodType,
            "period" to label,
            "from" to from,
            "to" to to,
            "transactionVolume" to volume.toPlainString(),
            "serviceFees" to fees.toPlainString(),
            "totalTransactions" to totalTx,
            "successfulTransactions" to successTx,
            "failedTransactions" to (totalTx - successTx),
            "successRate" to if (totalTx > 0) "%.1f%%".format(successTx.toDouble() / totalTx * 100) else "N/A",
            "newUsers" to newUsers,
            "generatedAt" to LocalDateTime.now()
        )
    }
}
