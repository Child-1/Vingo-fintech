package com.myraba.backend.repository

import com.myraba.backend.model.BroadcastAudience
import com.myraba.backend.model.BroadcastMessage
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import org.springframework.stereotype.Repository
import java.time.LocalDateTime

@Repository
interface BroadcastRepository : JpaRepository<BroadcastMessage, Long> {

    fun findByActiveTrue(): List<BroadcastMessage>

    fun findByActiveTrueAndAudience(audience: BroadcastAudience): List<BroadcastMessage>

    fun findByActiveTrueAndTargetVingHandle(myrabaHandle: String): List<BroadcastMessage>

    @Query("""
        SELECT b FROM BroadcastMessage b WHERE b.active = true AND (
            b.expiresAt IS NULL OR b.expiresAt > :now
        ) AND (
            b.audience = 'ALL' OR
            (b.audience = 'SPECIFIC_USER' AND b.targetVingHandle = :myrabaHandle) OR
            b.audience = :kyc OR
            b.audience = :role
        )
    """)
    fun findActiveForUser(
        @Param("myrabaHandle") myrabaHandle: String,
        @Param("kyc") kyc: BroadcastAudience?,
        @Param("role") role: BroadcastAudience?,
        @Param("now") now: LocalDateTime
    ): List<BroadcastMessage>
}
