package com.myraba.backend.model

import jakarta.persistence.*
import java.time.LocalDateTime

@Entity
@Table(name = "audit_logs", indexes = [
    Index(name = "idx_audit_actor",  columnList = "actor_handle"),
    Index(name = "idx_audit_action", columnList = "action"),
    Index(name = "idx_audit_created", columnList = "created_at")
])
data class AuditLog(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0,

    // Who performed the action — admin handle for admin events, user handle for user events
    @Column(name = "actor_handle", nullable = false)
    val actorHandle: String,

    // ADMIN or USER
    @Column(name = "actor_type", nullable = false)
    val actorType: String = "USER",

    @Column(nullable = false)
    val action: String,

    @Column(name = "target_type", nullable = false)
    val targetType: String,

    @Column(name = "target_id", nullable = false)
    val targetId: String,

    @Column(nullable = true, length = 1000)
    val details: String? = null,

    @Column(nullable = true, columnDefinition = "TEXT")
    val previousValue: String? = null,

    @Column(nullable = true, columnDefinition = "TEXT")
    val newValue: String? = null,

    @Column(name = "ip_address", nullable = true, length = 45)
    val ipAddress: String? = null,

    @Column(name = "user_agent", nullable = true, length = 512)
    val userAgent: String? = null,

    @Column(name = "created_at")
    val createdAt: LocalDateTime = LocalDateTime.now()
)
