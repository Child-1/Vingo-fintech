package com.myraba.backend.model

import jakarta.persistence.*
import java.time.LocalDateTime

enum class KycType { BVN, NIN }
enum class KycVerificationStatus { PENDING, VERIFIED, FAILED, MANUAL_REVIEW }

@Entity
@Table(name = "kyc_submissions")
data class KycSubmission(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    val user: User,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val type: KycType,

    /** Masked — only last 4 digits stored e.g. "****5678" */
    @Column(nullable = false, length = 20)
    val maskedNumber: String,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    var status: KycVerificationStatus = KycVerificationStatus.PENDING,

    /** Name returned by Dojah — used to cross-check against user's fullName */
    @Column(length = 100)
    var verifiedName: String? = null,

    /** Date of birth returned by Dojah */
    @Column(length = 20)
    var verifiedDob: String? = null,

    @Column(length = 500)
    var failureReason: String? = null,

    val submittedAt: LocalDateTime = LocalDateTime.now(),
    var verifiedAt: LocalDateTime? = null
)
