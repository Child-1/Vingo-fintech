package com.myraba.backend.service

import com.myraba.backend.model.TransactionType
import com.myraba.backend.model.User
import com.myraba.backend.model.thrift.*
import com.myraba.backend.repository.WalletRepository
import com.myraba.backend.repository.thrift.*
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.math.BigDecimal
import java.math.RoundingMode
import java.time.LocalDateTime
import java.util.UUID

// Fee distribution constants
private val CREATOR_SHARE   = BigDecimal("0.30")   // 30% at completion
private val MEMBER_SHARE    = BigDecimal("0.60")   // 60% split equally among members
private val SYSTEM_SHARE    = BigDecimal("0.10")   // 10% to system
private val CREATOR_BONUS   = BigDecimal("0.50")   // 50% of system share → creator at completion

@Service
class PrivateThriftService(
    private val thriftRepo: PrivateThriftRepository,
    private val memberRepo: PrivateThriftMemberRepository,
    private val defaultRepo: ThriftDefaultRepository,
    private val walletRepo: WalletRepository,
    private val walletService: WalletService
) {

    // ─── Creation ─────────────────────────────────────────────────

    @Transactional
    fun createThrift(creator: User, request: CreatePrivateThriftRequest): PrivateThrift {
        // Creator cannot run more than one active thrift unless they have enough completed cycles + rating
        val activeCount = thriftRepo.countByCreatorAndStatusIn(
            creator, listOf(PrivateThriftStatus.ACTIVE, PrivateThriftStatus.DRAFT)
        )
        if (activeCount >= 1) {
            val completedCount = thriftRepo.countByCreatorAndStatusIn(creator, listOf(PrivateThriftStatus.COMPLETED))
            if (completedCount < 3)
                throw IllegalStateException("Complete at least 3 thrift cycles before running multiple thrifts")
        }

        // Creator must have enough collateral balance (one contribution amount)
        val creatorWallet = walletRepo.findByUserVingHandle(creator.myrabaHandle)
            ?: throw IllegalStateException("Creator wallet not found")
        if (creatorWallet.balance < request.contributionAmount)
            throw IllegalStateException(
                "You need at least ₦${request.contributionAmount} in your wallet as collateral to create this thrift"
            )

        val thrift = PrivateThrift(
            creator = creator,
            name = request.name,
            description = request.description,
            inviteCode = generateInviteCode(),
            contributionAmount = request.contributionAmount,
            frequency = request.frequency,
            paymentFlexibility = request.paymentFlexibility,
            totalCycles = request.totalCycles,
            positionAssignment = request.positionAssignment,
            entryFee = request.entryFee,
            surchargePerContribution = request.surchargePerContribution,
            creatorRules = request.creatorRules
        )
        return thriftRepo.save(thrift)
    }

    // ─── Joining ──────────────────────────────────────────────────

    @Transactional
    fun requestToJoin(user: User, inviteCode: String): PrivateThriftMember {
        val thrift = thriftRepo.findByInviteCode(inviteCode)
            ?: throw IllegalArgumentException("Invalid invite code")

        if (thrift.status != PrivateThriftStatus.DRAFT && thrift.status != PrivateThriftStatus.ACTIVE)
            throw IllegalStateException("This thrift is not accepting new members")

        if (memberRepo.existsByThriftAndUser(thrift, user))
            throw IllegalStateException("You have already joined this thrift")

        if (user.id == thrift.creator.id)
            throw IllegalStateException("The creator cannot join their own thrift as a member")

        val member = PrivateThriftMember(thrift = thrift, user = user)
        return memberRepo.save(member)
    }

    @Transactional
    fun acceptRulesAndJoin(user: User, thriftId: Long): PrivateThriftMember {
        val thrift = thriftRepo.findById(thriftId).orElseThrow { IllegalArgumentException("Thrift not found") }
        val member = memberRepo.findByThriftAndUser(thrift, user)
            ?: throw IllegalStateException("You have not been invited to this thrift")

        if (member.agreedToRules)
            throw IllegalStateException("You have already accepted the rules")

        // Charge entry fee
        if (thrift.entryFee > BigDecimal.ZERO) {
            val success = walletService.deductFromWallet(
                user = user,
                amount = thrift.entryFee,
                description = "Entry fee — ${thrift.name}",
                type = TransactionType.CONTRIBUTION
            )
            if (!success) throw IllegalStateException("Insufficient balance for entry fee of ₦${thrift.entryFee}")
            member.entryFeePaid = true
        }

        member.agreedToRules = true
        member.agreedAt = LocalDateTime.now()
        member.status = PrivateMemberStatus.ACTIVE
        return memberRepo.save(member)
    }

    // ─── Contributions ────────────────────────────────────────────

    @Transactional
    fun contribute(user: User, thriftId: Long, amount: BigDecimal): PrivateThriftMember {
        val thrift = thriftRepo.findById(thriftId).orElseThrow { IllegalArgumentException("Thrift not found") }
        val member = memberRepo.findByThriftAndUser(thrift, user)
            ?: throw IllegalStateException("You are not a member of this thrift")

        if (member.status != PrivateMemberStatus.ACTIVE)
            throw IllegalStateException("Your membership is not active")

        val totalWithSurcharge = amount.add(thrift.surchargePerContribution)

        val success = walletService.deductFromWallet(
            user = user,
            amount = totalWithSurcharge,
            description = "Thrift contribution — ${thrift.name}",
            type = TransactionType.CONTRIBUTION
        )
        if (!success) throw IllegalStateException("Insufficient balance")

        // Distribute surcharge: 30% creator (at end), 60% members (at payout), 10% system
        // For now we record contribution; fee distribution happens at cycle completion

        member.currentCycleContributed = member.currentCycleContributed.add(amount)
        member.totalContributed = member.totalContributed.add(amount)
        member.lastContributionAt = LocalDateTime.now()
        return memberRepo.save(member)
    }

    // ─── Position assignment ──────────────────────────────────────

    @Transactional
    fun assignPositions(creator: User, thriftId: Long, positionMap: Map<Long, Int>? = null) {
        val thrift = thriftRepo.findById(thriftId).orElseThrow { IllegalArgumentException("Thrift not found") }
        if (thrift.creator.id != creator.id) throw IllegalStateException("Only the creator can assign positions")

        val activeMembers = memberRepo.findByThriftAndStatus(thrift, PrivateMemberStatus.ACTIVE)

        when (thrift.positionAssignment) {
            PositionAssignment.RAFFLE -> {
                val shuffled = activeMembers.shuffled()
                shuffled.forEachIndexed { i, m ->
                    m.position = i + 1
                    memberRepo.save(m)
                }
            }
            PositionAssignment.MANUAL -> {
                positionMap ?: throw IllegalArgumentException("Position map required for manual assignment")
                for ((memberId, position) in positionMap) {
                    val m = activeMembers.find { it.id == memberId }
                        ?: throw IllegalArgumentException("Member $memberId not found in this thrift")
                    m.position = position
                    memberRepo.save(m)
                }
            }
        }

        thrift.status = PrivateThriftStatus.ACTIVE
        thrift.startedAt = LocalDateTime.now()
        thriftRepo.save(thrift)
    }

    // ─── Payout (creator-approved) ────────────────────────────────

    @Transactional
    fun approvePayout(creator: User, thriftId: Long, memberId: Long): PrivateThriftMember {
        val thrift = thriftRepo.findById(thriftId).orElseThrow { IllegalArgumentException("Thrift not found") }
        if (thrift.creator.id != creator.id) throw IllegalStateException("Only the creator can approve payouts")

        val member = memberRepo.findById(memberId).orElseThrow { IllegalArgumentException("Member not found") }
        if (member.thrift.id != thrift.id) throw IllegalStateException("Member does not belong to this thrift")
        if (member.hasReceivedPayout) throw IllegalStateException("This member has already been paid out")

        // Verify member has contributed their full cycle amount
        if (member.currentCycleContributed < thrift.contributionAmount)
            throw IllegalStateException(
                "Member has only contributed ₦${member.currentCycleContributed} of required ₦${thrift.contributionAmount}"
            )

        // The payout = all members' contributions for this cycle
        val activeCount = memberRepo.countByThriftAndStatus(thrift, PrivateMemberStatus.ACTIVE)
        val payoutAmount = thrift.contributionAmount.multiply(BigDecimal(activeCount))

        walletService.creditWallet(
            user = member.user,
            amount = payoutAmount,
            description = "Thrift payout — ${thrift.name} (cycle ${thrift.currentCycle + 1})",
            type = TransactionType.PAYOUT
        )

        member.hasReceivedPayout = true
        member.payoutApprovedAt = LocalDateTime.now()
        memberRepo.save(member)

        // Advance cycle
        thrift.currentCycle++

        // Reset all members' current cycle contributions
        val allActive = memberRepo.findByThriftAndStatus(thrift, PrivateMemberStatus.ACTIVE)
        allActive.forEach { m ->
            m.currentCycleContributed = BigDecimal.ZERO
            memberRepo.save(m)
        }

        // Check if thrift is complete
        if (thrift.currentCycle >= thrift.totalCycles) {
            completeCycle(thrift)
        }

        thriftRepo.save(thrift)
        return member
    }

    // ─── Ejection ─────────────────────────────────────────────────

    @Transactional
    fun ejectMember(creator: User, thriftId: Long, memberId: Long, reason: String) {
        val thrift = thriftRepo.findById(thriftId).orElseThrow { IllegalArgumentException("Thrift not found") }
        if (thrift.creator.id != creator.id) throw IllegalStateException("Only the creator can eject members")

        val member = memberRepo.findById(memberId).orElseThrow { IllegalArgumentException("Member not found") }

        // Reason must not be empty — creator must show cause within agreed rules
        if (reason.isBlank())
            throw IllegalArgumentException("Ejection reason is required and must be within agreed rules")

        // Return whatever they've contributed in the current cycle
        if (member.currentCycleContributed > BigDecimal.ZERO) {
            walletService.creditWallet(
                user = member.user,
                amount = member.currentCycleContributed,
                description = "Refund — removed from ${thrift.name}",
                type = TransactionType.FUNDED
            )
        }

        member.status = PrivateMemberStatus.EJECTED
        member.ejectionReason = reason
        memberRepo.save(member)
    }

    // ─── Default flagging ─────────────────────────────────────────

    @Transactional
    fun flagDefault(creator: User, thriftId: Long, defaulterVingHandle: String, amountOwed: BigDecimal): ThriftDefault {
        val thrift = thriftRepo.findById(thriftId).orElseThrow { IllegalArgumentException("Thrift not found") }
        if (thrift.creator.id != creator.id) throw IllegalStateException("Only the creator can flag defaults")

        val defaulterMember = memberRepo.findByThrift(thrift)
            .firstOrNull { it.user.myrabaHandle == defaulterVingHandle }
            ?: throw IllegalArgumentException("User is not a member of this thrift")

        val default = ThriftDefault(
            defaulter = defaulterMember.user,
            creator = creator,
            thrift = thrift,
            amountOwed = amountOwed
        )
        return defaultRepo.save(default)
    }

    // ─── Default recovery scheduler ──────────────────────────────

    /**
     * Runs every 6 hours. For each ACTIVE default, check if the defaulter's
     * wallet now has enough to cover what they owe. If so, freeze it.
     */
    @Scheduled(cron = "0 0 */6 * * *")
    @Transactional
    fun checkAndFreezeDefaulterFunds() {
        val activeDefaults = defaultRepo.findByStatus(DefaultStatus.ACTIVE)

        for (default in activeDefaults) {
            val wallet = walletRepo.findByUserVingHandle(default.defaulter.myrabaHandle) ?: continue
            if (wallet.balance >= default.amountOwed) {
                // Freeze the funds
                wallet.balance = wallet.balance.subtract(default.amountOwed)
                walletRepo.save(wallet)

                default.status = DefaultStatus.FROZEN
                default.frozenAt = LocalDateTime.now()
                default.disputeRound = 1
                default.disputeDeadline = LocalDateTime.now().plusWeeks(2)
                defaultRepo.save(default)

                // TODO: send notification to defaulter
            }
        }
    }

    /**
     * Daily check on frozen defaults that have passed their dispute deadline.
     */
    @Scheduled(cron = "0 0 3 * * *")
    @Transactional
    fun processFrozenDefaultDeadlines() {
        val frozenDefaults = defaultRepo.findByStatus(DefaultStatus.FROZEN)
        val now = LocalDateTime.now()

        for (default in frozenDefaults) {
            val deadline = default.disputeDeadline ?: continue
            if (now.isBefore(deadline)) continue

            when (default.disputeRound) {
                1 -> {   // 2-week window expired → give another 2 weeks (round 2)
                    default.disputeRound = 2
                    default.disputeDeadline = now.plusWeeks(2)
                    defaultRepo.save(default)
                    // TODO: notify
                }
                2 -> {   // round 2 expired → give 4 weeks (round 3 / final)
                    default.disputeRound = 3
                    default.disputeDeadline = now.plusWeeks(4)
                    defaultRepo.save(default)
                    // TODO: notify
                }
                3 -> {   // final deadline expired → forfeit to creator
                    walletService.creditWallet(
                        user = default.creator,
                        amount = default.amountOwed,
                        description = "Default recovery — ${default.thrift.name}",
                        type = TransactionType.FUNDED
                    )
                    default.status = DefaultStatus.FORFEITED
                    default.resolvedAt = now
                    defaultRepo.save(default)
                    // TODO: notify both parties
                }
            }
        }
    }

    // ─── Cycle completion & fee distribution ─────────────────────

    @Transactional
    fun completeCycle(thrift: PrivateThrift) {
        thrift.status = PrivateThriftStatus.COMPLETED
        thrift.completedAt = LocalDateTime.now()

        val allMembers = memberRepo.findByThriftAndStatus(thrift, PrivateMemberStatus.ACTIVE)
        val memberCount = allMembers.size

        if (memberCount == 0) return

        // Total fees collected = (entryFee × members) + (surcharge × totalCycles × members)
        val totalEntryFees = thrift.entryFee.multiply(BigDecimal(memberCount))
        val totalSurcharges = thrift.surchargePerContribution
            .multiply(BigDecimal(thrift.totalCycles))
            .multiply(BigDecimal(memberCount))
        val totalFees = totalEntryFees.add(totalSurcharges)

        if (totalFees <= BigDecimal.ZERO) return

        val creatorShare  = totalFees.multiply(CREATOR_SHARE)
        val memberPool    = totalFees.multiply(MEMBER_SHARE)
        val systemShare   = totalFees.multiply(SYSTEM_SHARE)
        val creatorBonus  = systemShare.multiply(CREATOR_BONUS)  // 5% of total = 50% of system's 10%

        // Pay creator their 30% + 5% bonus
        val totalCreatorPay = creatorShare.add(creatorBonus)
        walletService.creditWallet(
            user = thrift.creator,
            amount = totalCreatorPay,
            description = "Thrift completion reward — ${thrift.name}",
            type = TransactionType.FUNDED
        )

        // Distribute 60% equally to all members
        val perMemberShare = memberPool.divide(BigDecimal(memberCount), 2, RoundingMode.DOWN)
        for (member in allMembers) {
            walletService.creditWallet(
                user = member.user,
                amount = perMemberShare,
                description = "Thrift member reward — ${thrift.name}",
                type = TransactionType.FUNDED
            )
        }

        // Remaining 5% stays with system (no action needed)
    }

    // ─── Creator dashboard queries ────────────────────────────────

    fun getCreatorThrifts(creator: User) = thriftRepo.findByCreator(creator)

    fun getThriftMembers(creator: User, thriftId: Long): List<PrivateThriftMember> {
        val thrift = thriftRepo.findById(thriftId).orElseThrow { IllegalArgumentException("Thrift not found") }
        if (thrift.creator.id != creator.id) throw IllegalStateException("Access denied")
        return memberRepo.findByThrift(thrift)
    }

    fun getMemberThrifts(user: User) = memberRepo.findByUser(user)

    private fun generateInviteCode(): String {
        var code: String
        do {
            code = UUID.randomUUID().toString().replace("-", "").take(8).uppercase()
        } while (thriftRepo.findByInviteCode(code) != null)
        return code
    }
}

data class CreatePrivateThriftRequest(
    val name: String,
    val description: String? = null,
    val contributionAmount: BigDecimal,
    val frequency: String = "MONTHLY",
    val paymentFlexibility: PaymentFlexibility = PaymentFlexibility.FIXED,
    val totalCycles: Int,
    val positionAssignment: PositionAssignment = PositionAssignment.RAFFLE,
    val entryFee: BigDecimal = BigDecimal.ZERO,
    val surchargePerContribution: BigDecimal = BigDecimal.ZERO,
    val creatorRules: String? = null
)
