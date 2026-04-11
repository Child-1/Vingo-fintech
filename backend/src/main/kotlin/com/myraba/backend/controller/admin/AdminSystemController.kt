package com.myraba.backend.controller.admin

import com.myraba.backend.repository.OtpRepository
import com.myraba.backend.repository.TransactionRepository
import com.myraba.backend.repository.UserRepository
import com.myraba.backend.repository.WalletRepository
import com.myraba.backend.repository.thrift.ThriftCategoryRepository
import com.myraba.backend.repository.thrift.ThriftMemberRepository
import com.myraba.backend.service.AesEncryptionService
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.web.bind.annotation.*
import java.math.BigDecimal
import java.time.LocalDate
import java.time.LocalDateTime

@RestController
@RequestMapping("/api/admin/system")
class AdminSystemController(
    private val userRepository: UserRepository,
    private val walletRepository: WalletRepository,
    private val transactionRepository: TransactionRepository,
    private val categoryRepository: ThriftCategoryRepository,
    private val memberRepository: ThriftMemberRepository,
    private val otpRepository: OtpRepository,
    private val aes: AesEncryptionService
) {

    /** DEV ONLY — retrieve active OTP for a contact (email or phone) */
    @GetMapping("/dev/otp")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    fun getOtp(@RequestParam contact: String): ResponseEntity<Map<String, Any>> {
        val now = LocalDateTime.now()
        val otps = if (contact.contains("@"))
            otpRepository.findActiveOtpsByEmail(contact, "REGISTRATION", now)
        else
            otpRepository.findActiveOtpsByPhone(contact, "REGISTRATION", now)
        if (otps.isEmpty()) return ResponseEntity.ok(mapOf("message" to "No active OTP found for $contact"))
        val code = aes.decryptOrNull(otps.last().code) ?: "Could not decrypt"
        return ResponseEntity.ok(mapOf(
            "contact" to contact,
            "otp" to code,
            "expiresAt" to otps.last().expiresAt.toString()
        ))
    }

    @GetMapping("/health")
    @PreAuthorize("hasAnyRole('STAFF', 'ADMIN', 'SUPER_ADMIN')")
    fun getSystemHealth(): ResponseEntity<Map<String, Any>> {
        val last24h = LocalDateTime.now().minusDays(1)
        val todayStart = LocalDate.now().atStartOfDay()

        return ResponseEntity.ok(mapOf(
            "status" to "UP",
            "timestamp" to LocalDateTime.now().toString(),
            "metrics" to mapOf(
                "totalUsers" to userRepository.count(),
                "newUsersToday" to userRepository.countByCreatedAtAfter(todayStart),
                "totalWalletBalance" to (walletRepository.getTotalBalance() ?: BigDecimal.ZERO).toPlainString(),
                "failedTransactions24h" to transactionRepository.countFailedSince(last24h),
                "activeThriftCategories" to categoryRepository.countActiveThrifts(),
                "activeThriftMembers" to memberRepository.sumActiveMemberContributions()?.toPlainString()
            )
        ))
    }

    @GetMapping("/liquidity")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
    fun getLiquidityReport(): ResponseEntity<Map<String, Any>> {
        val totalWalletBalance = walletRepository.getTotalBalance() ?: BigDecimal.ZERO
        val lockedInThrifts = memberRepository.sumActiveMemberContributions() ?: BigDecimal.ZERO
        val totalVolume = transactionRepository.sumAllSuccessfulAmounts() ?: BigDecimal.ZERO
        val totalFees = transactionRepository.sumAllFees() ?: BigDecimal.ZERO

        return ResponseEntity.ok(mapOf(
            "totalSystemBalance" to totalWalletBalance.toPlainString(),
            "lockedInThrifts" to lockedInThrifts.toPlainString(),
            "availableLiquidity" to totalWalletBalance.subtract(lockedInThrifts).toPlainString(),
            "totalTransactionVolume" to totalVolume.toPlainString(),
            "totalFeesCollected" to totalFees.toPlainString(),
            "generatedAt" to LocalDateTime.now().toString()
        ))
    }

    @PostMapping("/thrift-categories/{id}/deactivate")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
    fun deactivateThriftCategory(@PathVariable id: Long): ResponseEntity<Map<String, Any>> {
        val category = categoryRepository.findById(id).orElseThrow {
            org.springframework.web.server.ResponseStatusException(
                org.springframework.http.HttpStatus.NOT_FOUND, "Category not found"
            )
        }
        category.isActive = false
        categoryRepository.save(category)
        return ResponseEntity.ok(mapOf("message" to "Thrift category '${category.name}' deactivated"))
    }

    @PostMapping("/thrift-categories/{id}/activate")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
    fun activateThriftCategory(@PathVariable id: Long): ResponseEntity<Map<String, Any>> {
        val category = categoryRepository.findById(id).orElseThrow {
            org.springframework.web.server.ResponseStatusException(
                org.springframework.http.HttpStatus.NOT_FOUND, "Category not found"
            )
        }
        category.isActive = true
        categoryRepository.save(category)
        return ResponseEntity.ok(mapOf("message" to "Thrift category '${category.name}' activated"))
    }
}
