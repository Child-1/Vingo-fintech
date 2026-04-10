package com.myraba.backend.service

import com.myraba.backend.model.PointEvent
import com.myraba.backend.model.PointReason
import com.myraba.backend.model.User
import com.myraba.backend.model.UserPoints
import com.myraba.backend.repository.PointEventRepository
import com.myraba.backend.repository.UserPointsRepository
import com.myraba.backend.repository.WalletRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.math.BigDecimal
import java.math.RoundingMode
import java.time.LocalDateTime

// Points-to-naira conversion rate: 100 points = ₦1
private const val NAIRA_PER_100_POINTS = 1L

@Service
class PointsService(
    private val userPointsRepository: UserPointsRepository,
    private val pointEventRepository: PointEventRepository,
    private val walletRepository: WalletRepository
) {

    fun getOrCreateUserPoints(user: User): UserPoints =
        userPointsRepository.findByUserId(user.id)
            ?: userPointsRepository.save(UserPoints(user = user))

    @Transactional
    fun awardPoints(user: User, points: Long, reason: PointReason, description: String? = null): UserPoints {
        val userPoints = getOrCreateUserPoints(user)
        userPoints.totalPoints += points
        userPoints.thisYearPoints += points
        userPoints.allTimePoints += points
        userPoints.lastEarnedAt = LocalDateTime.now()
        userPointsRepository.save(userPoints)

        val year = LocalDateTime.now().year
        pointEventRepository.save(
            PointEvent(user = user, points = points, reason = reason, description = description, year = year)
        )

        return userPoints
    }

    /**
     * Year-end conversion: thisYearPoints → wallet credit (100 pts = ₦1).
     * Called by admin or scheduled job at year-end.
     */
    @Transactional
    fun convertYearEndPoints(user: User): BigDecimal {
        val userPoints = getOrCreateUserPoints(user)
        if (userPoints.thisYearPoints <= 0) return BigDecimal.ZERO

        val nairaValue = BigDecimal(userPoints.thisYearPoints)
            .divide(BigDecimal(100), 2, RoundingMode.FLOOR)

        if (nairaValue > BigDecimal.ZERO) {
            val wallet = walletRepository.findByUserVingHandle(user.myrabaHandle)
            if (wallet != null) {
                wallet.balance = wallet.balance.add(nairaValue)
                walletRepository.save(wallet)
            }
        }

        userPoints.totalPoints -= userPoints.thisYearPoints
        userPoints.thisYearPoints = 0L
        userPointsRepository.save(userPoints)

        return nairaValue
    }

    fun getUserPoints(user: User): UserPoints = getOrCreateUserPoints(user)

    fun getPointHistory(user: User): List<PointEvent> =
        pointEventRepository.findByUserIdOrderByCreatedAtDesc(user.id)

    fun getYearPoints(user: User, year: Int): Long =
        pointEventRepository.sumPointsByUserAndYear(user.id, year) ?: 0L
}
