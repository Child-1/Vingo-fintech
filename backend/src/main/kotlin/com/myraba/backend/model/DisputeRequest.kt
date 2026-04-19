package com.myraba.backend.model

import jakarta.persistence.*
import java.time.LocalDateTime

enum class DisputeStatus { OPEN, REVIEWING, RESOLVED, REJECTED }

@Entity
@Table(name = "dispute_requests")
data class DisputeRequest(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    val user: User,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "transaction_id", nullable = false)
    val transaction: Transaction,

    @Column(nullable = false, length = 50)
    val reason: String,                // WRONG_TRANSFER | DUPLICATE | FRAUD | OTHER

    @Column(nullable = false, length = 1000)
    val description: String,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    var status: DisputeStatus = DisputeStatus.OPEN,

    @Column(length = 500)
    var adminNote: String? = null,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reviewed_by", nullable = true)
    var reviewedBy: User? = null,

    val createdAt: LocalDateTime = LocalDateTime.now(),
    var resolvedAt: LocalDateTime? = null,
)
