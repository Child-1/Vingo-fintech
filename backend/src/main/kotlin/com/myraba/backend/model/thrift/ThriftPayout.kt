// src/main/kotlin/com/vingo/backend/model/thrift/ThriftPayout.kt
package com.myraba.backend.model.thrift

import jakarta.persistence.*
import com.myraba.backend.model.thrift.ThriftMember
import java.math.BigDecimal
import java.time.LocalDate

@Entity
@Table(name = "thrift_payouts")
class ThriftPayout(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long? = null,

    @OneToOne
    @JoinColumn(name = "member_id", nullable = false)
    val member: ThriftMember,

    var amount: BigDecimal,
    var payoutDate: LocalDate = LocalDate.now(),
    var initiatedBySystem: Boolean = true
)