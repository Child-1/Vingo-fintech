package com.myraba.backend.service

import com.myraba.backend.model.Otp
import com.myraba.backend.repository.OtpRepository
import org.springframework.stereotype.Service
import java.time.LocalDateTime
import kotlin.random.Random

@Service
class OtpService(
    private val otpRepository: OtpRepository,
    private val resend: ResendEmailService,
    private val aes: AesEncryptionService,
    private val sms: SmsService,
) {

    // ─── Phone OTP ────────────────────────────────────────────────

    fun generateOtpForPhone(phone: String, purpose: String = "REGISTRATION"): String {
        otpRepository.findTopByPhoneAndPurposeOrderByIdDesc(phone, purpose)?.let {
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
        otpRepository.findTopByEmailAndPurposeOrderByIdDesc(email, purpose)?.let {
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
        val subject = when (purpose) {
            "REGISTRATION" -> "Your Myraba registration code"
            "LOGIN"        -> "Your Myraba login code"
            "WITHDRAWAL"   -> "Confirm your Myraba withdrawal"
            else           -> "Your Myraba verification code"
        }
        val text = """
            Your Myraba verification code is: $code

            This code expires in 10 minutes. Do not share it with anyone.

            If you did not request this, please ignore this email.

            — The Myraba Team
        """.trimIndent()

        val sent = resend.send(email, subject, text)
        if (!sent) println("=== OTP FALLBACK — Email: $email | Code: $code ===")
    }
}
