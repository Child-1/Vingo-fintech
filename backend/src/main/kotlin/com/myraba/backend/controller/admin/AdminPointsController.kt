package com.myraba.backend.controller.admin

import com.myraba.backend.model.PointReason
import com.myraba.backend.repository.UserPointsRepository
import com.myraba.backend.repository.UserRepository
import com.myraba.backend.service.PointsService
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException

data class AdminGrantPointsRequest(
    val myrabaHandle: String,
    val points: Long,
    val description: String? = null
)

@RestController
@RequestMapping("/api/admin/points")
@PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
class AdminPointsController(
    private val pointsService: PointsService,
    private val userRepository: UserRepository,
    private val userPointsRepository: UserPointsRepository
) {

    /** Platform-wide points stats */
    @GetMapping("/stats")
    fun getStats(): ResponseEntity<Any> {
        val allPoints = userPointsRepository.findAll()
        val totalIssued = allPoints.sumOf { it.totalPoints }
        val totalLifetime = allPoints.sumOf { it.allTimePoints }
        val usersWithPoints = allPoints.count { it.totalPoints > 0 }
        val currentYear = java.time.LocalDateTime.now().year
        val thisYearTotal = allPoints.sumOf { it.thisYearPoints }
        return ResponseEntity.ok(mapOf(
            "totalPointsIssued"  to totalIssued,
            "totalLifetime"      to totalLifetime,
            "thisYearTotal"      to thisYearTotal,
            "usersWithPoints"    to usersWithPoints
        ))
    }

    /** Top 20 users by this-year points */
    @GetMapping("/leaderboard")
    fun getLeaderboard(): ResponseEntity<Any> {
        val all = userPointsRepository.findAll()
        val top = all.sortedByDescending { it.thisYearPoints }.take(20)
        return ResponseEntity.ok(mapOf(
            "users" to top.map { p ->
                mapOf(
                    "id"           to p.user.id,
                    "fullName"     to p.user.fullName,
                    "myrabaHandle" to p.user.myrabaHandle,
                    "thisYear"     to p.thisYearPoints,
                    "allTime"      to p.allTimePoints,
                    "updatedAt"    to p.lastEarnedAt?.toString()
                )
            }
        ))
    }

    /** Manually grant points to a user */
    @PostMapping("/grant")
    fun grantPoints(@RequestBody request: AdminGrantPointsRequest): ResponseEntity<Any> {
        if (request.points <= 0)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Points must be positive")

        val user = userRepository.findByVingHandle(request.myrabaHandle)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "User not found: ${request.myrabaHandle}")

        val updated = pointsService.awardPoints(
            user = user,
            points = request.points,
            reason = PointReason.ADMIN_GRANT,
            description = request.description ?: "Admin grant"
        )

        return ResponseEntity.ok(
            mapOf(
                "userId"         to user.id,
                "myrabaHandle"     to user.myrabaHandle,
                "pointsGranted"  to request.points,
                "newTotal"       to updated.totalPoints,
                "thisYearTotal"  to updated.thisYearPoints
            )
        )
    }

    /** View a user's points */
    @GetMapping("/user/{userId}")
    fun getUserPoints(@PathVariable userId: Long): ResponseEntity<Any> {
        val user = userRepository.findById(userId).orElse(null)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "User not found")
        val points = pointsService.getUserPoints(user)
        return ResponseEntity.ok(
            mapOf(
                "userId"         to user.id,
                "myrabaHandle"     to user.myrabaHandle,
                "totalPoints"    to points.totalPoints,
                "thisYearPoints" to points.thisYearPoints,
                "allTimePoints"  to points.allTimePoints,
                "lastEarnedAt"   to points.lastEarnedAt?.toString()
            )
        )
    }

    /** Trigger year-end conversion for a single user (for testing / manual runs) */
    @PostMapping("/convert/{userId}")
    fun convertUserPoints(@PathVariable userId: Long): ResponseEntity<Any> {
        val user = userRepository.findById(userId).orElse(null)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "User not found")
        val naira = pointsService.convertYearEndPoints(user)
        return ResponseEntity.ok(
            mapOf(
                "userId"        to user.id,
                "myrabaHandle"    to user.myrabaHandle,
                "nairaAwarded"  to naira.toPlainString(),
                "message"       to "Points converted and credited to wallet"
            )
        )
    }

    /** Trigger year-end conversion for ALL users (run once per year) */
    @PostMapping("/convert/all")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    fun convertAllUsersPoints(): ResponseEntity<Any> {
        val users = userRepository.findAll()
        var totalConverted = 0
        var totalNaira = java.math.BigDecimal.ZERO

        for (user in users) {
            val naira = pointsService.convertYearEndPoints(user)
            if (naira > java.math.BigDecimal.ZERO) {
                totalConverted++
                totalNaira = totalNaira.add(naira)
            }
        }

        return ResponseEntity.ok(
            mapOf(
                "usersConverted" to totalConverted,
                "totalNairaPaid" to totalNaira.toPlainString(),
                "message"        to "Year-end conversion complete"
            )
        )
    }
}
