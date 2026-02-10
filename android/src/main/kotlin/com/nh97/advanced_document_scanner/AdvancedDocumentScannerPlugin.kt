package com.nh97.advanced_document_scanner

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.annotation.NonNull
import com.google.android.gms.tasks.Task
import com.google.mlkit.vision.documentscanner.GmsDocumentScanner
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener
import java.io.File
import java.io.FileOutputStream

/**
 * Native scanner bridge.
 *
 * Android: Google ML Kit Document Scanner (Play services).
 */
class AdvancedDocumentScannerPlugin : FlutterPlugin, ActivityAware, MethodCallHandler,
    ActivityResultListener {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var pendingResult: Result? = null
    private var scanner: GmsDocumentScanner? = null

    private val requestCode = 8921

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "advanced_document_scanner/native_scanner")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // -------- ActivityAware --------
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // -------- MethodCallHandler --------
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "scan" -> startScan(call, result)
            else -> result.notImplemented()
        }
    }

    private fun startScan(call: MethodCall, result: Result) {
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "Plugin is not attached to an Activity.", null)
            return
        }
        if (pendingResult != null) {
            result.error("IN_PROGRESS", "Another scan is already running.", null)
            return
        }

        val pageLimit = (call.argument<Int>("pageLimit") ?: 10).coerceIn(1, 50)
        val allowGallery = call.argument<Boolean>("allowGallery") ?: true
        val returnPdf = call.argument<Boolean>("returnPdf") ?: true
        val returnJpeg = call.argument<Boolean>("returnJpeg") ?: true

        val formats = mutableListOf<Int>()
        if (returnJpeg) formats.add(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
        if (returnPdf) formats.add(GmsDocumentScannerOptions.RESULT_FORMAT_PDF)

        // If nothing selected, default JPEG
        if (formats.isEmpty()) formats.add(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)

        val optionsBuilder = GmsDocumentScannerOptions.Builder()
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .setPageLimit(pageLimit)
            .setGalleryImportAllowed(allowGallery)

        when (formats.size) {
            1 -> optionsBuilder.setResultFormats(formats[0])
            else -> optionsBuilder.setResultFormats(formats[0], formats[1])
        }

        val options = optionsBuilder.build()

        scanner = GmsDocumentScanning.getClient(options)

        pendingResult = result

        val task: Task<android.content.IntentSender> = scanner!!.getStartScanIntent(act)
        task.addOnSuccessListener { intentSender ->
            try {
                act.startIntentSenderForResult(intentSender, requestCode, null, 0, 0, 0)
            } catch (e: Exception) {
                finishWithError("START_FAILED", e.message ?: "Failed to start scanner", null)
            }
        }.addOnFailureListener { e ->
            finishWithError("START_FAILED", e.message ?: "Failed to get scan intent", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != this.requestCode) return false

        val res = pendingResult ?: return true
        pendingResult = null

        if (resultCode != Activity.RESULT_OK || data == null) {
            // User cancelled
            res.success(mapOf("imagePaths" to emptyList<String>(), "pdfPath" to null))
            return true
        }

        try {
            val scanResult = GmsDocumentScanningResult.fromActivityResultIntent(data)
            if (scanResult == null) {
                res.success(mapOf("imagePaths" to emptyList<String>(), "pdfPath" to null))
                return true
            }

            val act = activity
            if (act == null) {
                res.error("NO_ACTIVITY", "Activity missing while receiving result.", null)
                return true
            }

            val outImages = mutableListOf<String>()
            scanResult.pages?.forEachIndexed { idx, page ->
                val uri: Uri = page.imageUri
                val path =
                    copyUriToCache(act, uri, "mlkit_page_${System.currentTimeMillis()}_${idx}.jpg")
                outImages.add(path)
            }

            var pdfPath: String? = null
            val pdf = scanResult.pdf
            if (pdf != null) {
                pdfPath =
                    copyUriToCache(act, pdf.uri, "mlkit_scan_${System.currentTimeMillis()}.pdf")
            }

            res.success(mapOf("imagePaths" to outImages, "pdfPath" to pdfPath))
        } catch (e: Exception) {
            res.error("RESULT_PARSE_FAILED", e.message ?: "Failed to parse scan result", null)
        }
        return true
    }

    private fun copyUriToCache(activity: Activity, uri: Uri, fileName: String): String {
        val dir = File(activity.cacheDir, "ads_mlkit")
        if (!dir.exists()) dir.mkdirs()
        val outFile = File(dir, fileName)

        activity.contentResolver.openInputStream(uri).use { input ->
            if (input == null) throw IllegalStateException("Unable to open input stream for $uri")
            FileOutputStream(outFile).use { output ->
                input.copyTo(output)
                output.flush()
            }
        }
        return outFile.absolutePath
    }

    private fun finishWithError(code: String, message: String, details: Any?) {
        val res = pendingResult
        pendingResult = null
        res?.error(code, message, details)
    }
}
