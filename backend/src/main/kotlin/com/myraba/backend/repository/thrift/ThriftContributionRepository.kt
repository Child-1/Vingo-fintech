// src/main/kotlin/com/vingo/backend/repository/thrift/ThriftContributionRepository.kt
package com.myraba.backend.repository.thrift

import com.myraba.backend.model.thrift.ThriftContribution
import com.myraba.backend.model.thrift.ThriftMember
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository
import java.time.LocalDate

@Repository
interface ThriftContributionRepository : JpaRepository<ThriftContribution, Long> {

    fun existsByMemberAndContributionDate(member: ThriftMember, date: LocalDate): Boolean

    // Optional: helpful queries
    fun findByMemberAndContributionDate(member: ThriftMember, date: LocalDate): ThriftContribution?
    fun countByMember(member: ThriftMember): Long
}