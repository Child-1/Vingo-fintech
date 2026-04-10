package com.myraba.backend.service

import com.myraba.backend.model.Otp
import com.myraba.backend.repository.OtpRepository
import org.springframework.mail.SimpleMailMessage
import org.springframework.mail.javamail.JavaMailSender
import org.springframework.stereotype.Service
import java.time.LocalDateTime
import kotlin.random.Random

@Service
class OtpService(
    private val otpRepository: OtpRepository,
    private val mailSender: JavaMailSender,
    private val aes: AesEncryptionService,
    private val sms: SmsService,
) {

    // ─── Phone OTP ────────────────────────────────────────────────

    fun generateOtpForPhone(phone: String, purpose: String = "REGISTRATION"): String {
        otpRepository.findByPhoneAndPurpose(phone, purpose)?.let {
            it.used = true; otpRepository.save(it)
        }
        val code = newCode()
        otpRepository.save(Otp(phone = phone, code = aes.encrypt(code), purpose = purpose,
            expiresAt = LocalDateTime.now().plusMinutes(10)))

        sms.sendOtp(phone, code, purpose)
        return code
    }

    fun verifyOtpForPhone(phone: String, code: String, purpose: String = "REGISTRATION"): Boolean {
        val otps = otpRepository.findActiveOtpsByPhone(phone, purpose, LocalDateTime.now())
        val match = otps.firstOrNull { aes.decryptOrNull(it.code) == code } ?: return false
        match.used = true; otpRepository.save(match)
        return true
    }

    // ─── Email OTP ────────────────────────────────────────────────

    fun generateOtpForEmail(email: String, purpose: String = "REGISTRATION"): String {
        otpRepository.findByEmailAndPurpose(email, purpose)?.let {
            it.used = true; otpRepository.save(it)
        }
        val code = newCode()
        otpRepository.save(Otp(email = email, code = aes.encrypt(code), purpose = purpose,
            expiresAt = LocalDateTime.now().plusMinutes(10)))

        sendEmailOtp(email, code, purpose)
        return code
    }

    fun verifyOtpForEmail(email: String, code: String, purpose: String = "REGISTRATION"): Boolean {
        val otps = otpRepository.findActiveOtpsByEmail(email, purpose, LocalDateTime.now())
        val match = otps.firstOrNull { aes.decryptOrNull(it.code) == code } ?: return false
        match.used = true; otpRepository.save(match)
        return true
    }

    // ─── Generic (detects phone vs email by format) ───────────────

    fun generateOtp(contact: String, purpose: String = "REGISTRATION"): String =
        if (contact.contains("@")) generateOtpForEmail(contact, purpose)
        else generateOtpForPhone(contact, purpose)

    fun verifyOtp(contact: String, code: String, purpose: String = "REGISTRATION"): Boolean =
        if (contact.contains("@")) verifyOtpForEmail(contact, code, purpose)
        else verifyOtpForPhone(contact, code, purpose)

    // ─── Private helpers ──────────────────────────────────────────

    private fun newCode() = String.format("%06d", Random.nextInt(0, 999999))

    private fun sendEmailOtp(email: String, code: String, purpose: String) {
        try {
            val subject = when (purpose) {
                "REGISTRATION" -> "Your Myraba registration code"
                "LOGIN"        -> "Your Myraba login code"
                "WITHDRAWAL"   -> "Confirm your Myraba withdrawal"
                else           -> "Your Myraba verification code"
            }
            val message = SimpleMailMessage()
            message.setTo(email)
            message.subject = subject
            message.text = """
                Your Myraba verification code is: $code

                This code expires in 10 minutes. Do not share it with anyone.

                If you did not request this, please ignore this email.

                — The Myraba Team
            """.trimIndent()
            mailSender.send(message)
        } catch (e: Exception) {
            // Log but don't fail — in dev the mail server may not be configured
            println("=== MYRABA EMAIL OTP (mail send failed: ${e.message}) ===\nEmail: $email\nCode: $code\n===")
        }
    }
}
