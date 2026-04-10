package com.myraba.backend.filter

import com.myraba.backend.util.JwtUtil
import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.security.core.userdetails.UserDetailsService
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource
import org.springframework.stereotype.Component
import org.springframework.web.filter.OncePerRequestFilter

@Component
class JwtRequestFilter(
    private val userDetailsService: UserDetailsService,
    private val jwtUtil: JwtUtil
) : OncePerRequestFilter() {

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        filterChain: FilterChain
    ) {
        val requestUri = request.requestURI

        // FIXED: Skip JWT check for register/login (with or without trailing slash) + CORS preflight
        if (requestUri.startsWith("/auth/register") ||
            requestUri.startsWith("/auth/login") ||
            request.method == "OPTIONS") {
            filterChain.doFilter(request, response)
            return
        }

        val authorizationHeader = request.getHeader("Authorization")
        var username: String? = null
        var jwt: String? = null

        if (authorizationHeader != null && authorizationHeader.startsWith("Bearer ")) {
            jwt = authorizationHeader.substring(7)
            try {
                username = jwtUtil.extractUsername(jwt)
            } catch (e: Exception) { }
        }

        if (username != null && SecurityContextHolder.getContext().authentication == null) {
            val userDetails = try {
                userDetailsService.loadUserByUsername(username)
            } catch (e: Exception) { null }

            if (userDetails != null && jwt != null && jwtUtil.validateToken(jwt, userDetails)) {
                val authToken = UsernamePasswordAuthenticationToken(
                    userDetails, null, userDetails.authorities
                )
                authToken.details = WebAuthenticationDetailsSource().buildDetails(request)
                SecurityContextHolder.getContext().authentication = authToken
            }
        }

        filterChain.doFilter(request, response)
    }
}