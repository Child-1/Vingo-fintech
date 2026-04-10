package com.myraba.backend.service

import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import java.security.SecureRandom
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * AES-256-GCM authenticated encryption.
 * Output format: Base64(iv[12] + ciphertext + authTag[16])
 * The IV is randomly generated per encryption — identical plaintexts produce different ciphertexts.
 */
@Service
class AesEncryptionService(
    @Value("\${encryption.key}") rawKey: String
) {
    private val secretKey: SecretKey

    init {
        // Accept either a raw 32-char string or a Base64-encoded 32-byte key
        val keyBytes = try {
            val decoded = Base64.getDecoder().decode(rawKey)
            require(decoded.size >= 32) { "Decoded key must be at least 32 bytes" }
            decoded.copyOf(32)
        } catch (_: IllegalArgumentException) {
            // Not valid Base64 — treat as raw UTF-8 string, pad/truncate to 32 bytes
            rawKey.toByteArray(Charsets.UTF_8).copyOf(32)
        }
        secretKey = SecretKeySpec(keyBytes, "AES")
    }

    fun encrypt(plaintext: String): String {
        val iv = ByteArray(12).also { SecureRandom().nextBytes(it) }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, secretKey, GCMParameterSpec(128, iv))
        val ciphertext = cipher.doFinal(plaintext.toByteArray(Charsets.UTF_8))
        // Prepend IV to ciphertext
        val combined = iv + ciphertext
        return Base64.getEncoder().encodeToString(combined)
    }

    fun decrypt(encoded: String): String {
        val combined = Base64.getDecoder().decode(encoded)
        val iv         = combined.copyOfRange(0, 12)
        val ciphertext = combined.copyOfRange(12, combined.size)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, secretKey, GCMParameterSpec(128, iv))
        return String(cipher.doFinal(ciphertext), Charsets.UTF_8)
    }

    /** Safe decrypt — returns null if decryption fails (e.g. legacy unencrypted value) */
    fun decryptOrNull(encoded: String): String? = try { decrypt(encoded) } catch (_: Exception) { null }
}
