package com.myraba.backend.dto

data class TransactionHistoryResponse(
    val transactions: List<TransactionResponse>,
    val total: Int,
    val balance: String
)