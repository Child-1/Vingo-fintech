package com.vingo.backend.model

import com.vingo.backend.dto.UserResponse
import jakarta.persistence.*
import java.time.LocalDateTime
import com.fasterxml.jackson.annotation.JsonInclude

@Entity
@Table(name = "users")
@JsonInclude(JsonInclude.Include.NON_NULL)
data class User(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0,

    @Column(unique = true, nullable = false)
    val vingHandle: String,

    @Column(nullable = false)
    val fullName: String,

    @Column(nullable = false, unique = true)
    val phone: String,

    val email: String? = null,

    val createdAt: LocalDateTime = LocalDateTime.now()
) {
    fun toResponse(): UserResponse {
        return UserResponse(
            id = id,
            vingHandle = vingHandle,
            fullName = fullName,
            phone = phone,
            email = email,
            createdAt = createdAt.toString()
        )
    }
}