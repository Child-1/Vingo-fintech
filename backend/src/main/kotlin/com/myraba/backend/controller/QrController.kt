package com.myraba.backend.controller

import com.google.zxing.BarcodeFormat
import com.google.zxing.client.j2se.MatrixToImageWriter
import com.google.zxing.qrcode.QRCodeWriter
import com.myraba.backend.model.User
import org.springframework.http.*
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RestController
import java.io.ByteArrayOutputStream

@RestController
class QrController {

    @GetMapping("/api/users/me/qr", produces = [MediaType.IMAGE_PNG_VALUE])
    fun getMyQr(@AuthenticationPrincipal user: User): ResponseEntity<ByteArray> {
        val deepLink = "vingo://pay/${user.myrabaHandle}"
        val bitMatrix = QRCodeWriter().encode(deepLink, BarcodeFormat.QR_CODE, 500, 500)
        val outputStream = ByteArrayOutputStream()
        MatrixToImageWriter.writeToStream(bitMatrix, "PNG", outputStream)

        return ResponseEntity.ok()
            .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"${user.myrabaHandle}.png\"")
            .header(HttpHeaders.CACHE_CONTROL, "no-cache")
            .body(outputStream.toByteArray())
    }
}