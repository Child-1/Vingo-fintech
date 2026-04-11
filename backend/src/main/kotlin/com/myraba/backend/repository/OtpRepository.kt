package com.myraba.backend.repository

import com.myraba.backend.model.Otp
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import java.time.LocalDateTime

interface OtpRepository : JpaRepository<Otp, Long> {

    fun findTopByPhoneAndPurposeOrderByIdDesc(phone: String, purpose: String): Otp?

    fun findTopByEmailAndPurposeOrderByIdDesc(email: String, purpose: String): Otp?

    /** Fetch all active (unused, unexpired) OTPs for a phone — code comparison done in-memory after decryption */
    @Query("SELECT o FROM Otp o WHERE o.phone = :phone AND o.purpose = :purpose AND o.used = false AND o.expiresAt > :now")
    fun findActiveOtpsByPhone(phone: String, purpose: String, now: LocalDateTime): List<Otp>

    /** Fetch all active OTPs for an email */
    @Query("SELECT o FROM Otp o WHERE o.email = :email AND o.purpose = :purpose AND o.used = false AND o.expiresAt > :now")
    fun findActiveOtpsByEmail(email: String, purpose: String, now: LocalDateTime): List<Otp>
}
