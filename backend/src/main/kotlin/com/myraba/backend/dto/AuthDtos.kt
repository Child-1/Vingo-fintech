package com.myraba.backend.dto

import jakarta.validation.constraints.Pattern
import jakarta.validation.constraints.Size

data class RegisterRequest(
    @field:Pattern(
        regexp = "^[a-zA-Z0-9_]{3,20}$",
        message = "MyrabaTag must be 3–20 characters and contain only letters, numbers, or underscores"
    )
    val myrabaHandle: String,

    @field:Size(min = 8, message = "Password must be at least 8 characters")
    val password: String,

    @field:Size(min = 2, max = 100, message = "Full name must be between 2 and 100 characters")
    val fullName: String,

    val phone: String,                 // Required — becomes the 10-digit account number
    val email: String? = null,         // Optional
    val otpCode: String? = null,
    val customAccountId: String? = null, // User's own chosen Custom ID (e.g. "5678-smith")
    val referralCode: String? = null,
    val gender: String? = null
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
