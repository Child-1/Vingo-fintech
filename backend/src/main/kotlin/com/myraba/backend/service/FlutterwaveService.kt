package com.myraba.backend.service

import org.springframework.beans.factory.annotation.Value
import org.springframework.http.*
import org.springframework.stereotype.Service
import org.springframework.web.client.RestTemplate
import java.math.BigDecimal
import java.util.UUID

data class FlwPaymentLink(
    val link: String,
    val reference: String
)

data class FlwVerifyResult(
    val verified: Boolean,
    val amount: BigDecimal?,
    val reference: String,
    val status: String
)

@Service
class FlutterwaveService(
    @Value("\${myraba.flutterwave.secret-key}") private val secretKey: String,
    @Value("\${myraba.flutterwave.base-url}") private val baseUrl: String
) {
    private val rest = RestTemplate()

    private fun headers(): HttpHeaders = HttpHeaders().apply {
        set("Authorization", "Bearer $secretKey")
        contentType = MediaType.APPLICATION_JSON
    }

    /**
     * Create a payment link for non-app users to pay for a gift.
     * Returns the hosted payment URL to redirect the user to.
     */
    fun createGiftPaymentLink(
        amount: BigDecimal,
        recipientVingHandle: String,
        giftItemName: String,
        senderName: String,
        senderEmail: String,
        redirectUrl: String
    ): FlwPaymentLink {
        val reference = "MYRABA-GIFT-${UUID.randomUUID().toString().take(12).uppercase()}"

        val body = mapOf(
            "tx_ref"       to reference,
            "amount"       to amount.toPlainString(),
            "currency"     to "NGN",
            "redirect_url" to redirectUrl,
            "customer"     to mapOf(
                "email"        to senderEmail,
                "name"         to senderName
            ),
            "customizations" to mapOf(
                "title"        to "Gift for m₦$recipientVingHandle",
                "description"  to "Sending: $giftItemName",
                "logo"         to "https://vingo.ng/logo.png"
            ),
            "meta" to mapOf(
                "recipient"    to recipientVingHandle,
                "gift_item"    to giftItemName
            )
        )

        val response = rest.exchange(
            "$baseUrl/payments",
            HttpMethod.POST,
            HttpEntity(body, headers()),
            Map::class.java
        )

        val data = (response.body?.get("data") as? Map<*, *>)
        val link = data?.get("link") as? String
            ?: throw RuntimeException("Flutterwave did not return a payment link")

        return FlwPaymentLink(link = link, reference = reference)
    }

    /**
     * Verify that a Flutterwave transaction actually succeeded.
     * Called after user is redirected back from the payment page.
     */
    fun verifyTransaction(transactionId: String): FlwVerifyResult {
        return try {
            val response = rest.exchange(
                "$baseUrl/transactions/$transactionId/verify",
                HttpMethod.GET,
                HttpEntity<Void>(headers()),
                Map::class.java
            )
            val data = response.body?.get("data") as? Map<*, *>
            val status = data?.get("status") as? String ?: "failed"
            val amount = (data?.get("amount") as? Number)?.let { BigDecimal(it.toString()) }
            val ref = data?.get("tx_ref") as? String ?: ""

            FlwVerifyResult(
                verified = status == "successful",
                amount = amount,
                reference = ref,
                status = status
            )
        } catch (e: Exception) {
            FlwVerifyResult(verified = false, amount = null, reference = transactionId, status = "error")
        }
    }
}
