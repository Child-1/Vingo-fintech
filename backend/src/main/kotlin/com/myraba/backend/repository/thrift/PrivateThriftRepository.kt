package com.myraba.backend.repository.thrift

import com.myraba.backend.model.User
import com.myraba.backend.model.thrift.PrivateThrift
import com.myraba.backend.model.thrift.PrivateThriftStatus
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

@Repository
interface PrivateThriftRepository : JpaRepository<PrivateThrift, Long> {
    fun findByInviteCode(inviteCode: String): PrivateThrift?
    fun findByCreator(creator: User): List<PrivateThrift>
    fun findByCreatorAndStatus(creator: User, status: PrivateThriftStatus): List<PrivateThrift>
    fun countByCreatorAndStatusIn(creator: User, statuses: List<PrivateThriftStatus>): Long
}
