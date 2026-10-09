package cn.bh2vsq.qslmanager

import android.content.Intent
import android.media.AudioManager
import android.media.ToneGenerator
import android.net.Uri
import android.nfc.NfcAdapter
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val updateChannelName = "qslmm/app_update"
    private val nfcChannelName = "qslmm/nfc"

    /// URI delivered to the app by an NFC tag scan / deep link. Kept here until
    /// Dart asks for it via `consumeLaunchUri`.
    private var pendingLaunchUri: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action ?: return
        if (action == NfcAdapter.ACTION_NDEF_DISCOVERED || action == Intent.ACTION_VIEW) {
            intent.data?.let { pendingLaunchUri = it.toString() }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updateChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("INVALID_PATH", "APK 路径为空", null)
                        return@setMethodCallHandler
                    }
                    val file = File(path)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "APK 文件不存在", null)
                        return@setMethodCallHandler
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !packageManager.canRequestPackageInstalls()) {
                        val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    try {
                        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("INSTALL_FAILED", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, nfcChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "isNfcEnabled" -> {
                    result.success(NfcAdapter.getDefaultAdapter(this)?.isEnabled == true)
                }
                "beep" -> {
                    playBeep()
                    result.success(null)
                }
                "consumeLaunchUri" -> {
                    val uri = pendingLaunchUri
                    pendingLaunchUri = null
                    result.success(uri)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun playBeep() {
        try {
            val tone = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 80)
            tone.startTone(ToneGenerator.TONE_PROP_BEEP, 120)
            Handler(Looper.getMainLooper()).postDelayed({ tone.release() }, 200)
        } catch (_: Exception) {
            // Ignore audio failures; the beep is cosmetic feedback.
        }
    }
}
