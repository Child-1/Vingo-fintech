package com.myraba.backend.model

import jakarta.persistence.*
import java.math.BigDecimal
import java.time.LocalDateTime

@Entity
@Table(name = "wallets")
data class Wallet(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @OneToOne
    @JoinColumn(name = "user_id", unique = true, nullable = false)
    val user: User,

    @Column(nullable = false, precision = 15, scale = 2)
    var balance: BigDecimal = BigDecimal.ZERO,

    @Version
    var version: Long = 0L,

    val createdAt: LocalDateTime = LocalDateTime.now(),
    var updatedAt: LocalDateTime = LocalDateTime.now()
)