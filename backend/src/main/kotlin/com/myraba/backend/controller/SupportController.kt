package com.myraba.backend.controller

import com.myraba.backend.model.SupportMessage
import com.myraba.backend.model.SupportSender
import com.myraba.backend.model.User
import com.myraba.backend.repository.SupportMessageRepository
import com.myraba.backend.repository.UserRepository
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException

data class SendMessageRequest(val content: String)

@RestController
@RequestMapping("/api/support")
class SupportController(private val supportRepo: SupportMessageRepository) {

    @GetMapping("/messages")
    fun getMessages(auth: Authentication): ResponseEntity<Any> {
        val user = auth.principal as User
        supportRepo.markAllReadByUserAndSender(user, SupportSender.AGENT)
        val messages = supportRepo.findByUserOrderByCreatedAtAsc(user)
        return ResponseEntity.ok(mapOf("messages" to messages.map { it.toDto() }))
    }

    @PostMapping("/messages")
    fun sendMessage(@RequestBody req: SendMessageRequest, auth: Authentication): ResponseEntity<Any> {
        val user = auth.principal as User
        if (req.content.isBlank())
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Message cannot be empty")
        val msg = supportRepo.save(SupportMessage(
            user = user,
            sender = SupportSender.USER,
            content = req.content.trim(),
        ))
        return ResponseEntity.status(HttpStatus.CREATED).body(msg.toDto())
    }

    @GetMapping("/unread-count")
    fun unreadCount(auth: Authentication): ResponseEntity<Any> {
        val user = auth.principal as User
        val count = supportRepo.countByUserAndSenderAndIsReadFalse(user, SupportSender.AGENT)
        return ResponseEntity.ok(mapOf("unread" to count))
    }
}

// ── Admin support endpoints ───────────────────────────────────────────────────
@RestController
@RequestMapping("/api/admin/support")
class AdminSupportController(
    private val supportRepo: SupportMessageRepository,
    private val userRepo: UserRepository,
) {
    @GetMapping("/conversations")
    fun listConversations(): ResponseEntity<Any> {
        val users = supportRepo.findDistinctUsers()
        val conversations = users.map { user ->
            val messages = supportRepo.findByUserOrderByCreatedAtAsc(user)
            val unread = messages.count { it.sender == SupportSender.USER && !it.isRead }
            val last = messages.lastOrNull()
            mapOf(
                "userId"       to user.id,
                "handle"       to user.myrabaHandle,
                "fullName"     to user.fullName,
                "lastMessage"  to last?.content,
                "lastAt"       to last?.createdAt,
                "unreadCount"  to unread,
            )
        }
        return ResponseEntity.ok(mapOf("conversations" to conversations))
    }

    @GetMapping("/conversations/{userId}")
    fun getConversation(@PathVariable userId: Long): ResponseEntity<Any> {
        val user = userRepo.findById(userId).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "User not found")
        }
        supportRepo.markAllReadByUserAndSender(user, SupportSender.USER)
        val messages = supportRepo.findByUserOrderByCreatedAtAsc(user)
        return ResponseEntity.ok(mapOf(
            "user"     to mapOf("id" to user.id, "handle" to user.myrabaHandle, "fullName" to user.fullName),
            "messages" to messages.map { it.toDto() },
        ))
    }

    @PostMapping("/conversations/{userId}/reply")
    fun reply(
        @PathVariable userId: Long,
        @RequestBody req: SendMessageRequest,
    ): ResponseEntity<Any> {
        val user = userRepo.findById(userId).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "User not found")
        }
        if (req.content.isBlank())
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Message cannot be empty")
        val msg = supportRepo.save(SupportMessage(
            user = user,
            sender = SupportSender.AGENT,
            content = req.content.trim(),
        ))
        return ResponseEntity.status(HttpStatus.CREATED).body(msg.toDto())
    }
}

private fun SupportMessage.toDto() = mapOf(
    "id"        to id,
    "sender"    to sender.name,
    "content"   to content,
    "isRead"    to isRead,
    "createdAt" to createdAt,
)
