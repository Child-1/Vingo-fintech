package com.myraba.backend.config

import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.MethodArgumentNotValidException
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.RestControllerAdvice
import org.springframework.web.server.ResponseStatusException

data class ErrorResponse(val error: String, val message: String)

@RestControllerAdvice
class GlobalExceptionHandler {

    /** Validation failures (@Valid annotation) → 400 */
    @ExceptionHandler(MethodArgumentNotValidException::class)
    fun handleValidation(ex: MethodArgumentNotValidException): ResponseEntity<ErrorResponse> {
        val message = ex.bindingResult.fieldErrors
            .joinToString("; ") { "${it.field}: ${it.defaultMessage}" }
        return ResponseEntity.badRequest()
            .body(ErrorResponse("Validation failed", message))
    }

    /** Bad input (wrong ID, missing entity, invalid param) → 400 */
    @ExceptionHandler(IllegalArgumentException::class)
    fun handleIllegalArgument(ex: IllegalArgumentException): ResponseEntity<ErrorResponse> =
        ResponseEntity.badRequest()
            .body(ErrorResponse("Bad request", ex.message ?: "Invalid input"))

    /** Business rule violation (duplicate, wrong state, insufficient funds) → 409 */
    @ExceptionHandler(IllegalStateException::class)
    fun handleIllegalState(ex: IllegalStateException): ResponseEntity<ErrorResponse> =
        ResponseEntity.status(HttpStatus.CONFLICT)
            .body(ErrorResponse("Conflict", ex.message ?: "Operation not allowed"))

    /** NoSuchElement (orElseThrow with no message override) → 404 */
    @ExceptionHandler(NoSuchElementException::class)
    fun handleNotFound(ex: NoSuchElementException): ResponseEntity<ErrorResponse> =
        ResponseEntity.status(HttpStatus.NOT_FOUND)
            .body(ErrorResponse("Not found", ex.message ?: "Resource not found"))

    /** Already-correct ResponseStatusException — pass through unchanged */
    @ExceptionHandler(ResponseStatusException::class)
    fun handleResponseStatus(ex: ResponseStatusException): ResponseEntity<ErrorResponse> =
        ResponseEntity.status(ex.statusCode)
            .body(ErrorResponse("Error", ex.reason ?: ex.message))

    /** Catch-all → 500 */
    @ExceptionHandler(Exception::class)
    fun handleGeneric(ex: Exception): ResponseEntity<ErrorResponse> {
        println("=== UNHANDLED EXCEPTION: ${ex::class.simpleName}: ${ex.message} ===")
        ex.printStackTrace()
        return ResponseEntity.internalServerError()
            .body(ErrorResponse("Internal server error", "${ex::class.simpleName}: ${ex.message}"))
    }
}
