package com.example.caregiver_timer

import android.content.Intent
import android.net.Uri
import androidx.annotation.NonNull
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.caregiver_timer/email"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sendEmailWithAttachment") {
                val filePath = call.argument<String>("filePath")
                val recipient = call.argument<String>("recipient")
                val subject = call.argument<String>("subject")
                val body = call.argument<String>("body")

                if (filePath != null && recipient != null) {
                    val success = sendEmailWithAttachment(filePath, recipient, subject ?: "", body ?: "")
                    result.success(success)
                } else {
                    result.error("INVALID_ARGUMENTS", "File path or recipient is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun sendEmailWithAttachment(filePath: String, recipient: String, subject: String, body: String): Boolean {
        try {
            val file = File(filePath)
            if (!file.exists()) {
                return false
            }

            val uri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                file
            )

            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "message/rfc822"
                putExtra(Intent.EXTRA_EMAIL, arrayOf(recipient))
                putExtra(Intent.EXTRA_SUBJECT, subject)
                putExtra(Intent.EXTRA_TEXT, body)
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            // Try to specifically target Gmail
            val gmailIntent = Intent(Intent.ACTION_SEND).apply {
                type = "message/rfc822"
                putExtra(Intent.EXTRA_EMAIL, arrayOf(recipient))
                putExtra(Intent.EXTRA_SUBJECT, subject)
                putExtra(Intent.EXTRA_TEXT, body)
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                setPackage("com.google.android.gm") // Gmail package
            }

            // Try to start Gmail directly, fall back to email chooser if Gmail not available
            try {
                startActivity(gmailIntent)
            } catch (e: Exception) {
                startActivity(Intent.createChooser(intent, "メールアプリを選択"))
            }

            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }
}
