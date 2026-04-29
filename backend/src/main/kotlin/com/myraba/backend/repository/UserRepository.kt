package com.myraba.backend.repository

import com.myraba.backend.model.User
import com.myraba.backend.model.UserStatus
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import org.springframework.stereotype.Repository
import java.time.LocalDateTime

@Repository
interface UserRepository : JpaRepository<User, Long> {

    /**
     * Finds a User entity based on the unique myrabaHandle.
     */
    @Query("SELECT u FROM User u WHERE u.myrabaHandle = :myrabaHandle")
    fun findByVingHandle(@Param("myrabaHandle") myrabaHandle: String): User?

    /**
     * Finds users whose account number contains the given string (case-insensitive).
     * We use this + exact match in code to simulate "findByAccountNumber".
     */
    fun findByPhone(phone: String): User?
    fun findByEmail(email: String): User?
    fun findByAccountNumber(accountNumber: String): User?
    fun findByCustomAccountId(customAccountId: String): User?
    fun findByAccountNumberContainingIgnoreCase(accountNumber: String): List<User>
    fun findByFullNameContainingIgnoreCase(name: String): List<User>
    fun findByAccountStatus(status: UserStatus, pageable: Pageable): Page<User>
    fun countByCreatedAtAfter(dateTime: LocalDateTime): Long
    fun countByKycStatus(status: String): Long
    fun countByAccountStatus(status: UserStatus): Long

    @Query("SELECT u FROM User u WHERE LOWER(u.myrabaHandle) LIKE LOWER(CONCAT('%', :q, '%')) OR LOWER(u.fullName) LIKE LOWER(CONCAT('%', :q, '%')) OR LOWER(u.email) LIKE LOWER(CONCAT('%', :q, '%')) OR u.phone LIKE CONCAT('%', :q, '%') OR u.accountNumber LIKE CONCAT('%', :q, '%')")
    fun searchUsers(@Param("q") query: String, pageable: Pageable): Page<User>

    fun countByCreatedAtBetween(from: LocalDateTime, to: LocalDateTime): Long
    fun findByReferralCode(referralCode: String): User?
    fun findByReferredBy(referralCode: String): List<User>
    fun findByStaffId(staffId: String): User?
    fun findByStaffInviteToken(token: String): User?
}