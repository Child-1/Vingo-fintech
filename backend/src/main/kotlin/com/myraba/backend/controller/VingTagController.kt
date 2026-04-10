package com.myraba.backend.controller

import com.myraba.backend.model.TagChangeStatus
import com.myraba.backend.model.User
import com.myraba.backend.model.MyrabaTagChangeRequest
import com.myraba.backend.repository.UserRepository
import com.myraba.backend.repository.MyrabaTagChangeRequestRepository
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException

data class TagChangeRequestBody(
    val requestedTag: String,
    val reason: String? = null
)

@RestController
@RequestMapping("/api/users/me/tag-change")
class MyrabaTagController(
    private val tagChangeRepo: MyrabaTagChangeRequestRepository,
    private val userRepository: UserRepository
) {

    /** Submit a request to change your MyrabaTag (admin must approve) */
    @PostMapping
    fun requestTagChange(
        authentication: Authentication,
        @RequestBody body: TagChangeRequestBody
    ): ResponseEntity<Any> {
        val user = authentication.principal as User

        val requestedTag = body.requestedTag.trim()
        if (requestedTag.isBlank() || requestedTag.length > 30)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Tag must be 1–30 characters")

        if (requestedTag.equals(user.myrabaHandle, ignoreCase = true))
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "That is already your MyrabaTag")

        if (userRepository.findByVingHandle(requestedTag) != null)
            throw ResponseStatusException(HttpStatus.CONFLICT, "MyrabaTag already taken")

        // Only one pending request allowed at a time
        val pending = tagChangeRepo.countByUserIdAndStatus(user.id, TagChangeStatus.PENDING)
        if (pending > 0)
            throw ResponseStatusException(HttpStatus.CONFLICT, "You already have a pending tag change request")

        val saved = tagChangeRepo.save(
            MyrabaTagChangeRequest(
                user = user,
                currentTag = user.myrabaHandle,
                requestedTag = requestedTag,
                reason = body.reason
            )
        )

        return ResponseEntity.status(HttpStatus.CREATED).body(
            mapOf(
                "id"           to saved.id,
                "currentTag"   to saved.currentTag,
                "requestedTag" to saved.requestedTag,
                "status"       to saved.status.name,
                "createdAt"    to saved.createdAt.toString()
            )
        )
    }

    /** View your own tag change request history */
    @GetMapping
    fun myRequests(authentication: Authentication): ResponseEntity<Any> {
        val user = authentication.principal as User
        val requests = tagChangeRepo.findByUserId(user.id).map { r ->
            mapOf(
                "id"           to r.id,
                "currentTag"   to r.currentTag,
                "requestedTag" to r.requestedTag,
                "reason"       to r.reason,
                "status"       to r.status.name,
                "adminNote"    to r.adminNote,
                "createdAt"    to r.createdAt.toString(),
                "resolvedAt"   to r.resolvedAt?.toString()
            )
        }
        return ResponseEntity.ok(requests)
    }
}
