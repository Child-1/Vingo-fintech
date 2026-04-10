package com.myraba.backend.model

import jakarta.persistence.*

@Entity
@Table(name = "mfa_secrets")
data class MfaSecret(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    val user: User,

    /** AES-encrypted Base32 TOTP secret */
    @Column(nullable = false, length = 500)
    val encryptedSecret: String,

    var enabled: Boolean = false
)
