package com.myraba.backend.dto

import java.math.BigDecimal

data class TransferResponse(
    val transactionId: Long?,  // ← MAKE NULLABLE
    val from: String,
    val to: String,
    val amount: BigDecimal,
    val status: String
)