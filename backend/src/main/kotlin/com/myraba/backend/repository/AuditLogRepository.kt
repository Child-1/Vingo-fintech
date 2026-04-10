package com.myraba.backend.repository

import com.myraba.backend.model.AuditLog
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository
import java.time.LocalDateTime

@Repository
interface AuditLogRepository : JpaRepository<AuditLog, Long> {
    fun findByActorHandle(actorHandle: String, pageable: Pageable): Page<AuditLog>
    fun findByActorType(actorType: String, pageable: Pageable): Page<AuditLog>
    fun findByTargetTypeAndTargetId(targetType: String, targetId: String, pageable: Pageable): Page<AuditLog>
    fun findByCreatedAtAfter(since: LocalDateTime, pageable: Pageable): Page<AuditLog>
    fun findByAction(action: String, pageable: Pageable): Page<AuditLog>
}
