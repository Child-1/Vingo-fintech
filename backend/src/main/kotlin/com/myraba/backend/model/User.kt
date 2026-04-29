package com.myraba.backend.model

import com.fasterxml.jackson.annotation.JsonIgnore
import com.fasterxml.jackson.annotation.JsonInclude
import jakarta.persistence.*
import org.springframework.security.core.GrantedAuthority
import org.springframework.security.core.authority.SimpleGrantedAuthority
import org.springframework.security.core.userdetails.UserDetails
import java.time.LocalDateTime

enum class UserRole {
    USER, STAFF, ADMIN, SUPER_ADMIN
}

enum class UserStatus {
    ACTIVE, SUSPENDED, FROZEN
}

@Entity
@Table(name = "users")
@JsonInclude(JsonInclude.Include.NON_NULL)
data class User(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    var role: UserRole = UserRole.USER,

    @Column(unique = true, nullable = false, length = 30)
    var myrabaHandle: String,

    @Column(nullable = false)
    val passwordHash: String,

    @Column(nullable = false)
    var fullName: String,

    @Column(unique = true, nullable = true)
    var phone: String? = null,

    @Column(unique = true, nullable = true)
    var email: String? = null,

    // Null for STAFF/ADMIN — they don't have financial accounts
    @Column(name = "account_number", unique = true, nullable = true, length = 10)
    val accountNumber: String? = null,

    // Optional "5678-smith" style identifier — in-app transfers only (users only)
    @Column(name = "custom_account_id", unique = true, nullable = true, length = 20)
    var customAccountId: String? = null,

    @Column(nullable = true, length = 255)
    var address: String? = null,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    var accountStatus: UserStatus = UserStatus.ACTIVE,

    var kycStatus: String = "NONE", // NONE, PENDING, APPROVED, REJECTED

    @Column(nullable = false)
    var forcePasswordChange: Boolean = false,

    val createdAt: LocalDateTime = LocalDateTime.now(),

    @Column(unique = true, nullable = true, length = 12)
    val referralCode: String? = null,

    @Column(nullable = true, length = 12)
    val referredBy: String? = null,

    @Column(nullable = true, length = 10)
    var gender: String? = null,

    @Column(nullable = true, length = 512)
    var profilePicture: String? = null,

    // ── Staff-only fields ──────────────────────────────────────────

    // e.g. "STF-2025-001" or "ADM-2025-001" — used to log into the admin portal
    @Column(name = "staff_id", unique = true, nullable = true, length = 20)
    var staffId: String? = null,

    // UUID sent in the invitation email link; cleared after registration is completed
    @Column(name = "staff_invite_token", unique = true, nullable = true, length = 64)
    var staffInviteToken: String? = null,

    @Column(name = "staff_invite_token_expiry", nullable = true)
    var staffInviteTokenExpiry: LocalDateTime? = null,

    // True once the staff member sets their password via the invite link
    @Column(name = "staff_activated", nullable = false, columnDefinition = "boolean not null default false")
    var staffActivated: Boolean = false,

    // HR data collected at registration — not used for login
    @Column(name = "date_of_birth", nullable = true, length = 20)
    var dateOfBirth: String? = null,

    @Column(name = "personal_phone", nullable = true, length = 20)
    var personalPhone: String? = null,

    @OneToOne(mappedBy = "user", cascade = [CascadeType.ALL], fetch = FetchType.LAZY)
    @JsonIgnore
    var wallet: Wallet? = null
) : UserDetails {

    override fun getAuthorities(): MutableCollection<out GrantedAuthority> =
        mutableListOf(SimpleGrantedAuthority("ROLE_${role.name}"))

    override fun getPassword(): String = passwordHash
    override fun getUsername(): String = myrabaHandle
    override fun isAccountNonExpired(): Boolean = true
    override fun isAccountNonLocked(): Boolean = true
    override fun isCredentialsNonExpired(): Boolean = true
    override fun isEnabled(): Boolean = true
}