package com.myraba.backend.service

import org.springframework.beans.factory.annotation.Value
import org.springframework.http.*
import org.springframework.stereotype.Service
import org.springframework.web.client.RestTemplate
import java.math.BigDecimal
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.UUID

data class VTpassResult(
    val success: Boolean,
    val transactionCode: String?,
    val message: String
)

@Service
class VTpassService(
    @Value("\${myraba.vtpass.api-key}")    private val apiKey: String,
    @Value("\${myraba.vtpass.public-key}") private val publicKey: String,
    @Value("\${myraba.vtpass.secret-key}") private val secretKey: String,
    @Value("\${myraba.vtpass.base-url}")   private val baseUrl: String
) {
    private val rest = RestTemplate()

    private fun headers(): HttpHeaders = HttpHeaders().apply {
        set("api-key", apiKey)
        set("public-key", publicKey)
        set("secret-key", secretKey)
        contentType = MediaType.APPLICATION_JSON
    }

    fun generateRequestId(): String {
        val ts = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss"))
        return "$ts${UUID.randomUUID().toString().take(6).uppercase()}"
    }

    // ─── Airtime ──────────────────────────────────────────────────

    fun buyAirtime(phone: String, amount: BigDecimal, network: String, requestId: String): VTpassResult {
        val body = mapOf(
            "request_id"  to requestId,
            "serviceID"   to network.lowercase(),   // "mtn", "airtel", "glo", "etisalat"
            "amount"      to amount.toPlainString(),
            "phone"       to phone
        )
        return post("/pay", body)
    }

    // ─── Data ─────────────────────────────────────────────────────

    fun buyData(phone: String, planCode: String, network: String, requestId: String): VTpassResult {
        val body = mapOf(
            "request_id"   to requestId,
            "serviceID"    to "${network.lowercase()}-data",
            "billersCode"  to phone,
            "variation_code" to planCode,
            "amount"       to "",       // VTpass infers from variation
            "phone"        to phone
        )
        return post("/pay", body)
    }

    // ─── Electricity ──────────────────────────────────────────────

    fun payElectricity(
        meterNumber: String,
        disco: String,       // e.g. "ikeja-electric", "ekedc", "aedc"
        meterType: String,   // "prepaid" or "postpaid"
        amount: BigDecimal,
        phone: String,
        requestId: String
    ): VTpassResult {
        val body = mapOf(
            "request_id"     to requestId,
            "serviceID"      to disco,
            "billersCode"    to meterNumber,
            "variation_code" to meterType,
            "amount"         to amount.toPlainString(),
            "phone"          to phone
        )
        return post("/pay", body)
    }

    // ─── Cable TV ─────────────────────────────────────────────────

    fun payCableTv(
        smartCardNumber: String,
        provider: String,    // "dstv", "gotv", "startimes"
        planCode: String,
        phone: String,
        requestId: String
    ): VTpassResult {
        val body = mapOf(
            "request_id"     to requestId,
            "serviceID"      to provider,
            "billersCode"    to smartCardNumber,
            "variation_code" to planCode,
            "amount"         to "",
            "phone"          to phone
        )
        return post("/pay", body)
    }

    // ─── Betting wallet funding ────────────────────────────────────

    fun fundBettingWallet(
        userId: String,     // betting site user ID / account number
        provider: String,   // "bet9ja", "sportybet", "1xbet"
        amount: BigDecimal,
        phone: String,
        requestId: String
    ): VTpassResult {
        val body = mapOf(
            "request_id"   to requestId,
            "serviceID"    to provider,
            "billersCode"  to userId,
            "amount"       to amount.toPlainString(),
            "phone"        to phone
        )
        return post("/pay", body)
    }

    // ─── Verify a meter or smart card number before payment ───────

    fun verifyMeter(meterNumber: String, disco: String, meterType: String): Map<String, Any?> {
        val body = mapOf(
            "serviceID"      to disco,
            "billersCode"    to meterNumber,
            "type"           to meterType
        )
        return try {
            val response = rest.exchange(
                "$baseUrl/merchant-verify",
                HttpMethod.POST,
                HttpEntity(body, headers()),
                Map::class.java
            )
            @Suppress("UNCHECKED_CAST")
            response.body as? Map<String, Any?> ?: emptyMap()
        } catch (e: Exception) {
            mapOf("error" to e.message)
        }
    }

    // ─── Get available variation codes (data plans, cable packages) ─

    fun getVariations(serviceId: String): List<Map<String, Any?>> {
        return try {
            val response = rest.exchange(
                "$baseUrl/service-variations?serviceID=$serviceId",
                HttpMethod.GET,
                HttpEntity<Void>(headers()),
                Map::class.java
            )
            @Suppress("UNCHECKED_CAST")
            (response.body?.get("content") as? Map<*, *>)
                ?.get("varations") as? List<Map<String, Any?>> ?: emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }

    // ─── Private ──────────────────────────────────────────────────

    private fun post(path: String, body: Map<String, Any?>): VTpassResult {
        return try {
            val response = rest.exchange(
                "$baseUrl$path",
                HttpMethod.POST,
                HttpEntity(body, headers()),
                Map::class.java
            )
            val respBody = response.body
            val code = (respBody?.get("code") as? String) ?: ""
            val txCode = (respBody?.get("content") as? Map<*, *>)
                ?.let { (it["transactions"] as? Map<*, *>)?.get("transactionId") as? String }
            val message = (respBody?.get("response_description") as? String) ?: "Transaction processed"

            VTpassResult(
                success = code == "000",
                transactionCode = txCode,
                message = message
            )
        } catch (e: Exception) {
            VTpassResult(success = false, transactionCode = null, message = e.message ?: "Request failed")
        }
    }
}
