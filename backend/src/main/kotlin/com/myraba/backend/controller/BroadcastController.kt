package com.myraba.backend.controller

import com.myraba.backend.model.BroadcastAudience
import com.myraba.backend.model.BroadcastMessage
import com.myraba.backend.model.User
import com.myraba.backend.repository.BroadcastRepository
import org.springframework.http.ResponseEntity
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.*
import java.time.LocalDateTime

@RestController
@RequestMapping("/api/broadcasts")
class BroadcastController(private val broadcastRepository: BroadcastRepository) {

    data class BroadcastResponse(
        val id: Long,
        val title: String,
        val body: String,
        val type: String,
        val createdAt: LocalDateTime,
        val expiresAt: LocalDateTime?
    )

    @GetMapping
    fun getMyBroadcasts(auth: Authentication): ResponseEntity<List<BroadcastResponse>> {
        val user = auth.principal as User

        val kycAudience = when (user.kycStatus) {
            "APPROVED" -> BroadcastAudience.KYC_APPROVED
            "PENDING"  -> BroadcastAudience.KYC_PENDING
            else -> null
        }
        val roleAudience = when (user.role.name) {
            "STAFF" -> BroadcastAudience.ROLE_STAFF
            else -> BroadcastAudience.ROLE_USER
        }

        val messages = broadcastRepository.findActiveForUser(
            myrabaHandle = user.myrabaHandle,
            kyc = kycAudience,
            role = roleAudience,
            now = LocalDateTime.now()
        )

        return ResponseEntity.ok(messages.sortedByDescending { it.createdAt }.map { it.toResponse() })
    }

    private fun BroadcastMessage.toResponse() = BroadcastResponse(
        id = this.id,
        title = this.title,
        body = this.body,
        type = this.type.name,
        createdAt = this.createdAt,
        expiresAt = this.expiresAt
    )
}
