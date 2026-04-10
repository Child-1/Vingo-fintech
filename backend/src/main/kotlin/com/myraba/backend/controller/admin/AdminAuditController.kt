package com.myraba.backend.controller.admin

import com.myraba.backend.model.AuditLog
import com.myraba.backend.repository.AuditLogRepository
import org.springframework.data.domain.PageRequest
import org.springframework.data.domain.Sort
import org.springframework.format.annotation.DateTimeFormat
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.web.bind.annotation.*
import java.time.LocalDateTime

@RestController
@RequestMapping("/api/admin/audit")
@PreAuthorize("hasAnyRole('STAFF', 'ADMIN', 'SUPER_ADMIN')")
class AdminAuditController(
    private val auditLogRepository: AuditLogRepository
) {

    data class AuditLogResponse(
        val id: Long,
        val actorHandle: String,
        val actorType: String,
        val action: String,
        val targetType: String,
        val targetId: String,
        val details: String?,
        val previousValue: String?,
        val newValue: String?,
        val ipAddress: String?,
        val createdAt: LocalDateTime
    )

    @GetMapping
    fun listAuditLogs(
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "50") size: Int,
        @RequestParam(required = false) actorHandle: String?,
        @RequestParam(required = false) action: String?,
        @RequestParam(required = false) targetType: String?,
        @RequestParam(required = false) targetId: String?,
        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) since: LocalDateTime?
    ): ResponseEntity<Map<String, Any>> {
        val pageable = PageRequest.of(page, size, Sort.by("createdAt").descending())

        val logs = when {
            !actorHandle.isNullOrBlank() -> auditLogRepository.findByActorHandle(actorHandle, pageable)
            !action.isNullOrBlank() -> auditLogRepository.findByAction(action, pageable)
            !targetType.isNullOrBlank() && !targetId.isNullOrBlank() ->
                auditLogRepository.findByTargetTypeAndTargetId(targetType, targetId, pageable)
            since != null -> auditLogRepository.findByCreatedAtAfter(since, pageable)
            else -> auditLogRepository.findAll(pageable)
        }

        return ResponseEntity.ok(mapOf(
            "logs" to logs.content.map { it.toResponse() },
            "total" to logs.totalElements,
            "page" to page,
            "size" to size
        ))
    }

    private fun AuditLog.toResponse() = AuditLogResponse(
        id = this.id,
        actorHandle = this.actorHandle,
        actorType = this.actorType,
        action = this.action,
        targetType = this.targetType,
        targetId = this.targetId,
        details = this.details,
        previousValue = this.previousValue,
        newValue = this.newValue,
        ipAddress = this.ipAddress,
        createdAt = this.createdAt
    )
}
