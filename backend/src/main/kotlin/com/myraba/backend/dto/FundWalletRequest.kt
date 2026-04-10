package com.myraba.backend.dto

data class FundWalletRequest(
    val myrabaHandle: String,
    val amount: java.math.BigDecimal
)