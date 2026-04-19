package com.myraba.backend.dto

import jakarta.validation.constraints.Pattern
import jakarta.validation.constraints.Size

data class RegisterRequest(
    // 3–20 chars: letters, digits, underscores only — no spaces, no m₦ prefix
    @field:Pattern(
        regexp = "^[a-zA-Z0-9_]{3,20}$",
        message = "MyrabaTag must be 3–20 characters and contain only letters, numbers, or underscores"
    )
    val myrabaHandle: String,

    @field:Size(min = 8, message = "Password must be at least 8 characters")
    val password: String,

    @field:Size(min = 2, max = 100, message = "Full name must be between 2 and 100 characters")
    val fullName: String,

    val phone: String? = null,        // provide phone OR email — at least one required
    val email: String? = null,
    val otpCode: String? = null,
    val useCustomAccountId: Boolean = false,
    val nameChoice: String = "LAST",  // "FIRST", "LAST", or "MIDDLE"
    val usePhoneAsAccountNumber: Boolean = true,
    val referralCode: String? = null  // optional invite code from an existing user
)

data class LoginRequest(
    val identifier: String,           // phone number OR email address
    val password: String
)

data class LoginResponse(
    val token: String?,               // null when mfaRequired = true
    val myrabaHandle: String,
    val myrabaTag: String,
    val role: String,
    val mfaRequired: Boolean = false,
    val forcePasswordChange: Boolean = false
)

data class SendOtpRequest(
    val contact: String,              // phone number or email address
    val purpose: String = "REGISTRATION"
)
