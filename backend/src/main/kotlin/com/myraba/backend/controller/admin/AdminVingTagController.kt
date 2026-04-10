package com.myraba.backend.controller.admin

import com.myraba.backend.model.TagChangeStatus
import com.myraba.backend.repository.UserRepository
import com.myraba.backend.repository.MyrabaTagChangeRequestRepository
import org.springframework.data.domain.PageRequest
import org.springframework.data.domain.Sort
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import java.time.LocalDateTime

data class TagDecisionBody(
    val approved: Boolean,
    val adminNote: String? = null
)

@RestController
@RequestMapping("/api/admin/tag-requests")
@PreAuthorize("hasAnyRole('STAFF','ADMIN','SUPER_ADMIN')")
class AdminMyrabaTagController(
    private val tagChangeRepo: MyrabaTagChangeRequestRepository,
    private val userRepository: UserRepository
) {

    @GetMapping("/pending")
    fun listPending(
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int
    ): ResponseEntity<Any> {
        val pageable = PageRequest.of(page, size, Sort.by("createdAt").descending())
        val result = tagChangeRepo.findByStatus(TagChangeStatus.PENDING, pageable)
        return ResponseEntity.ok(
            mapOf(
                "content" to result.content.map { r ->
                    mapOf(
                        "id"           to r.id,
                        "userId"       to r.user.id,
                        "currentTag"   to r.currentTag,
                        "requestedTag" to r.requestedTag,
                        "reason"       to r.reason,
                        "createdAt"    to r.createdAt.toString()
                    )
                },
                "totalElements" to result.totalElements,
                "totalPages"    to result.totalPages
            )
        )
    }

    @PutMapping("/{id}/decision")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    @Transactional
    fun decide(
        @PathVariable id: Long,
        @RequestBody body: TagDecisionBody
    ): ResponseEntity<Any> {
        val request = tagChangeRepo.findById(id).orElse(null)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Request not found")

        if (request.status != TagChangeStatus.PENDING)
            throw ResponseStatusException(HttpStatus.CONFLICT, "Request already resolved")

        if (body.approved) {
            if (userRepository.findByVingHandle(request.requestedTag) != null)
                throw ResponseStatusException(HttpStatus.CONFLICT, "MyrabaTag was taken since request was submitted")

            val user = userRepository.findById(request.user.id).orElseThrow()
            user.myrabaHandle = request.requestedTag
            userRepository.save(user)

            request.status = TagChangeStatus.APPROVED
            request.adminNote = body.adminNote
            request.resolvedAt = LocalDateTime.now()
            tagChangeRepo.save(request)

            return ResponseEntity.ok(
                mapOf(
                    "id"         to request.id,
                    "status"     to "APPROVED",
                    "newMyrabaTag" to "m₦${request.requestedTag}",
                    "message"    to "MyrabaTag updated successfully"
                )
            )
        }

        request.status = TagChangeStatus.DENIED
        request.adminNote = body.adminNote
        request.resolvedAt = LocalDateTime.now()
        tagChangeRepo.save(request)

        return ResponseEntity.ok(
            mapOf(
                "id"     to request.id,
                "status" to "DENIED",
                "message" to "Request denied"
            )
        )
    }
}
