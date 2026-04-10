package com.myraba.backend

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.databind.SerializationFeature
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication
import org.springframework.context.annotation.Bean
import org.springframework.http.ResponseEntity
import org.springframework.scheduling.annotation.EnableScheduling
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RestController
import java.time.LocalDateTime

@SpringBootApplication
@EnableScheduling
class MyrabaBackendApplication {

    @Bean
    fun objectMapper(): ObjectMapper = jacksonObjectMapper().apply {
        registerModule(JavaTimeModule())
        disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS)
    }
}

@RestController
class HealthController {
    @GetMapping("/")
    fun root(): ResponseEntity<Map<String, Any>> = ResponseEntity.ok(
        mapOf(
            "app" to "Myraba Fintech API",
            "status" to "UP",
            "timestamp" to LocalDateTime.now().toString()
        )
    )
}

fun main(args: Array<String>) {
    runApplication<MyrabaBackendApplication>(*args)
}