package com.myraba.backend.scheduler

import com.myraba.backend.model.FixedDepositStatus
import com.myraba.backend.repository.FixedDepositRepository
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component
import java.time.LocalDateTime

@Component
class FixedDepositScheduler(private val depositRepo: FixedDepositRepository) {

    @Scheduled(fixedDelay = 3_600_000) // every hour
    fun matureDeposits() {
        val due = depositRepo.findByStatusAndMaturesAtBefore(FixedDepositStatus.ACTIVE, LocalDateTime.now())
        due.forEach { deposit ->
            deposit.status = FixedDepositStatus.MATURED
            deposit.maturedAt = LocalDateTime.now()
            depositRepo.save(deposit)
        }
    }
}
