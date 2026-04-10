package com.myraba.backend.model

import jakarta.persistence.*
import java.time.LocalDateTime

enum class BroadcastAudience {
    ALL, KYC_APPROVED, KYC_PENDING, ROLE_USER, ROLE_STAFF, SPECIFIC_USER
}

enum class BroadcastType {
    INFO, WARNING, PROMOTION, MAINTENANCE, SECURITY
}

@Entity
@Table(name = "broadcast_messages")
data class BroadcastMessage(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0,

    @Column(nullable = false)
    val title: String,

    @Column(nullable = false, columnDefinition = "TEXT")
    val body: String,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val type: BroadcastType = BroadcastType.INFO,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val audience: BroadcastAudience = BroadcastAudience.ALL,

    // If audience = SPECIFIC_USER, the targetVingHandle is set
    @Column(nullable = true)
    val targetVingHandle: String? = null,

    // Who sent this broadcast
    @Column(nullable = false)
    val sentBy: String,

    // Whether users have "dismissed" this — stored in a separate read-receipts table in v2
    @Column(nullable = false)
    val active: Boolean = true,

    val createdAt: LocalDateTime = LocalDateTime.now(),

    // Optional expiry
    val expiresAt: LocalDateTime? = null
)
