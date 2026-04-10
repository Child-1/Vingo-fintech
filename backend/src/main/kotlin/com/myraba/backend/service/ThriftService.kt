package com.myraba.backend.service

import com.myraba.backend.model.TransactionType
import com.myraba.backend.model.User
import com.myraba.backend.model.thrift.*
import com.myraba.backend.repository.thrift.*
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.math.BigDecimal
import java.time.LocalDate

@Service
class ThriftService(
    private val categoryRepo: ThriftCategoryRepository,
    private val memberRepo: ThriftMemberRepository,
    private val contributionRepo: ThriftContributionRepository,
    private val penaltyRepo: ThriftPenaltyRepository,
    private val payoutRepo: ThriftPayoutRepository,
    private val walletService: WalletService
) {

    // ─── Join ─────────────────────────────────────────────────────

    data class JoinResponse(
        val categoryId: Long,
        val displayPosition: Long,   // what the user sees (includes placeholders)
        val realPosition: Long,      // actual queue position among real members
        val cyclesRequired: Int,
        val contributionAmount: String,
        val frequency: String,
        val estimatedPayout: String,
        val message: String
    )

    @Transactional
    fun joinPublicCategory(categoryId: Long, user: User): JoinResponse {
        val category = categoryRepo.findById(categoryId)
            .orElseThrow { IllegalArgumentException("Thrift category not found") }

        if (!category.isPublic || !category.isActive)
            throw IllegalStateException("This thrift category is not currently open")

        if (memberRepo.existsByUserAndCategoryAndHasWithdrawnFalse(user, category))
            throw IllegalStateException("You are already in this thrift")

        // Real position = how many active real members already + 1
        val realMemberCount = memberRepo.countByCategoryIdAndHasWithdrawn(categoryId, false)
        val realPosition = realMemberCount + 1

        // Display position = placeholders + real position
        // This ensures user must complete all durationInCycles contributions before "their turn"
        val placeholders = if (category.placeholderCount > 0) category.placeholderCount
                           else category.durationInCycles
        val displayPosition = placeholders + realPosition

        val member = ThriftMember(
            user = user,
            category = category,
            position = realPosition,
            joinedAt = LocalDate.now()
        )
        memberRepo.save(member)

        return JoinResponse(
            categoryId = category.id!!,
            displayPosition = displayPosition,
            realPosition = realPosition,
            cyclesRequired = category.durationInCycles,
            contributionAmount = "₦${category.contributionAmount}",
            frequency = category.contributionFrequency,
            estimatedPayout = "₦${category.payoutAmount}",
            message = "You're in! There are $displayPosition members ahead of you. " +
                      "Save ${category.contributionFrequency.lowercase()} and you'll collect in ${category.durationInCycles} ${category.contributionFrequency.lowercase()} cycles."
        )
    }

    // ─── Manual contribution (user pays their cycle) ──────────────

    @Transactional
    fun recordContribution(memberId: Long): ThriftContribution {
        val member = memberRepo.findById(memberId)
            .orElseThrow { IllegalArgumentException("Member record not found") }

        if (member.hasWithdrawn)
            throw IllegalStateException("You have already completed this thrift")

        val category = member.category
        val today = LocalDate.now()

        // Check if already contributed this cycle
        val alreadyContributed = contributionRepo.existsByMemberAndContributionDate(member, today)
        if (alreadyContributed)
            throw IllegalStateException("You have already contributed today")

        // Deduct from wallet
        val success = walletService.deductFromWallet(
            user = member.user,
            amount = category.contributionAmount,
            description = "Thrift contribution — ${category.name}",
            type = TransactionType.CONTRIBUTION
        )
        if (!success) throw IllegalStateException("Insufficient balance")

        member.daysContributed++
        member.totalContributed = member.totalContributed.add(category.contributionAmount)
        member.lastContributionDate = today
        member.consecutiveMissedDays = 0
        memberRepo.save(member)

        val contribution = ThriftContribution(
            member = member,
            amount = category.contributionAmount,
            contributionDate = today
        )
        contributionRepo.save(contribution)

        // Auto-payout when cycles complete
        if (member.daysContributed >= category.durationInCycles) {
            payoutAndComplete(member)
        }

        return contribution
    }

    // ─── Payout ───────────────────────────────────────────────────

    @Transactional
    fun payoutAndComplete(member: ThriftMember) {
        if (member.hasWithdrawn) return

        walletService.creditWallet(
            user = member.user,
            amount = member.totalContributed,
            description = "Thrift payout — ${member.category.name}",
            type = TransactionType.PAYOUT
        )

        payoutRepo.save(ThriftPayout(
            member = member,
            amount = member.totalContributed,
            payoutDate = LocalDate.now(),
            initiatedBySystem = true
        ))

        member.hasWithdrawn = true
        member.withdrawalDate = LocalDate.now()
        memberRepo.save(member)
    }

    // ─── Scheduler — runs daily at midnight ──────────────────────

    /**
     * Each midnight: for every active member in a DAILY category,
     * check if they contributed today. If not, increment missed days
     * and apply penalty after threshold.
     */
    @Scheduled(cron = "0 0 0 * * *")
    @Transactional
    fun processDailyMissedContributions() {
        val yesterday = LocalDate.now().minusDays(1)
        val activeMembers = memberRepo.findAllActiveMembers()

        for (member in activeMembers) {
            if (member.category.contributionFrequency != "DAILY") continue
            if (member.lastContributionDate == yesterday) continue  // contributed, skip

            applyMissedContribution(member)
        }
    }

    @Scheduled(cron = "0 0 1 * * MON")   // every Monday at 1am
    @Transactional
    fun processWeeklyMissedContributions() {
        val activeMembers = memberRepo.findAllActiveMembers()
        val lastWeekEnd = LocalDate.now().minusDays(1)

        for (member in activeMembers) {
            if (member.category.contributionFrequency != "WEEKLY") continue
            val lastContrib = member.lastContributionDate ?: member.joinedAt
            if (lastContrib.isAfter(lastWeekEnd.minusDays(7))) continue  // paid this week

            applyMissedContribution(member)
        }
    }

    @Scheduled(cron = "0 0 2 1 * *")   // 1st of every month at 2am
    @Transactional
    fun processMonthlyMissedContributions() {
        val activeMembers = memberRepo.findAllActiveMembers()

        for (member in activeMembers) {
            if (member.category.contributionFrequency != "MONTHLY") continue
            val lastContrib = member.lastContributionDate ?: member.joinedAt
            if (lastContrib.month == LocalDate.now().minusMonths(1).month) continue

            applyMissedContribution(member)
        }
    }

    private fun applyMissedContribution(member: ThriftMember) {
        member.consecutiveMissedDays++
        member.totalMissedDays++

        // Penalty threshold: 3 consecutive misses
        if (member.consecutiveMissedDays >= 3) {
            val penaltyAmount = member.category.contributionAmount.multiply(BigDecimal("0.1"))  // 10% penalty
            member.penaltyLevel++

            penaltyRepo.save(ThriftPenalty(
                member = member,
                amount = penaltyAmount,
                reason = "Missed ${member.consecutiveMissedDays} consecutive contributions",
                appliedAt = LocalDate.now()
            ))

            // Attempt to deduct penalty from wallet (non-blocking)
            walletService.deductFromWallet(
                user = member.user,
                amount = penaltyAmount,
                description = "Thrift penalty — ${member.category.name}",
                type = TransactionType.PENALTY
            )
        }

        memberRepo.save(member)
    }

    // ─── Queries ─────────────────────────────────────────────────

    fun getMemberStatus(user: User): List<ThriftMember> =
        memberRepo.findByUserAndHasWithdrawn(user, false)

    fun getCategoryDetails(categoryId: Long): ThriftCategory =
        categoryRepo.findById(categoryId).orElseThrow { IllegalArgumentException("Category not found") }
}
