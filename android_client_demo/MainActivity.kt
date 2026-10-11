package com.kidpro.attendance

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Matrix
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Bundle
import android.util.Size
import android.view.View
import android.widget.EditText
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import com.kidpro.attendance.databinding.ActivityMainBinding
import com.kidpro.attendance.network.RetrofitClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.ByteArrayOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private var imageCapture: ImageCapture? = null
    private lateinit var cameraExecutor: ExecutorService

    private val toneGenerator = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 100)

    companion object {
        private const val REQUEST_CODE_PERMISSIONS = 10
        private val REQUIRED_PERMISSIONS = arrayOf(Manifest.permission.CAMERA)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        cameraExecutor = Executors.newSingleThreadExecutor()

        if (allPermissionsGranted()) {
            startCamera()
        } else {
            ActivityCompat.requestPermissions(this, REQUIRED_PERMISSIONS, REQUEST_CODE_PERMISSIONS)
        }

        binding.btnCheckIn.setOnClickListener {
            captureAndCheckIn()
        }

        binding.btnRetry.setOnClickListener {
            resetUi()
            captureAndCheckIn()
        }

        binding.btnManualFallback.setOnClickListener {
            Toast.makeText(this, "Chuyển sang màn hình điểm danh thủ công", Toast.LENGTH_SHORT).show()
        }

        binding.btnConfigIp.setOnClickListener {
            showIpDialog()
        }
    }

    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        cameraProviderFuture.addListener({
            val cameraProvider = cameraProviderFuture.get()

            // 1. Preview 720p
            val preview = Preview.Builder()
                .setTargetResolution(Size(1280, 720))
                .build()
                .also {
                    it.setSurfaceProvider(binding.viewFinder.surfaceProvider)
                }

            // 2. ImageCapture 720p
            imageCapture = ImageCapture.Builder()
                .setTargetResolution(Size(1280, 720))
                .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
                .build()

            val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

            try {
                cameraProvider.unbindAll()
                cameraProvider.bindToLifecycle(this, cameraSelector, preview, imageCapture)
            } catch (exc: Exception) {
                Toast.makeText(this, "Khởi tạo Camera thất bại: ${exc.message}", Toast.LENGTH_SHORT).show()
            }
        }, ContextCompat.getMainExecutor(this))
    }

    private fun captureAndCheckIn() {
        val imageCapture = imageCapture ?: return

        binding.progressBar.visibility = View.VISIBLE
        binding.btnCheckIn.isEnabled = false

        imageCapture.takePicture(
            ContextCompat.getMainExecutor(this),
            object : ImageCapture.OnImageCapturedCallback() {
                override fun onCaptureSuccess(imageProxy: ImageProxy) {
                    processImageAndSendApi(imageProxy)
                }

                override fun onError(exception: ImageCaptureException) {
                    binding.progressBar.visibility = View.GONE
                    binding.btnCheckIn.isEnabled = true
                    Toast.makeText(this@MainActivity, "Chụp ảnh lỗi: ${exception.message}", Toast.LENGTH_SHORT).show()
                }
            }
        )
    }

    private fun processImageAndSendApi(imageProxy: ImageProxy) {
        lifecycleScope.launch(Dispatchers.Default) {
            // A. Convert ImageProxy to Bitmap with rotation
            val buffer = imageProxy.planes[0].buffer
            val bytes = ByteArray(buffer.remaining())
            buffer.get(bytes)
            val originalBitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)

            val rotationDegrees = imageProxy.imageInfo.rotationDegrees
            val matrix = Matrix().apply { postRotate(rotationDegrees.toFloat()) }
            val rotatedBitmap = Bitmap.createBitmap(
                originalBitmap, 0, 0, originalBitmap.width, originalBitmap.height, matrix, true
            )
            imageProxy.close()

            // B. Resize chiều dài lớn nhất về 640px
            val maxDim = 640
            val width = rotatedBitmap.width
            val height = rotatedBitmap.height
            val scale = if (width > height) maxDim.toFloat() / width else maxDim.toFloat() / height
            val scaledBitmap = Bitmap.createScaledBitmap(
                rotatedBitmap,
                (width * scale).toInt(),
                (height * scale).toInt(),
                true
            )

            // C. Nén JPEG chất lượng 80% (khoảng 100 - 200 KB)
            val stream = ByteArrayOutputStream()
            scaledBitmap.compress(Bitmap.CompressFormat.JPEG, 80, stream)
            val compressedBytes = stream.toByteArray()

            // D. Gửi Multipart HTTP tới FastAPI
            val requestBody = compressedBytes.toRequestBody("image/jpeg".toMediaTypeOrNull())
            val multipartFile = MultipartBody.Part.createFormData("file", "checkin.jpg", requestBody)

            try {
                val response = RetrofitClient.getService().checkInFace(multipartFile)
                withContext(Dispatchers.Main) {
                    binding.progressBar.visibility = View.GONE
                    binding.btnCheckIn.isEnabled = true

                    if (response.isSuccessful && response.body() != null) {
                        handleCheckInResponse(response.body()!!)
                    } else {
                        Toast.makeText(this@MainActivity, "Lỗi server: ${response.code()}", Toast.LENGTH_SHORT).show()
                    }
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    binding.progressBar.visibility = View.GONE
                    binding.btnCheckIn.isEnabled = true
                    Toast.makeText(this@MainActivity, "Lỗi kết nối AI Server: ${e.message}", Toast.LENGTH_LONG).show()
                }
            }
        }
    }

    private fun handleCheckInResponse(result: com.kidpro.attendance.network.CheckInResponse) {
        binding.cardResult.visibility = View.VISIBLE

        if (result.status == "PRESENT") {
            // Viền xanh lá
            binding.cameraBorder.strokeColor = Color.parseColor("#10B981")
            binding.cardResult.strokeColor = Color.parseColor("#10B981")

            // Beep sound
            toneGenerator.startTone(ToneGenerator.TONE_PROP_BEEP, 200)

            binding.txtStatus.text = "✓ ĐIỂM DANH THÀNH CÔNG"
            binding.txtStatus.setTextColor(Color.parseColor("#10B981"))
            binding.txtStudentName.text = result.name ?: "Học sinh"

            val scorePercent = ((result.confidence_score ?: 0.0) * 100).toInt()
            binding.txtClassAndScore.text = "Lớp: ${result.class_name} • Độ khớp: $scorePercent% • ${result.checkin_time}"

            binding.layoutFallbackActions.visibility = View.GONE
        } else {
            // Viền đỏ cảnh báo người lạ
            binding.cameraBorder.strokeColor = Color.parseColor("#EF4444")
            binding.cardResult.strokeColor = Color.parseColor("#EF4444")

            binding.txtStatus.text = "⚠ CẢNH BÁO: KHÔNG NHẬN DIỆN ĐƯỢC"
            binding.txtStatus.setTextColor(Color.parseColor("#EF4444"))
            binding.txtStudentName.text = "Người lạ / Khuôn mặt chưa đăng ký"

            val scorePercent = ((result.confidence_score ?: 0.0) * 100).toInt()
            binding.txtClassAndScore.text = "Điểm khớp cao nhất: $scorePercent% (Dưới ngưỡng 65%)"

            binding.layoutFallbackActions.visibility = View.VISIBLE
        }
    }

    private fun resetUi() {
        binding.cameraBorder.strokeColor = Color.WHITE
        binding.cardResult.visibility = View.GONE
    }

    private fun showIpDialog() {
        val input = EditText(this)
        input.setText(RetrofitClient.baseUrl)
        AlertDialog.Builder(this)
            .setTitle("Cấu hình IP AI Server")
            .setMessage("Nhập URL Laptop (ví dụ http://192.168.1.15:8000/):")
            .setView(input)
            .setPositiveButton("Lưu") { _, _ ->
                val newUrl = input.text.toString().trim()
                RetrofitClient.baseUrl = if (newUrl.endsWith("/")) newUrl else "$newUrl/"
                Toast.makeText(this, "Đã đổi sang: ${RetrofitClient.baseUrl}", Toast.LENGTH_SHORT).show()
            }
            .setNegativeButton("Hủy", null)
            .show()
    }

    private fun allPermissionsGranted() = REQUIRED_PERMISSIONS.all {
        ContextCompat.checkSelfPermission(baseContext, it) == PackageManager.PERMISSION_GRANTED
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_CODE_PERMISSIONS) {
            if (allPermissionsGranted()) {
                startCamera()
            } else {
                Toast.makeText(this, "Cần cấp quyền Camera để điểm danh", Toast.LENGTH_SHORT).show()
                finish()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        cameraExecutor.shutdown()
        toneGenerator.release()
    }
}
