package com.myraba.backend.controller

import com.myraba.backend.model.User
import com.myraba.backend.repository.UserRepository
import com.myraba.backend.repository.WalletRepository
import org.springframework.http.ResponseEntity
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/referrals")
class ReferralController(
    private val userRepository: UserRepository,
    private val walletRepository: WalletRepository,
) {
    @GetMapping("/my")
    fun getMyReferrals(auth: Authentication): ResponseEntity<Any> {
        val user = auth.principal as User
        val referrals = userRepository.findByReferredBy(user.referralCode ?: "")
        val wallet = walletRepository.findByUserVingHandle(user.myrabaHandle)
        return ResponseEntity.ok(mapOf(
            "myReferralCode" to (user.referralCode ?: ""),
            "shareLink"      to "https://myraba.app/join?ref=${user.referralCode}",
            "totalReferrals" to referrals.size,
            "totalEarned"    to referrals.size * 50,   // ₦50 per referral
            "pointsEarned"   to referrals.size * 100,  // 100 points per referral
            "referrals"      to referrals.map { mapOf(
                "fullName"  to it.fullName,
                "handle"    to it.myrabaHandle,
                "joinedAt"  to it.createdAt,
            )},
        ))
    }
}
