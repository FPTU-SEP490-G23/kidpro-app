package com.kidpro.attendance.network

import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Response
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.Multipart
import retrofit2.http.POST
import retrofit2.http.Part
import java.util.concurrent.TimeUnit

data class CheckInResponse(
    val status: String, // "PRESENT" or "UNKNOWN"
    val student_id: String?,
    val name: String?,
    val class_name: String?,
    val confidence_score: Double?,
    val checkin_time: String?,
    val message: String?
)

interface AttendanceApiService {
    @Multipart
    @POST("/api/v1/check-in")
    suspend fun checkInFace(
        @Part file: MultipartBody.Part
    ): Response<CheckInResponse>
}

object RetrofitClient {
    // Thay đổi BASE_URL thành IP LAN của Laptop (ví dụ http://192.168.1.15:8000/ hoặc 10.0.2.2:8000 trên Emulator)
    var baseUrl = "http://10.0.2.2:8000/"

    private val okHttpClient = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .writeTimeout(10, TimeUnit.SECONDS)
        .addInterceptor(HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BODY
        })
        .build()

    fun getService(customUrl: String? = null): AttendanceApiService {
        val targetUrl = customUrl ?: baseUrl
        return Retrofit.Builder()
            .baseUrl(targetUrl)
            .client(okHttpClient)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(AttendanceApiService::class.java)
    }
}
