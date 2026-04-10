package com.myraba.backend.controller

import com.myraba.backend.model.User
import com.myraba.backend.model.thrift.PositionAssignment
import com.myraba.backend.model.thrift.PaymentFlexibility
import com.myraba.backend.service.AuditLogService
import com.myraba.backend.service.CreatePrivateThriftRequest
import com.myraba.backend.service.PrivateThriftService
import jakarta.servlet.http.HttpServletRequest
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import java.math.BigDecimal

// ─── Request bodies ───────────────────────────────────────────────

data class CreateThriftBody(
    val name: String,
    val description: String? = null,
    val contributionAmount: BigDecimal,
    val frequency: String = "MONTHLY",
    val paymentFlexibility: String = "FIXED",
    val totalCycles: Int,
    val positionAssignment: String = "RAFFLE",
    val entryFee: BigDecimal = BigDecimal.ZERO,
    val surchargePerContribution: BigDecimal = BigDecimal.ZERO,
    val creatorRules: String? = null
)

data class ContributeBody(val amount: BigDecimal)
data class EjectMemberBody(val reason: String)
data class FlagDefaultBody(val defaulterVingHandle: String, val amountOwed: BigDecimal)
data class ManualPositionBody(val positions: Map<Long, Int>)  // memberId → position

@RestController
@RequestMapping("/api/private-thrifts")
class PrivateThriftController(
    private val service: PrivateThriftService,
    private val auditLogService: AuditLogService,
) {

    // ─── Creator endpoints ────────────────────────────────────────

    @PostMapping
    fun create(
        authentication: Authentication,
        @RequestBody body: CreateThriftBody,
        httpRequest: HttpServletRequest
    ): ResponseEntity<Any> {
        val creator = authentication.principal as User
        val thrift = service.createThrift(
            creator = creator,
            request = CreatePrivateThriftRequest(
                name = body.name,
                description = body.description,
                contributionAmount = body.contributionAmount,
                frequency = body.frequency,
                paymentFlexibility = PaymentFlexibility.valueOf(body.paymentFlexibility),
                totalCycles = body.totalCycles,
                positionAssignment = PositionAssignment.valueOf(body.positionAssignment),
                entryFee = body.entryFee,
                surchargePerContribution = body.surchargePerContribution,
                creatorRules = body.creatorRules
            )
        )
        auditLogService.logUser(creator.myrabaHandle, "PRIVATE_THRIFT_CREATE", "PRIVATE_THRIFT", thrift.id.toString(),
            details = "Created private thrift '${thrift.name}' invite:${thrift.inviteCode}", request = httpRequest)
        return ResponseEntity.status(HttpStatus.CREATED).body(
            mapOf(
                "id"           to thrift.id,
                "name"         to thrift.name,
                "inviteCode"   to thrift.inviteCode,
                "status"       to thrift.status.name,
                "collateral"   to "You must maintain ₦${thrift.requiredCreatorCollateral} in your wallet throughout this thrift",
                "message"      to "Thrift created. Share invite code '${thrift.inviteCode}' with members."
            )
        )
    }

    @GetMapping("/my-created")
    fun myCreatedThrifts(authentication: Authentication): ResponseEntity<Any> {
        val creator = authentication.principal as User
        val thrifts = service.getCreatorThrifts(creator).map { t ->
            mapOf(
                "id"                 to t.id,
                "name"               to t.name,
                "inviteCode"         to t.inviteCode,
                "status"             to t.status.name,
                "contributionAmount" to t.contributionAmount.toPlainString(),
                "frequency"          to t.frequency,
                "totalCycles"        to t.totalCycles,
                "currentCycle"       to t.currentCycle,
                "memberCount"        to t.members.size,
                "createdAt"          to t.createdAt.toString()
            )
        }
        return ResponseEntity.ok(mapOf("thrifts" to thrifts, "total" to thrifts.size))
    }

    @GetMapping("/{thriftId}/members")
    fun getMembers(
        authentication: Authentication,
        @PathVariable thriftId: Long
    ): ResponseEntity<Any> {
        val creator = authentication.principal as User
        val members = service.getThriftMembers(creator, thriftId).map { m ->
            mapOf(
                "memberId"              to m.id,
                "myrabaTag"               to "m₦${m.user.myrabaHandle}",
                "fullName"              to m.user.fullName,
                "position"             to m.position,
                "status"               to m.status.name,
                "currentCycleContrib"  to m.currentCycleContributed.toPlainString(),
                "totalContributed"     to m.totalContributed.toPlainString(),
                "hasReceivedPayout"    to m.hasReceivedPayout,
                "entryFeePaid"         to m.entryFeePaid,
                "joinedAt"             to m.joinedAt.toString()
            )
        }
        return ResponseEntity.ok(mapOf("members" to members, "total" to members.size))
    }

    @PostMapping("/{thriftId}/assign-positions")
    fun assignPositions(
        authentication: Authentication,
        @PathVariable thriftId: Long,
        @RequestBody(required = false) body: ManualPositionBody?
    ): ResponseEntity<Any> {
        val creator = authentication.principal as User
        service.assignPositions(creator, thriftId, body?.positions)
        return ResponseEntity.ok(mapOf("message" to "Positions assigned. Thrift is now ACTIVE."))
    }

    @PostMapping("/{thriftId}/payout/{memberId}")
    fun approvePayout(
        authentication: Authentication,
        @PathVariable thriftId: Long,
        @PathVariable memberId: Long
    ): ResponseEntity<Any> {
        val creator = authentication.principal as User
        val member = service.approvePayout(creator, thriftId, memberId)
        return ResponseEntity.ok(
            mapOf(
                "message"          to "Payout approved for m₦${member.user.myrabaHandle}",
                "payoutApprovedAt" to member.payoutApprovedAt?.toString()
            )
        )
    }

    @PostMapping("/{thriftId}/eject/{memberId}")
    fun ejectMember(
        authentication: Authentication,
        @PathVariable thriftId: Long,
        @PathVariable memberId: Long,
        @RequestBody body: EjectMemberBody
    ): ResponseEntity<Any> {
        val creator = authentication.principal as User
        service.ejectMember(creator, thriftId, memberId, body.reason)
        return ResponseEntity.ok(mapOf("message" to "Member ejected. Reason recorded."))
    }

    @PostMapping("/{thriftId}/flag-default")
    fun flagDefault(
        authentication: Authentication,
        @PathVariable thriftId: Long,
        @RequestBody body: FlagDefaultBody
    ): ResponseEntity<Any> {
        val creator = authentication.principal as User
        val default = service.flagDefault(creator, thriftId, body.defaulterVingHandle, body.amountOwed)
        return ResponseEntity.status(HttpStatus.CREATED).body(
            mapOf(
                "defaultId"      to default.id,
                "defaulter"      to "m₦${default.defaulter.myrabaHandle}",
                "amountOwed"     to default.amountOwed.toPlainString(),
                "status"         to default.status.name,
                "message"        to "Default flagged. The system will monitor the defaulter's wallet and freeze funds when available."
            )
        )
    }

    // ─── Member endpoints ─────────────────────────────────────────

    /** Use invite code to request joining (step 1 — before seeing/accepting rules) */
    @PostMapping("/join/{inviteCode}")
    fun requestJoin(
        authentication: Authentication,
        @PathVariable inviteCode: String,
        httpRequest: HttpServletRequest
    ): ResponseEntity<Any> {
        val user = authentication.principal as User
        val member = service.requestToJoin(user, inviteCode)
        val thrift = member.thrift
        auditLogService.logUser(user.myrabaHandle, "PRIVATE_THRIFT_JOIN_REQUEST", "PRIVATE_THRIFT", thrift.id.toString(),
            details = "Requested to join private thrift '${thrift.name}' via invite code", request = httpRequest)
        return ResponseEntity.status(HttpStatus.CREATED).body(
            mapOf(
                "thriftId"       to thrift.id,
                "thriftName"     to thrift.name,
                "creator"        to "m₦${thrift.creator.myrabaHandle}",
                "contributionAmount" to thrift.contributionAmount.toPlainString(),
                "frequency"      to thrift.frequency,
                "totalCycles"    to thrift.totalCycles,
                "entryFee"       to thrift.entryFee.toPlainString(),
                "surcharge"      to thrift.surchargePerContribution.toPlainString(),
                "creatorRules"   to thrift.creatorRules,
                "systemNotice"   to "By accepting these rules you acknowledge: (1) You trust the thrift creator. " +
                                    "(2) The system will not be responsible for defaults — the creator is. " +
                                    "(3) All general system rules apply. " +
                                    "(4) Creator rules above supplement but do not override system rules.",
                "status"         to member.status.name,
                "nextStep"       to "POST /api/private-thrifts/${thrift.id}/accept-rules to confirm"
            )
        )
    }

    /** Accept rules and officially join (step 2 — charges entry fee) */
    @PostMapping("/{thriftId}/accept-rules")
    fun acceptRules(
        authentication: Authentication,
        @PathVariable thriftId: Long
    ): ResponseEntity<Any> {
        val user = authentication.principal as User
        val member = service.acceptRulesAndJoin(user, thriftId)
        return ResponseEntity.ok(
            mapOf(
                "message"      to "Welcome to the thrift! You are now an active member.",
                "memberId"     to member.id,
                "entryFeePaid" to member.entryFeePaid,
                "agreedAt"     to member.agreedAt?.toString()
            )
        )
    }

    /** Make a contribution to the current cycle */
    @PostMapping("/{thriftId}/contribute")
    fun contribute(
        authentication: Authentication,
        @PathVariable thriftId: Long,
        @RequestBody body: ContributeBody,
        httpRequest: HttpServletRequest
    ): ResponseEntity<Any> {
        val user = authentication.principal as User
        val member = service.contribute(user, thriftId, body.amount)
        val thrift = member.thrift
        val remaining = thrift.contributionAmount.subtract(member.currentCycleContributed)
            .coerceAtLeast(BigDecimal.ZERO)
        auditLogService.logUser(user.myrabaHandle, "PRIVATE_THRIFT_CONTRIBUTE", "PRIVATE_THRIFT", thriftId.toString(),
            details = "Contributed ₦${body.amount} to private thrift '${thrift.name}'", request = httpRequest)
        return ResponseEntity.ok(
            mapOf(
                "message"              to "Contribution recorded",
                "thisContribution"     to body.amount.toPlainString(),
                "currentCycleTotal"    to member.currentCycleContributed.toPlainString(),
                "requiredThisCycle"    to thrift.contributionAmount.toPlainString(),
                "remainingThisCycle"   to remaining.toPlainString(),
                "cycleComplete"        to (remaining == BigDecimal.ZERO)
            )
        )
    }

    /** View all private thrifts the current user is a member of */
    @GetMapping("/me")
    fun myMemberships(authentication: Authentication): ResponseEntity<Any> {
        val user = authentication.principal as User
        val memberships = service.getMemberThrifts(user).map { m ->
            val thrift = m.thrift
            mapOf(
                "thriftId"           to thrift.id,
                "thriftName"         to thrift.name,
                "creator"            to "m₦${thrift.creator.myrabaHandle}",
                "status"             to m.status.name,
                "position"           to m.position,
                "currentCycle"       to thrift.currentCycle,
                "totalCycles"        to thrift.totalCycles,
                "contributionAmount" to thrift.contributionAmount.toPlainString(),
                "currentCycleContrib" to m.currentCycleContributed.toPlainString(),
                "totalContributed"   to m.totalContributed.toPlainString(),
                "hasReceivedPayout"  to m.hasReceivedPayout
            )
        }
        return ResponseEntity.ok(mapOf("memberships" to memberships, "total" to memberships.size))
    }
}

private fun BigDecimal.coerceAtLeast(min: BigDecimal): BigDecimal = if (this < min) min else this
