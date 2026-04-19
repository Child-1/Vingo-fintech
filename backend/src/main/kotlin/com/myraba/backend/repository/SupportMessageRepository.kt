package com.myraba.backend.repository

import com.myraba.backend.model.SupportMessage
import com.myraba.backend.model.SupportSender
import com.myraba.backend.model.User
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Modifying
import org.springframework.data.jpa.repository.Query
import org.springframework.transaction.annotation.Transactional

interface SupportMessageRepository : JpaRepository<SupportMessage, Long> {
    fun findByUserOrderByCreatedAtAsc(user: User): List<SupportMessage>
    fun findAllByOrderByCreatedAtDesc(): List<SupportMessage>
    fun countByUserAndSenderAndIsReadFalse(user: User, sender: SupportSender): Long

    @Modifying
    @Transactional
    @Query("UPDATE SupportMessage m SET m.isRead = true WHERE m.user = :user AND m.sender = :sender")
    fun markAllReadByUserAndSender(user: User, sender: SupportSender)

    fun findDistinctUserByOrderByCreatedAtDesc(): List<User>
}
