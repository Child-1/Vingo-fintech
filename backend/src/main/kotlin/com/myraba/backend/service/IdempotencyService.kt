package com.myraba.backend.service

import com.fasterxml.jackson.databind.ObjectMapper
import com.myraba.backend.model.IdempotencyRecord
import com.myraba.backend.repository.IdempotencyRepository
import org.springframework.http.ResponseEntity
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDateTime

@Service
class IdempotencyService(
    private val repo: IdempotencyRepository,
    private val mapper: ObjectMapper
) {

    /**
     * Check whether [key] has already been processed for [ownerVingHandle].
     * Returns the cached ResponseEntity if found and not expired, null otherwise.
     */
    fun getCached(key: String, ownerVingHandle: String): ResponseEntity<Any>? {
        val record = repo.findByIdempotencyKeyAndOwnerVingHandle(key, ownerVingHandle)
            ?: return null
        if (record.expiresAt.isBefore(LocalDateTime.now())) return null

        @Suppress("UNCHECKED_CAST")
        val body = mapper.readValue(record.responseBody, Any::class.java)
        return ResponseEntity.status(record.responseStatus).body(body)
    }

    /**
     * Persist the result of a request so retries return the same response.
     */
    @Transactional
    fun store(key: String, ownerVingHandle: String, response: ResponseEntity<*>) {
        if (repo.findByIdempotencyKeyAndOwnerVingHandle(key, ownerVingHandle) != null) return
        repo.save(
            IdempotencyRecord(
                idempotencyKey = key,
                ownerVingHandle = ownerVingHandle,
                responseStatus = response.statusCode.value(),
                responseBody = mapper.writeValueAsString(response.body)
            )
        )
    }

    /** Runs nightly at 2am — removes keys older than 24 h */
    @Scheduled(cron = "0 0 2 * * *")
    @Transactional
    fun purgeExpired() {
        val deleted = repo.deleteExpired(LocalDateTime.now())
        if (deleted > 0) println("Idempotency cleanup: removed $deleted expired keys")
    }
}
