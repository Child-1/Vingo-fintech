// src/main/kotlin/com/vingo/backend/model/thrift/ThriftPenalty.kt
package com.myraba.backend.model.thrift

import jakarta.persistence.*
import com.myraba.backend.model.thrift.ThriftMember
import java.math.BigDecimal
import java.time.LocalDate

@Entity
@Table(name = "thrift_penalties")
class ThriftPenalty(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long? = null,

    @ManyToOne
    @JoinColumn(name = "member_id")
    val member: ThriftMember,

    var amount: BigDecimal,
    var reason: String,
    var appliedAt: LocalDate = LocalDate.now()
)