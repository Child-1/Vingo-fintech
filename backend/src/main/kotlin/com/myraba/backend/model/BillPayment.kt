package com.myraba.backend.model

import jakarta.persistence.*
import java.math.BigDecimal
import java.time.LocalDateTime

enum class BillCategory {
    AIRTIME, DATA, ELECTRICITY, CABLE_TV, WATER, BETTING, EDUCATION
}

@Entity
@Table(name = "bill_payments")
data class BillPayment(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    val user: User,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val category: BillCategory,

    /** VTpass service ID e.g. "mtn", "dstv", "ikeja-electric" */
    @Column(nullable = false, length = 50)
    val serviceId: String,

    /** Human-readable provider name e.g. "MTN Nigeria" */
    @Column(nullable = false, length = 80)
    val providerName: String,

    /** Phone number, meter number, smartcard number etc. */
    @Column(nullable = false, length = 50)
    val billIdentifier: String,

    @Column(nullable = false, precision = 12, scale = 2)
    val amount: BigDecimal,

    /** VTpass request ID for tracking */
    @Column(unique = true, nullable = false, length = 60)
    val requestId: String,

    /** VTpass transaction code returned on success */
    @Column(length = 60)
    var vtpassCode: String? = null,

    /** SUCCESS, PENDING, FAILED */
    @Column(nullable = false, length = 20)
    var status: String = "PENDING",

    @Column(length = 300)
    var failureReason: String? = null,

    val createdAt: LocalDateTime = LocalDateTime.now(),
    var completedAt: LocalDateTime? = null
)
