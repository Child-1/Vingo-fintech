package com.myraba.backend.util

import io.jsonwebtoken.Claims
import io.jsonwebtoken.Jwts
import io.jsonwebtoken.security.Keys
import org.springframework.beans.factory.annotation.Value
import org.springframework.security.core.userdetails.UserDetails
import org.springframework.stereotype.Component
import java.util.*
import javax.crypto.SecretKey

@Component
class JwtUtil {

    @Value("\${jwt.secret}")
    private lateinit var secret: String

    @Value("\${jwt.expiration}") 
    private var expirationMs: Long = 86400000

    private fun getSigningKey(): SecretKey {
        // Use UTF-8 bytes directly — the secret in application.yml is a plain string, not base64
        val keyBytes = secret.toByteArray(Charsets.UTF_8)
        return Keys.hmacShaKeyFor(keyBytes)
    }

    /**
     * Generates a new JWT token for a given user.
     */
    fun generateToken(userDetails: UserDetails): String {
        return Jwts.builder()
            .subject(userDetails.username) // myrabaHandle
            .issuedAt(Date(System.currentTimeMillis()))
            // Use the injected expiration time
            .expiration(Date(System.currentTimeMillis() + expirationMs)) 
            // FIX: Removed the deprecated SignatureAlgorithm argument.
            // The algorithm (HS256) is now inferred from the SecretKey type.
            .signWith(getSigningKey()) 
            .compact()
    }

    /**
     * Extracts the username (myrabaHandle) from the token.
     */
    fun extractUsername(token: String): String {
        return extractAllClaims(token).subject
    }

    /**
     * Checks if the token is valid (not expired) and belongs to the correct user.
     */
    fun validateToken(token: String, userDetails: UserDetails): Boolean {
        val username = extractUsername(token)
        return (username == userDetails.username && !isTokenExpired(token))
    }

    /**
     * Correct jjwt 0.12.x way of parsing the token
     */
    private fun extractAllClaims(token: String): Claims {
        return Jwts.parser()
            .verifyWith(getSigningKey())
            .build()
            .parseSignedClaims(token)
            .payload
    }

    private fun isTokenExpired(token: String): Boolean {
        return extractAllClaims(token).expiration.before(Date())
    }
}