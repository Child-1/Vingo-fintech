package com.myraba.backend.model

import jakarta.persistence.*
import java.time.LocalDateTime

enum class SupportSender { USER, AGENT }

@Entity
@Table(name = "support_messages")
data class SupportMessage(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    val user: User,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val sender: SupportSender,

    @Column(nullable = false, length = 2000)
    val content: String,

    @Column(nullable = false)
    var isRead: Boolean = false,

    val createdAt: LocalDateTime = LocalDateTime.now(),
)
