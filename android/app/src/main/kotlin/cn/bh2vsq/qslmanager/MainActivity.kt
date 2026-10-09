package cn.bh2vsq.qslmanager

import android.content.Intent
import android.media.AudioManager
import android.media.ToneGenerator
import android.net.Uri
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.Ndef
import android.nfc.tech.NdefFormatable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File

class MainActivity : FlutterActivity(), EventChannel.StreamHandler {
    private val updateChannelName = "qslmm/app_update"
    private val nfcChannelName = "qslmm/nfc"
    private val nfcEventChannelName = "qslmm/nfc_events"

    /// URI delivered to the app by an NFC tag scan / deep link. Kept here until
    /// Dart asks for it via `consumeLaunchUri`.
    private var pendingLaunchUri: String? = null

    // NFC reader-mode state.
    private var nfcEventSink: EventChannel.EventSink? = null
    private var nfcHandlerThread: HandlerThread? = null
    private var nfcHandler: Handler? = null
    private var nfcOperation: String? = null // "write" or "format"
    private var nfcWriteUrl: String? = null
    private var nfcWritePackage: String? = null

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

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, nfcEventChannelName)
            .setStreamHandler(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, nfcChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "getNfcAvailability" -> {
                    val adapter = NfcAdapter.getDefaultAdapter(this)
                    when {
                        adapter == null -> result.success("not_supported")
                        adapter.isEnabled -> result.success("available")
                        else -> result.success("disabled")
                    }
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
                "startNfcWrite" -> {
                    val url = call.argument<String>("url") ?: ""
                    val packageName = call.argument<String>("packageName") ?: ""
                    startNfcOperation("write", url, packageName, result)
                }
                "startNfcFormat" -> {
                    startNfcOperation("format", null, null, result)
                }
                "stopNfc" -> {
                    stopNfc()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        nfcEventSink = events
    }

    override fun onCancel(arguments: Any?) {
        nfcEventSink = null
    }

    private fun ensureNfcHandler() {
        if (nfcHandlerThread == null || nfcHandlerThread?.isAlive == false) {
            nfcHandlerThread = HandlerThread("qslmm-nfc").apply { start() }
            nfcHandler = Handler(nfcHandlerThread!!.looper)
        }
    }

    private fun startNfcOperation(mode: String, url: String?, packageName: String?, result: MethodChannel.Result) {
        val adapter = NfcAdapter.getDefaultAdapter(this)
        if (adapter == null) {
            result.error("NFC_UNSUPPORTED", "NFC not supported", null)
            return
        }
        if (!adapter.isEnabled) {
            result.error("NFC_DISABLED", "NFC disabled", null)
            return
        }

        ensureNfcHandler()
        stopNfc()
        nfcOperation = mode
        nfcWriteUrl = url
        nfcWritePackage = packageName

        val flags = NfcAdapter.FLAG_READER_NFC_A or
            NfcAdapter.FLAG_READER_NFC_B or
            NfcAdapter.FLAG_READER_NFC_F or
            NfcAdapter.FLAG_READER_NFC_V or
            NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS

        adapter.enableReaderMode(this, { tag ->
            nfcHandler?.post { writeTag(tag, mode, url, packageName) }
        }, flags, null)

        result.success(null)
    }

    private fun writeTag(tag: Tag, mode: String, url: String?, packageName: String?) {
        try {
            val message = when (mode) {
                "write" -> NdefMessage(
                    arrayOf(
                        NdefRecord.createUri(url ?: ""),
                        NdefRecord.createApplicationRecord(packageName ?: "")
                    )
                )
                else -> NdefMessage(arrayOf())
            }

            var written = false
            val ndef = Ndef.get(tag)
            if (ndef != null) {
                ndef.connect()
                try {
                    if (ndef.isWritable) {
                        ndef.writeNdefMessage(message)
                        written = true
                    }
                } finally {
                    ndef.close()
                }
            } else {
                val formattable = NdefFormatable.get(tag)
                if (formattable != null) {
                    formattable.connect()
                    try {
                        formattable.format(message)
                        written = true
                    } finally {
                        formattable.close()
                    }
                }
            }

            if (written) {
                playBeep()
                emitEvent(JSONObject(mapOf("type" to "success", "mode" to mode)).toString())
                if (mode == "write") stopNfc()
            } else {
                emitEvent(JSONObject(mapOf("type" to "error", "message" to "标签不可写")).toString())
                if (mode == "write") stopNfc()
            }
        } catch (e: Exception) {
            emitEvent(JSONObject(mapOf("type" to "error", "message" to (e.message ?: e.toString()))).toString())
            if (mode == "write") stopNfc()
        }
    }

    private fun emitEvent(json: String) {
        Handler(Looper.getMainLooper()).post {
            nfcEventSink?.success(json)
        }
    }

    private fun stopNfc() {
        nfcOperation = null
        val disable = Runnable {
            try {
                NfcAdapter.getDefaultAdapter(this@MainActivity)?.disableReaderMode(this@MainActivity)
            } catch (_: Exception) {
            }
        }
        // disableReaderMode must run on the main thread. When stopNfc() is
        // called from the main thread (startNfcOperation / the stopNfc method
        // channel), run it synchronously so it cannot race the enableReaderMode
        // that follows; from the NFC handler thread, post it to the main looper.
        if (Looper.myLooper() == Looper.getMainLooper()) {
            disable.run()
        } else {
            Handler(Looper.getMainLooper()).post(disable)
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
