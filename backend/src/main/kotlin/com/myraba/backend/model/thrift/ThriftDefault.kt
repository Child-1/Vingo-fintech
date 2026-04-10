package com.myraba.backend.model.thrift

import com.myraba.backend.model.User
import jakarta.persistence.*
import java.math.BigDecimal
import java.time.LocalDateTime

enum class DefaultStatus {
    ACTIVE,       // flagged, monitoring for recoverable funds
    FROZEN,       // funds found and frozen, awaiting dispute/forfeit decision
    DISPUTED,     // user filed a dispute
    RESOLVED,     // user proved they paid — funds released
    FORFEITED     // funds transferred to creator after deadline
}

@Entity
@Table(name = "thrift_defaults")
data class ThriftDefault(

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "defaulter_id", nullable = false)
    val defaulter: User,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "creator_id", nullable = false)
    val creator: User,   // the thrift creator who is owed

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "thrift_id", nullable = false)
    val thrift: PrivateThrift,

    /** Amount the defaulter owes */
    @Column(nullable = false, precision = 15, scale = 2)
    val amountOwed: BigDecimal,

    @Enumerated(EnumType.STRING)
    var status: DefaultStatus = DefaultStatus.ACTIVE,

    val flaggedAt: LocalDateTime = LocalDateTime.now(),

    /** When funds were detected and frozen */
    var frozenAt: LocalDateTime? = null,

    /** Dispute deadline tracking */
    var disputeRound: Int = 0,         // 0 = not in dispute, 1 = round 1, 2 = round 2, 3 = final
    var disputeDeadline: LocalDateTime? = null,

    var resolvedAt: LocalDateTime? = null,

    @Column(length = 1000)
    var disputeProofNote: String? = null,

    @Column(length = 500)
    var adminNote: String? = null
)
