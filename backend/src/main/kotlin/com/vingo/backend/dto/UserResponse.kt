package com.vingo.backend.dto

data class UserResponse(
    val id: Long,
    val vingHandle: String,
    val fullName: String,
    val phone: String,
    val email: String?,
    val createdAt: String
)