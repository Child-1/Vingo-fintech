package com.myraba.backend.repository

import com.myraba.backend.model.IdempotencyRecord
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Modifying
import org.springframework.data.jpa.repository.Query
import org.springframework.stereotype.Repository
import java.time.LocalDateTime

@Repository
interface IdempotencyRepository : JpaRepository<IdempotencyRecord, Long> {

    fun findByIdempotencyKeyAndOwnerVingHandle(key: String, owner: String): IdempotencyRecord?

    @Modifying
    @Query("DELETE FROM IdempotencyRecord r WHERE r.expiresAt < :now")
    fun deleteExpired(now: LocalDateTime): Int
}
