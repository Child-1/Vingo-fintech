package com.myraba.backend.model

import jakarta.persistence.*
import java.math.BigDecimal
import java.time.LocalDateTime

@Entity
@Table(name = "gift_transactions")
data class GiftTransaction(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    /** Null for non-app senders */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "sender_user_id", nullable = true)
    val senderUser: User? = null,

    /** Name provided by non-app sender (or overridden if anonymous) */
    @Column(length = 100)
    val senderName: String? = null,

    /** Phone provided by non-app sender */
    @Column(length = 20)
    val senderPhone: String? = null,

    /** Whether sender chose to be anonymous */
    val anonymous: Boolean = false,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "recipient_user_id", nullable = false)
    val recipient: User,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "gift_item_id", nullable = false)
    val giftItem: GiftItem,

    @Column(nullable = false, precision = 10, scale = 2)
    val nairaValue: BigDecimal,

    @Column(length = 500)
    val note: String? = null,

    /** WALLET, CARD, BANK_TRANSFER — payment method used */
    @Column(nullable = false, length = 20)
    val paymentMethod: String = "WALLET",

    /** Flutterwave transaction reference for card/bank payments */
    @Column(length = 100)
    val externalReference: String? = null,

    /** PENDING, COMPLETED, FAILED */
    @Column(nullable = false, length = 20)
    var status: String = "COMPLETED",

    val createdAt: LocalDateTime = LocalDateTime.now()
)

@Entity
@Table(name = "gift_balances")
data class GiftBalance(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", unique = true, nullable = false)
    val user: User,

    @Column(nullable = false, precision = 15, scale = 2)
    var balance: BigDecimal = BigDecimal.ZERO,

    var updatedAt: LocalDateTime = LocalDateTime.now()
)
