package com.myraba.backend.repository.thrift

import com.myraba.backend.model.User
import com.myraba.backend.model.thrift.ThriftCategory
import com.myraba.backend.model.thrift.ThriftMember
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.stereotype.Repository

@Repository
interface ThriftMemberRepository : JpaRepository<ThriftMember, Long> {

    fun existsByUserAndCategoryAndHasWithdrawnFalse(user: User, category: ThriftCategory): Boolean

    fun findByCategoryIdAndHasWithdrawnOrderByPositionAsc(categoryId: Long, hasWithdrawn: Boolean): List<ThriftMember>

    fun findByUserAndHasWithdrawn(user: User, hasWithdrawn: Boolean): List<ThriftMember>

    fun countByCategoryIdAndHasWithdrawn(categoryId: Long, hasWithdrawn: Boolean): Long

    @Query("SELECT COALESCE(MAX(m.position), 0) FROM ThriftMember m WHERE m.category.id = :categoryId AND m.hasWithdrawn = false")
    fun findMaxPositionInCategory(categoryId: Long): Long?

    @Query("SELECT COALESCE(SUM(m.totalContributed), 0) FROM ThriftMember m WHERE m.hasWithdrawn = false")
    fun sumActiveMemberContributions(): java.math.BigDecimal?

    @Query("SELECT m FROM ThriftMember m WHERE m.hasWithdrawn = false AND m.category.isActive = true")
    fun findAllActiveMembers(): List<ThriftMember>
}
