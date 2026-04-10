package com.myraba.backend.repository

import com.myraba.backend.model.TagChangeStatus
import com.myraba.backend.model.MyrabaTagChangeRequest
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

@Repository
interface MyrabaTagChangeRequestRepository : JpaRepository<MyrabaTagChangeRequest, Long> {
    fun findByUserId(userId: Long): List<MyrabaTagChangeRequest>
    fun findByUserIdAndStatus(userId: Long, status: TagChangeStatus): List<MyrabaTagChangeRequest>
    fun findByStatus(status: TagChangeStatus, pageable: Pageable): Page<MyrabaTagChangeRequest>
    fun countByUserIdAndStatus(userId: Long, status: TagChangeStatus): Long
}
