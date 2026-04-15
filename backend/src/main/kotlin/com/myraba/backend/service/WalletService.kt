// src/main/kotlin/com/vingo/backend/service/WalletService.kt
package com.myraba.backend.service

import com.myraba.backend.model.Transaction
import com.myraba.backend.model.TransactionType
import com.myraba.backend.model.User
import com.myraba.backend.model.UserStatus
import com.myraba.backend.model.Wallet
import com.myraba.backend.repository.TransactionRepository
import com.myraba.backend.repository.WalletRepository
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.math.BigDecimal
import java.time.LocalDateTime

@Service
class WalletService(
    private val walletRepo: WalletRepository,
    private val transactionRepo: TransactionRepository,
    @Value("\${myraba.aml.daily-transfer-limit}")  private val dailyLimit: BigDecimal,
    @Value("\${myraba.aml.single-transfer-limit}") private val singleLimit: BigDecimal,
) {

    @Transactional
    fun deductFromWallet(user: User, amount: BigDecimal, description: String, type: TransactionType = TransactionType.WITHDRAWAL): Boolean {
        if (user.accountStatus != UserStatus.ACTIVE) return false
        // Load wallet fresh from DB — the User principal from JWT is detached/stale and user.wallet may not be initialized
        val wallet = walletRepo.findByUserVingHandle(user.myrabaHandle) ?: return false
        if (wallet.balance < amount) return false

        // AML velocity checks — only applied to user-initiated transfers
        if (type == TransactionType.TRANSFER) {
            if (amount > singleLimit)
                throw IllegalStateException("Transfer of ₦$amount exceeds single-transaction limit of ₦$singleLimit")

            val startOfDay = LocalDateTime.now().toLocalDate().atStartOfDay()
            val sentToday = transactionRepo.sumSentSince(wallet, startOfDay) ?: BigDecimal.ZERO
            if (sentToday.add(amount) > dailyLimit)
                throw IllegalStateException("Daily transfer limit of ₦$dailyLimit exceeded. Sent today: ₦$sentToday")
        }

        wallet.balance = wallet.balance.subtract(amount)
        wallet.updatedAt = LocalDateTime.now()
        walletRepo.save(wallet)

        transactionRepo.save(
            Transaction(
                senderWallet = wallet,
                receiverWallet = null,
                amount = amount,
                type = type,
                description = description,
                status = "SUCCESS"
            )
        )
        return true
    }

    @Transactional
    fun creditWallet(user: User, amount: BigDecimal, description: String, type: TransactionType = TransactionType.FUNDED) {
        val wallet = user.wallet ?: return

        wallet.balance = wallet.balance.add(amount)
        wallet.updatedAt = LocalDateTime.now()
        walletRepo.save(wallet)

        transactionRepo.save(
            Transaction(
                senderWallet = null,
                receiverWallet = wallet,
                amount = amount,
                type = type,
                description = description,
                status = "SUCCESS"
            )
        )
    }
}