package com.dsjerry.live_color_picker

import android.content.ClipData
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "live_color_picker/share",
        ).setMethodCallHandler { call, result ->
            if (call.method != "sharePng") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val path = call.argument<String>("path")
            if (path == null) {
                result.error("INVALID_PATH", "Missing PNG path", null)
                return@setMethodCallHandler
            }

            try {
                val file = File(path)
                val uri = FileProvider.getUriForFile(
                    this,
                    "$packageName.fileprovider",
                    file,
                )
                val sendIntent = Intent(Intent.ACTION_SEND).apply {
                    type = "image/png"
                    putExtra(Intent.EXTRA_STREAM, uri)
                    clipData = ClipData.newUri(contentResolver, file.name, uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                startActivity(
                    Intent.createChooser(
                        sendIntent,
                        call.argument<String>("title"),
                    ).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION),
                )
                result.success(null)
            } catch (error: Exception) {
                result.error("SHARE_FAILED", error.message, null)
            }
        }
    }
}
