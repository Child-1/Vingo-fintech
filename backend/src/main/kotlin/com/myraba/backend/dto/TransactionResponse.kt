package com.myraba.backend.dto

import java.math.BigDecimal
import java.time.LocalDateTime

data class TransactionResponse(
    val id: Long,
    val type: String,           // "SENT", "RECEIVED", "FUNDED"
    val amount: BigDecimal,
    val description: String,
    val counterparty: String?,  // myrabaHandle of the other person (null for fund)
    val date: LocalDateTime,
    val status: String = "SUCCESS"
)