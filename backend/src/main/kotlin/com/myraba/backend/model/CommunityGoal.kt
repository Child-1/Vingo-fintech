package com.myraba.backend.model

import jakarta.persistence.*
import java.math.BigDecimal
import java.time.LocalDateTime

enum class GoalStatus { ACTIVE, COMPLETED, WITHDRAWN, CANCELLED }

@Entity
@Table(name = "community_goals")
data class CommunityGoal(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "creator_id", nullable = false)
    val creator: User,

    @Column(nullable = false, length = 100)
    val title: String,

    @Column(nullable = false, length = 500)
    val description: String,

    @Column(nullable = false, precision = 19, scale = 4)
    val targetAmount: BigDecimal,

    @Column(nullable = false, precision = 19, scale = 4)
    var balance: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, unique = true, length = 12)
    val inviteCode: String,

    val deadline: LocalDateTime? = null,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    var status: GoalStatus = GoalStatus.ACTIVE,

    val createdAt: LocalDateTime = LocalDateTime.now(),
    var withdrawnAt: LocalDateTime? = null,
)

@Entity
@Table(name = "goal_contributions")
data class GoalContribution(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "goal_id", nullable = false)
    val goal: CommunityGoal,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "contributor_id", nullable = false)
    val contributor: User,

    @Column(nullable = false, precision = 19, scale = 4)
    val amount: BigDecimal,

    @Column(length = 200)
    val note: String? = null,

    val createdAt: LocalDateTime = LocalDateTime.now(),
)
