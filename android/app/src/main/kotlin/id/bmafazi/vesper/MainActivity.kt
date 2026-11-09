package id.bmafazi.vesper

import android.os.Bundle
import android.view.WindowManager
import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterFragmentActivity

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
        // Protect task previews and screenshots before the first Flutter frame.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }
}
