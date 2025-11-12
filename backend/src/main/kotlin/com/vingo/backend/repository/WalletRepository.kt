package com.vingo.backend.repository

import com.vingo.backend.model.Wallet
import org.springframework.data.jpa.repository.JpaRepository

interface WalletRepository : JpaRepository<Wallet, Long> {
    fun findByUserVingHandle(vingHandle: String): Wallet?
}