package com.myraba.backend.scheduler

import com.myraba.backend.model.PersonalGoalStatus
import com.myraba.backend.model.Transaction
import com.myraba.backend.model.TransactionType
import com.myraba.backend.repository.PersonalGoalRepository
import com.myraba.backend.repository.TransactionRepository
import com.myraba.backend.repository.WalletRepository
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component
import java.math.BigDecimal
import java.time.LocalDate
import java.time.LocalDateTime

@Component
class PersonalGoalScheduler(
    private val goalRepo: PersonalGoalRepository,
    private val walletRepo: WalletRepository,
    private val txRepo: TransactionRepository,
) {
    @Scheduled(cron = "0 0 8 * * *") // 8 AM daily
    fun processAutoDeductions() {
        val due = goalRepo.findByStatusAndNextDeductDateLessThanEqual(
            PersonalGoalStatus.ACTIVE, LocalDate.now()
        )
        for (goal in due) {
            val amount = goal.autoDeductAmount ?: continue
            val wallet = walletRepo.findByUserVingHandle(goal.user.myrabaHandle) ?: continue

            if (wallet.balance < amount) {
                // Skip this cycle — insufficient funds, try next period
            } else {
                wallet.balance = wallet.balance.subtract(amount)
                walletRepo.save(wallet)

                goal.savedAmount = goal.savedAmount.add(amount)
                if (goal.savedAmount >= goal.targetAmount) {
                    goal.status = PersonalGoalStatus.COMPLETED
                    goal.completedAt = LocalDateTime.now()
                }

                txRepo.save(Transaction(
                    senderWallet = wallet, receiverWallet = null,
                    amount = amount, type = TransactionType.WITHDRAWAL,
                    status = "SUCCESS",
                    description = "Auto-deduction for savings goal '${goal.name}'",
                ))
            }

            // Advance nextDeductDate regardless of success/failure
            goal.nextDeductDate = when (goal.autoDeductFrequency) {
                "DAILY"   -> LocalDate.now().plusDays(1)
                "WEEKLY"  -> LocalDate.now().plusWeeks(1)
                "MONTHLY" -> LocalDate.now().plusMonths(1)
                else      -> null
            }
            goalRepo.save(goal)
        }
    }
}
