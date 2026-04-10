package com.myraba.backend.controller

import com.myraba.backend.repository.GiftItemRepository
import com.myraba.backend.repository.UserRepository
import com.myraba.backend.service.FlutterwaveService
import com.myraba.backend.service.GiftService
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException

data class WebGiftInitRequest(
    val giftItemId: Long,
    val senderName: String,
    val senderPhone: String,
    val senderEmail: String,
    val note: String? = null
)

data class WebGiftVerifyRequest(
    val flwTransactionId: String,
    val flwReference: String,
    val giftItemId: Long,
    val senderName: String,
    val senderPhone: String,
    val note: String? = null
)

/**
 * Public endpoints — no authentication required.
 * These are hit from the public web gifting page (vingo.ng/gift/{myrabaHandle}).
 */
@RestController
@RequestMapping("/public/gift")
class PublicGiftController(
    private val giftService: GiftService,
    private val flutterwaveService: FlutterwaveService,
    private val userRepo: UserRepository,
    private val giftItemRepo: GiftItemRepository,
    @Value("\${myraba.flutterwave.redirect-url:https://vingo.ng/gift/confirm}") private val redirectUrl: String
) {

    /** Load a user's public gift profile — called when someone opens a MyrabaTag link */
    @GetMapping("/{myrabaHandle}")
    fun getGiftProfile(@PathVariable myrabaHandle: String): ResponseEntity<Any> {
        val user = userRepo.findByVingHandle(myrabaHandle)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "m₦$myrabaHandle not found")

        val categories = giftService.getCategories().map { c ->
            mapOf(
                "id"          to c.id,
                "name"        to c.name,
                "slug"        to c.slug,
                "description" to c.description,
                "emoji"       to c.emoji
            )
        }

        return ResponseEntity.ok(
            mapOf(
                "recipient" to mapOf(
                    "myrabaTag"  to "m₦${user.myrabaHandle}",
                    "fullName" to user.fullName
                ),
                "categories" to categories
            )
        )
    }

    /** Get items for a category on the public page */
    @GetMapping("/{myrabaHandle}/category/{categoryId}/items")
    fun getCategoryItems(
        @PathVariable myrabaHandle: String,
        @PathVariable categoryId: Long
    ): ResponseEntity<Any> {
        userRepo.findByVingHandle(myrabaHandle)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Recipient not found")

        val items = giftService.getItemsForCategory(categoryId).map { i ->
            mapOf(
                "id"         to i.id,
                "name"       to i.name,
                "description" to i.description,
                "emoji"      to i.emoji,
                "nairaValue" to i.nairaValue.toPlainString()
            )
        }
        return ResponseEntity.ok(mapOf("items" to items))
    }

    /**
     * Step 1 — non-app user selects a gift and initiates payment.
     * Returns a Flutterwave hosted payment link.
     */
    @PostMapping("/{myrabaHandle}/initiate")
    fun initiateWebGift(
        @PathVariable myrabaHandle: String,
        @RequestBody request: WebGiftInitRequest
    ): ResponseEntity<Any> {
        userRepo.findByVingHandle(myrabaHandle)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Recipient not found")

        val item = giftItemRepo.findById(request.giftItemId).orElse(null)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Gift item not found")
        if (!item.isActive)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "This gift item is no longer available")

        val paymentLink = flutterwaveService.createGiftPaymentLink(
            amount = item.nairaValue,
            recipientVingHandle = myrabaHandle,
            giftItemName = item.name,
            senderName = request.senderName,
            senderEmail = request.senderEmail,
            redirectUrl = "$redirectUrl?recipient=$myrabaHandle&item=${item.id}"
        )

        return ResponseEntity.ok(
            mapOf(
                "paymentUrl"  to paymentLink.link,
                "reference"   to paymentLink.reference,
                "amount"      to item.nairaValue.toPlainString(),
                "giftItem"    to item.name,
                "recipient"   to "m₦$myrabaHandle",
                "message"     to "Complete payment to send your gift"
            )
        )
    }

    /**
     * Step 2 — after Flutterwave redirects back, verify the payment and record the gift.
     */
    @PostMapping("/{myrabaHandle}/confirm")
    fun confirmWebGift(
        @PathVariable myrabaHandle: String,
        @RequestBody request: WebGiftVerifyRequest
    ): ResponseEntity<Any> {
        val verification = flutterwaveService.verifyTransaction(request.flwTransactionId)

        if (!verification.verified)
            throw ResponseStatusException(HttpStatus.PAYMENT_REQUIRED, "Payment could not be verified")

        val item = giftItemRepo.findById(request.giftItemId).orElse(null)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Gift item not found")

        // Guard: verified amount must match the gift item value
        if (verification.amount != null && verification.amount < item.nairaValue)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Payment amount does not match gift value")

        val tx = giftService.recordWebGift(
            recipientVingHandle = myrabaHandle,
            giftItemId = request.giftItemId,
            senderName = request.senderName,
            senderPhone = request.senderPhone,
            note = request.note,
            flwReference = request.flwReference
        )

        return ResponseEntity.status(HttpStatus.CREATED).body(
            mapOf(
                "transactionId" to tx.id,
                "giftItem"      to tx.giftItem.name,
                "emoji"         to tx.giftItem.emoji,
                "value"         to tx.nairaValue.toPlainString(),
                "recipient"     to "m₦${tx.recipient.myrabaHandle}",
                "from"          to request.senderName,
                "message"       to "Your gift has been delivered! 🎁"
            )
        )
    }
}
