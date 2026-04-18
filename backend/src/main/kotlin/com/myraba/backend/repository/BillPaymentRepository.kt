package com.myraba.backend.repository

import com.myraba.backend.model.BillCategory
import com.myraba.backend.model.BillPayment
import com.myraba.backend.model.User
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository
import java.time.LocalDateTime

@Repository
interface BillPaymentRepository : JpaRepository<BillPayment, Long> {
    fun findByUserOrderByCreatedAtDesc(user: User): List<BillPayment>
    fun findByUserAndCategoryOrderByCreatedAtDesc(user: User, category: BillCategory): List<BillPayment>
    fun findByUserAndCreatedAtAfterAndStatus(user: User, since: LocalDateTime, status: String): List<BillPayment>
    fun existsByRequestId(requestId: String): Boolean
}
