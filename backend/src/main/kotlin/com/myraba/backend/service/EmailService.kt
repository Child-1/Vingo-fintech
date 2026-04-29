package com.myraba.backend.service

import org.springframework.stereotype.Service

@Service
class EmailService(private val resend: ResendEmailService) {

    fun sendStaffInvitation(to: String, fullName: String, staffId: String, inviteLink: String, role: String) {
        val sent = resend.send(
            to = to,
            subject = "You've been invited to join Myraba Staff",
            text = """
                Hi $fullName,

                You have been added to the Myraba admin team as: $role

                Your Staff ID: $staffId

                Please complete your registration by clicking the link below (expires in 72 hours):
                $inviteLink

                You will be asked to set your password and provide some personal details.

                If you did not expect this email, please ignore it.

                — Myraba Team
            """.trimIndent()
        )
        if (!sent) println("=== STAFF INVITE FALLBACK — StaffId: $staffId | Link: $inviteLink ===")
    }

    fun sendStaffWelcome(to: String, fullName: String, staffId: String, role: String) {
        val sent = resend.send(
            to = to,
            subject = "Welcome to Myraba — Registration Complete",
            text = """
                Hi $fullName,

                Your Myraba staff account is now active.

                Staff ID : $staffId
                Role     : $role

                You can log in at the admin portal using your Staff ID and the password you set.

                — Myraba Team
            """.trimIndent()
        )
        if (!sent) println("=== STAFF WELCOME FALLBACK — StaffId: $staffId ===")
    }
}
