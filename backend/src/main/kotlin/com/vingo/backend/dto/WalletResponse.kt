package com.vingo.backend.dto

import java.math.BigDecimal

data class WalletResponse(
    val walletId: Long,
    val vingHandle: String,
    val balance: BigDecimal
)