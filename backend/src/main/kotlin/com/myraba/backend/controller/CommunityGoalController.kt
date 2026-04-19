package com.myraba.backend.controller

import com.myraba.backend.model.*
import com.myraba.backend.repository.CommunityGoalRepository
import com.myraba.backend.repository.GoalContributionRepository
import com.myraba.backend.repository.WalletRepository
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import java.math.BigDecimal
import java.time.LocalDateTime

data class CreateGoalRequest(
    val title: String,
    val description: String,
    val targetAmount: BigDecimal,
    val deadline: String? = null,   // ISO date string, optional
)

data class ContributeRequest(
    val amount: BigDecimal,
    val note: String? = null,
)

@RestController
@RequestMapping("/api/goals")
class CommunityGoalController(
    private val goalRepo: CommunityGoalRepository,
    private val contributionRepo: GoalContributionRepository,
    private val walletRepo: WalletRepository,
) {
    @PostMapping
    fun create(@RequestBody req: CreateGoalRequest, auth: Authentication): ResponseEntity<Any> {
        val user = auth.principal as User
        if (req.title.isBlank())
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Title is required")
        if (req.description.isBlank())
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Description is required")
        if (req.targetAmount < BigDecimal("500"))
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Minimum goal amount is ₦500")

        val deadline = req.deadline?.let {
            try { LocalDateTime.parse(it) } catch (_: Exception) {
                throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid deadline format. Use ISO datetime.")
            }
        }

        val inviteCode = generateInviteCode(goalRepo)
        val goal = goalRepo.save(CommunityGoal(
            creator = user,
            title = req.title.trim(),
            description = req.description.trim(),
            targetAmount = req.targetAmount,
            inviteCode = inviteCode,
            deadline = deadline,
        ))
        return ResponseEntity.status(HttpStatus.CREATED).body(goal.toDto(emptyList()))
    }

    @GetMapping("/my")
    fun myGoals(auth: Authentication): ResponseEntity<Any> {
        val user = auth.principal as User
        val goals = goalRepo.findByCreatorOrderByCreatedAtDesc(user)
        return ResponseEntity.ok(mapOf("goals" to goals.map { it.toDto(contributionRepo.findByGoalOrderByCreatedAtDesc(it)) }))
    }

    @GetMapping("/backing")
    fun goalsIBack(auth: Authentication): ResponseEntity<Any> {
        val user = auth.principal as User
        val goals = goalRepo.findGoalsContributedByUser(user)
        return ResponseEntity.ok(mapOf("goals" to goals.map { it.toDto(contributionRepo.findByGoalOrderByCreatedAtDesc(it)) }))
    }

    @GetMapping("/{code}")
    fun getByCode(@PathVariable code: String, auth: Authentication): ResponseEntity<Any> {
        val goal = goalRepo.findByInviteCode(code.uppercase())
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Goal not found")
        val contributions = contributionRepo.findByGoalOrderByCreatedAtDesc(goal)
        return ResponseEntity.ok(goal.toDto(contributions, includeContributions = true))
    }

    @PostMapping("/{code}/contribute")
    fun contribute(
        @PathVariable code: String,
        @RequestBody req: ContributeRequest,
        auth: Authentication,
    ): ResponseEntity<Any> {
        val user = auth.principal as User
        val goal = goalRepo.findByInviteCode(code.uppercase())
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Goal not found")

        if (goal.status != GoalStatus.ACTIVE)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "This goal is no longer accepting contributions")
        if (req.amount < BigDecimal("50"))
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Minimum contribution is ₦50")

        val wallet = walletRepo.findByUserVingHandle(user.myrabaHandle)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Wallet not found")
        if (wallet.balance < req.amount)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Insufficient wallet balance")

        wallet.balance = wallet.balance.subtract(req.amount)
        walletRepo.save(wallet)

        goal.balance = goal.balance.add(req.amount)
        if (goal.balance >= goal.targetAmount) goal.status = GoalStatus.COMPLETED
        goalRepo.save(goal)

        val contribution = contributionRepo.save(GoalContribution(
            goal = goal,
            contributor = user,
            amount = req.amount,
            note = req.note?.trim(),
        ))

        return ResponseEntity.status(HttpStatus.CREATED).body(mapOf(
            "message"      to "Contribution successful!",
            "contributed"  to contribution.amount,
            "goalBalance"  to goal.balance,
            "goalStatus"   to goal.status.name,
        ))
    }

    @PostMapping("/{id}/withdraw")
    fun withdraw(@PathVariable id: Long, auth: Authentication): ResponseEntity<Any> {
        val user = auth.principal as User
        val goal = goalRepo.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "Goal not found")
        }
        if (goal.creator.id != user.id)
            throw ResponseStatusException(HttpStatus.FORBIDDEN, "Only the creator can withdraw")
        if (goal.balance <= BigDecimal.ZERO)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "No balance to withdraw")
        if (goal.status == GoalStatus.WITHDRAWN)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Already withdrawn")

        val wallet = walletRepo.findByUserVingHandle(user.myrabaHandle)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Wallet not found")

        wallet.balance = wallet.balance.add(goal.balance)
        walletRepo.save(wallet)

        val withdrawn = goal.balance
        goal.balance = BigDecimal.ZERO
        goal.status = GoalStatus.WITHDRAWN
        goal.withdrawnAt = LocalDateTime.now()
        goalRepo.save(goal)

        return ResponseEntity.ok(mapOf(
            "message"   to "₦$withdrawn has been moved to your wallet",
            "withdrawn" to withdrawn,
        ))
    }

    @DeleteMapping("/{id}")
    fun cancel(@PathVariable id: Long, auth: Authentication): ResponseEntity<Any> {
        val user = auth.principal as User
        val goal = goalRepo.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "Goal not found")
        }
        if (goal.creator.id != user.id)
            throw ResponseStatusException(HttpStatus.FORBIDDEN, "Only the creator can cancel")
        if (goal.balance > BigDecimal.ZERO)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST,
                "Withdraw the goal balance before cancelling")
        goal.status = GoalStatus.CANCELLED
        goalRepo.save(goal)
        return ResponseEntity.ok(mapOf("message" to "Goal cancelled"))
    }
}

