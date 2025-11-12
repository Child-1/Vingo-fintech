package com.vingo.backend.controller

import com.vingo.backend.model.User
import com.vingo.backend.model.Wallet
import com.vingo.backend.repository.UserRepository
import com.vingo.backend.repository.WalletRepository
import com.vingo.backend.dto.UserResponse
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/users")
class UserController(
    private val userRepository: UserRepository,
    private val walletRepository: WalletRepository  // ← ADD THIS
) {

    @PostMapping
    fun createUser(@RequestBody user: User): UserResponse {
        val savedUser = userRepository.save(user)
        // Auto-create wallet
        val wallet = Wallet(user = savedUser)
        walletRepository.save(wallet)
        return savedUser.toResponse()
    }

    @GetMapping("/{vingHandle}")
    fun getUserByHandle(@PathVariable vingHandle: String): ResponseEntity<UserResponse> {
        val user = userRepository.findByVingHandle(vingHandle)
        return if (user != null) {
            ResponseEntity.ok(user.toResponse())
        } else {
            ResponseEntity.notFound().build()
        }
    }
}