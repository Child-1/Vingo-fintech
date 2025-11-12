package com.vingo.backend.controller

import com.vingo.backend.dto.WalletResponse
import com.vingo.backend.repository.WalletRepository
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/wallets")
class WalletController(private val walletRepository: WalletRepository) {

    @GetMapping("/{vingHandle}")
    fun getWallet(@PathVariable vingHandle: String): ResponseEntity<WalletResponse> {
        val wallet = walletRepository.findByUserVingHandle(vingHandle)
        return if (wallet != null) {
            ResponseEntity.ok(wallet.toResponse())
        } else {
            ResponseEntity.notFound().build()
        }
    }
}