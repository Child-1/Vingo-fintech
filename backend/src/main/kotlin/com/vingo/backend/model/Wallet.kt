package com.vingo.backend.model

import com.vingo.backend.dto.WalletResponse
import jakarta.persistence.*
import java.math.BigDecimal
import java.time.LocalDateTime

@Entity
@Table(name = "wallets")
data class Wallet(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0,

    @OneToOne
    @JoinColumn(name = "user_id", unique = true)
    val user: User,

    @Column(nullable = false, precision = 15, scale = 2)
    var balance: BigDecimal = BigDecimal.ZERO,

    val createdAt: LocalDateTime = LocalDateTime.now(),
    var updatedAt: LocalDateTime = LocalDateTime.now()
) {
    fun toResponse(): WalletResponse {
        return WalletResponse(
            walletId = id,
            vingHandle = user.vingHandle,
            balance = balance
        )
    }
}