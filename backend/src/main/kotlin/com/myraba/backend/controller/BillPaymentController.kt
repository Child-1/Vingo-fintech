package com.myraba.backend.controller

import com.myraba.backend.model.BillCategory
import com.myraba.backend.model.BillPayment
import com.myraba.backend.model.User
import com.myraba.backend.repository.BillPaymentRepository
import com.myraba.backend.service.AuditLogService
import com.myraba.backend.service.VTpassService
import com.myraba.backend.service.WalletService
import jakarta.servlet.http.HttpServletRequest
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import java.math.BigDecimal
import java.time.LocalDateTime

// ─── Request bodies ───────────────────────────────────────────────

data class AirtimeRequest(
    val phone: String,
    val amount: BigDecimal,
    val network: String     // mtn, airtel, glo, etisalat
)

data class DataRequest(
    val phone: String,
    val network: String,
    val planCode: String    // from GET /api/bills/data/{network}/plans
)

data class ElectricityRequest(
    val meterNumber: String,
    val disco: String,      // ikeja-electric, ekedc, aedc, ibedc, eedc, phedc, etc.
    val meterType: String,  // prepaid or postpaid
    val amount: BigDecimal,
    val phone: String
)

data class CableTvRequest(
    val smartCardNumber: String,
    val provider: String,   // dstv, gotv, startimes
    val planCode: String,
    val phone: String
)

data class BettingRequest(
    val bettingUserId: String,
    val provider: String,   // bet9ja, sportybet, 1xbet
    val amount: BigDecimal,
    val phone: String
)

data class EducationRequest(
    val examBody: String,       // WAEC, NECO, JAMB
    val profileCode: String,    // JAMB profile code or phone for WAEC/NECO
    val phone: String,          // phone for SMS delivery
    val quantity: Int = 1,      // number of PINs (WAEC/NECO); ignored for JAMB
    val amount: BigDecimal      // total amount to pay
)

