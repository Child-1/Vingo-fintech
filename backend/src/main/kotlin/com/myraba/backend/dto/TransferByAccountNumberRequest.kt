package com.myraba.backend.dto

import java.math.BigDecimal

data class TransferByAccountNumberRequest(
    val accountNumber: String,
    val amount: BigDecimal
)