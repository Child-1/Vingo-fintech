package com.myraba.backend.model

import jakarta.persistence.*
import java.time.LocalDateTime

@Entity
@Table(name = "otps")
data class Otp(
    @Id @GeneratedValue val id: Long? = null,

    // Either phone or email — exactly one must be non-null
    val phone: String? = null,
    val email: String? = null,

    @Column(nullable = false)
    val code: String,

    @Column(nullable = false)
    val purpose: String,   // REGISTRATION, LOGIN, WITHDRAWAL, CARD_LINK

    @Column(nullable = false)
    val expiresAt: LocalDateTime,

    var used: Boolean = false
)
