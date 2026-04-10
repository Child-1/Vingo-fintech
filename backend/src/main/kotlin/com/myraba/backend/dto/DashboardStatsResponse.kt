package com.myraba.backend.dto

data class DashboardStatsResponse(
    // User Metrics
    val totalUsers: Long,
    val newUsersToday: Long,
    val kycPending: Long,
    
    // Financial Metrics
    val totalVolume: Double,
    val systemLiquidity: Double,
    val totalServiceFees: Double,
    
    // Thrift/Pool Metrics
    val activeThrifts: Long,
    val totalLockedInThrifts: Double,
    
    // Operational Health
    val pendingPayouts: Long,
    val failedTransactions24h: Long
)