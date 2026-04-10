package com.myraba.backend.repository

import com.myraba.backend.model.Wallet
import jakarta.persistence.LockModeType
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Lock
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import org.springframework.stereotype.Repository
import java.math.BigDecimal

@Repository
interface WalletRepository : JpaRepository<Wallet, Long> {
    @Query("SELECT COALESCE(SUM(w.balance), 0) FROM Wallet w")
    fun getTotalBalance(): BigDecimal?

    // Alias used by AdminDashboardController
    @Query("SELECT COALESCE(SUM(w.balance), 0) FROM Wallet w")
    fun sumAllBalances(): BigDecimal?

    @Query("SELECT w FROM Wallet w WHERE w.user.myrabaHandle = :myrabaHandle")
    fun findByUserVingHandle(@Param("myrabaHandle") myrabaHandle: String): Wallet?

    // Pessimistic write lock — use inside @Transactional for transfer operations
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT w FROM Wallet w WHERE w.user.myrabaHandle = :myrabaHandle")
    fun findByUserVingHandleForUpdate(myrabaHandle: String): Wallet?
}

