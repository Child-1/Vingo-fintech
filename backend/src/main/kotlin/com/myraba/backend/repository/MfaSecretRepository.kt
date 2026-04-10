package com.myraba.backend.repository

import com.myraba.backend.model.MfaSecret
import org.springframework.data.jpa.repository.JpaRepository

interface MfaSecretRepository : JpaRepository<MfaSecret, Long> {
    fun findByUserId(userId: Long): MfaSecret?
}
