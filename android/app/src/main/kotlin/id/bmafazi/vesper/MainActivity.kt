package id.bmafazi.vesper

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var pendingExport: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vesper/financial_export")
            .setMethodCallHandler { call, result ->
                if (call.method != "saveFile") {
                    result.notImplemented()
                } else if (pendingExport != null) {
                    result.error("BUSY", "Selesaikan penyimpanan sebelumnya.", null)
                } else {
                    val content = call.argument<ByteArray>("bytes")
                    val name = call.argument<String>("name")
                    if (content == null || name == null) {
                        result.error("INVALID", "Data ekspor tidak valid.", null)
                    } else {
                        pendingBytes = content
                        pendingExport = result
                        try {
                            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = call.argument<String>("mimeType") ?: "application/octet-stream"
                                putExtra(Intent.EXTRA_TITLE, name)
                            }
                            startActivityForResult(intent, 7007)
                        } catch (_: Exception) {
                            pendingBytes = null
                            pendingExport = null
                            result.error("EXPORT_FAILED", "Pemilih berkas tidak tersedia.", null)
                        }
                    }
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vesper/device_info")
            .setMethodCallHandler { call, result ->
                if (call.method != "getDeviceInfo") {
                    result.notImplemented()
                } else {
                    val deviceName = readSetting {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
                            Settings.Global.getString(contentResolver, Settings.Global.DEVICE_NAME)
                        } else {
                            null
                        }
                    } ?: readSetting {
                        Settings.System.getString(contentResolver, "device_name")
                    } ?: readSetting {
                        Settings.Secure.getString(contentResolver, "bluetooth_name")
                    }
                    val isEmulator = (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"))
                        || Build.FINGERPRINT.startsWith("generic")
                        || Build.FINGERPRINT.startsWith("unknown")
                        || Build.HARDWARE.contains("goldfish")
                        || Build.HARDWARE.contains("ranchu")
                        || Build.MODEL.contains("google_sdk")
                        || Build.MODEL.contains("Emulator")
                        || Build.MODEL.contains("Android SDK built for x86")
                        || Build.MODEL.startsWith("sdk_gphone")
                        || Build.MANUFACTURER.contains("Genymotion")
                        || Build.PRODUCT.contains("sdk_gphone")
                        || Build.PRODUCT.contains("emulator")
                        || Build.PRODUCT.contains("simulator")
                    result.success(
                        mapOf(
                            "deviceName" to deviceName,
                            "manufacturer" to Build.MANUFACTURER,
                            "brand" to Build.BRAND,
                            "model" to Build.MODEL,
                            "osVersion" to Build.VERSION.RELEASE,
                            "sdkInt" to Build.VERSION.SDK_INT,
                            "isEmulator" to isEmulator,
                        ),
                    )
                }
            }
    }

    private fun readSetting(reader: () -> String?): String? {
        return try {
            reader()?.trim()?.takeIf { it.isNotEmpty() }
        } catch (_: Exception) {
            null
        }
    }

    @Deprecated("Required for document picker result")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 7007) return
        val result = pendingExport ?: return
        val bytes = pendingBytes
        pendingExport = null
        pendingBytes = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || bytes == null) {
            result.success(null)
            return
        }
        try {
            val stream = contentResolver.openOutputStream(uri, "wt")
                ?: throw IllegalStateException("No output stream")
            stream.use { it.write(bytes) }
            result.success(uri.toString())
        } catch (_: Exception) {
            result.error("EXPORT_FAILED", "Berkas ekspor gagal disimpan.", null)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // FLAG_SECURE intentionally not set so users can take screenshots.
        // To re-enable screenshot/task-preview protection, add:
        // window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }
}
