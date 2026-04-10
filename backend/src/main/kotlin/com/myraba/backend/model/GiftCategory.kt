package com.myraba.backend.model

import jakarta.persistence.*
import java.time.LocalDateTime

@Entity
@Table(name = "gift_categories")
data class GiftCategory(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @Column(nullable = false, unique = true, length = 60)
    var name: String,                      // e.g. "Lovers Corner"

    @Column(nullable = false, unique = true, length = 30)
    var slug: String,                      // e.g. "lovers-corner" — used in URLs

    @Column(length = 300)
    var description: String? = null,       // e.g. "Show love the Nigerian way"

    @Column(length = 50)
    var emoji: String? = null,             // e.g. "💘"

    var isActive: Boolean = true,
    val createdAt: LocalDateTime = LocalDateTime.now(),

    @OneToMany(mappedBy = "category", cascade = [CascadeType.ALL], orphanRemoval = true)
    val items: MutableList<GiftItem> = mutableListOf()
)

@Entity
@Table(name = "gift_items")
data class GiftItem(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "category_id", nullable = false)
    val category: GiftCategory,

    @Column(nullable = false, length = 60)
    var name: String,                      // e.g. "Iyawo Mi Rose" (My Wife Rose)

    @Column(length = 300)
    var description: String? = null,

    @Column(length = 50)
    var emoji: String? = null,             // e.g. "🌹"

    @Column(nullable = false, precision = 10, scale = 2)
    var nairaValue: java.math.BigDecimal,  // monetary equivalent

    var isActive: Boolean = true,
    val createdAt: LocalDateTime = LocalDateTime.now()
)
