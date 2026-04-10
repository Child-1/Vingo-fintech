package com.myraba.backend.controller.admin

import com.myraba.backend.model.thrift.ThriftCategory
import com.myraba.backend.repository.thrift.ThriftCategoryRepository
import jakarta.validation.Valid
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.web.bind.annotation.*
import java.math.BigDecimal
import java.time.LocalDateTime

@RestController
@RequestMapping("/api/admin/thrifts/categories")
@PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_ADMIN')")
class AdminThriftController(
    private val categoryRepo: ThriftCategoryRepository
) {

    data class CreateCategoryRequest(
        val name: String,
        val description: String?,
        val contributionAmount: BigDecimal,
        val contributionFrequency: String,
        val durationInCycles: Int,
        val targetAmount: BigDecimal? = null
    )

    data class CategoryResponse(
        val id: Long,
        val name: String,
        val contributionAmount: BigDecimal,
        val contributionFrequency: String,
        val durationInCycles: Int,
        val memberCount: Int,
        val createdAt: LocalDateTime
    )

    @PostMapping
    fun createPublicCategory(@Valid @RequestBody req: CreateCategoryRequest): ResponseEntity<Any> {
        val category = ThriftCategory(
            name = req.name,
            description = req.description,
            contributionAmount = req.contributionAmount,
            contributionFrequency = req.contributionFrequency.uppercase(),
            durationInCycles = req.durationInCycles,
            targetAmount = req.targetAmount,
            isPublic = true,
            createdByAdmin = true,
            createdAt = LocalDateTime.now()
        )

        val saved = categoryRepo.save(category)

        return ResponseEntity.ok(
            CategoryResponse(
                id = saved.id!!,
                name = saved.name,
                contributionAmount = saved.contributionAmount,
                contributionFrequency = saved.contributionFrequency,
                durationInCycles = saved.durationInCycles,
                memberCount = 0,
                createdAt = saved.createdAt
            )
        )
    }

    @GetMapping
    fun getAllPublicCategories(): ResponseEntity<List<CategoryResponse>> {
        val categories = categoryRepo.findByIsPublicAndIsActive(true, true)
        val response = categories.map {
            CategoryResponse(
                id = it.id!!,
                name = it.name,
                contributionAmount = it.contributionAmount,
                contributionFrequency = it.contributionFrequency,
                durationInCycles = it.durationInCycles,
                memberCount = it.members.size,
                createdAt = it.createdAt
            )
        }
        return ResponseEntity.ok(response)
    }
}