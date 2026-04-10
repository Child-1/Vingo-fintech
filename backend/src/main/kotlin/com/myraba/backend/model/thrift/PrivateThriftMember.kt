package com.myraba.backend.model.thrift

import com.myraba.backend.model.User
import jakarta.persistence.*
import java.math.BigDecimal
import java.time.LocalDateTime

enum class PrivateMemberStatus {
    INVITED,            // invite code used, awaiting rule acceptance
    ACTIVE,             // rules accepted, participating
    COMPLETED,          // received their payout and finished all contributions
    EJECTED,            // removed by creator for cause
    WITHDRAWN           // voluntarily left before payout
}

@Entity
@Table(name = "private_thrift_members")
data class PrivateThriftMember(

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "thrift_id", nullable = false)
    val thrift: PrivateThrift,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    val user: User,

    /** Queue position — null until assigned (MANUAL) or raffled (RAFFLE) */
    var position: Int? = null,

    @Enumerated(EnumType.STRING)
    var status: PrivateMemberStatus = PrivateMemberStatus.INVITED,

    var agreedToRules: Boolean = false,
    var agreedAt: LocalDateTime? = null,

    /** Total contributed across all cycles so far */
    @Column(precision = 15, scale = 2)
    var totalContributed: BigDecimal = BigDecimal.ZERO,

    /** Amount contributed in the current cycle */
    @Column(precision = 15, scale = 2)
    var currentCycleContributed: BigDecimal = BigDecimal.ZERO,

    var hasReceivedPayout: Boolean = false,
    var payoutApprovedAt: LocalDateTime? = null,

    /** Entry fee paid flag */
    var entryFeePaid: Boolean = false,

    val joinedAt: LocalDateTime = LocalDateTime.now(),
    var lastContributionAt: LocalDateTime? = null,

    /** Ejection reason — must match a pre-agreed rule */
    @Column(length = 500)
    var ejectionReason: String? = null
)
