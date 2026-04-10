package com.myraba.backend.model.thrift

import com.myraba.backend.model.User
import jakarta.persistence.*
import java.math.BigDecimal
import java.time.LocalDateTime

enum class PrivateThriftStatus { DRAFT, ACTIVE, PAUSED, COMPLETED, CANCELLED }
enum class PositionAssignment { MANUAL, RAFFLE }
enum class PaymentFlexibility {
    FIXED,           // must pay full amount at once on due date
    FLEXIBLE_SPLIT,  // can split into smaller payments within the cycle window
}

@Entity
@Table(name = "private_thrifts")
data class PrivateThrift(

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "creator_id", nullable = false)
    val creator: User,

    @Column(nullable = false)
    var name: String,

    @Column(length = 1000)
    var description: String? = null,

    /** The invite code members use to request joining */
    @Column(unique = true, nullable = false, length = 12)
    val inviteCode: String,

    /** Amount required per contribution cycle (e.g. ₦50,000/month) */
    @Column(nullable = false, precision = 15, scale = 2)
    var contributionAmount: BigDecimal,

    @Column(nullable = false)
    var frequency: String = "MONTHLY",   // DAILY, WEEKLY, MONTHLY

    @Enumerated(EnumType.STRING)
    var paymentFlexibility: PaymentFlexibility = PaymentFlexibility.FIXED,

    /** Total number of cycles (= number of members who will each collect once) */
    @Column(nullable = false)
    var totalCycles: Int,

    @Enumerated(EnumType.STRING)
    var positionAssignment: PositionAssignment = PositionAssignment.RAFFLE,

    @Enumerated(EnumType.STRING)
    var status: PrivateThriftStatus = PrivateThriftStatus.DRAFT,

    /** Rules the creator sets — displayed to members before they accept */
    @Column(length = 2000)
    var creatorRules: String? = null,

    /** One-time entry fee charged to each member on joining (e.g. ₦500) */
    @Column(nullable = false, precision = 10, scale = 2)
    var entryFee: BigDecimal = BigDecimal.ZERO,

    /** Surcharge added to each contribution payment (e.g. ₦20 per ₦50k payment) */
    @Column(nullable = false, precision = 10, scale = 2)
    var surchargePerContribution: BigDecimal = BigDecimal.ZERO,

    /** Current cycle number (1-based). Increments after each payout. */
    var currentCycle: Int = 0,

    val createdAt: LocalDateTime = LocalDateTime.now(),
    var startedAt: LocalDateTime? = null,
    var completedAt: LocalDateTime? = null,

    @OneToMany(mappedBy = "thrift", cascade = [CascadeType.ALL], orphanRemoval = true)
    val members: MutableList<PrivateThriftMember> = mutableListOf()
) {
    /** Creator must maintain at least one contribution amount in their wallet as collateral */
    val requiredCreatorCollateral: BigDecimal get() = contributionAmount
}
