package com.vingo.backend.repository

import com.vingo.backend.model.User
import org.springframework.data.jpa.repository.JpaRepository

interface UserRepository : JpaRepository<User, Long> {
    fun findByVingHandle(vingHandle: String): User?
}