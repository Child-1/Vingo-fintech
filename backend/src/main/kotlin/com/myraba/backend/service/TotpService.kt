package com.myraba.backend.service

import org.springframework.stereotype.Service
import java.security.SecureRandom
import java.time.Instant
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import kotlin.math.pow
import java.util.Base64

/**
 * Pure RFC 6238 TOTP — no external library needed.
 * Compatible with Google Authenticator, Authy, etc.
 * Step = 30s, digits = 6, algorithm = HmacSHA1
 */
@Service
class TotpService {

    private val base32Chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

    /** Generate a random 20-byte Base32-encoded secret */
    fun generateSecret(): String {
        val bytes = ByteArray(20).also { SecureRandom().nextBytes(it) }
        return encodeBase32(bytes)
    }

    /** Verify a 6-digit TOTP code — accepts current window ±1 step (±30s clock drift) */
    fun verify(secret: String, code: String): Boolean {
        val counter = Instant.now().epochSecond / 30
        return (-1L..1L).any { delta ->
            generateTotp(secret, counter + delta) == code.trim()
        }
    }

    /** Build an otpauth:// URI for QR code generation */
    fun buildOtpAuthUri(secret: String, accountName: String, issuer: String = "Myraba"): String {
        val encoded = java.net.URLEncoder.encode(accountName, "UTF-8")
        val issuerEncoded = java.net.URLEncoder.encode(issuer, "UTF-8")
        return "otpauth://totp/$issuerEncoded:$encoded?secret=$secret&issuer=$issuerEncoded&algorithm=SHA1&digits=6&period=30"
    }

    // ── Private ───────────────────────────────────────────────────

    private fun generateTotp(secret: String, counter: Long): String {
        val key = decodeBase32(secret)
        val msg = ByteArray(8) { i -> (counter ushr (56 - i * 8)).toByte() }
        val mac = Mac.getInstance("HmacSHA1")
        mac.init(SecretKeySpec(key, "HmacSHA1"))
        val hash = mac.doFinal(msg)
        val offset = (hash.last().toInt() and 0x0f)
        val code = ((hash[offset].toInt() and 0x7f) shl 24) or
                   ((hash[offset + 1].toInt() and 0xff) shl 16) or
                   ((hash[offset + 2].toInt() and 0xff) shl 8) or
                   (hash[offset + 3].toInt() and 0xff)
        return String.format("%06d", code % 10.0.pow(6).toInt())
    }

    private fun encodeBase32(bytes: ByteArray): String {
        val sb = StringBuilder()
        var buffer = 0; var bitsLeft = 0
        for (b in bytes) {
            buffer = (buffer shl 8) or (b.toInt() and 0xff)
            bitsLeft += 8
            while (bitsLeft >= 5) {
                bitsLeft -= 5
                sb.append(base32Chars[(buffer ushr bitsLeft) and 0x1f])
            }
        }
        if (bitsLeft > 0) sb.append(base32Chars[(buffer shl (5 - bitsLeft)) and 0x1f])
        return sb.toString()
    }

    private fun decodeBase32(s: String): ByteArray {
        var buffer = 0; var bitsLeft = 0
        val result = mutableListOf<Byte>()
        for (c in s.uppercase()) {
            val idx = base32Chars.indexOf(c)
            if (idx < 0) continue
            buffer = (buffer shl 5) or idx
            bitsLeft += 5
            if (bitsLeft >= 8) {
                bitsLeft -= 8
                result.add((buffer ushr bitsLeft).toByte())
                buffer = buffer and ((1 shl bitsLeft) - 1)
            }
        }
        return result.toByteArray()
    }
}
