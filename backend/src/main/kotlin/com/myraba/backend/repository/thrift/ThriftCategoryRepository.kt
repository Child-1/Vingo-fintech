package com.myraba.backend.repository.thrift

import com.myraba.backend.model.thrift.ThriftCategory
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.stereotype.Repository

@Repository
interface ThriftCategoryRepository : JpaRepository<ThriftCategory, Long> {

    // Used for the mobile app to show available public plans
    fun findByIsPublicAndIsActive(isPublic: Boolean, isActive: Boolean): List<ThriftCategory>

    // Used by admin to list all public categories regardless of active state
    fun findByIsPublicOrderByCreatedAtDesc(isPublic: Boolean): List<ThriftCategory>

    // Used for general statistics
    fun countByIsPublicAndIsActive(isPublic: Boolean, isActive: Boolean): Long

    // This matches the call in AdminDashboardController.getStats()
    @Query("SELECT COUNT(c) FROM ThriftCategory c WHERE c.isActive = true")
    fun countActiveThrifts(): Long
}