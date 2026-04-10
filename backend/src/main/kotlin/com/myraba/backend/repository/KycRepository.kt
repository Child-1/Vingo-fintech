package com.myraba.backend.repository

import com.myraba.backend.model.KycSubmission
import com.myraba.backend.model.KycType
import com.myraba.backend.model.KycVerificationStatus
import com.myraba.backend.model.User
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

@Repository
interface KycRepository : JpaRepository<KycSubmission, Long> {
    fun findByUser(user: User): List<KycSubmission>
    fun findByUserAndType(user: User, type: KycType): KycSubmission?
    fun findByStatus(status: KycVerificationStatus, pageable: Pageable): Page<KycSubmission>
    fun countByStatus(status: KycVerificationStatus): Long
}
