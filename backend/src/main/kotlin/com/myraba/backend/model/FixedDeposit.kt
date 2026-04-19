package com.myraba.backend.model

import jakarta.persistence.*
import java.math.BigDecimal
import java.time.LocalDateTime

enum class FixedDepositStatus { ACTIVE, MATURED, WITHDRAWN }

@Entity
@Table(name = "fixed_deposits")
data class FixedDeposit(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    val user: User,

    @Column(nullable = false, precision = 19, scale = 4)
    val amount: BigDecimal,

    @Column(nullable = false)
    val termDays: Int,                        // 30 / 90 / 180 / 365

    @Column(nullable = false, precision = 5, scale = 2)
    val interestRate: BigDecimal,             // annual % e.g. 12.50

    @Column(nullable = false, precision = 19, scale = 4)
    val expectedReturn: BigDecimal,           // amount + interest at maturity

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    var status: FixedDepositStatus = FixedDepositStatus.ACTIVE,

    val createdAt: LocalDateTime = LocalDateTime.now(),

    val maturesAt: LocalDateTime,

    var maturedAt: LocalDateTime? = null,
    var withdrawnAt: LocalDateTime? = null,
)
