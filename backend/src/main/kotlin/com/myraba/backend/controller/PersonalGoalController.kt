package com.myraba.backend.controller

import com.myraba.backend.model.*
import com.myraba.backend.repository.PersonalGoalRepository
import com.myraba.backend.repository.TransactionRepository
import com.myraba.backend.repository.WalletRepository
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import java.math.BigDecimal
import java.math.RoundingMode
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit

@RestController
@RequestMapping("/api/savings-goals")
class PersonalGoalController(
    private val goalRepo: PersonalGoalRepository,
    private val walletRepo: WalletRepository,
    private val txRepo: TransactionRepository,
) {
    data class CreateGoalRequest(
        val name: String,
        val description: String? = null,
        val targetAmount: BigDecimal,
        val targetDate: LocalDate,
        val initialAmount: BigDecimal? = null,
        val autoDeductAmount: BigDecimal? = null,
        val autoDeductFrequency: String? = null, // DAILY | WEEKLY | MONTHLY
    )

    data class TopupRequest(val amount: BigDecimal)

    @GetMapping
    fun list(auth: Authentication): ResponseEntity<Any> {
        val user = auth.principal as User
        val goals = goalRepo.findByUserOrderByCreatedAtDesc(user)
        return ResponseEntity.ok(mapOf("goals" to goals.map { it.toDto() }))
    }

    @PostMapping
    fun create(@RequestBody req: CreateGoalRequest, auth: Authentication): ResponseEntity<Any> {
        val user = auth.principal as User
        if (req.name.isBlank())
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Goal name is required")
        if (req.targetAmount < BigDecimal("500"))
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Minimum goal amount is ₦500")
        if (!req.targetDate.isAfter(LocalDate.now()))
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Target date must be in the future")

        val freq = req.autoDeductFrequency?.uppercase()
        if (freq != null && freq !in listOf("DAILY", "WEEKLY", "MONTHLY"))
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Frequency must be DAILY, WEEKLY, or MONTHLY")
        if (freq != null && (req.autoDeductAmount == null || req.autoDeductAmount <= BigDecimal.ZERO))
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Auto-deduct amount is required when frequency is set")

        val wallet = walletRepo.findByUserVingHandle(user.myrabaHandle)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Wallet not found")

        val initial = req.initialAmount?.takeIf { it > BigDecimal.ZERO } ?: BigDecimal.ZERO
        if (initial > BigDecimal.ZERO && wallet.balance < initial)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Insufficient wallet balance for initial deposit")

        val nextDeduct = when (freq) {
            "DAILY"   -> LocalDate.now().plusDays(1)
            "WEEKLY"  -> LocalDate.now().plusWeeks(1)
            "MONTHLY" -> LocalDate.now().plusMonths(1)
            else      -> null
        }

        if (initial > BigDecimal.ZERO) {
            wallet.balance = wallet.balance.subtract(initial)
            walletRepo.save(wallet)
            txRepo.save(Transaction(
                senderWallet = wallet, receiverWallet = null,
                amount = initial, type = TransactionType.WITHDRAWAL,
                status = "SUCCESS",
                description = "Savings goal '${req.name}' — initial deposit",
            ))
        }

        val goal = goalRepo.save(PersonalGoal(
            user = user,
            name = req.name,
            description = req.description,
            targetAmount = req.targetAmount,
            savedAmount = initial,
            targetDate = req.targetDate,
            autoDeductAmount = req.autoDeductAmount,
            autoDeductFrequency = freq,
            nextDeductDate = nextDeduct,
        ))

        return ResponseEntity.status(HttpStatus.CREATED).body(goal.toDto())
    }

    @PostMapping("/{id}/topup")
    fun topup(@PathVariable id: Long, @RequestBody req: TopupRequest, auth: Authentication): ResponseEntity<Any> {
        val user = auth.principal as User
        val goal = findOwned(id, user)
        if (goal.status != PersonalGoalStatus.ACTIVE)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Goal is no longer active")
        if (req.amount <= BigDecimal.ZERO)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Amount must be positive")

        val wallet = walletRepo.findByUserVingHandle(user.myrabaHandle)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Wallet not found")
        if (wallet.balance < req.amount)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Insufficient wallet balance")

        wallet.balance = wallet.balance.subtract(req.amount)
        walletRepo.save(wallet)

        goal.savedAmount = goal.savedAmount.add(req.amount)
        if (goal.savedAmount >= goal.targetAmount) {
            goal.status = PersonalGoalStatus.COMPLETED
            goal.completedAt = LocalDateTime.now()
        }
        goalRepo.save(goal)

        txRepo.save(Transaction(
            senderWallet = wallet, receiverWallet = null,
            amount = req.amount, type = TransactionType.WITHDRAWAL,
            status = "SUCCESS",
            description = "Savings goal '${goal.name}' — top-up",
        ))

        return ResponseEntity.ok(goal.toDto())
    }

    @GetMapping("/{id}/break-preview")
    fun breakPreview(@PathVariable id: Long, auth: Authentication): ResponseEntity<Any> {
        val user = auth.principal as User
        val goal = findOwned(id, user)
        if (goal.status != PersonalGoalStatus.ACTIVE)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Goal is not active")
        if (goal.savedAmount <= BigDecimal.ZERO)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Nothing saved yet")

        val saved = goal.savedAmount
        val warningPenalty = saved.multiply(BigDecimal("0.25")).setScale(2, RoundingMode.HALF_UP)
        val actualPenalty  = saved.multiply(BigDecimal("0.02")).setScale(2, RoundingMode.HALF_UP)
        return ResponseEntity.ok(mapOf(
            "savedAmount"        to saved,
            "warningPenaltyPct"  to 25,
            "warningPenalty"     to warningPenalty,
            "warningReturn"      to saved.subtract(warningPenalty),
            "actualPenaltyPct"   to 2,
            "actualPenalty"      to actualPenalty,
            "actualReturn"       to saved.subtract(actualPenalty),
        ))
    }

    @PostMapping("/{id}/break")
    fun breakGoal(@PathVariable id: Long, auth: Authentication): ResponseEntity<Any> {
        val user = auth.principal as User
        val goal = findOwned(id, user)
        if (goal.status != PersonalGoalStatus.ACTIVE)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Goal is not active")
        if (goal.savedAmount <= BigDecimal.ZERO)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Nothing saved yet")

        val saved       = goal.savedAmount
        val penalty     = saved.multiply(BigDecimal("0.02")).setScale(4, RoundingMode.HALF_UP)
        val returnAmt   = saved.subtract(penalty).setScale(4, RoundingMode.HALF_UP)

        val wallet = walletRepo.findByUserVingHandle(user.myrabaHandle)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Wallet not found")
        wallet.balance = wallet.balance.add(returnAmt)
        walletRepo.save(wallet)

        goal.status = PersonalGoalStatus.WITHDRAWN
        goal.withdrawnAt = LocalDateTime.now()
        goal.savedAmount = BigDecimal.ZERO
        goalRepo.save(goal)

        txRepo.save(Transaction(
            senderWallet = null, receiverWallet = wallet,
            amount = returnAmt, type = TransactionType.TRANSFER,
            status = "SUCCESS",
            description = "Savings goal '${goal.name}' broken — ₦${penalty.toPlainString()} penalty applied",
        ))

        return ResponseEntity.ok(mapOf(
            "returnedAmount" to returnAmt,
            "penalty"        to penalty,
            "message"        to "We recognised your urgent need and only charged ₦${penalty.setScale(2, RoundingMode.HALF_UP)} (2%) instead of the full 25%. ₦${returnAmt.setScale(2, RoundingMode.HALF_UP)} has been returned to your wallet. Please try to honour your savings goals next time. 🙏",
        ))
    }

    @PostMapping("/{id}/complete")
    fun complete(@PathVariable id: Long, auth: Authentication): ResponseEntity<Any> {
        val user = auth.principal as User
        val goal = findOwned(id, user)
        if (goal.status != PersonalGoalStatus.ACTIVE && goal.status != PersonalGoalStatus.COMPLETED)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Goal cannot be completed")
        if (!goal.targetDate.isBefore(LocalDate.now().plusDays(1)))
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Target date has not been reached yet")
        if (goal.savedAmount <= BigDecimal.ZERO)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Nothing saved yet")

        val wallet = walletRepo.findByUserVingHandle(user.myrabaHandle)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Wallet not found")
        wallet.balance = wallet.balance.add(goal.savedAmount)
        walletRepo.save(wallet)

        txRepo.save(Transaction(
            senderWallet = null, receiverWallet = wallet,
            amount = goal.savedAmount, type = TransactionType.TRANSFER,
            status = "SUCCESS",
            description = "Savings goal '${goal.name}' completed — funds released 🎉",
        ))

        goal.status = PersonalGoalStatus.COMPLETED
        goal.completedAt = LocalDateTime.now()
        val released = goal.savedAmount
        goal.savedAmount = BigDecimal.ZERO
        goalRepo.save(goal)

        return ResponseEntity.ok(mapOf(
            "releasedAmount" to released,
            "message"        to "Congratulations! ₦${released.setScale(2, RoundingMode.HALF_UP)} from your '${goal.name}' goal has been released to your wallet. Well done! 🎉",
        ))
    }

    @GetMapping("/calculate")
    fun calculate(
        @RequestParam target: BigDecimal,
        @RequestParam targetDate: LocalDate,
        @RequestParam(defaultValue = "WEEKLY") frequency: String,
    ): ResponseEntity<Any> {
        if (!targetDate.isAfter(LocalDate.now()))
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Target date must be in the future")
        val days = ChronoUnit.DAYS.between(LocalDate.now(), targetDate).coerceAtLeast(1)
        val periods = when (frequency.uppercase()) {
            "DAILY"   -> days
            "WEEKLY"  -> (days / 7).coerceAtLeast(1)
            "MONTHLY" -> (days / 30).coerceAtLeast(1)
            else      -> throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Frequency must be DAILY, WEEKLY, or MONTHLY")
        }
        val perPeriod = target.divide(BigDecimal(periods), 2, RoundingMode.CEILING)
        return ResponseEntity.ok(mapOf(
            "targetAmount"  to target,
            "targetDate"    to targetDate,
            "frequency"     to frequency.uppercase(),
            "periods"       to periods,
            "amountPerPeriod" to perPeriod,
            "daysUntilTarget" to days,
        ))
    }

    private fun findOwned(id: Long, user: User): PersonalGoal {
        val goal = goalRepo.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "Goal not found")
        }
        if (goal.user.id != user.id)
            throw ResponseStatusException(HttpStatus.FORBIDDEN, "Not your goal")
        return goal
    }

    private fun PersonalGoal.toDto(): Map<String, Any?> {
        val daysLeft = ChronoUnit.DAYS.between(LocalDate.now(), targetDate).coerceAtLeast(0)
        val progress = if (targetAmount > BigDecimal.ZERO)
            savedAmount.divide(targetAmount, 4, RoundingMode.HALF_UP).multiply(BigDecimal(100))
                .setScale(1, RoundingMode.HALF_UP)
        else BigDecimal.ZERO
        return mapOf(
            "id"                   to id,
            "name"                 to name,
            "description"          to description,
            "targetAmount"         to targetAmount,
            "savedAmount"          to savedAmount,
            "progressPercent"      to progress,
            "targetDate"           to targetDate,
            "daysRemaining"        to daysLeft,
            "autoDeductAmount"     to autoDeductAmount,
            "autoDeductFrequency"  to autoDeductFrequency,
            "nextDeductDate"       to nextDeductDate,
            "status"               to status.name,
            "createdAt"            to createdAt,
            "completedAt"          to completedAt,
            "withdrawnAt"          to withdrawnAt,
        )
    }
}
