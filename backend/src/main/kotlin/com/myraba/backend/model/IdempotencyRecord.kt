package com.myraba.backend.model

import jakarta.persistence.*
import java.time.LocalDateTime

/**
 * Idempotency store for transfer operations.
 *
 * When a client sends a transfer with an Idempotency-Key header, we store
 * the result here. Any retry with the same key returns the cached result
 * instead of processing the transfer again — preventing double charges if
 * the network drops mid-request.
 *
 * Keys expire after 24 hours (matching JWT lifetime).
 */
@Entity
@Table(
    name = "idempotency_records",
    indexes = [Index(name = "idx_idempotency_key", columnList = "idempotencyKey", unique = true)]
)
data class IdempotencyRecord(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0,

    @Column(nullable = false, unique = true, length = 128)
    val idempotencyKey: String,

    /** The owner VingHandle — keys are scoped per user */
    @Column(nullable = false, length = 30)
    val ownerVingHandle: String,

    /** HTTP status code of the original response */
    @Column(nullable = false)
    val responseStatus: Int,

    /** Serialised JSON body of the original response */
    @Column(nullable = false, columnDefinition = "TEXT")
    val responseBody: String,

    @Column(nullable = false)
    val createdAt: LocalDateTime = LocalDateTime.now(),

    /** Records expire after 24 h — a scheduled job can clean these up */
    @Column(nullable = false)
    val expiresAt: LocalDateTime = LocalDateTime.now().plusHours(24)
)
