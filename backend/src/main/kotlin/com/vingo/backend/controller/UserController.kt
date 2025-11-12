package com.vingo.backend.controller

import com.vingo.backend.model.User
import com.vingo.backend.repository.UserRepository
import com.vingo.backend.dto.UserResponse
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/users")
class UserController(private val userRepository: UserRepository) {

    @PostMapping
fun createUser(@RequestBody user: User): UserResponse {
    return userRepository.save(user).toResponse()
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