private fun generateInviteCode(repo: CommunityGoalRepository): String {
    val chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    var code: String
    do { code = (1..8).map { chars.random() }.joinToString("") }
    while (repo.findByInviteCode(code) != null)
    return code
}

private fun CommunityGoal.toDto(
    contributions: List<com.myraba.backend.model.GoalContribution>,
    includeContributions: Boolean = false,
): Map<String, Any?> {
    val base = mapOf(
        "id"              to id,
        "title"           to title,
        "description"     to description,
        "targetAmount"    to targetAmount,
        "balance"         to balance,
        "percentFunded"   to if (targetAmount > BigDecimal.ZERO)
            balance.multiply(java.math.BigDecimal(100))
                .divide(targetAmount, 2, java.math.RoundingMode.HALF_UP) else java.math.BigDecimal.ZERO,
        "inviteCode"      to inviteCode,
        "shareLink"       to "https://myraba.app/goal/$inviteCode",
        "status"          to status.name,
        "deadline"        to deadline,
        "contributorCount" to contributions.map { it.contributor.id }.distinct().size,
        "createdAt"       to createdAt,
        "withdrawnAt"     to withdrawnAt,
        "creator"         to mapOf(
            "handle"   to creator.myrabaHandle,
            "fullName" to creator.fullName,
        ),
    )
    return if (includeContributions) base + mapOf(
        "contributions" to contributions.map { c -> mapOf(
            "id"          to c.id,
            "contributor" to mapOf("handle" to c.contributor.myrabaHandle, "fullName" to c.contributor.fullName),
            "amount"      to c.amount,
            "note"        to c.note,
            "createdAt"   to c.createdAt,
        )}
    ) else base
}
