package com.myraba.backend.model

import jakarta.persistence.*
import java.math.BigDecimal
import java.time.LocalDate
import java.time.LocalDateTime

enum class PersonalGoalStatus { ACTIVE, COMPLETED, WITHDRAWN }

@Entity
@Table(name = "personal_goals")
data class PersonalGoal(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    val user: User,

    @Column(nullable = false, length = 100)
    val name: String,

    @Column(length = 300)
    val description: String? = null,

    @Column(nullable = false, precision = 19, scale = 4)
    val targetAmount: BigDecimal,

    @Column(nullable = false, precision = 19, scale = 4)
    var savedAmount: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false)
    val targetDate: LocalDate,

    // Optional scheduled auto-deduction from main wallet
    @Column(precision = 19, scale = 4)
    val autoDeductAmount: BigDecimal? = null,

    @Column(length = 10) // DAILY | WEEKLY | MONTHLY
    val autoDeductFrequency: String? = null,

    @Column
    var nextDeductDate: LocalDate? = null,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    var status: PersonalGoalStatus = PersonalGoalStatus.ACTIVE,

    val createdAt: LocalDateTime = LocalDateTime.now(),
    var completedAt: LocalDateTime? = null,
    var withdrawnAt: LocalDateTime? = null,
)
