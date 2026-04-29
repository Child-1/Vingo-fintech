package com.myraba.backend.repository

import com.myraba.backend.model.PersonalGoal
import com.myraba.backend.model.PersonalGoalStatus
import com.myraba.backend.model.User
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository
import java.time.LocalDate

@Repository
interface PersonalGoalRepository : JpaRepository<PersonalGoal, Long> {
    fun findByUserOrderByCreatedAtDesc(user: User): List<PersonalGoal>
    fun findByStatusAndNextDeductDateLessThanEqual(
        status: PersonalGoalStatus,
        date: LocalDate
    ): List<PersonalGoal>
}
