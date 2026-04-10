// src/main/kotlin/com/vingo/backend/model/thrift/ThriftContribution.kt
package com.myraba.backend.model.thrift

import jakarta.persistence.*
import java.math.BigDecimal
import java.time.LocalDate
import com.myraba.backend.model.thrift.ThriftMember

@Entity
@Table(name = "thrift_contributions")
class ThriftContribution(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long? = null,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    val member: ThriftMember,

    var amount: BigDecimal,
    var contributionDate: LocalDate = LocalDate.now(),
    var isLate: Boolean = false,
    var penaltyApplied: BigDecimal = BigDecimal.ZERO
)