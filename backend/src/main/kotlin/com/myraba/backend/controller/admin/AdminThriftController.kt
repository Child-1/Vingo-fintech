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
        val amount: BigDecimal,
        val frequency: String,
        val duration: Int,
        val memberCount: Int? = null,
        val targetAmount: BigDecimal? = null
    )

    data class CategoryResponse(
        val id: Long,
        val name: String,
        val description: String?,
        val amount: BigDecimal,
        val frequency: String,
        val duration: Int,
        val memberCount: Int,
        val isActive: Boolean,
        val createdAt: LocalDateTime
    )

    private fun ThriftCategory.toResponse() = CategoryResponse(
        id           = this.id!!,
        name         = this.name,
        description  = this.description,
        amount       = this.contributionAmount,
        frequency    = this.contributionFrequency,
        duration     = this.durationInCycles,
        memberCount  = this.members.size,
        isActive     = this.isActive,
        createdAt    = this.createdAt
    )

    @PostMapping
    fun createPublicCategory(@Valid @RequestBody req: CreateCategoryRequest): ResponseEntity<CategoryResponse> {
        val category = ThriftCategory(
            name                  = req.name,
            description           = req.description,
            contributionAmount    = req.amount,
            contributionFrequency = req.frequency.uppercase(),
            durationInCycles      = req.duration,
            placeholderCount      = req.memberCount ?: req.duration,
            targetAmount          = req.targetAmount ?: req.amount.multiply(BigDecimal(req.duration)),
            isPublic              = true,
            createdByAdmin        = true,
            createdAt             = LocalDateTime.now()
        )
        return ResponseEntity.ok(categoryRepo.save(category).toResponse())
    }

    @GetMapping
    fun getAllPublicCategories(): ResponseEntity<List<CategoryResponse>> {
        val categories = categoryRepo.findByIsPublicOrderByCreatedAtDesc(true)
        return ResponseEntity.ok(categories.map { it.toResponse() })
    }
}
