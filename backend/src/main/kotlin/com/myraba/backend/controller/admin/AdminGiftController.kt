package com.myraba.backend.controller.admin

import com.myraba.backend.model.GiftCategory
import com.myraba.backend.model.GiftItem
import com.myraba.backend.repository.GiftCategoryRepository
import com.myraba.backend.repository.GiftItemRepository
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import java.math.BigDecimal

data class CreateCategoryBody(
    val name: String,
    val slug: String,
    val description: String? = null,
    val emoji: String? = null
)

data class CreateGiftItemBody(
    val name: String,
    val description: String? = null,
    val emoji: String? = null,
    val nairaValue: BigDecimal
)

@RestController
@RequestMapping("/api/admin/gifts")
@PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
class AdminGiftController(
    private val categoryRepo: GiftCategoryRepository,
    private val itemRepo: GiftItemRepository
) {

    // ─── Categories ───────────────────────────────────────────────

    @GetMapping("/categories")
    fun listCategories(): ResponseEntity<Any> {
        val cats = categoryRepo.findAll().map { c ->
            mapOf("id" to c.id, "name" to c.name, "slug" to c.slug,
                  "emoji" to c.emoji, "isActive" to c.isActive,
                  "itemCount" to c.items.size)
        }
        return ResponseEntity.ok(mapOf("categories" to cats))
    }

    @PostMapping("/categories")
    fun createCategory(@RequestBody body: CreateCategoryBody): ResponseEntity<Any> {
        if (categoryRepo.findBySlug(body.slug) != null)
            throw ResponseStatusException(HttpStatus.CONFLICT, "Slug '${body.slug}' already in use")
        val saved = categoryRepo.save(
            GiftCategory(name = body.name, slug = body.slug,
                         description = body.description, emoji = body.emoji)
        )
        return ResponseEntity.status(HttpStatus.CREATED).body(
            mapOf("id" to saved.id, "name" to saved.name, "slug" to saved.slug)
        )
    }

    @PutMapping("/categories/{id}/toggle")
    fun toggleCategory(@PathVariable id: Long): ResponseEntity<Any> {
        val cat = categoryRepo.findById(id).orElse(null)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Category not found")
        cat.isActive = !cat.isActive
        categoryRepo.save(cat)
        return ResponseEntity.ok(mapOf("id" to cat.id, "isActive" to cat.isActive))
    }

    // ─── Gift items ───────────────────────────────────────────────

    @GetMapping("/items")
    fun listAllItems(): ResponseEntity<Any> {
        val items = itemRepo.findAll().map { i ->
            mapOf("id" to i.id, "name" to i.name, "emoji" to i.emoji,
                  "nairaValue" to i.nairaValue.toPlainString(), "isActive" to i.isActive,
                  "categoryName" to i.category.name, "categoryId" to i.category.id)
        }
        return ResponseEntity.ok(mapOf("items" to items))
    }

    @GetMapping("/categories/{categoryId}/items")
    fun listItems(@PathVariable categoryId: Long): ResponseEntity<Any> {
        val items = itemRepo.findByCategoryIdAndIsActiveTrue(categoryId).map { i ->
            mapOf("id" to i.id, "name" to i.name, "emoji" to i.emoji,
                  "nairaValue" to i.nairaValue.toPlainString(), "isActive" to i.isActive)
        }
        return ResponseEntity.ok(mapOf("items" to items))
    }

    @PostMapping("/categories/{categoryId}/items")
    fun createItem(
        @PathVariable categoryId: Long,
        @RequestBody body: CreateGiftItemBody
    ): ResponseEntity<Any> {
        val cat = categoryRepo.findById(categoryId).orElse(null)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Category not found")
        val saved = itemRepo.save(
            GiftItem(category = cat, name = body.name, description = body.description,
                     emoji = body.emoji, nairaValue = body.nairaValue)
        )
        return ResponseEntity.status(HttpStatus.CREATED).body(
            mapOf("id" to saved.id, "name" to saved.name, "nairaValue" to saved.nairaValue.toPlainString())
        )
    }

    @PutMapping("/items/{id}/toggle")
    fun toggleItem(@PathVariable id: Long): ResponseEntity<Any> {
        val item = itemRepo.findById(id).orElse(null)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Item not found")
        item.isActive = !item.isActive
        itemRepo.save(item)
        return ResponseEntity.ok(mapOf("id" to item.id, "isActive" to item.isActive))
    }

    @PutMapping("/items/{id}/price")
    fun updatePrice(@PathVariable id: Long, @RequestBody body: Map<String, BigDecimal>): ResponseEntity<Any> {
        val item = itemRepo.findById(id).orElse(null)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Item not found")
        val newPrice = body["nairaValue"] ?: throw ResponseStatusException(HttpStatus.BAD_REQUEST, "nairaValue required")
        item.nairaValue = newPrice
        itemRepo.save(item)
        return ResponseEntity.ok(mapOf("id" to item.id, "nairaValue" to item.nairaValue.toPlainString()))
    }
}
