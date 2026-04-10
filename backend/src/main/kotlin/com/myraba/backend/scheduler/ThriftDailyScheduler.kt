// src/main/kotlin/com/vingo/backend/scheduler/ThriftDailyScheduler.kt
package com.myraba.backend.scheduler

import com.myraba.backend.model.thrift.ThriftMember
import com.myraba.backend.model.thrift.ThriftPenalty
import com.myraba.backend.repository.thrift.*
import com.myraba.backend.service.AuditLogService
import com.myraba.backend.service.ThriftService
import com.myraba.backend.service.WalletService
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component
import org.springframework.transaction.annotation.Transactional
import java.math.BigDecimal
import java.time.LocalDate

@Component
class ThriftDailyScheduler(
    private val memberRepo: ThriftMemberRepository,
    private val contributionRepo: ThriftContributionRepository,
    private val penaltyRepo: ThriftPenaltyRepository,
    private val walletService: WalletService,
    private val thriftService: ThriftService,
    private val auditLogService: AuditLogService,
) {

    /**
     * Runs every day at 00:05 AM UTC
     * Processes all active thrift members:
     * - Deducts daily contribution if not paid
     * - Applies penalties on 3rd missed day
     * - Force-withdraws after 7 consecutive missed days
     * - Triggers payout when cycle is complete
     */
    @Scheduled(cron = "0 5 0 * * *")
    @Transactional
    fun processDailyThriftContributions() {
        val today = LocalDate.now()
        auditLogService.log("SYSTEM", "SCHEDULER_RUN", "THRIFT_DAILY", today.toString(),
            details = "Daily thrift contribution processing started")

        // Get only active members in active categories
        val activeMembers = memberRepo.findAll()
            .filter { !it.hasWithdrawn && it.category.isActive }

        for (member in activeMembers) {
            val category = member.category
            val amount = category.contributionAmount

            // Skip if already contributed today
            val alreadyPaidToday = contributionRepo.existsByMemberAndContributionDate(member, today)
            if (alreadyPaidToday) continue

            // Try to deduct daily contribution
            val success = walletService.deductFromWallet(
                user = member.user,
                amount = amount,
                description = "Daily Thrift - ${category.name}"
            )

            if (success) {
                // SUCCESS: Update member stats
                member.daysContributed += 1
                member.totalContributed = member.totalContributed.add(amount)
                member.lastContributionDate = today
                member.consecutiveMissedDays = 0
                memberRepo.save(member)

                // CHECK IF CYCLE IS COMPLETE → PAYOUT TIME!
                if (member.daysContributed >= category.durationInDays) {
                    thriftService.payoutAndComplete(member)
                }
            } else {
                // FAILURE: Handle missed payment
                member.consecutiveMissedDays += 1
                member.totalMissedDays += 1

                when {
                    // 7+ consecutive missed days → KICK OUT
                    member.consecutiveMissedDays >= 7 -> {
                        member.hasWithdrawn = true
                        member.withdrawalDate = today
                        memberRepo.save(member)
                        auditLogService.log("SYSTEM", "THRIFT_MEMBER_EJECTED", "THRIFT_MEMBER", member.id.toString(),
                            details = "@${member.user.myrabaHandle} ejected from '${member.category.name}' — 7 consecutive missed days")
                    }

                    // First penalty (3rd missed day)
                    member.consecutiveMissedDays == 3 && member.penaltyLevel == 0 -> {
                        member.penaltyLevel = 1
                        applyPenalty(member, amount.multiply(BigDecimal("0.005"))) // 0.5%
                    }

                    // Second penalty (still on 3rd day, but already level 1)
                    member.consecutiveMissedDays == 3 && member.penaltyLevel == 1 -> {
                        member.penaltyLevel = 2
                        applyPenalty(member, amount.multiply(BigDecimal("0.01"))) // 1%
                    }

                    // Ongoing penalty (every day after with level 2+)
                    member.consecutiveMissedDays >= 3 && member.penaltyLevel >= 2 -> {
                        applyPenalty(member, amount.multiply(BigDecimal("0.02"))) // 2%
                    }
                }

                memberRepo.save(member)
            }
        }
    }

    // Penalty handler — clean, private, no errors
    private fun applyPenalty(member: ThriftMember, penaltyAmount: BigDecimal) {
        val deducted = walletService.deductFromWallet(
            user = member.user,
            amount = penaltyAmount,
            description = "Thrift penalty - late contribution"
        )

        if (deducted) {
            penaltyRepo.save(
                ThriftPenalty(
                    member = member,
                    amount = penaltyAmount,
                    reason = "Late/missed contribution"
                )
            )
            auditLogService.log("SYSTEM", "THRIFT_PENALTY_APPLIED", "THRIFT_MEMBER", member.id.toString(),
                details = "@${member.user.myrabaHandle} penalised ₦$penaltyAmount (level ${member.penaltyLevel}) in '${member.category.name}'")
        }
    }
}