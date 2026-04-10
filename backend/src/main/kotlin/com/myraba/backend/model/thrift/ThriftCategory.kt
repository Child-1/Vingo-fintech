package com.myraba.backend.model.thrift

import jakarta.persistence.*
import java.math.BigDecimal
import java.time.LocalDateTime

@Entity
@Table(name = "thrift_categories")
data class ThriftCategory(

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long? = null,

    var name: String = "",
    var description: String? = null,

    @Column(nullable = false)
    var contributionAmount: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false)
    var contributionFrequency: String = "DAILY",  // DAILY, WEEKLY, MONTHLY

    /** How many contributions a member must make before becoming eligible for payout */
    @Column(nullable = false)
    var durationInCycles: Int = 0,

    /**
     * How many placeholder "ghost" positions fill the front of the queue.
     * Defaults to durationInCycles so the first real member must complete
     * all cycles before reaching position 1.
     * Admin can override this to make the queue appear larger.
     */
    @Column(nullable = false)
    var placeholderCount: Int = 0,

    var targetAmount: BigDecimal? = null,  // contributionAmount * durationInCycles
    var isPublic: Boolean = true,
    var isActive: Boolean = true,
    var createdByAdmin: Boolean = true,
    var createdAt: LocalDateTime = LocalDateTime.now(),

    @OneToMany(mappedBy = "category", cascade = [CascadeType.ALL], orphanRemoval = true)
    val members: MutableSet<ThriftMember> = mutableSetOf()
) {
    /** Total days the cycle runs (used by scheduler) */
    val durationInDays: Int
        get() = when (contributionFrequency.uppercase()) {
            "DAILY"   -> durationInCycles
            "WEEKLY"  -> durationInCycles * 7
            "MONTHLY" -> durationInCycles * 30
            else      -> durationInCycles
        }

    /** The amount a member will collect at payout = contributionAmount × durationInCycles */
    val payoutAmount: BigDecimal
        get() = contributionAmount.multiply(BigDecimal(durationInCycles))
}
