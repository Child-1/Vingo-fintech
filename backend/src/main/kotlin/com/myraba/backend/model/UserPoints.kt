package com.myraba.backend.model

import jakarta.persistence.*
import java.math.BigDecimal
import java.time.LocalDateTime

enum class PointReason {
    TRANSFER_SENT,
    TRANSFER_RECEIVED,
    THRIFT_CONTRIBUTION,
    KYC_COMPLETED,
    FIRST_TRANSFER,
    DAILY_LOGIN,
    REFERRAL,
    ADMIN_GRANT
}

@Entity
@Table(name = "user_points")
data class UserPoints(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    val user: User,

    var totalPoints: Long = 0L,          // lifetime cumulative
    var thisYearPoints: Long = 0L,       // resets each year after conversion
    var allTimePoints: Long = 0L,        // never decremented — historical record

    var lastEarnedAt: LocalDateTime? = null
)

@Entity
@Table(name = "point_events")
data class PointEvent(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    val user: User,

    val points: Long,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val reason: PointReason,

    val description: String? = null,

    val year: Int,   // e.g. 2025 — pre-calculated for quick Wrapped queries

    val createdAt: LocalDateTime = LocalDateTime.now()
)
