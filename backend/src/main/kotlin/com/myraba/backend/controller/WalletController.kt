package com.myraba.backend.controller

import com.myraba.backend.dto.FundWalletRequest
import com.myraba.backend.dto.TransactionHistoryResponse
import com.myraba.backend.dto.TransactionResponse
import com.myraba.backend.dto.TransferByAccountNumberRequest
import com.myraba.backend.dto.TransferRequest
import com.myraba.backend.dto.TransferResponse
import com.myraba.backend.model.Transaction
import com.myraba.backend.model.TransactionType
import com.myraba.backend.model.User
import com.myraba.backend.model.UserStatus
import com.myraba.backend.repository.TransactionRepository
import com.myraba.backend.repository.UserRepository
import com.myraba.backend.repository.WalletRepository
import com.myraba.backend.service.AuditLogService
import com.myraba.backend.service.IdempotencyService
import jakarta.servlet.http.HttpServletRequest
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.security.core.Authentication
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import java.math.BigDecimal

@RestController
@RequestMapping("/wallets")
class WalletController(
    private val walletRepository: WalletRepository,
    private val transactionRepository: TransactionRepository,
    private val userRepository: UserRepository,
    private val idempotencyService: IdempotencyService,
    private val auditLogService: AuditLogService,
) {

    /** Resolve an account number to a name — used before bank transfers */
    @GetMapping("/lookup/account/{accountNumber}")
    fun lookupByAccountNumber(@PathVariable accountNumber: String): ResponseEntity<Any> {
        val user = userRepository.findByAccountNumber(accountNumber)
            ?: return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(mapOf("message" to "No account found for this number"))
        return ResponseEntity.ok(
            mapOf(
                "accountNumber" to user.accountNumber,
                "fullName"      to user.fullName,
                "myrabaHandle"  to user.myrabaHandle
            )
        )
    }

    /** Public endpoint — used for QR code scanning (no auth required) */
    @GetMapping("/{myrabaHandle}")
    fun getWallet(@PathVariable myrabaHandle: String): ResponseEntity<Any> {
        val wallet = walletRepository.findByUserVingHandle(myrabaHandle)
            ?: return ResponseEntity.notFound().build()
        return ResponseEntity.ok(
            mapOf(
                "walletId"      to wallet.id,
                "myrabaHandle"    to wallet.user.myrabaHandle,
                "myrabaTag"      to "m₦${wallet.user.myrabaHandle}",
                "accountNumber" to wallet.user.accountNumber,
                "customAccountId" to wallet.user.customAccountId,
                "balance"       to wallet.balance.toPlainString()
            )
        )
    }

    @GetMapping("/history")
    fun getTransactionHistory(authentication: Authentication): ResponseEntity<TransactionHistoryResponse> {
        val user = authentication.principal as User
        val wallet = walletRepository.findByUserVingHandle(user.myrabaHandle)
            ?: return ResponseEntity.notFound().build()

        val transactions = transactionRepository
            .findBySenderWalletOrReceiverWalletOrderByCreatedAtDesc(wallet, wallet)
            .map { tx ->
                when (tx.type) {
                    TransactionType.FUNDED -> TransactionResponse(
                        id = tx.id, type = "FUNDED", amount = tx.amount,
                        description = tx.description ?: "Wallet funded",
                        counterparty = null, date = tx.createdAt, status = tx.status
                    )
                    TransactionType.PAYOUT -> TransactionResponse(
                        id = tx.id, type = "PAYOUT", amount = tx.amount,
                        description = tx.description ?: "Thrift payout",
                        counterparty = null, date = tx.createdAt, status = tx.status
                    )
                    TransactionType.CONTRIBUTION -> TransactionResponse(
                        id = tx.id, type = "CONTRIBUTION", amount = tx.amount,
                        description = tx.description ?: "Thrift contribution",
                        counterparty = null, date = tx.createdAt, status = tx.status
                    )
                    TransactionType.PENALTY -> TransactionResponse(
                        id = tx.id, type = "PENALTY", amount = tx.amount,
                        description = tx.description ?: "Penalty deduction",
                        counterparty = null, date = tx.createdAt, status = tx.status
                    )
                    TransactionType.WITHDRAWAL -> TransactionResponse(
                        id = tx.id, type = "WITHDRAWAL", amount = tx.amount,
                        description = tx.description ?: "Withdrawal",
                        counterparty = null, date = tx.createdAt, status = tx.status
                    )
                    TransactionType.BILL_PAYMENT -> TransactionResponse(
                        id = tx.id, type = "BILL_PAYMENT", amount = tx.amount,
                        description = tx.description ?: "Bill payment",
                        counterparty = null, date = tx.createdAt, status = tx.status
                    )
                    TransactionType.GIFT -> TransactionResponse(
                        id = tx.id, type = "GIFT", amount = tx.amount,
                        description = tx.description ?: "Gift",
                        counterparty = null, date = tx.createdAt, status = tx.status
                    )
                    TransactionType.ADMIN_CREDIT -> TransactionResponse(
                        id = tx.id, type = "ADMIN_CREDIT", amount = tx.amount,
                        description = tx.description ?: "Admin credit",
                        counterparty = null, date = tx.createdAt, status = tx.status
                    )
                    TransactionType.ADMIN_DEBIT -> TransactionResponse(
                        id = tx.id, type = "ADMIN_DEBIT", amount = tx.amount,
                        description = tx.description ?: "Admin deduction",
                        counterparty = null, date = tx.createdAt, status = tx.status
                    )
                    TransactionType.REVERSAL -> TransactionResponse(
                        id = tx.id, type = "REVERSAL", amount = tx.amount,
                        description = tx.description ?: "Transaction reversed",
                        counterparty = null, date = tx.createdAt, status = tx.status
                    )
                    else -> { // TRANSFER — has real sender & receiver wallets
                        if (tx.senderWallet?.id == wallet.id) {
                            TransactionResponse(
                                id = tx.id, type = "SENT", amount = tx.amount,
                                description = "Sent to ${tx.receiverWallet?.user?.myrabaHandle ?: "unknown"}",
                                counterparty = tx.receiverWallet?.user?.myrabaHandle,
                                date = tx.createdAt, status = tx.status
                            )
                        } else {
                            TransactionResponse(
                                id = tx.id, type = "RECEIVED", amount = tx.amount,
                                description = "Received from ${tx.senderWallet?.user?.myrabaHandle ?: "unknown"}",
                                counterparty = tx.senderWallet?.user?.myrabaHandle,
                                date = tx.createdAt, status = tx.status
                            )
                        }
                    }
                }
            }

        return ResponseEntity.ok(
            TransactionHistoryResponse(
                transactions = transactions,
                total = transactions.size,
                balance = wallet.balance.toPlainString()
            )
        )
    }

    /** Transfer by MyrabaTag (e.g. "Davinci96" — without the m₦ prefix) */
    @PostMapping("/transfer")
    @Transactional
    fun transfer(
        authentication: Authentication,
        @RequestBody request: TransferRequest,
        @RequestHeader(value = "Idempotency-Key", required = false) idempotencyKey: String?,
        httpRequest: HttpServletRequest
    ): ResponseEntity<TransferResponse> {
        val sender = authentication.principal as User
        checkAccountActive(sender)

        if (idempotencyKey != null) {
            @Suppress("UNCHECKED_CAST")
            val cached = idempotencyService.getCached(idempotencyKey, sender.myrabaHandle) as ResponseEntity<TransferResponse>?
            if (cached != null) return cached
        }

        val response = executeTransfer(
            senderVingHandle = sender.myrabaHandle,
            receiverWalletLookup = { walletRepository.findByUserVingHandle(request.receiverVingHandle) },
            receiverLabel = request.receiverVingHandle,
            amount = request.amount
        )
        if (response.body?.status == "SUCCESS") {
            auditLogService.logUser(sender.myrabaHandle, "TRANSFER", "TRANSACTION", response.body!!.transactionId.toString(),
                details = "Sent ₦${request.amount} to @${request.receiverVingHandle}", request = httpRequest)
        }
        if (idempotencyKey != null) idempotencyService.store(idempotencyKey, sender.myrabaHandle, response)
        return response
    }

    /** Transfer by 10-digit numeric account number */
    @PostMapping("/transfer/account")
    @Transactional
    fun transferByAccountNumber(
        authentication: Authentication,
        @RequestBody request: TransferByAccountNumberRequest,
        @RequestHeader(value = "Idempotency-Key", required = false) idempotencyKey: String?,
        httpRequest: HttpServletRequest
    ): ResponseEntity<TransferResponse> {
        val sender = authentication.principal as User
        checkAccountActive(sender)

        if (idempotencyKey != null) {
            @Suppress("UNCHECKED_CAST")
            val cached = idempotencyService.getCached(idempotencyKey, sender.myrabaHandle) as ResponseEntity<TransferResponse>?
            if (cached != null) return cached
        }

        val receiverUser = userRepository.findByAccountNumber(request.accountNumber)
            ?: throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Account not found")
        val receiverWallet = receiverUser.wallet
            ?: throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Receiver wallet not found")
        val response = executeTransfer(
            senderVingHandle = sender.myrabaHandle,
            receiverWalletLookup = { receiverWallet },
            receiverLabel = receiverUser.myrabaHandle,
            amount = request.amount
        )
        if (response.body?.status == "SUCCESS") {
            auditLogService.logUser(sender.myrabaHandle, "TRANSFER", "TRANSACTION", response.body!!.transactionId.toString(),
                details = "Sent ₦${request.amount} to account ${request.accountNumber}", request = httpRequest)
        }
        if (idempotencyKey != null) idempotencyService.store(idempotencyKey, sender.myrabaHandle, response)
        return response
    }

    /** Transfer by custom account ID ("5678-smith" style — Vingo-internal only) */
    @PostMapping("/transfer/custom-id")
    @Transactional
    fun transferByCustomAccountId(
        authentication: Authentication,
        @RequestBody request: TransferByCustomIdRequest,
        @RequestHeader(value = "Idempotency-Key", required = false) idempotencyKey: String?,
        httpRequest: HttpServletRequest
    ): ResponseEntity<TransferResponse> {
        val sender = authentication.principal as User
        checkAccountActive(sender)

        if (idempotencyKey != null) {
            @Suppress("UNCHECKED_CAST")
            val cached = idempotencyService.getCached(idempotencyKey, sender.myrabaHandle) as ResponseEntity<TransferResponse>?
            if (cached != null) return cached
        }

        val receiverUser = userRepository.findByCustomAccountId(request.customAccountId)
            ?: throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Custom account ID not found")
        val receiverWallet = receiverUser.wallet
            ?: throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Receiver wallet not found")
        val response = executeTransfer(
            senderVingHandle = sender.myrabaHandle,
            receiverWalletLookup = { receiverWallet },
            receiverLabel = receiverUser.myrabaHandle,
            amount = request.amount
        )
        if (response.body?.status == "SUCCESS") {
            auditLogService.logUser(sender.myrabaHandle, "TRANSFER", "TRANSACTION", response.body!!.transactionId.toString(),
                details = "Sent ₦${request.amount} to custom-id ${request.customAccountId}", request = httpRequest)
        }
        if (idempotencyKey != null) idempotencyService.store(idempotencyKey, sender.myrabaHandle, response)
        return response
    }

    @PostMapping("/fund")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
    @Transactional
    fun fundWallet(@RequestBody request: FundWalletRequest): ResponseEntity<String> {
        val wallet = walletRepository.findByUserVingHandle(request.myrabaHandle)
            ?: return ResponseEntity.notFound().build()

        wallet.balance = wallet.balance.add(request.amount)
        walletRepository.save(wallet)

        transactionRepository.save(
            Transaction(
                senderWallet = null,
                receiverWallet = wallet,
                amount = request.amount,
                type = TransactionType.FUNDED,
                description = "Wallet funded",
                status = "SUCCESS"
            )
        )

        return ResponseEntity.ok("Wallet funded successfully. New balance: ₦${wallet.balance}")
    }

    // ─────────────────────────────────────────────────────────────
    // Guards
    // ─────────────────────────────────────────────────────────────

    private fun checkAccountActive(user: User) {
        when (user.accountStatus) {
            UserStatus.FROZEN    -> throw ResponseStatusException(HttpStatus.FORBIDDEN, "Your account is frozen. Contact support.")
            UserStatus.SUSPENDED -> throw ResponseStatusException(HttpStatus.FORBIDDEN, "Your account is suspended. Contact support.")
            else -> Unit
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Shared transfer logic
    // ─────────────────────────────────────────────────────────────

    private fun executeTransfer(
        senderVingHandle: String,
        receiverWalletLookup: () -> com.myraba.backend.model.Wallet?,
        receiverLabel: String,
        amount: BigDecimal
    ): ResponseEntity<TransferResponse> {
        // Pessimistic write lock prevents double-spend on concurrent transfers
        val senderWallet = walletRepository.findByUserVingHandleForUpdate(senderVingHandle)
            ?: return ResponseEntity.notFound().build()
        val receiverWallet = receiverWalletLookup()
            ?: return ResponseEntity.badRequest().body(
                TransferResponse(null, senderVingHandle, receiverLabel, amount, "RECEIVER_NOT_FOUND")
            )

        if (senderWallet.id == receiverWallet.id)
            return ResponseEntity.badRequest().body(
                TransferResponse(null, senderVingHandle, receiverLabel, amount, "CANNOT_SEND_TO_SELF")
            )

        if (receiverWallet.user.accountStatus == UserStatus.FROZEN)
            return ResponseEntity.badRequest().body(
                TransferResponse(null, senderVingHandle, receiverLabel, amount, "RECEIVER_ACCOUNT_FROZEN")
            )

        if (senderWallet.balance < amount)
            return ResponseEntity.badRequest().body(
                TransferResponse(null, senderVingHandle, receiverLabel, amount, "INSUFFICIENT_FUNDS")
            )

        senderWallet.balance = senderWallet.balance.subtract(amount)
        receiverWallet.balance = receiverWallet.balance.add(amount)
        walletRepository.save(senderWallet)
        walletRepository.save(receiverWallet)

        val savedTx = transactionRepository.save(
            Transaction(
                senderWallet = senderWallet,
                receiverWallet = receiverWallet,
                amount = amount,
                type = TransactionType.TRANSFER,
                status = "SUCCESS"
            )
        )

        return ResponseEntity.ok(
            TransferResponse(savedTx.id, senderVingHandle, receiverLabel, amount, "SUCCESS")
        )
    }
}

data class TransferByCustomIdRequest(
    val customAccountId: String,
    val amount: BigDecimal
)
