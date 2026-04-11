package com.myraba.backend.service

import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse

@Service
class ResendEmailService(
    @Value("\${RESEND_API_KEY:}") private val apiKey: String,
    @Value("\${MYRABA_MAIL_FROM:onboarding@resend.dev}") private val fromAddress: String
) {
    private val client = HttpClient.newHttpClient()

    fun send(to: String, subject: String, text: String): Boolean {
        if (apiKey.isBlank()) {
            println("=== RESEND NOT CONFIGURED — Email to $to: $subject ===")
            return false
        }
        return try {
            val body = """
                {
                  "from": "$fromAddress",
                  "to": ["$to"],
                  "subject": ${subject.toJson()},
                  "text": ${text.toJson()}
                }
            """.trimIndent()

            val request = HttpRequest.newBuilder()
                .uri(URI.create("https://api.resend.com/emails"))
                .header("Authorization", "Bearer $apiKey")
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .build()

            val response = client.send(request, HttpResponse.BodyHandlers.ofString())
            val success = response.statusCode() in 200..299
            if (success) println("=== RESEND: Email sent to $to ===")
            else println("=== RESEND FAILED: ${response.statusCode()} ${response.body()} ===")
            success
        } catch (e: Exception) {
            println("=== RESEND ERROR: ${e.message} ===")
            false
        }
    }

    private fun String.toJson(): String =
        "\"${this.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")}\""
}
