package com.myraba.backend.service

import com.myraba.backend.model.AuditLog
import com.myraba.backend.repository.AuditLogRepository
import jakarta.servlet.http.HttpServletRequest
import org.springframework.stereotype.Service

@Service
class AuditLogService(private val auditLogRepository: AuditLogRepository) {

    /** Admin-side event (role changes, balance adjustments, etc.) */
    fun log(
        adminHandle: String,
        action: String,
        targetType: String,
        targetId: String,
        details: String? = null,
        previousValue: String? = null,
        newValue: String? = null,
        request: HttpServletRequest? = null
    ): AuditLog = auditLogRepository.save(AuditLog(
        actorHandle = adminHandle,
        actorType = "ADMIN",
        action = action,
        targetType = targetType,
        targetId = targetId,
        details = details,
        previousValue = previousValue,
        newValue = newValue,
        ipAddress = request?.resolveIp(),
        userAgent = request?.getHeader("User-Agent")?.take(512)
    ))

    /** User-side event (login, transfer, KYC, etc.) */
    fun logUser(
        userHandle: String,
        action: String,
        targetType: String,
        targetId: String,
        details: String? = null,
        request: HttpServletRequest? = null
    ): AuditLog = auditLogRepository.save(AuditLog(
        actorHandle = userHandle,
        actorType = "USER",
        action = action,
        targetType = targetType,
        targetId = targetId,
        details = details,
        ipAddress = request?.resolveIp(),
        userAgent = request?.getHeader("User-Agent")?.take(512)
    ))

    private fun HttpServletRequest.resolveIp(): String {
        return getHeader("X-Forwarded-For")?.split(",")?.firstOrNull()?.trim()
            ?: getHeader("X-Real-IP")
            ?: remoteAddr
    }
}
