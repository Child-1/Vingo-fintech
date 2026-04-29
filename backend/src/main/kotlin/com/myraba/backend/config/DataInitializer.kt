package com.myraba.backend.config

import com.myraba.backend.model.*
import com.myraba.backend.model.thrift.ThriftCategory
import com.myraba.backend.repository.*
import com.myraba.backend.repository.thrift.ThriftCategoryRepository
import org.springframework.boot.CommandLineRunner
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Component
import java.math.BigDecimal
import java.time.LocalDateTime

@Component
class DataInitializer(
    private val userRepository: UserRepository,
    private val walletRepository: WalletRepository,
    private val passwordEncoder: PasswordEncoder,
    private val giftCategoryRepository: GiftCategoryRepository,
    private val giftItemRepository: GiftItemRepository,
    private val thriftCategoryRepository: ThriftCategoryRepository
) : CommandLineRunner {

    override fun run(vararg args: String?) {
        seedAdmin()
        seedGiftCategories()
        seedThriftCategories()
    }

    private fun generateStaffId(role: UserRole): String {
        val year = LocalDateTime.now().year
        val prefix = if (role == UserRole.ADMIN || role == UserRole.SUPER_ADMIN) "ADM" else "STF"
        val staffRoles = listOf(UserRole.STAFF, UserRole.ADMIN, UserRole.SUPER_ADMIN)
        val count = userRepository.findAll().count { it.role in staffRoles } + 1
        var candidate = "$prefix-$year-${count.toString().padStart(3, '0')}"
        var suffix = count
        while (userRepository.findByStaffId(candidate) != null) {
            suffix++
            candidate = "$prefix-$year-${suffix.toString().padStart(3, '0')}"
        }
        return candidate
    }

    private fun seedAdmin() {
        // Migrate ALL existing admin/staff accounts that don't have a staffId yet
        val unmigratedAdmins = userRepository.findAdminUsersWithoutStaffId()
        if (unmigratedAdmins.isNotEmpty()) {
            for (user in unmigratedAdmins) {
                // Preserve the known super admin ID, generate for others
                val newId = if (user.myrabaHandle == "MyrabaAdmin") "ADM-SUPER-001"
                            else generateStaffId(user.role)
                user.staffId = newId
                user.staffActivated = true
                userRepository.save(user)
                println("=== Migrated admin account '${user.myrabaHandle}' → Staff ID: $newId ===")
            }
        }

        // Seed the initial super admin if no admin account exists at all
        if (userRepository.findByVingHandle("MyrabaAdmin") != null) return

        val adminPassword = System.getenv("ADMIN_INITIAL_PASSWORD")?.takeIf { it.length >= 8 }
            ?: "MyrabaAdmin2025!"
        val superAdmin = User(
            myrabaHandle = "MyrabaAdmin",
            passwordHash = passwordEncoder.encode(adminPassword),
            fullName = "System Super Admin",
            phone = "08000000000",
            email = "admin@myraba.ng",
            accountNumber = "8000000000",
            kycStatus = "APPROVED",
            role = UserRole.SUPER_ADMIN,
            staffId = "ADM-SUPER-001",
            staffActivated = true
        )
        val saved = userRepository.save(superAdmin)
        walletRepository.save(Wallet(user = saved))
        println("=== Super Admin seeded ===")
        println("  Staff ID: ADM-SUPER-001  |  Email: admin@myraba.ng")
        if (System.getenv("ADMIN_INITIAL_PASSWORD") == null) {
            println("  Password: $adminPassword  [WARNING: set ADMIN_INITIAL_PASSWORD env var in production!]")
        } else {
            println("  Password: [set via ADMIN_INITIAL_PASSWORD env var]")
        }
    }

    private fun seedGiftCategories() {
        if (giftCategoryRepository.count() > 0L) return

        data class CategorySeed(
            val name: String, val slug: String, val description: String, val emoji: String,
            val items: List<Triple<String, String, BigDecimal>>
        )

        val categories = listOf(
            CategorySeed(
                name = "Lovers Corner", slug = "lovers-corner",
                description = "Show love the Nigerian way 💘",
                emoji = "💘",
                items = listOf(
                    Triple("Iyawo Mi Rose",         "🌹", BigDecimal("500")),
                    Triple("Okonkwo's Bouquet",     "💐", BigDecimal("1500")),
                    Triple("Valentine Treat",       "🍫", BigDecimal("2000")),
                    Triple("Diamond Shine",         "💎", BigDecimal("5000")),
                    Triple("Forever Yours",         "❤️‍🔥", BigDecimal("10000")),
                    Triple("Wedding Bells",         "💍", BigDecimal("20000"))
                )
            ),
            CategorySeed(
                name = "Good Samaritan", slug = "good-samaritan",
                description = "Support others, spread goodness 🤝",
                emoji = "🤝",
                items = listOf(
                    Triple("Omo To Daju Support",   "🙏", BigDecimal("500")),
                    Triple("Agba Owo",              "💰", BigDecimal("1000")),
                    Triple("Ekiti Community Boost", "🪲", BigDecimal("2500")),
                    Triple("Eze Ndi Oma",           "👑", BigDecimal("5000")),
                    Triple("Alhaji's Blessing",     "🌟", BigDecimal("10000"))
                )
            ),
            CategorySeed(
                name = "Business Appreciation", slug = "business-appreciation",
                description = "Celebrate your vendors, partners & colleagues 💼",
                emoji = "💼",
                items = listOf(
                    Triple("Small Chops Thank You", "🥂", BigDecimal("1000")),
                    Triple("Owo Naira Salute",      "💵", BigDecimal("3000")),
                    Triple("Ogas on Top",           "🏆", BigDecimal("5000")),
                    Triple("Corporate Hammer",      "🔨", BigDecimal("10000")),
                    Triple("Board Level Respect",   "🎩", BigDecimal("25000"))
                )
            ),
            CategorySeed(
                name = "Birthday Bash", slug = "birthday-bash",
                description = "Make their birthday unforgettable 🎂",
                emoji = "🎂",
                items = listOf(
                    Triple("Asiko Cake Vibes",      "🎂", BigDecimal("1000")),
                    Triple("Shakara Balloon",       "🎈", BigDecimal("500")),
                    Triple("Owambe Package",        "🎉", BigDecimal("5000")),
                    Triple("Detty December Starter","🥳", BigDecimal("10000")),
                    Triple("Big Boy/Girl Energy",   "💫", BigDecimal("20000"))
                )
            ),
            CategorySeed(
                name = "Prayers & Blessings", slug = "prayers-blessings",
                description = "Send a spiritual gift with love 🙏",
                emoji = "🙏",
                items = listOf(
                    Triple("Amen Blessing",         "🕊️", BigDecimal("200")),
                    Triple("Iseun Oluwami",         "✨", BigDecimal("500")),
                    Triple("Inshallah Baraka",      "🌙", BigDecimal("1000")),
                    Triple("God Bless You Plenty",  "🌈", BigDecimal("2000"))
                )
            )
        )

        for (catSeed in categories) {
            val cat = giftCategoryRepository.save(
                GiftCategory(
                    name = catSeed.name,
                    slug = catSeed.slug,
                    description = catSeed.description,
                    emoji = catSeed.emoji
                )
            )
            for ((itemName, emoji, value) in catSeed.items) {
                giftItemRepository.save(
                    GiftItem(category = cat, name = itemName, emoji = emoji, nairaValue = value)
                )
            }
        }

        println("=== Gift categories seeded (${categories.size} categories) ===")
    }

    private fun seedThriftCategories() {
        if (thriftCategoryRepository.count() > 0L) return

        data class Seed(
            val name: String,
            val description: String,
            val amount: BigDecimal,
            val frequency: String,
            val cycles: Int
        )

        val plans = listOf(
            Seed("Daily Starter",    "Save ₦100 every day — small steps, big results",         BigDecimal("100"),    "DAILY",   10),
            Seed("Daily Bronze",     "₦500/day — build a serious habit in 15 days",            BigDecimal("500"),    "DAILY",   15),
            Seed("Daily Silver",     "₦1,000/day — steady growth over 20 days",               BigDecimal("1000"),   "DAILY",   20),
            Seed("Daily Gold",       "₦5,000/day — serious savers, serious returns",           BigDecimal("5000"),   "DAILY",   15),
            Seed("Daily Platinum",   "₦10,000/day — top-tier daily discipline",               BigDecimal("10000"),  "DAILY",   10),

            Seed("Weekly Starter",   "₦100/week — the easiest way to start saving",           BigDecimal("100"),    "WEEKLY",  10),
            Seed("Weekly Bronze",    "₦500/week — build momentum over 12 weeks",              BigDecimal("500"),    "WEEKLY",  12),
            Seed("Weekly Silver",    "₦1,000/week — a solid weekly savings plan",             BigDecimal("1000"),   "WEEKLY",  15),
            Seed("Weekly Gold",      "₦5,000/week — grow your money week by week",            BigDecimal("5000"),   "WEEKLY",  12),
            Seed("Weekly Platinum",  "₦10,000/week — high-value weekly contributions",        BigDecimal("10000"),  "WEEKLY",  10),

            Seed("Monthly Bronze",   "₦500/month — low-commitment monthly savings",           BigDecimal("500"),    "MONTHLY", 12),
            Seed("Monthly Silver",   "₦1,000/month — consistent monthly contributions",       BigDecimal("1000"),   "MONTHLY", 12),
            Seed("Monthly Gold",     "₦5,000/month — build a substantial monthly pool",       BigDecimal("5000"),   "MONTHLY", 10),
            Seed("Monthly Platinum", "₦10,000/month — premium monthly thrift rotation",       BigDecimal("10000"),  "MONTHLY", 10)
        )

        for (p in plans) {
            thriftCategoryRepository.save(
                ThriftCategory(
                    name                  = p.name,
                    description           = p.description,
                    contributionAmount    = p.amount,
                    contributionFrequency = p.frequency,
                    durationInCycles      = p.cycles,
                    placeholderCount      = p.cycles,
                    targetAmount          = p.amount.multiply(BigDecimal(p.cycles)),
                    isPublic              = true,
                    isActive              = true,
                    createdByAdmin        = true
                )
            )
        }
        println("=== Thrift categories seeded (${plans.size} plans: 5 daily, 5 weekly, 4 monthly) ===")
    }
}
