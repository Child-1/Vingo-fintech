package com.myraba.backend.dto

import java.math.BigDecimal

data class WalletResponse(
    val walletId: Long,
    val myrabaHandle: String,
    val balance: BigDecimal
)