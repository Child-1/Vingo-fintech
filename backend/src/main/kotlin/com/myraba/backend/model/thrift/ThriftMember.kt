// src/main/kotlin/com/vingo/backend/model/thrift/ThriftMember.kt
package com.myraba.backend.model.thrift

import com.myraba.backend.model.User
import jakarta.persistence.*
import java.math.BigDecimal
import java.time.LocalDate

@Entity
@Table(name = "thrift_members")
data class ThriftMember(                            // ← CHANGED TO data class
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long? = null,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    val user: User,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "category_id", nullable = false)
    val category: ThriftCategory,

    var position: Long = 0,
    var daysContributed: Int = 0,
    var totalContributed: BigDecimal = BigDecimal.ZERO,
    var hasWithdrawn: Boolean = false,
    var withdrawalDate: LocalDate? = null,

    var consecutiveMissedDays: Int = 0,
    var totalMissedDays: Int = 0,
    var penaltyLevel: Int = 0,

    var joinedAt: LocalDate = LocalDate.now(),
    var lastContributionDate: LocalDate? = null,

    @OneToMany(mappedBy = "member", cascade = [CascadeType.ALL], orphanRemoval = true)
    val contributions: MutableList<ThriftContribution> = mutableListOf()
) {
    val maxWithdrawableAmount: BigDecimal
        get() = totalContributed
}