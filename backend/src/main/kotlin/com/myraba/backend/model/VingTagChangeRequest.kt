package com.myraba.backend.model

import jakarta.persistence.*
import java.time.LocalDateTime

enum class TagChangeStatus { PENDING, APPROVED, DENIED }

@Entity
@Table(name = "ving_tag_change_requests")
data class MyrabaTagChangeRequest(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    val user: User,

    @Column(nullable = false, length = 30)
    val currentTag: String,

    @Column(nullable = false, length = 30)
    val requestedTag: String,

    @Column(length = 500)
    val reason: String? = null,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    var status: TagChangeStatus = TagChangeStatus.PENDING,

    @Column(length = 500)
    var adminNote: String? = null,

    val createdAt: LocalDateTime = LocalDateTime.now(),

    var resolvedAt: LocalDateTime? = null
)
