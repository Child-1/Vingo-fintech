package com.myraba.backend.controller

import com.myraba.backend.model.User
import com.myraba.backend.repository.thrift.ThriftCategoryRepository
import com.myraba.backend.service.AuditLogService
import com.myraba.backend.service.ThriftService
import jakarta.servlet.http.HttpServletRequest
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException

@RestController
@RequestMapping("/api/thrifts")
class ThriftController(
    private val thriftService: ThriftService,
    private val categoryRepo: ThriftCategoryRepository,
    private val auditLogService: AuditLogService,
) {

    /** List all public active categories */
    @GetMapping("/categories")
    fun getPublicCategories(): ResponseEntity<Any> {
        val categories = categoryRepo.findByIsPublicAndIsActive(true, true).map { c ->
            mapOf(
                "id"                  to c.id,
                "name"                to c.name,
                "description"         to c.description,
                "contributionAmount"  to c.contributionAmount.toPlainString(),
                "frequency"           to c.contributionFrequency,
                "cyclesRequired"      to c.durationInCycles,
                "estimatedPayout"     to c.payoutAmount.toPlainString(),
                "currentMemberCount"  to c.members.count { !it.hasWithdrawn }
            )
        }
        return ResponseEntity.ok(mapOf("categories" to categories, "total" to categories.size))
    }

    /** Get details of a single category */
    @GetMapping("/categories/{id}")
    fun getCategory(@PathVariable id: Long): ResponseEntity<Any> {
        val c = thriftService.getCategoryDetails(id)
        return ResponseEntity.ok(
            mapOf(
                "id"                 to c.id,
                "name"               to c.name,
                "description"        to c.description,
                "contributionAmount" to c.contributionAmount.toPlainString(),
                "frequency"          to c.contributionFrequency,
                "cyclesRequired"     to c.durationInCycles,
                "estimatedPayout"    to c.payoutAmount.toPlainString(),
                "isActive"           to c.isActive
            )
        )
    }

    /** Join a public thrift category */
    @PostMapping("/categories/{categoryId}/join")
    fun joinCategory(
        authentication: Authentication,
        @PathVariable categoryId: Long,
        httpRequest: HttpServletRequest
    ): ResponseEntity<Any> {
        val user = authentication.principal as User
        val result = thriftService.joinPublicCategory(categoryId, user)
        auditLogService.logUser(user.myrabaHandle, "THRIFT_JOIN", "THRIFT_CATEGORY", categoryId.toString(),
            details = "Joined public thrift category #$categoryId", request = httpRequest)
        return ResponseEntity.status(HttpStatus.CREATED).body(result)
    }

    /** Make a contribution for the current cycle */
    @PostMapping("/me/contribute/{memberId}")
    fun contribute(
        authentication: Authentication,
        @PathVariable memberId: Long,
        httpRequest: HttpServletRequest
    ): ResponseEntity<Any> {
        val user = authentication.principal as User
        val contribution = thriftService.recordContribution(memberId)
        auditLogService.logUser(user.myrabaHandle, "THRIFT_CONTRIBUTE", "THRIFT_MEMBER", memberId.toString(),
            details = "Contributed ₦${contribution.amount} to public thrift", request = httpRequest)
        return ResponseEntity.ok(
            mapOf(
                "message"       to "Contribution recorded successfully",
                "amount"        to contribution.amount.toPlainString(),
                "date"          to contribution.contributionDate.toString()
            )
        )
    }

    /** View all active thrifts the current user is in */
    @GetMapping("/me")
    fun myThrifts(authentication: Authentication): ResponseEntity<Any> {
        val user = authentication.principal as User
        val members = thriftService.getMemberStatus(user).map { m ->
            mapOf(
                "memberId"           to m.id,
                "categoryName"       to m.category.name,
                "frequency"          to m.category.contributionFrequency,
                "contributionAmount" to m.category.contributionAmount.toPlainString(),
                "cyclesCompleted"    to m.daysContributed,
                "cyclesRequired"     to m.category.durationInCycles,
                "totalContributed"   to m.totalContributed.toPlainString(),
                "estimatedPayout"    to m.category.payoutAmount.toPlainString(),
                "progressPercent"    to if (m.category.durationInCycles > 0)
                    (m.daysContributed * 100 / m.category.durationInCycles) else 0,
                "lastContribution"   to m.lastContributionDate?.toString(),
                "missedCycles"       to m.totalMissedDays,
                "penaltyLevel"       to m.penaltyLevel
            )
        }
        return ResponseEntity.ok(mapOf("thrifts" to members, "total" to members.size))
    }
}
