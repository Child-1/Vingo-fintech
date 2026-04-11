package com.myraba.backend.service

import org.springframework.stereotype.Service

@Service
class EmailService(private val resend: ResendEmailService) {

    fun sendStaffWelcome(to: String, fullName: String, handle: String, tempPassword: String, role: String) {
        val sent = resend.send(
            to = to,
            subject = "Welcome to Myraba — Your Staff Account",
            text = """
                Hi $fullName,

                Your Myraba staff account has been created with the role: $role.

                Login handle : @$handle
                Temporary password : $tempPassword

                Please log in and change your password immediately.

                — Myraba Team
            """.trimIndent()
        )
        if (!sent) println("=== STAFF WELCOME FALLBACK — Handle: @$handle | TempPass: $tempPassword ===")
    }
}
