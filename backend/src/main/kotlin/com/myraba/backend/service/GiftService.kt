package com.myraba.backend.service

import com.myraba.backend.model.*
import com.myraba.backend.repository.*
import org.springframework.http.HttpStatus
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.server.ResponseStatusException
import java.math.BigDecimal
import java.time.LocalDateTime

@Service
class GiftService(
    private val giftCategoryRepo: GiftCategoryRepository,
    private val giftItemRepo: GiftItemRepository,
    private val giftTransactionRepo: GiftTransactionRepository,
    private val giftBalanceRepo: GiftBalanceRepository,
    private val userRepo: UserRepository,
    private val walletService: WalletService,
    private val pointsService: PointsService
) {

    fun getOrCreateGiftBalance(user: User): GiftBalance =
        giftBalanceRepo.findByUser(user) ?: giftBalanceRepo.save(GiftBalance(user = user))

    fun getCategories(): List<GiftCategory> = giftCategoryRepo.findByIsActiveTrue()

    fun getItemsForCategory(categoryId: Long): List<GiftItem> =
        giftItemRepo.findByCategoryIdAndIsActiveTrue(categoryId)

    // ─── In-app gift (sender is an app user, pays from wallet) ───

    @Transactional
    fun sendGiftFromWallet(
        sender: User,
        recipientVingHandle: String,
        giftItemId: Long,
        note: String?,
        anonymous: Boolean
    ): GiftTransaction {
        val recipient = userRepo.findByVingHandle(recipientVingHandle)
            ?: throw IllegalArgumentException("Recipient m₦$recipientVingHandle not found")

        if (sender.id == recipient.id)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "You cannot gift yourself")

        val item = giftItemRepo.findById(giftItemId).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "Gift item not found")
        }
        if (!item.isActive) throw ResponseStatusException(HttpStatus.BAD_REQUEST, "This gift item is no longer available")
        if (item.nairaValue <= BigDecimal.ZERO)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "This gift item has no value configured yet. Contact support.")

        val success = walletService.deductFromWallet(
            user = sender,
            amount = item.nairaValue,
            description = "Gift sent${if (anonymous) "" else " to m₦$recipientVingHandle"} — ${item.name}",
            type = com.myraba.backend.model.TransactionType.GIFT
        )
        if (!success) throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Insufficient wallet balance. Please fund your wallet to send this gift.")

        val tx = giftTransactionRepo.save(
            GiftTransaction(
                senderUser = sender,
                senderName = if (anonymous) null else sender.fullName,
                anonymous = anonymous,
                recipient = recipient,
                giftItem = item,
                nairaValue = item.nairaValue,
                note = note,
                paymentMethod = "WALLET",
                status = "COMPLETED"
            )
        )

        creditGiftBalance(recipient, item.nairaValue)

        // Award points to sender (sending earns points, not receiving)
        pointsService.awardPoints(
            user = sender,
            points = calculateGiftPoints(item.nairaValue),
            reason = com.myraba.backend.model.PointReason.TRANSFER_SENT,
            description = "Gift sent — ${item.name}"
        )

        return tx
    }

    // ─── Web gift (non-app sender, paid via Flutterwave) ─────────

    @Transactional
    fun recordWebGift(
        recipientVingHandle: String,
        giftItemId: Long,
        senderName: String,
        senderPhone: String,
        note: String?,
        flwReference: String
    ): GiftTransaction {
        val recipient = userRepo.findByVingHandle(recipientVingHandle)
            ?: throw IllegalArgumentException("Recipient m₦$recipientVingHandle not found")

        val item = giftItemRepo.findById(giftItemId).orElseThrow {
            IllegalArgumentException("Gift item not found")
        }

        val tx = giftTransactionRepo.save(
            GiftTransaction(
                senderUser = null,
                senderName = senderName,
                senderPhone = senderPhone,
                anonymous = false,
                recipient = recipient,
                giftItem = item,
                nairaValue = item.nairaValue,
                note = note,
                paymentMethod = "CARD",
                externalReference = flwReference,
                status = "COMPLETED"
            )
        )

        creditGiftBalance(recipient, item.nairaValue)
        return tx
    }

    // ─── Convert gift balance → wallet balance (free) ─────────────

    @Transactional
    fun convertGiftBalanceToWallet(user: User, amount: BigDecimal): BigDecimal {
        val giftBalance = getOrCreateGiftBalance(user)

        if (giftBalance.balance < amount)
            throw IllegalStateException("Insufficient gift balance. Available: ₦${giftBalance.balance}")

        giftBalance.balance = giftBalance.balance.subtract(amount)
        giftBalance.updatedAt = LocalDateTime.now()
        giftBalanceRepo.save(giftBalance)

        walletService.creditWallet(
            user = user,
            amount = amount,
            description = "Gift balance converted to wallet",
            type = com.myraba.backend.model.TransactionType.FUNDED
        )

        return giftBalance.balance
    }

    // ─── Gift history ─────────────────────────────────────────────

    fun getReceivedGifts(user: User) = giftTransactionRepo.findByRecipientOrderByCreatedAtDesc(user)
    fun getSentGifts(user: User) = giftTransactionRepo.findBySenderUserOrderByCreatedAtDesc(user)

    // ─── Private helpers ──────────────────────────────────────────

    private fun creditGiftBalance(user: User, amount: BigDecimal) {
        val giftBalance = getOrCreateGiftBalance(user)
        giftBalance.balance = giftBalance.balance.add(amount)
        giftBalance.updatedAt = LocalDateTime.now()
        giftBalanceRepo.save(giftBalance)
    }

    /** 1 point per ₦10 gifted */
    private fun calculateGiftPoints(amount: BigDecimal): Long =
        amount.divide(BigDecimal("10"), 0, java.math.RoundingMode.DOWN).toLong().coerceAtLeast(1L)
}
