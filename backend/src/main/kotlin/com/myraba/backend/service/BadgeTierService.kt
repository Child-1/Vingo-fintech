package com.myraba.backend.service

import com.myraba.backend.repository.TransactionRepository
import com.myraba.backend.repository.WalletRepository
import org.springframework.stereotype.Service
import java.math.BigDecimal

enum class BadgeTier(val label: String, val minTxCount: Int, val minVolume: BigDecimal) {
    NEWCOMER  ("Newcomer",  0,    BigDecimal.ZERO),
    BRONZE    ("Bronze",    5,    BigDecimal("5000")),
    SILVER    ("Silver",    20,   BigDecimal("50000")),
    GOLD      ("Gold",      50,   BigDecimal("200000")),
    PLATINUM  ("Platinum",  100,  BigDecimal("500000")),
    DIAMOND   ("Diamond",   250,  BigDecimal("1500000")),
    ELITE     ("Elite",     500,  BigDecimal("5000000")),
    MASTER    ("Master",    1000, BigDecimal("15000000")),
    LEGEND    ("Legend",    2500, BigDecimal("50000000")),
    TITAN     ("Titan",     5000, BigDecimal("200000000"));
}

@Service
class BadgeTierService(
    private val walletRepository: WalletRepository,
    private val transactionRepository: TransactionRepository,
) {
    fun getBadge(myrabaHandle: String): String {
        val wallet = walletRepository.findByUserVingHandle(myrabaHandle) ?: return BadgeTier.NEWCOMER.label
        val txList = transactionRepository.findBySenderWalletOrReceiverWalletOrderByCreatedAtDesc(wallet, wallet)
        val txCount = txList.size
        val totalVolume = txList
            .filter { it.status == "SUCCESS" }
            .fold(BigDecimal.ZERO) { acc, tx -> acc + tx.amount }

        return BadgeTier.entries
            .sortedByDescending { it.ordinal }
            .firstOrNull { txCount >= it.minTxCount && totalVolume >= it.minVolume }
            ?.label ?: BadgeTier.NEWCOMER.label
    }
}
