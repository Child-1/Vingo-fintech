package com.myraba.backend.controller.admin

import com.myraba.backend.dto.DashboardStatsResponse
import com.myraba.backend.repository.TransactionRepository
import com.myraba.backend.repository.UserRepository
import com.myraba.backend.repository.WalletRepository
import com.myraba.backend.repository.thrift.ThriftCategoryRepository
import com.myraba.backend.repository.thrift.ThriftMemberRepository
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.time.LocalDate
import java.time.LocalDateTime

@RestController
@RequestMapping("/api/admin/dashboard")
@PreAuthorize("hasAnyRole('STAFF', 'ADMIN', 'SUPER_ADMIN')")
class AdminDashboardController(
    private val userRepository: UserRepository,
    private val walletRepository: WalletRepository,
    private val transactionRepository: TransactionRepository,
    private val categoryRepository: ThriftCategoryRepository,
    private val memberRepository: ThriftMemberRepository
) {

    @GetMapping("/stats")
    fun getStats(): ResponseEntity<DashboardStatsResponse> {
        val todayStart = LocalDate.now().atStartOfDay()
        val last24h = LocalDateTime.now().minusDays(1)

        val stats = DashboardStatsResponse(
            totalUsers = userRepository.count(),
            newUsersToday = userRepository.countByCreatedAtAfter(todayStart),
            kycPending = userRepository.countByKycStatus("PENDING"),

            totalVolume = (transactionRepository.sumAllSuccessfulAmounts() ?: java.math.BigDecimal.ZERO).toDouble(),
            systemLiquidity = (walletRepository.sumAllBalances() ?: java.math.BigDecimal.ZERO).toDouble(),
            totalServiceFees = (transactionRepository.sumAllFees() ?: java.math.BigDecimal.ZERO).toDouble(),

            activeThrifts = categoryRepository.countActiveThrifts(),
            totalLockedInThrifts = (memberRepository.sumActiveMemberContributions() ?: java.math.BigDecimal.ZERO).toDouble(),

            pendingPayouts = transactionRepository.countByStatusAndType("PENDING", com.myraba.backend.model.TransactionType.PAYOUT),
            failedTransactions24h = transactionRepository.countFailedSince(last24h)
        )

        return ResponseEntity.ok(stats)
    }
}