package com.myraba.backend.repository.thrift

import com.myraba.backend.model.User
import com.myraba.backend.model.thrift.PrivateThrift
import com.myraba.backend.model.thrift.PrivateMemberStatus
import com.myraba.backend.model.thrift.PrivateThriftMember
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.stereotype.Repository

@Repository
interface PrivateThriftMemberRepository : JpaRepository<PrivateThriftMember, Long> {
    fun findByThrift(thrift: PrivateThrift): List<PrivateThriftMember>
    fun findByThriftAndStatus(thrift: PrivateThrift, status: PrivateMemberStatus): List<PrivateThriftMember>
    fun findByUser(user: User): List<PrivateThriftMember>
    fun findByThriftAndUser(thrift: PrivateThrift, user: User): PrivateThriftMember?
    fun existsByThriftAndUser(thrift: PrivateThrift, user: User): Boolean
    fun countByThriftAndStatus(thrift: PrivateThrift, status: PrivateMemberStatus): Long

    @Query("SELECT m FROM PrivateThriftMember m WHERE m.thrift = :thrift AND m.status = 'ACTIVE' ORDER BY m.position ASC NULLS LAST")
    fun findActiveByThriftOrderByPosition(thrift: PrivateThrift): List<PrivateThriftMember>
}