@RestController
@RequestMapping("/api/bills")
class BillPaymentController(
    private val vtpassService: VTpassService,
    private val walletService: WalletService,
    private val billPaymentRepo: BillPaymentRepository,
    private val auditLogService: AuditLogService,
) {

    // ─── Catalogue endpoints (no charge, just lookups) ────────────

    @GetMapping("/data/{network}/plans")
    fun getDataPlans(@PathVariable network: String): ResponseEntity<Any> {
        val plans = vtpassService.getVariations("${network.lowercase()}-data")
        return ResponseEntity.ok(mapOf("network" to network, "plans" to plans))
    }

    @GetMapping("/cable/{provider}/packages")
    fun getCablePackages(@PathVariable provider: String): ResponseEntity<Any> {
        val packages = vtpassService.getVariations(provider.lowercase())
        return ResponseEntity.ok(mapOf("provider" to provider, "packages" to packages))
    }

    @GetMapping("/electricity/verify-meter")
    fun verifyMeter(
        @RequestParam meterNumber: String,
        @RequestParam disco: String,
        @RequestParam meterType: String
    ): ResponseEntity<Any> {
        val result = vtpassService.verifyMeter(meterNumber, disco, meterType)
        return ResponseEntity.ok(result)
    }

    // ─── Payment endpoints ────────────────────────────────────────

    @PostMapping("/airtime")
    fun buyAirtime(
        authentication: Authentication,
        @RequestBody request: AirtimeRequest,
        httpRequest: HttpServletRequest
    ): ResponseEntity<Any> {
        val user = authentication.principal as User
        return processBill(
            user = user,
            category = BillCategory.AIRTIME,
            serviceId = request.network.lowercase(),
            providerName = "${request.network.uppercase()} Nigeria",
            billIdentifier = request.phone,
            amount = request.amount,
            httpRequest = httpRequest
        ) { requestId ->
            vtpassService.buyAirtime(request.phone, request.amount, request.network, requestId)
        }
    }

    @PostMapping("/data")
    fun buyData(
        authentication: Authentication,
        @RequestBody request: DataRequest,
        httpRequest: HttpServletRequest
    ): ResponseEntity<Any> {
        val user = authentication.principal as User
        return processBill(
            user = user,
            category = BillCategory.DATA,
            serviceId = "${request.network.lowercase()}-data",
            providerName = "${request.network.uppercase()} Data",
            billIdentifier = request.phone,
            amount = BigDecimal("0"),
            httpRequest = httpRequest
        ) { requestId ->
            vtpassService.buyData(request.phone, request.planCode, request.network, requestId)
        }
    }

    @PostMapping("/electricity")
    fun payElectricity(
        authentication: Authentication,
        @RequestBody request: ElectricityRequest,
        httpRequest: HttpServletRequest
    ): ResponseEntity<Any> {
        val user = authentication.principal as User
        return processBill(
            user = user,
            category = BillCategory.ELECTRICITY,
            serviceId = request.disco,
            providerName = request.disco.replace("-", " ").uppercase(),
            billIdentifier = request.meterNumber,
            amount = request.amount,
            httpRequest = httpRequest
        ) { requestId ->
            vtpassService.payElectricity(
                request.meterNumber, request.disco, request.meterType,
                request.amount, request.phone, requestId
            )
        }
    }

    @PostMapping("/cable")
    fun payCableTv(
        authentication: Authentication,
        @RequestBody request: CableTvRequest,
        httpRequest: HttpServletRequest
    ): ResponseEntity<Any> {
        val user = authentication.principal as User
        return processBill(
            user = user,
            category = BillCategory.CABLE_TV,
            serviceId = request.provider.lowercase(),
            providerName = request.provider.uppercase(),
            billIdentifier = request.smartCardNumber,
            amount = BigDecimal("0"),
            httpRequest = httpRequest
        ) { requestId ->
            vtpassService.payCableTv(
                request.smartCardNumber, request.provider,
                request.planCode, request.phone, requestId
            )
        }
    }

    @PostMapping("/betting")
    fun fundBetting(
        authentication: Authentication,
        @RequestBody request: BettingRequest,
        httpRequest: HttpServletRequest
    ): ResponseEntity<Any> {
        val user = authentication.principal as User
        return processBill(
            user = user,
            category = BillCategory.BETTING,
            serviceId = request.provider.lowercase(),
            providerName = request.provider.uppercase(),
            billIdentifier = request.bettingUserId,
            amount = request.amount,
            httpRequest = httpRequest
        ) { requestId ->
            vtpassService.fundBettingWallet(
                request.bettingUserId, request.provider,
                request.amount, request.phone, requestId
            )
        }
    }

    @PostMapping("/education")
    fun payEducation(
        authentication: Authentication,
        @RequestBody request: EducationRequest,
        httpRequest: HttpServletRequest
    ): ResponseEntity<Any> {
        val user = authentication.principal as User
        val examBody = request.examBody.uppercase()
        if (examBody !in listOf("WAEC", "NECO", "JAMB"))
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Unsupported exam body. Use WAEC, NECO, or JAMB.")
        val providerName = when (examBody) {
            "WAEC" -> "WAEC e-PIN"
            "NECO" -> "NECO e-PIN"
            "JAMB" -> "JAMB ePIN/Scratch Card"
            else   -> examBody
        }
        return processBill(
            user = user,
            category = BillCategory.EDUCATION,
            serviceId = examBody.lowercase(),
            providerName = providerName,
            billIdentifier = request.profileCode,
            amount = request.amount,
            httpRequest = httpRequest
        ) { requestId ->
            vtpassService.payExamPin(
                examBody = examBody,
                profileCode = request.profileCode,
                quantity = request.quantity,
                phone = request.phone,
                amount = request.amount,
                requestId = requestId
            )
        }
    }

    // ─── History ──────────────────────────────────────────────────

    @GetMapping("/history")
    fun getHistory(
        authentication: Authentication,
        @RequestParam(required = false) category: String?
    ): ResponseEntity<Any> {
        val user = authentication.principal as User
        val records = if (category != null) {
            val cat = try { BillCategory.valueOf(category.uppercase()) }
                      catch (e: Exception) { throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid category") }
            billPaymentRepo.findByUserAndCategoryOrderByCreatedAtDesc(user, cat)
        } else {
            billPaymentRepo.findByUserOrderByCreatedAtDesc(user)
        }

        return ResponseEntity.ok(
            mapOf(
                "records" to records.map { r ->
                    mapOf(
                        "id"           to r.id,
                        "category"     to r.category.name,
                        "provider"     to r.providerName,
                        "identifier"   to r.billIdentifier,
                        "amount"       to r.amount.toPlainString(),
                        "status"       to r.status,
                        "vtpassCode"   to r.vtpassCode,
                        "createdAt"    to r.createdAt.toString()
                    )
                },
                "total" to records.size
            )
        )
    }

    // ─── Shared payment processor ─────────────────────────────────

    private fun processBill(
        user: User,
        category: BillCategory,
        serviceId: String,
        providerName: String,
        billIdentifier: String,
        amount: BigDecimal,
        httpRequest: HttpServletRequest,
        vtpassCall: (String) -> com.myraba.backend.service.VTpassResult
    ): ResponseEntity<Any> {
        // Deduct from wallet first (before calling VTpass)
        if (amount > BigDecimal.ZERO) {
            val success = walletService.deductFromWallet(
                user = user,
                amount = amount,
                description = "$providerName payment",
                type = com.myraba.backend.model.TransactionType.BILL_PAYMENT
            )
            if (!success) throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Insufficient wallet balance")
        }

        val requestId = vtpassService.generateRequestId()
        val record = billPaymentRepo.save(
            BillPayment(
                user = user,
                category = category,
                serviceId = serviceId,
                providerName = providerName,
                billIdentifier = billIdentifier,
                amount = amount,
                requestId = requestId,
                status = "PENDING"
            )
        )

        val result = vtpassCall(requestId)

        record.status = if (result.success) "SUCCESS" else "FAILED"
        record.vtpassCode = result.transactionCode
        record.failureReason = if (!result.success) result.message else null
        record.completedAt = LocalDateTime.now()
        billPaymentRepo.save(record)

        auditLogService.logUser(user.myrabaHandle, "BILL_PAYMENT", "BILL", record.id.toString(),
            details = "${category.name} — $providerName — $billIdentifier — ₦$amount — ${record.status}",
            request = httpRequest)

        // Refund if VTpass failed (wallet was already deducted)
        if (!result.success && amount > BigDecimal.ZERO) {
            walletService.creditWallet(
                user = user,
                amount = amount,
                description = "Refund — failed $providerName payment",
                type = com.myraba.backend.model.TransactionType.FUNDED
            )
            return ResponseEntity.status(HttpStatus.BAD_GATEWAY).body(
                mapOf("status" to "FAILED", "message" to result.message,
                      "refunded" to true, "refundAmount" to amount.toPlainString())
            )
        }

        return ResponseEntity.ok(
            mapOf(
                "status"      to "SUCCESS",
                "provider"    to providerName,
                "identifier"  to billIdentifier,
                "amount"      to amount.toPlainString(),
                "vtpassCode"  to result.transactionCode,
                "message"     to result.message
            )
        )
    }
}
