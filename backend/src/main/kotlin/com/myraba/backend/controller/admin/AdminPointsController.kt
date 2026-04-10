package com.myraba.backend.controller.admin

import com.myraba.backend.model.PointReason
import com.myraba.backend.repository.UserRepository
import com.myraba.backend.service.PointsService
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException

data class AdminGrantPointsRequest(
    val userId: Long,
    val points: Long,
    val description: String? = null
)

@RestController
@RequestMapping("/api/admin/points")
@PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
class AdminPointsController(
    private val pointsService: PointsService,
    private val userRepository: UserRepository
) {

    /** Manually grant points to a user */
    @PostMapping("/grant")
    fun grantPoints(@RequestBody request: AdminGrantPointsRequest): ResponseEntity<Any> {
        if (request.points <= 0)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Points must be positive")

        val user = userRepository.findById(request.userId).orElse(null)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "User not found")

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
