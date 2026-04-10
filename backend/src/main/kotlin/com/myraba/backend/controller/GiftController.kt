package com.myraba.backend.controller

import com.myraba.backend.model.User
import com.myraba.backend.service.AuditLogService
import com.myraba.backend.service.FlutterwaveService
import com.myraba.backend.service.GiftService
import jakarta.servlet.http.HttpServletRequest
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.*
import java.math.BigDecimal

data class SendGiftRequest(
    val recipientVingHandle: String,   // without the m₦ prefix
    val giftItemId: Long,
    val note: String? = null,
    val anonymous: Boolean = false
)

data class ConvertGiftBalanceRequest(val amount: BigDecimal)

@RestController
@RequestMapping("/api/gifts")
class GiftController(
    private val giftService: GiftService,
    private val auditLogService: AuditLogService,
) {

    @GetMapping("/categories")
    fun getCategories(): ResponseEntity<Any> {
        val cats = giftService.getCategories().map { c ->
            mapOf(
                "id"          to c.id,
                "name"        to c.name,
                "slug"        to c.slug,
                "description" to c.description,
                "emoji"       to c.emoji
            )
        }
        return ResponseEntity.ok(mapOf("categories" to cats))
    }

    @GetMapping("/categories/{categoryId}/items")
    fun getCategoryItems(@PathVariable categoryId: Long): ResponseEntity<Any> {
        val items = giftService.getItemsForCategory(categoryId).map { i ->
            mapOf(
                "id"          to i.id,
                "name"        to i.name,
                "description" to i.description,
                "emoji"       to i.emoji,
                "nairaValue"  to i.nairaValue.toPlainString()
            )
        }
        return ResponseEntity.ok(mapOf("items" to items))
    }

    @PostMapping("/send")
    fun sendGift(
        authentication: Authentication,
        @RequestBody request: SendGiftRequest,
        httpRequest: HttpServletRequest
    ): ResponseEntity<Any> {
        val sender = authentication.principal as User
        val tx = giftService.sendGiftFromWallet(
            sender = sender,
            recipientVingHandle = request.recipientVingHandle,
            giftItemId = request.giftItemId,
            note = request.note,
            anonymous = request.anonymous
        )
        auditLogService.logUser(sender.myrabaHandle, "GIFT_SEND", "GIFT_TRANSACTION", tx.id.toString(),
            details = "Sent ${tx.giftItem.emoji} ${tx.giftItem.name} (₦${tx.nairaValue}) to @${request.recipientVingHandle}",
            request = httpRequest)
        return ResponseEntity.status(HttpStatus.CREATED).body(
            mapOf(
                "transactionId" to tx.id,
                "giftItem"      to tx.giftItem.name,
                "emoji"         to tx.giftItem.emoji,
                "value"         to tx.nairaValue.toPlainString(),
                "recipient"     to "m₦${tx.recipient.myrabaHandle}",
                "anonymous"     to tx.anonymous,
                "message"       to "Gift sent successfully!"
            )
        )
    }

    @GetMapping("/balance")
    fun getGiftBalance(authentication: Authentication): ResponseEntity<Any> {
        val user = authentication.principal as User
        val balance = giftService.getOrCreateGiftBalance(user)
        return ResponseEntity.ok(
            mapOf(
                "giftBalance"  to balance.balance.toPlainString(),
                "updatedAt"    to balance.updatedAt.toString()
            )
        )
    }

    @PostMapping("/balance/convert")
    fun convertToWallet(
        authentication: Authentication,
        @RequestBody request: ConvertGiftBalanceRequest,
        httpRequest: HttpServletRequest
    ): ResponseEntity<Any> {
        val user = authentication.principal as User
        val remaining = giftService.convertGiftBalanceToWallet(user, request.amount)
        auditLogService.logUser(user.myrabaHandle, "GIFT_BALANCE_CONVERT", "WALLET", user.id.toString(),
            details = "Converted ₦${request.amount} gift balance to wallet", request = httpRequest)
        return ResponseEntity.ok(
            mapOf(
                "amountConverted"    to request.amount.toPlainString(),
                "remainingGiftBal"   to remaining.toPlainString(),
                "message"            to "₦${request.amount} moved to your wallet"
            )
        )
    }

    @GetMapping("/received")
    fun receivedGifts(authentication: Authentication): ResponseEntity<Any> {
        val user = authentication.principal as User
        val gifts = giftService.getReceivedGifts(user).map { tx ->
            mapOf(
                "id"         to tx.id,
                "item"       to tx.giftItem.name,
                "emoji"      to tx.giftItem.emoji,
                "value"      to tx.nairaValue.toPlainString(),
                "from"       to if (tx.anonymous) "Anonymous" else (tx.senderUser?.let { "m₦${it.myrabaHandle}" } ?: tx.senderName),
                "note"       to tx.note,
                "date"       to tx.createdAt.toString()
            )
        }
        return ResponseEntity.ok(mapOf("gifts" to gifts, "total" to gifts.size))
    }

    @GetMapping("/sent")
    fun sentGifts(authentication: Authentication): ResponseEntity<Any> {
        val user = authentication.principal as User
        val gifts = giftService.getSentGifts(user).map { tx ->
            mapOf(
                "id"          to tx.id,
                "item"        to tx.giftItem.name,
                "emoji"       to tx.giftItem.emoji,
                "value"       to tx.nairaValue.toPlainString(),
                "recipient"   to "m₦${tx.recipient.myrabaHandle}",
                "anonymous"   to tx.anonymous,
                "note"        to tx.note,
                "date"        to tx.createdAt.toString()
            )
        }
        return ResponseEntity.ok(mapOf("gifts" to gifts, "total" to gifts.size))
    }
}
