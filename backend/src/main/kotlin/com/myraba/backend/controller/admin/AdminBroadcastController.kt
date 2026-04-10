package com.myraba.backend.controller.admin

import com.myraba.backend.model.BroadcastAudience
import com.myraba.backend.model.BroadcastMessage
import com.myraba.backend.model.BroadcastType
import com.myraba.backend.model.User
import com.myraba.backend.repository.BroadcastRepository
import com.myraba.backend.service.AuditLogService
import org.springframework.format.annotation.DateTimeFormat
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import java.time.LocalDateTime

@RestController
@RequestMapping("/api/admin/broadcasts")
@PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
class AdminBroadcastController(
    private val broadcastRepository: BroadcastRepository,
    private val auditLogService: AuditLogService
) {

    data class CreateBroadcastRequest(
        val title: String,
        val body: String,
        val type: String = "INFO",
        val audience: String = "ALL",
        val targetVingHandle: String? = null,
        @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME)
        val expiresAt: LocalDateTime? = null
    )

    data class BroadcastResponse(
        val id: Long,
        val title: String,
        val body: String,
        val type: String,
        val audience: String,
        val targetVingHandle: String?,
        val sentBy: String,
        val active: Boolean,
        val createdAt: LocalDateTime,
        val expiresAt: LocalDateTime?
    )

    @PostMapping
    fun sendBroadcast(
        @RequestBody req: CreateBroadcastRequest,
        auth: Authentication
    ): ResponseEntity<BroadcastResponse> {
        val admin = auth.principal as User

        val broadcastType = try { BroadcastType.valueOf(req.type.uppercase()) }
            catch (e: IllegalArgumentException) { throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid type: ${req.type}. Use INFO, WARNING, PROMOTION, MAINTENANCE, SECURITY") }

        val audience = try { BroadcastAudience.valueOf(req.audience.uppercase()) }
            catch (e: IllegalArgumentException) { throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid audience: ${req.audience}. Use ALL, KYC_APPROVED, KYC_PENDING, ROLE_USER, ROLE_STAFF, SPECIFIC_USER") }

        if (audience == BroadcastAudience.SPECIFIC_USER && req.targetVingHandle.isNullOrBlank()) {
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "targetVingHandle is required when audience = SPECIFIC_USER")
        }

        val saved = broadcastRepository.save(
            BroadcastMessage(
                title = req.title,
                body = req.body,
                type = broadcastType,
                audience = audience,
                targetVingHandle = req.targetVingHandle,
                sentBy = admin.myrabaHandle,
                active = true,
                expiresAt = req.expiresAt
            )
        )

        auditLogService.log(
            adminHandle = admin.myrabaHandle,
            action = "SEND_BROADCAST",
            targetType = "BROADCAST",
            targetId = saved.id.toString(),
            details = "Broadcast '${saved.title}' sent to audience=${saved.audience}"
        )

        return ResponseEntity.ok(saved.toResponse())
    }

    @GetMapping
    fun listBroadcasts(): ResponseEntity<List<BroadcastResponse>> {
        return ResponseEntity.ok(broadcastRepository.findAll().sortedByDescending { it.createdAt }.map { it.toResponse() })
    }

    @GetMapping("/{id}")
    fun getBroadcast(@PathVariable id: Long): ResponseEntity<BroadcastResponse> {
        val msg = broadcastRepository.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "Broadcast not found")
        }
        return ResponseEntity.ok(msg.toResponse())
    }

    @DeleteMapping("/{id}")
    fun deactivateBroadcast(
        @PathVariable id: Long,
        auth: Authentication
    ): ResponseEntity<Map<String, Any>> {
        val msg = broadcastRepository.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "Broadcast not found")
        }
        val updated = msg.copy(active = false)
        broadcastRepository.save(updated)

        auditLogService.log(
            adminHandle = (auth.principal as User).myrabaHandle,
            action = "DEACTIVATE_BROADCAST",
            targetType = "BROADCAST",
            targetId = id.toString(),
            details = "Broadcast '${msg.title}' deactivated"
        )

        return ResponseEntity.ok(mapOf("message" to "Broadcast #$id deactivated"))
    }

    private fun BroadcastMessage.toResponse() = BroadcastResponse(
        id = this.id,
        title = this.title,
        body = this.body,
        type = this.type.name,
        audience = this.audience.name,
        targetVingHandle = this.targetVingHandle,
        sentBy = this.sentBy,
        active = this.active,
        createdAt = this.createdAt,
        expiresAt = this.expiresAt
    )
}
