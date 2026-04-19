package com.myraba.backend.controller

import com.myraba.backend.dto.LoginRequest
import com.myraba.backend.dto.LoginResponse
import com.myraba.backend.dto.RegisterRequest
import com.myraba.backend.dto.SendOtpRequest
import com.myraba.backend.model.User
import com.myraba.backend.model.UserRole
import com.myraba.backend.model.Wallet
import com.myraba.backend.repository.MfaSecretRepository
import com.myraba.backend.repository.UserRepository
import com.myraba.backend.repository.UserPointsRepository
import com.myraba.backend.repository.WalletRepository
import com.myraba.backend.service.AuditLogService
import com.myraba.backend.service.OtpService
import com.myraba.backend.util.JwtUtil
import jakarta.servlet.http.HttpServletRequest
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.authentication.AuthenticationManager
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken
import org.springframework.security.core.userdetails.UserDetailsService
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.validation.annotation.Validated
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import kotlin.random.Random

@RestController
@RequestMapping("/auth")
@Validated
class AuthController(
    private val authenticationManager: AuthenticationManager,
    private val userDetailsService: UserDetailsService,
    private val jwtUtil: JwtUtil,
    private val userRepository: UserRepository,
    private val walletRepository: WalletRepository,
    private val passwordEncoder: PasswordEncoder,
    private val otpService: OtpService,
    private val mfaRepo: MfaSecretRepository,
    private val auditLogService: AuditLogService,
    private val userPointsRepository: UserPointsRepository,
) {

    private fun generateReferralCode(): String {
        val chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        var code: String
        do { code = (1..8).map { chars.random() }.joinToString("") }
        while (userRepository.findByReferralCode(code) != null)
        return code
    }

    // ─── Account number helpers ───────────────────────────────────

    /** Nigerian format: 08012345678 → 8012345678 (10 digits) */
    private fun phoneToAccountNumber(phone: String): String {
        val digits = phone.trim()
            .removePrefix("+234").removePrefix("234").removePrefix("0")
            .filter { it.isDigit() }
        return digits.takeLast(10).padStart(10, '0')
    }

    /** Fallback when no phone: random unique 10-digit number */
    private fun generateUniqueAccountNumber(): String {
        var candidate: String
        do {
            candidate = String.format("%010d", Random.nextLong(1_000_000_000L, 9_999_999_999L))
        } while (userRepository.findByAccountNumber(candidate) != null)
        return candidate
    }

    /** "5678-smith" style custom account ID */
    private fun buildCustomAccountId(phone: String, fullName: String, nameChoice: String): String {
        val lastFour = phone.filter { it.isDigit() }.takeLast(4)
        val parts = fullName.trim().split(Regex("\\s+"))
        val rawName = when (nameChoice.uppercase()) {
            "FIRST"  -> parts.firstOrNull() ?: parts.first()
            "MIDDLE" -> parts.getOrNull(1) ?: parts.firstOrNull() ?: parts.first()
            else     -> parts.lastOrNull() ?: parts.first()
        }
        val namePart = rawName.lowercase().filter { it.isLetter() }.take(10)
        var candidate = "$lastFour-$namePart"
        var suffix = 2
        while (userRepository.findByCustomAccountId(candidate) != null) {
            candidate = "$lastFour-$namePart$suffix"
            suffix++
        }
        return candidate
    }

    // ─── Endpoints ────────────────────────────────────────────────

    @PostMapping("/send-otp")
    fun sendOtp(@RequestBody request: SendOtpRequest): ResponseEntity<String> {
        val contact = request.contact.trim()
        if (contact.isBlank())
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Phone number or email required")
        otpService.generateOtp(contact, request.purpose)
        val destination = if (contact.contains("@")) "email" else "phone"
        return ResponseEntity.ok("OTP sent to your $destination")
    }

    @PostMapping("/login")
    fun login(@RequestBody request: LoginRequest, httpRequest: HttpServletRequest): ResponseEntity<LoginResponse> {
        val identifier = request.identifier.trim()

        // Find user by email, phone, or myrabaHandle
        val user = if (identifier.contains("@"))
            userRepository.findByEmail(identifier)
        else
            userRepository.findByPhone(identifier) ?: userRepository.findByVingHandle(identifier)

        user ?: throw ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid credentials")

        try {
            authenticationManager.authenticate(
                UsernamePasswordAuthenticationToken(user.myrabaHandle, request.password)
            )
        } catch (e: Exception) {
            auditLogService.logUser(user.myrabaHandle, "LOGIN_FAILED", "USER", user.id.toString(),
                details = "Failed login attempt", request = httpRequest)
            throw ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid credentials")
        }

        // If MFA is enabled, withhold token until TOTP verified
        val mfa = mfaRepo.findByUserId(user.id)
        if (mfa?.enabled == true) {
            return ResponseEntity.ok(
                LoginResponse(token = null, myrabaHandle = user.myrabaHandle,
                    myrabaTag = "m₦${user.myrabaHandle}", role = user.role.name, mfaRequired = true)
            )
        }

        val userDetails = userDetailsService.loadUserByUsername(user.myrabaHandle)
        val token = jwtUtil.generateToken(userDetails)

        auditLogService.logUser(user.myrabaHandle, "LOGIN", "USER", user.id.toString(),
            details = "Successful login", request = httpRequest)
        return ResponseEntity.ok(
            LoginResponse(token = token, myrabaHandle = user.myrabaHandle,
                myrabaTag = "m₦${user.myrabaHandle}", role = user.role.name,
                forcePasswordChange = user.forcePasswordChange)
        )
    }

    @PostMapping("/register")
    fun register(@RequestBody @jakarta.validation.Valid request: RegisterRequest, httpRequest: HttpServletRequest): ResponseEntity<LoginResponse> {
        // Validate: phone or email must be provided
        if (request.phone.isNullOrBlank() && request.email.isNullOrBlank())
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Phone number or email is required")

        // OTP verification — check against whichever contact was provided
        val contact = (request.phone?.takeIf { it.isNotBlank() } ?: request.email)!!.trim()
        if (request.otpCode == null || !otpService.verifyOtp(contact, request.otpCode))
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid or expired OTP")

        // Duplicate checks
        if (userRepository.findByVingHandle(request.myrabaHandle) != null)
            throw ResponseStatusException(HttpStatus.CONFLICT, "MyrabaTag already taken")
        if (request.phone != null && userRepository.findByPhone(request.phone) != null)
            throw ResponseStatusException(HttpStatus.CONFLICT, "Phone number already registered")
        if (request.email != null && userRepository.findByEmail(request.email) != null)
            throw ResponseStatusException(HttpStatus.CONFLICT, "Email already registered")

        // Account number — use phone digits if phone provided AND user opted in; otherwise auto-generate
        val accountNumber = if (!request.phone.isNullOrBlank() && request.usePhoneAsAccountNumber)
            phoneToAccountNumber(request.phone)
        else
            generateUniqueAccountNumber()

        if (userRepository.findByAccountNumber(accountNumber) != null)
            throw ResponseStatusException(HttpStatus.CONFLICT, "Account number conflict — contact support")

        // Custom account ID (only available when phone is provided)
        val customAccountId: String? = if (request.useCustomAccountId && !request.phone.isNullOrBlank())
            buildCustomAccountId(request.phone, request.fullName, request.nameChoice)
        else null

        val inviterCode = request.referralCode?.trim()?.uppercase()
        val inviter = if (!inviterCode.isNullOrBlank()) userRepository.findByReferralCode(inviterCode) else null

        val newUser = User(
            myrabaHandle = request.myrabaHandle,
            passwordHash = passwordEncoder.encode(request.password),
            fullName = request.fullName,
            phone = request.phone?.trim(),
            email = request.email?.trim(),
            accountNumber = accountNumber,
            customAccountId = customAccountId,
            role = UserRole.USER,
            referralCode = generateReferralCode(),
            referredBy = inviter?.referralCode,
        )

        val savedUser = userRepository.save(newUser)
        walletRepository.save(Wallet(user = savedUser))

        // Reward inviter: 100 points + ₦50 wallet credit
        if (inviter != null) {
            val inviterPoints = userPointsRepository.findByUser(inviter)
            if (inviterPoints != null) {
                inviterPoints.totalLifetime += 100
                inviterPoints.thisYear += 100
                userPointsRepository.save(inviterPoints)
            }
            val inviterWallet = walletRepository.findByUserVingHandle(inviter.myrabaHandle)
            if (inviterWallet != null) {
                inviterWallet.balance = inviterWallet.balance.add(java.math.BigDecimal("50.00"))
                walletRepository.save(inviterWallet)
            }
        }

        auditLogService.logUser(savedUser.myrabaHandle, "REGISTRATION", "USER", savedUser.id.toString(),
            details = "New account registered via ${if (savedUser.phone != null) "phone" else "email"}",
            request = httpRequest)

        val userDetails = userDetailsService.loadUserByUsername(savedUser.myrabaHandle)
        val token = jwtUtil.generateToken(userDetails)

        return ResponseEntity.status(HttpStatus.CREATED).body(
            LoginResponse(
                token = token,
                myrabaHandle = savedUser.myrabaHandle,
                myrabaTag = "m₦${savedUser.myrabaHandle}",
                role = savedUser.role.name
            )
        )
    }
}
