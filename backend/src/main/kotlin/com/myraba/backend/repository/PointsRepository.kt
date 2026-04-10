package com.myraba.backend.repository

import com.myraba.backend.model.PointEvent
import com.myraba.backend.model.PointReason
import com.myraba.backend.model.UserPoints
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.stereotype.Repository

@Repository
interface UserPointsRepository : JpaRepository<UserPoints, Long> {
    fun findByUserId(userId: Long): UserPoints?
}

@Repository
interface PointEventRepository : JpaRepository<PointEvent, Long> {
    fun findByUserIdOrderByCreatedAtDesc(userId: Long): List<PointEvent>
    fun findByUserIdAndYear(userId: Long, year: Int): List<PointEvent>

    @Query("SELECT SUM(e.points) FROM PointEvent e WHERE e.user.id = :userId AND e.year = :year")
    fun sumPointsByUserAndYear(userId: Long, year: Int): Long?

    @Query("SELECT SUM(e.points) FROM PointEvent e WHERE e.user.id = :userId AND e.year = :year AND e.reason = :reason")
    fun sumPointsByUserYearAndReason(userId: Long, year: Int, reason: PointReason): Long?

    fun countByUserIdAndYear(userId: Long, year: Int): Long
}
