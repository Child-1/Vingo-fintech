package com.myraba.backend.repository

import com.myraba.backend.model.CommunityGoal
import com.myraba.backend.model.GoalContribution
import com.myraba.backend.model.User
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query

interface CommunityGoalRepository : JpaRepository<CommunityGoal, Long> {
    fun findByCreatorOrderByCreatedAtDesc(creator: User): List<CommunityGoal>
    fun findByInviteCode(inviteCode: String): CommunityGoal?

    @Query("SELECT DISTINCT c.goal FROM GoalContribution c WHERE c.contributor = :user ORDER BY c.goal.createdAt DESC")
    fun findGoalsContributedByUser(user: User): List<CommunityGoal>
}

interface GoalContributionRepository : JpaRepository<GoalContribution, Long> {
    fun findByGoalOrderByCreatedAtDesc(goal: CommunityGoal): List<GoalContribution>
    fun findByContributorOrderByCreatedAtDesc(contributor: User): List<GoalContribution>
}
