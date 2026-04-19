package com.myraba.backend.repository

import com.myraba.backend.model.FixedDeposit
import com.myraba.backend.model.FixedDepositStatus
import com.myraba.backend.model.User
import org.springframework.data.jpa.repository.JpaRepository
import java.time.LocalDateTime

interface FixedDepositRepository : JpaRepository<FixedDeposit, Long> {
    fun findByUserOrderByCreatedAtDesc(user: User): List<FixedDeposit>
    fun findByStatusAndMaturesAtBefore(status: FixedDepositStatus, now: LocalDateTime): List<FixedDeposit>
}
