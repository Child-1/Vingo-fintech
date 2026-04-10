package com.myraba.backend.repository

import com.myraba.backend.model.GiftBalance
import com.myraba.backend.model.GiftCategory
import com.myraba.backend.model.GiftItem
import com.myraba.backend.model.GiftTransaction
import com.myraba.backend.model.User
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

@Repository
interface GiftCategoryRepository : JpaRepository<GiftCategory, Long> {
    fun findByIsActiveTrue(): List<GiftCategory>
    fun findBySlug(slug: String): GiftCategory?
}

@Repository
interface GiftItemRepository : JpaRepository<GiftItem, Long> {
    fun findByCategoryAndIsActiveTrue(category: GiftCategory): List<GiftItem>
    fun findByCategoryIdAndIsActiveTrue(categoryId: Long): List<GiftItem>
}

@Repository
interface GiftTransactionRepository : JpaRepository<GiftTransaction, Long> {
    fun findByRecipientOrderByCreatedAtDesc(recipient: User): List<GiftTransaction>
    fun findBySenderUserOrderByCreatedAtDesc(sender: User): List<GiftTransaction>
    fun countByRecipient(recipient: User): Long
}

@Repository
interface GiftBalanceRepository : JpaRepository<GiftBalance, Long> {
    fun findByUser(user: User): GiftBalance?
}
