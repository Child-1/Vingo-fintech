package com.myraba.backend.service

import com.myraba.backend.model.*
import com.myraba.backend.repository.KycRepository
import com.myraba.backend.repository.UserRepository
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.*
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.client.RestTemplate
import java.time.LocalDateTime

@Service
class KycService(
    private val kycRepo: KycRepository,
    private val userRepo: UserRepository,
    private val aes: AesEncryptionService,
    @Value("\${myraba.dojah.app-id}")     private val appId: String,
    @Value("\${myraba.dojah.private-key}") private val privateKey: String,
    @Value("\${myraba.dojah.base-url}")    private val baseUrl: String
) {
    private val rest = RestTemplate()

    private fun headers(): HttpHeaders = HttpHeaders().apply {
        set("AppId", appId)
        set("Authorization", privateKey)
        contentType = MediaType.APPLICATION_JSON
    }

    // ─── BVN Verification ─────────────────────────────────────────

    @Transactional
    fun verifyBvn(user: User, bvn: String): KycSubmission {
        validateNotAlreadyVerified(user, KycType.BVN)

        val masked = aes.encrypt(mask(bvn))
        val submission = kycRepo.save(
            KycSubmission(user = user, type = KycType.BVN, maskedNumber = masked)
        )

        return try {
            val response = rest.exchange(
                "$baseUrl/api/v1/kyc/bvn/advance?bvn=$bvn",
                HttpMethod.GET,
                HttpEntity<Void>(headers()),
                Map::class.java
            )

            @Suppress("UNCHECKED_CAST")
            val entity = (response.body?.get("entity") as? Map<String, Any?>)
            val firstName  = entity?.get("first_name") as? String ?: ""
            val lastName   = entity?.get("last_name")  as? String ?: ""
            val dob        = entity?.get("date_of_birth") as? String

            submission.verifiedName = "$firstName $lastName".trim()
            submission.verifiedDob  = dob
            submission.status = KycVerificationStatus.VERIFIED
            submission.verifiedAt = LocalDateTime.now()

            updateUserKycStatus(user)
            kycRepo.save(submission)
        } catch (e: Exception) {
            submission.status = KycVerificationStatus.FAILED
            submission.failureReason = e.message?.take(400)
            kycRepo.save(submission)
        }
    }

    // ─── NIN Verification ─────────────────────────────────────────

    @Transactional
    fun verifyNin(user: User, nin: String): KycSubmission {
        validateNotAlreadyVerified(user, KycType.NIN)

        val masked = mask(nin)
        val submission = kycRepo.save(
            KycSubmission(user = user, type = KycType.NIN, maskedNumber = masked)
        )

        return try {
            val response = rest.exchange(
                "$baseUrl/api/v1/kyc/nin?nin=$nin",
                HttpMethod.GET,
                HttpEntity<Void>(headers()),
                Map::class.java
            )

            @Suppress("UNCHECKED_CAST")
            val entity = (response.body?.get("entity") as? Map<String, Any?>)
            val firstName  = entity?.get("firstname")  as? String ?: ""
            val lastName   = entity?.get("surname")    as? String ?: ""
            val dob        = entity?.get("birthdate")  as? String

            submission.verifiedName = "$firstName $lastName".trim()
            submission.verifiedDob  = dob
            submission.status = KycVerificationStatus.VERIFIED
            submission.verifiedAt = LocalDateTime.now()

            updateUserKycStatus(user)
            kycRepo.save(submission)
        } catch (e: Exception) {
            submission.status = KycVerificationStatus.FAILED
            submission.failureReason = e.message?.take(400)
            kycRepo.save(submission)
        }
    }

    // ─── Status check ─────────────────────────────────────────────

    fun getKycStatus(user: User): Map<String, Any?> {
        val submissions = kycRepo.findByUser(user)
        val bvn = submissions.firstOrNull { it.type == KycType.BVN }
        val nin = submissions.firstOrNull { it.type == KycType.NIN }
        return mapOf(
            "overallStatus" to user.kycStatus,
            "bvn" to bvn?.let { mapOf(
                "status"       to it.status.name,
                "maskedNumber" to it.maskedNumber,
                "verifiedName" to it.verifiedName,
                "verifiedAt"   to it.verifiedAt?.toString()
            )},
            "nin" to nin?.let { mapOf(
                "status"       to it.status.name,
                "maskedNumber" to it.maskedNumber,
                "verifiedName" to it.verifiedName,
                "verifiedAt"   to it.verifiedAt?.toString()
            )}
        )
    }

    // ─── Private helpers ──────────────────────────────────────────

    /**
     * Once BVN or NIN is verified, mark the user's account KYC as APPROVED.
     * Either one is sufficient for basic KYC.
     */
    private fun updateUserKycStatus(user: User) {
        user.kycStatus = "APPROVED"
        userRepo.save(user)
    }

    private fun validateNotAlreadyVerified(user: User, type: KycType) {
        val existing = kycRepo.findByUserAndType(user, type)
        if (existing?.status == KycVerificationStatus.VERIFIED)
            throw IllegalStateException("${type.name} already verified for this account")
    }

    private fun mask(number: String): String {
        if (number.length <= 4) return number
        return "*".repeat(number.length - 4) + number.takeLast(4)
    }
}
