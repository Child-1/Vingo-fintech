package com.myraba.backend.repository

import com.myraba.backend.model.Transaction
import com.myraba.backend.model.TransactionType
import com.myraba.backend.model.Wallet
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import org.springframework.stereotype.Repository
import java.math.BigDecimal
import java.time.LocalDate
import java.time.LocalDateTime

@Repository
interface TransactionRepository : JpaRepository<Transaction, Long> {

    @Query("SELECT COALESCE(SUM(t.amount), 0) FROM Transaction t WHERE CAST(t.createdAt AS date) = :today AND t.type = com.myraba.backend.model.TransactionType.CONTRIBUTION")
    fun getTodayContributions(@Param("today") today: LocalDate): BigDecimal?

    @Query("SELECT COALESCE(SUM(t.amount), 0) FROM Transaction t WHERE t.status = 'PENDING' AND t.type = com.myraba.backend.model.TransactionType.PAYOUT")
    fun getPendingPayouts(): BigDecimal?

    @Query("SELECT COALESCE(SUM(t.amount), 0) FROM Transaction t WHERE t.status = 'SUCCESS'")
    fun sumAllSuccessfulAmounts(): BigDecimal?

    @Query("SELECT COALESCE(SUM(t.fee), 0) FROM Transaction t WHERE t.status = 'SUCCESS' AND t.fee IS NOT NULL")
    fun sumAllFees(): BigDecimal?

    @Query("SELECT COUNT(t) FROM Transaction t WHERE t.status = 'FAILED' AND t.createdAt > :dateTime")
    fun countFailedSince(@Param("dateTime") dateTime: LocalDateTime): Long

    fun countByStatusAndType(status: String, type: TransactionType): Long

    fun findBySenderWalletOrReceiverWalletOrderByCreatedAtDesc(sender: Wallet, receiver: Wallet): List<Transaction>

    @Query("""
        SELECT t FROM Transaction t WHERE
        (:type IS NULL OR t.type = :type) AND
        (:status IS NULL OR LOWER(t.status) = LOWER(:status)) AND
        (:from IS NULL OR t.createdAt >= :from) AND
        (:to IS NULL OR t.createdAt <= :to) AND
        (:minAmount IS NULL OR t.amount >= :minAmount) AND
        (:maxAmount IS NULL OR t.amount <= :maxAmount)
    """)
    fun filterTransactions(
        @Param("type") type: TransactionType?,
        @Param("status") status: String?,
        @Param("from") from: LocalDateTime?,
        @Param("to") to: LocalDateTime?,
        @Param("minAmount") minAmount: BigDecimal?,
        @Param("maxAmount") maxAmount: BigDecimal?,
        pageable: Pageable
    ): Page<Transaction>

    @Query("SELECT COALESCE(SUM(t.amount), 0) FROM Transaction t WHERE t.status = 'SUCCESS' AND t.createdAt >= :from AND t.createdAt <= :to")
    fun sumSuccessfulAmountsBetween(@Param("from") from: LocalDateTime, @Param("to") to: LocalDateTime): BigDecimal?

    @Query("SELECT COUNT(t) FROM Transaction t WHERE t.createdAt >= :from AND t.createdAt <= :to")
    fun countBetween(@Param("from") from: LocalDateTime, @Param("to") to: LocalDateTime): Long

    @Query("SELECT COUNT(t) FROM Transaction t WHERE t.status = 'SUCCESS' AND t.createdAt >= :from AND t.createdAt <= :to")
    fun countSuccessfulBetween(@Param("from") from: LocalDateTime, @Param("to") to: LocalDateTime): Long

    @Query("SELECT COALESCE(SUM(t.fee), 0) FROM Transaction t WHERE t.status = 'SUCCESS' AND t.fee IS NOT NULL AND t.createdAt >= :from AND t.createdAt <= :to")
    fun sumFeesBetween(@Param("from") from: LocalDateTime, @Param("to") to: LocalDateTime): BigDecimal?

    @Query("SELECT DATE(t.createdAt) as day, COUNT(t), SUM(t.amount) FROM Transaction t WHERE t.status = 'SUCCESS' AND t.createdAt >= :from GROUP BY DATE(t.createdAt) ORDER BY DATE(t.createdAt)")
    fun dailyVolumeSince(@Param("from") from: LocalDateTime): List<Array<Any>>

    /** Sum of outgoing (sent) transfers for a wallet since a given time — used for AML velocity check */
    @Query("""
        SELECT COALESCE(SUM(t.amount), 0) FROM Transaction t
        WHERE t.senderWallet = :wallet
          AND t.status = 'SUCCESS'
          AND t.type = com.myraba.backend.model.TransactionType.TRANSFER
          AND t.createdAt >= :since
    """)
    fun sumSentSince(@Param("wallet") wallet: Wallet, @Param("since") since: LocalDateTime): BigDecimal?
}