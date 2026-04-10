package com.myraba.backend.service

import org.springframework.beans.factory.annotation.Value
import org.springframework.http.*
import org.springframework.stereotype.Service
import org.springframework.web.client.RestTemplate

/**
 * Termii SMS gateway.
 * Docs: https://developers.termii.com/messaging
 * Falls back to console log if API key is not configured (dev mode).
 */
@Service
class SmsService(
    @Value("\${myraba.termii.api-key}")   private val apiKey: String,
    @Value("\${myraba.termii.sender-id}") private val senderId: String,
    @Value("\${myraba.termii.base-url}")  private val baseUrl: String,
) {
    private val rest = RestTemplate()
    private val isDev get() = apiKey == "changeme"

    fun sendOtp(phone: String, code: String, purpose: String) {
        val message = buildMessage(code, purpose)

        if (isDev) {
            println("=== MYRABA SMS (DEV — Termii not configured) ===\nTo: $phone\n$message\n===============")
            return
        }

        val payload = mapOf(
            "to"       to normalisePhone(phone),
            "from"     to senderId,
            "sms"      to message,
            "type"     to "plain",
            "channel"  to "dnd",        // "dnd" reaches DND numbers in Nigeria; fallback to "generic"
            "api_key"  to apiKey,
        )

        try {
            val headers = HttpHeaders().apply { contentType = MediaType.APPLICATION_JSON }
            val response = rest.exchange(
                "$baseUrl/api/sms/send",
                HttpMethod.POST,
                HttpEntity(payload, headers),
                Map::class.java
            )
            if (response.statusCode != HttpStatus.OK) {
                // Termii returns 200 even on soft errors — log body for debugging
                println("Termii non-200: ${response.statusCode} ${response.body}")
            }
        } catch (e: Exception) {
            // Log but never throw — SMS failure must not block the OTP flow
            println("Termii SMS failed for $phone: ${e.message}")
        }
    }

    // ── Private ───────────────────────────────────────────────────

    private fun buildMessage(code: String, purpose: String): String = when (purpose) {
        "REGISTRATION" -> "Your Myraba registration code is $code. Valid for 10 minutes. Do not share."
        "LOGIN"        -> "Your Myraba login code is $code. Valid for 10 minutes."
        "WITHDRAWAL"   -> "Myraba withdrawal OTP: $code. Valid 10 min. If not you, call support immediately."
        else           -> "Your Myraba verification code is $code. Valid for 10 minutes."
    }

    /** Normalise to international format: 08012345678 → 2348012345678 */
    private fun normalisePhone(phone: String): String {
        val digits = phone.trim().filter { it.isDigit() }
        return when {
            digits.startsWith("234") -> digits
            digits.startsWith("0")   -> "234${digits.drop(1)}"
            else                     -> "234$digits"
        }
    }
}
