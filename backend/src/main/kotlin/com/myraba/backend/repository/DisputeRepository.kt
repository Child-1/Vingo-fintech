package com.myraba.backend.repository

import com.myraba.backend.model.DisputeRequest
import com.myraba.backend.model.DisputeStatus
import com.myraba.backend.model.User
import org.springframework.data.jpa.repository.JpaRepository

interface DisputeRepository : JpaRepository<DisputeRequest, Long> {
    fun findByUserOrderByCreatedAtDesc(user: User): List<DisputeRequest>
    fun findByStatusOrderByCreatedAtAsc(status: DisputeStatus): List<DisputeRequest>
    fun findAllByOrderByCreatedAtDesc(): List<DisputeRequest>
}
