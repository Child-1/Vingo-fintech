package com.myraba.backend.dto

import com.myraba.backend.model.User
import java.time.format.DateTimeFormatter

data class UserResponse(
    val id: Long,
    val myrabaHandle: String,
    val myrabaTag: String,               // "m₦Davinci96" — formatted for display/sharing
    val fullName: String,
    val phone: String?,
    val email: String?,
    val accountNumber: String,
    val customAccountId: String?,       // "5678-smith" style — in-app transfers only
    val role: String,
    val kycStatus: String,
    val accountStatus: String,
    val balance: String,
    val createdAt: String
)

fun User.toResponse(balance: String): UserResponse {
    val formatter = DateTimeFormatter.ISO_LOCAL_DATE_TIME
    return UserResponse(
        id = this.id,
        myrabaHandle = this.myrabaHandle,
        myrabaTag = "m₦${this.myrabaHandle}",
        fullName = this.fullName,
        phone = this.phone,
        email = this.email,
        accountNumber = this.accountNumber,
        customAccountId = this.customAccountId,
        role = this.role.name,
        kycStatus = this.kycStatus,
        accountStatus = this.accountStatus.name,
        balance = balance,
        createdAt = this.createdAt.format(formatter)
    )
}
