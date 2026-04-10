package com.myraba.backend.controller

import com.myraba.backend.model.KycType
import com.myraba.backend.model.KycVerificationStatus
import com.myraba.backend.model.User
import com.myraba.backend.repository.KycRepository
import com.myraba.backend.service.AuditLogService
import com.myraba.backend.service.KycService
import jakarta.servlet.http.HttpServletRequest
import org.springframework.data.domain.PageRequest
import org.springframework.data.domain.Sort
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.*

data class BvnRequest(val bvn: String)
data class NinRequest(val nin: String)

@RestController
@RequestMapping("/api/kyc")
class KycController(
    private val kycService: KycService,
    private val kycRepo: KycRepository,
    private val auditLogService: AuditLogService,
) {

    @GetMapping("/status")
    fun getStatus(authentication: Authentication): ResponseEntity<Any> {
        val user = authentication.principal as User
        return ResponseEntity.ok(kycService.getKycStatus(user))
    }

    @PostMapping("/verify/bvn")
    fun submitBvn(
        authentication: Authentication,
        @RequestBody request: BvnRequest,
        httpRequest: HttpServletRequest
    ): ResponseEntity<Any> {
        val user = authentication.principal as User
        if (request.bvn.length != 11 || !request.bvn.all { it.isDigit() })
            return ResponseEntity.badRequest().body(mapOf("error" to "BVN must be exactly 11 digits"))

        val result = kycService.verifyBvn(user, request.bvn)
        auditLogService.logUser(user.myrabaHandle, "KYC_BVN_SUBMIT", "KYC", user.id.toString(),
            details = "BVN verification — result: ${result.status.name}", request = httpRequest)
        return ResponseEntity.ok(
            mapOf(
                "status"       to result.status.name,
                "maskedBvn"    to result.maskedNumber,
                "verifiedName" to result.verifiedName,
                "message"      to when (result.status) {
                    KycVerificationStatus.VERIFIED -> "BVN verified successfully. Your account is now fully active."
                    KycVerificationStatus.FAILED   -> "BVN verification failed: ${result.failureReason}"
                    else -> "Verification is being reviewed"
                }
            )
        )
    }

    @PostMapping("/verify/nin")
    fun submitNin(
        authentication: Authentication,
        @RequestBody request: NinRequest,
        httpRequest: HttpServletRequest
    ): ResponseEntity<Any> {
        val user = authentication.principal as User
        if (request.nin.length != 11 || !request.nin.all { it.isDigit() })
            return ResponseEntity.badRequest().body(mapOf("error" to "NIN must be exactly 11 digits"))

        val result = kycService.verifyNin(user, request.nin)
        auditLogService.logUser(user.myrabaHandle, "KYC_NIN_SUBMIT", "KYC", user.id.toString(),
            details = "NIN verification — result: ${result.status.name}", request = httpRequest)
        return ResponseEntity.ok(
            mapOf(
                "status"       to result.status.name,
                "maskedNin"    to result.maskedNumber,
                "verifiedName" to result.verifiedName,
                "message"      to when (result.status) {
                    KycVerificationStatus.VERIFIED -> "NIN verified successfully. Your account is now fully active."
                    KycVerificationStatus.FAILED   -> "NIN verification failed: ${result.failureReason}"
                    else -> "Verification is being reviewed"
                }
            )
        )
    }

    // ─── Admin ────────────────────────────────────────────────────

    @GetMapping("/admin/pending")
    @PreAuthorize("hasAnyRole('STAFF','ADMIN','SUPER_ADMIN')")
    fun listPending(
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int
    ): ResponseEntity<Any> {
        val pageable = PageRequest.of(page, size, Sort.by("submittedAt").descending())
        val result = kycRepo.findByStatus(KycVerificationStatus.PENDING, pageable)
        return ResponseEntity.ok(
            mapOf(
                "content" to result.content.map { s ->
                    mapOf(
                        "id"           to s.id,
                        "userId"       to s.user.id,
                        "myrabaTag"      to "m₦${s.user.myrabaHandle}",
                        "type"         to s.type.name,
                        "maskedNumber" to s.maskedNumber,
                        "submittedAt"  to s.submittedAt.toString()
                    )
                },
                "totalElements" to result.totalElements,
                "totalPages"    to result.totalPages
            )
        )
    }

    @GetMapping("/admin/stats")
    @PreAuthorize("hasAnyRole('STAFF','ADMIN','SUPER_ADMIN')")
    fun kycStats(): ResponseEntity<Any> = ResponseEntity.ok(
        mapOf(
            "pending"      to kycRepo.countByStatus(KycVerificationStatus.PENDING),
            "verified"     to kycRepo.countByStatus(KycVerificationStatus.VERIFIED),
            "failed"       to kycRepo.countByStatus(KycVerificationStatus.FAILED),
            "manualReview" to kycRepo.countByStatus(KycVerificationStatus.MANUAL_REVIEW)
        )
    )
}
