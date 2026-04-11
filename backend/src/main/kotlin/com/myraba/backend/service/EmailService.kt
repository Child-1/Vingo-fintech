package com.myraba.backend.service

import org.springframework.beans.factory.annotation.Value
import org.springframework.mail.javamail.JavaMailSender
import org.springframework.mail.javamail.MimeMessageHelper
import org.springframework.stereotype.Service

@Service
class EmailService(private val mailSender: JavaMailSender) {

    @Value("\${MYRABA_MAIL_FROM:onboarding@resend.dev}") private val from: String = "onboarding@resend.dev"

    fun sendStaffWelcome(to: String, fullName: String, handle: String, tempPassword: String, role: String) {
        try {
            val msg = mailSender.createMimeMessage()
            val helper = MimeMessageHelper(msg, false, "UTF-8")
            helper.setFrom(from)
            helper.setTo(to)
            helper.setSubject("Welcome to Myraba — Your Staff Account")
            helper.setText("""
                Hi $fullName,

                Your Myraba staff account has been created with the role: $role.

                Login handle : @$handle
                Temporary password : $tempPassword

                Please log in to the admin panel and change your password immediately.

                — Myraba Team
            """.trimIndent())
            mailSender.send(msg)
            println("=== EMAIL SENT to $to for @$handle ===")
        } catch (e: Exception) {
            println("=== EMAIL FAILED for $to: ${e.message} | TempPass: $tempPassword ===")
        }
    }
}
