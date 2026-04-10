package com.myraba.backend.dto

import java.math.BigDecimal

data class TransferRequest(
    val amount: BigDecimal,
    val receiverVingHandle: String
)