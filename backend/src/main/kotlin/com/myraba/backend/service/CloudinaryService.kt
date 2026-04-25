package com.myraba.backend.service

import com.cloudinary.Cloudinary
import com.cloudinary.utils.ObjectUtils
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import org.springframework.web.multipart.MultipartFile

@Service
class CloudinaryService(
    @Value("\${myraba.cloudinary.cloud-name}") cloudName: String,
    @Value("\${myraba.cloudinary.api-key}") apiKey: String,
    @Value("\${myraba.cloudinary.api-secret}") apiSecret: String,
) {
    private val cloudinary = Cloudinary(
        mapOf("cloud_name" to cloudName, "api_key" to apiKey, "api_secret" to apiSecret)
    )

    fun uploadAvatar(file: MultipartFile, userHandle: String): String {
        val result = cloudinary.uploader().upload(
            file.bytes,
            ObjectUtils.asMap(
                "public_id", "avatars/$userHandle",
                "overwrite", true,
                "folder", "myraba",
                "transformation", listOf(
                    mapOf("width" to 400, "height" to 400, "crop" to "fill", "gravity" to "face")
                )
            )
        )
        return result["secure_url"] as String
    }

    fun deleteAvatar(userHandle: String) {
        cloudinary.uploader().destroy("myraba/avatars/$userHandle", ObjectUtils.emptyMap())
    }
}
