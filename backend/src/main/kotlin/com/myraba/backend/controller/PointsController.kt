package com.myraba.backend.controller

import com.myraba.backend.model.User
import com.myraba.backend.service.PointsService
import org.springframework.http.ResponseEntity
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/points")
class PointsController(private val pointsService: PointsService) {

    /** Get your current points balance */
    @GetMapping
    fun getMyPoints(authentication: Authentication): ResponseEntity<Any> {
        val user = authentication.principal as User
        val points = pointsService.getUserPoints(user)
        return ResponseEntity.ok(
            mapOf(
                "totalPoints"     to points.totalPoints,
                "thisYearPoints"  to points.thisYearPoints,
                "allTimePoints"   to points.allTimePoints,
                "estimatedValue"  to "₦${"%.2f".format(points.thisYearPoints / 100.0)}",
                "lastEarnedAt"    to points.lastEarnedAt?.toString()
            )
        )
    }

    /** Get your full point event history */
    @GetMapping("/history")
    fun getMyPointHistory(authentication: Authentication): ResponseEntity<Any> {
        val user = authentication.principal as User
        val events = pointsService.getPointHistory(user).map { e ->
            mapOf(
                "id"          to e.id,
                "points"      to e.points,
                "reason"      to e.reason.name,
                "description" to e.description,
                "year"        to e.year,
                "createdAt"   to e.createdAt.toString()
            )
        }
        return ResponseEntity.ok(mapOf("events" to events, "total" to events.size))
    }

    /** Get total points earned in a specific year */
    @GetMapping("/year/{year}")
    fun getYearPoints(
        authentication: Authentication,
        @PathVariable year: Int
    ): ResponseEntity<Any> {
        val user = authentication.principal as User
        val total = pointsService.getYearPoints(user, year)
        return ResponseEntity.ok(
            mapOf(
                "year"           to year,
                "points"         to total,
                "estimatedValue" to "₦${"%.2f".format(total / 100.0)}"
            )
        )
    }
}
