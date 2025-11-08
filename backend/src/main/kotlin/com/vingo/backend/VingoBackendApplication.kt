package com.vingo.backend

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication

@SpringBootApplication
class VingoBackendApplication

fun main(args: Array<String>) {
	runApplication<VingoBackendApplication>(*args)
}
