package com.myraba.backend.config

import com.myraba.backend.filter.JwtRequestFilter
import com.myraba.backend.filter.RateLimitFilter
import jakarta.servlet.http.HttpServletResponse
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.http.HttpMethod
import org.springframework.http.MediaType
import org.springframework.security.authentication.AuthenticationManager
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity
import org.springframework.security.config.annotation.web.builders.HttpSecurity
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity
import org.springframework.security.config.http.SessionCreationPolicy
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.security.web.SecurityFilterChain
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter
import org.springframework.web.cors.CorsConfiguration
import org.springframework.web.cors.CorsConfigurationSource
import org.springframework.web.cors.UrlBasedCorsConfigurationSource

@Configuration
@EnableWebSecurity
@EnableMethodSecurity 
class SecurityConfig(
    private val jwtRequestFilter: JwtRequestFilter,
    private val rateLimitFilter: RateLimitFilter,
) {

    @Bean
    fun passwordEncoder(): PasswordEncoder = BCryptPasswordEncoder()

    @Bean
    fun authenticationManager(config: AuthenticationConfiguration): AuthenticationManager = 
        config.authenticationManager

    @Bean
    fun securityFilterChain(http: HttpSecurity): SecurityFilterChain {
        http.csrf { it.disable() }
            .cors { it.configurationSource(corsConfigurationSource()) }
            .sessionManagement { it.sessionCreationPolicy(SessionCreationPolicy.STATELESS) }
            .exceptionHandling { ex ->
                // Return 401 JSON instead of 403 for missing/invalid token
                ex.authenticationEntryPoint { _, response, authException ->
                    response.contentType = MediaType.APPLICATION_JSON_VALUE
                    response.status = HttpServletResponse.SC_UNAUTHORIZED
                    response.writer.write("""{"error":"Unauthorized","message":"${authException.message}"}""")
                }
                // Return 403 JSON for authenticated users hitting endpoints they don't have role for
                ex.accessDeniedHandler { _, response, accessDeniedException ->
                    response.contentType = MediaType.APPLICATION_JSON_VALUE
                    response.status = HttpServletResponse.SC_FORBIDDEN
                    response.writer.write("""{"error":"Forbidden","message":"${accessDeniedException.message}"}""")
                }
            }
            .authorizeHttpRequests { auth ->
                auth
                    .requestMatchers("/auth/**", "/auth/mfa/verify", "/actuator/**", "/error", "/").permitAll()
                    // Public gift page — accessible without login (for web gifting)
                    .requestMatchers("/public/gift/**").permitAll()
                    // Public wallet lookup (QR code scanning)
                    .requestMatchers(HttpMethod.GET, "/wallets/{myrabaHandle}").permitAll()

                    // Specific Role-Based Access
                    // Fine-grained access is enforced per-method via @PreAuthorize on each controller
                    .requestMatchers("/api/admin/**").hasAnyRole("STAFF", "ADMIN", "SUPER_ADMIN")

                    .anyRequest().authenticated()
            }
            .addFilterBefore(rateLimitFilter, UsernamePasswordAuthenticationFilter::class.java)
            .addFilterBefore(jwtRequestFilter, UsernamePasswordAuthenticationFilter::class.java)

        return http.build()
    }

    @Bean
    fun corsConfigurationSource(): CorsConfigurationSource {
        val configuration = CorsConfiguration()
        val allowedOrigins = System.getenv("ALLOWED_ORIGINS")
            ?.split(",")?.map { it.trim() }
        if (allowedOrigins != null) {
            configuration.allowedOrigins = allowedOrigins
        } else {
            // Dev: allow all origins (ngrok, localhost, etc.)
            configuration.allowedOriginPatterns = listOf("*")
        }
        configuration.allowedMethods = listOf("GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH")
        configuration.allowedHeaders = listOf("Authorization", "Content-Type", "Accept", "X-Requested-With")
        configuration.allowCredentials = true
        configuration.maxAge = 3600L
        val source = UrlBasedCorsConfigurationSource()
        source.registerCorsConfiguration("/**", configuration)
        return source
    }
}