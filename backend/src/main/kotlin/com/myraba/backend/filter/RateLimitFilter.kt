package com.myraba.backend.filter

import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.http.MediaType
import org.springframework.stereotype.Component
import org.springframework.web.filter.OncePerRequestFilter
import java.time.Instant
import java.util.concurrent.ConcurrentHashMap

/**
 * Simple sliding-window rate limiter — no extra dependencies.
 * Rules:
 *   /auth/send-otp  → max 5 requests per 10 minutes per IP
 *   /auth/login     → max 10 requests per 5 minutes per IP
 */
@Component
class RateLimitFilter : OncePerRequestFilter() {

    data class Rule(val maxRequests: Int, val windowSeconds: Long)

    private val rules = mapOf(
        "/auth/send-otp" to Rule(5,  600),   // 5 per 10 min
        "/auth/login"    to Rule(10, 300),   // 10 per 5 min
    )

    // key = "IP::path", value = timestamps of requests within window
    private val buckets = ConcurrentHashMap<String, ArrayDeque<Long>>()

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        chain: FilterChain
    ) {
        val path  = request.requestURI
        val rule  = rules[path]

        if (rule == null) {
            chain.doFilter(request, response)
            return
        }

        val ip    = request.getHeader("X-Forwarded-For")?.split(",")?.first()?.trim()
                    ?: request.remoteAddr
        val key   = "$ip::$path"
        val now   = Instant.now().epochSecond
        val cutoff = now - rule.windowSeconds

        val timestamps = buckets.getOrPut(key) { ArrayDeque() }

        synchronized(timestamps) {
            // Evict expired entries
            while (timestamps.isNotEmpty() && timestamps.first() < cutoff) {
                timestamps.removeFirst()
            }

            if (timestamps.size >= rule.maxRequests) {
                val retryAfter = (timestamps.first() + rule.windowSeconds - now).coerceAtLeast(1)
                response.status = 429
                response.contentType = MediaType.APPLICATION_JSON_VALUE
                response.addHeader("Retry-After", retryAfter.toString())
                response.writer.write(
                    """{"error":"Too many requests","message":"Rate limit exceeded. Try again in ${retryAfter}s."}"""
                )
                return
            }

            timestamps.addLast(now)
        }

        chain.doFilter(request, response)
    }
}
