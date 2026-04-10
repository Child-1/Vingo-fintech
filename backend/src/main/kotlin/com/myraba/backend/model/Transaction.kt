package com.myraba.backend.model

import jakarta.persistence.*
import java.math.BigDecimal
import java.time.LocalDateTime

enum class TransactionType {
    TRANSFER,
    FUNDED,
    WITHDRAWAL,
    CONTRIBUTION,
    PAYOUT,
    PENALTY,
    ADMIN_CREDIT,
    ADMIN_DEBIT,
    REVERSAL,
    BILL_PAYMENT,
    GIFT
}

@Entity
@Table(name = "transactions")
data class Transaction(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0,

    // Nullable: null senderWallet means system-originated credit (e.g. FUNDED, PAYOUT)
    @ManyToOne
    @JoinColumn(name = "sender_wallet_id", nullable = true)
    val senderWallet: Wallet? = null,

    // Nullable: null receiverWallet means system-originated debit (e.g. PENALTY, CONTRIBUTION)
    @ManyToOne
    @JoinColumn(name = "receiver_wallet_id", nullable = true)
    val receiverWallet: Wallet? = null,

    @Column(nullable = false, precision = 15, scale = 2)
    val amount: BigDecimal,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    val type: TransactionType = TransactionType.TRANSFER,

    @Column(nullable = true, precision = 10, scale = 2)
    val fee: BigDecimal? = null,

    var description: String? = null,

    val status: String = "SUCCESS",

    val createdAt: LocalDateTime = LocalDateTime.now()
)