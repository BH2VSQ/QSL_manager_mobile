package cn.bh2vsq.qslmanager

import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.ToneGenerator
import android.net.Uri
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.MifareClassic
import android.nfc.tech.MifareUltralight
import android.nfc.tech.Ndef
import android.nfc.tech.NdefFormatable
import android.nfc.tech.NfcA
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
import java.security.MessageDigest

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

    // Identity written to each QSL tag so the client can be recognised by its
    // package name and signing certificate when the tag is scanned back.
    private val identityDomain = "cn.bh2vsq.qslmanager"
    private val identityType = "identity"
    private val identityFullType = "$identityDomain:$identityType"

    // MIFARE Classic keys/access bits. protectClassic keeps data readable via
    // Key A and writable only via Key B; unprotectClassic restores the factory
    // transport configuration so the tag can be reformatted.
    private val classicFormatKeyA = byteArrayOf(0xD3.toByte(), 0xF7.toByte(), 0xD3.toByte(), 0xF7.toByte(), 0xD3.toByte(), 0xF7.toByte())
    private val classicMadKey = byteArrayOf(0xA0.toByte(), 0xA1.toByte(), 0xA2.toByte(), 0xA3.toByte(), 0xA4.toByte(), 0xA5.toByte())
    private val classicFactoryKey = ByteArray(6) { 0xFF.toByte() }
    private val classicProtectAccess = byteArrayOf(0x87.toByte(), 0x8F.toByte(), 0x07, 0x00)
    private val classicFactoryAccess = byteArrayOf(0xFF.toByte(), 0x07, 0x80.toByte(), 0x69)

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
        if (action == NfcAdapter.ACTION_NDEF_DISCOVERED) {
            // Only deep-link into QSLMM when the tag carries our identity record
            // with a matching package name and signing certificate. A foreign or
            // legacy URI tag still opens the web page via the browser fallback.
            if (matchesAppIdentity(intent)) {
                intent.data?.let { pendingLaunchUri = it.toString() }
            }
        } else if (action == Intent.ACTION_VIEW) {
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
                    val keyA = call.argument<String>("keyA") ?: ""
                    val keyB = call.argument<String>("keyB") ?: ""
                    startNfcOperation("write", url, keyA, keyB, result)
                }
                "startNfcFormat" -> {
                    val keyA = call.argument<String>("keyA") ?: ""
                    val keyB = call.argument<String>("keyB") ?: ""
                    startNfcOperation("format", null, keyA, keyB, result)
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

    private fun startNfcOperation(mode: String, url: String?, keyA: String, keyB: String, result: MethodChannel.Result) {
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

        val flags = NfcAdapter.FLAG_READER_NFC_A or
            NfcAdapter.FLAG_READER_NFC_B or
            NfcAdapter.FLAG_READER_NFC_F or
            NfcAdapter.FLAG_READER_NFC_V or
            NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS

        adapter.enableReaderMode(this, { tag ->
            nfcHandler?.post { writeTag(tag, mode, url, keyA, keyB) }
        }, flags, null)

        result.success(null)
    }

    private fun writeTag(tag: Tag, mode: String, url: String?, keyA: String, keyB: String) {
        try {
            // For formatting, drop any password protection first so the empty
            // record below can be written back to a protected tag.
            if (mode == "format") {
                if (MifareClassic.get(tag) != null) {
                    unprotectClassic(tag, keyB)
                } else {
                    unprotectTag(tag, keyA)
                }
            }

            val message = when (mode) {
                // URI first so a device without QSLMM opens the query URL in the
                // browser. NTAG tags also carry an identity record (package name
                // + signing certificate) so QSLMM can verify them on a later
                // scan; MIFARE Classic (SAK08) tags get the URI only.
                "write" -> {
                    val records = mutableListOf(NdefRecord.createUri(url ?: ""))
                    if (isNtag(tag)) records.add(buildIdentityRecord())
                    NdefMessage(records.toTypedArray())
                }
                // A single empty record is a valid NDEF message and clears the
                // tag; NdefMessage() with zero records throws "must have at
                // least one record".
                else -> NdefMessage(
                    arrayOf(NdefRecord(NdefRecord.TNF_EMPTY, ByteArray(0), ByteArray(0), ByteArray(0)))
                )
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
                // For writing, lock the tag with the password so it cannot be
                // rewritten without authenticating first. A password failure
                // does not discard the data that was just written.
                var protectFailed: String? = null
                if (mode == "write" && keyA.isNotEmpty()) {
                    try {
                        if (MifareClassic.get(tag) != null) {
                            protectClassic(tag, keyA, keyB)
                        } else {
                            protectTag(tag, keyA)
                        }
                    } catch (e: Exception) {
                        protectFailed = "数据已写入，但设置密码失败：${e.message ?: e.toString()}"
                    }
                }
                playBeep()
                if (protectFailed != null) {
                    emitEvent(JSONObject(mapOf("type" to "error", "message" to protectFailed)).toString())
                } else {
                    emitEvent(JSONObject(mapOf("type" to "success", "mode" to mode)).toString())
                }
                if (mode == "write") stopNfc()
            } else {
                emitEvent(JSONObject(mapOf("type" to "error", "message" to "标签不可写")).toString())
                if (mode == "write") stopNfc()
            }
        } catch (e: Exception) {
            val reason = e.message ?: e.toString()
            val message = if (mode == "write") "写入失败：$reason" else "格式化失败：$reason"
            emitEvent(JSONObject(mapOf("type" to "error", "message" to message)).toString())
            if (mode == "write") stopNfc()
        }
    }

    private fun emitEvent(json: String) {
        Handler(Looper.getMainLooper()).post {
            nfcEventSink?.success(json)
        }
    }

    /// NTAG21x configuration-page addresses for a specific tag model.
    private data class NtagConfig(val cfg0: Int, val cfg1: Int, val pwd: Int, val pack: Int)

    /// Derives the 6-byte key from the user-entered string (first six UTF-8
    /// bytes, zero-padded). NTAG uses the first four bytes as its PWD; MIFARE
    /// Classic uses all six bytes as a sector key.
    private fun passwordTo6Bytes(key: String): ByteArray =
        key.toByteArray(Charsets.UTF_8).copyOf(6)

    /// Reads the CC (capability container) to identify the NTAG model and return
    /// its configuration-page addresses, or null for an unknown tag.
    private fun readNtagConfig(nfcA: NfcA): NtagConfig? {
        return try {
            val cc = nfcA.transceive(byteArrayOf(0x30.toByte(), 0x03)) ?: return null
            val mlen = cc.getOrNull(2)?.toInt()?.and(0xFF) ?: return null
            when (mlen) {
                0x12 -> NtagConfig(0x29, 0x2A, 0x2B, 0x2C) // NTAG213
                0x3E -> NtagConfig(0x81, 0x82, 0x83, 0x84) // NTAG215
                0x6D -> NtagConfig(0xE1, 0xE2, 0xE3, 0xE4) // NTAG216
                else -> null
            }
        } catch (_: Exception) {
            null
        }
    }

    /// Writes a single NTAG page (WRITE command carries the page + 4 bytes).
    /// NTAG EEPROM writes take a few ms each, so pause briefly between pages.
    private fun writeNtagPage(nfcA: NfcA, page: Int, data: ByteArray) {
        val cmd = ByteArray(6)
        cmd[0] = 0xA2.toByte()
        cmd[1] = page.toByte()
        System.arraycopy(data, 0, cmd, 2, 4)
        nfcA.transceive(cmd)
        Thread.sleep(5)
    }

    /// True only for NTAG/Ultralight (SAK 0x00) tags, which support the password
    /// feature and the identity record. MIFARE Classic (SAK 0x08) is excluded so
    /// the password code never touches it.
    private fun isNtag(tag: Tag): Boolean {
        if (MifareUltralight.get(tag) == null) return false
        return NfcA.get(tag)?.sak?.toInt()?.and(0xFF) == 0x00
    }

    /// Applies the password to an NTAG after the NDEF payload has been written,
    /// so the data pages cannot be rewritten without authenticating first.
    private fun protectTag(tag: Tag, keyA: String) {
        if (!isNtag(tag)) return
        val nfcA = NfcA.get(tag) ?: return
        nfcA.connect()
        try {
            val cfg = readNtagConfig(nfcA) ?: return
            val pwd = passwordTo6Bytes(keyA).copyOf(4)
            writeNtagPage(nfcA, cfg.pwd, pwd)                         // PWD
            writeNtagPage(nfcA, cfg.pack, ByteArray(4))               // PACK (RFUI = 0)
            writeNtagPage(nfcA, cfg.cfg0, byteArrayOf(0, 0, 0, 0))    // AUTH0 = 0x00
            writeNtagPage(nfcA, cfg.cfg1, byteArrayOf(0x80.toByte(), 0, 0, 0)) // ACCESS = 0x80
        } finally {
            nfcA.close()
        }
    }

    /// Removes NTAG password protection before formatting. Throws a descriptive
    /// error when the tag is protected but the password is missing or wrong.
    private fun unprotectTag(tag: Tag, keyA: String) {
        if (!isNtag(tag)) return
        val nfcA = NfcA.get(tag) ?: return
        nfcA.connect()
        try {
            val cfg = readNtagConfig(nfcA) ?: return
            // READ cfg0 returns pages [cfg0..cfg0+3]; byte 3 is AUTH0.
            val cfgResp = nfcA.transceive(byteArrayOf(0x30.toByte(), cfg.cfg0.toByte())) ?: return
            val auth0 = cfgResp.getOrNull(3)?.toInt()?.and(0xFF) ?: return
            if (auth0 == 0xFF) return // already unprotected

            if (keyA.isEmpty()) {
                throw Exception("标签已加密，请先在设置中填写标签密码")
            }
            val pwd = passwordTo6Bytes(keyA).copyOf(4)
            val authed = try {
                val pack = nfcA.transceive(byteArrayOf(0x1B.toByte(), pwd[0], pwd[1], pwd[2], pwd[3]))
                pack != null && pack.size == 2
            } catch (_: Exception) {
                false
            }
            if (!authed) {
                throw Exception("密码错误，无法解除标签保护")
            }
            writeNtagPage(nfcA, cfg.cfg0, byteArrayOf(0, 0, 0, 0xFF.toByte())) // AUTH0 = 0xFF
            writeNtagPage(nfcA, cfg.cfg1, ByteArray(4))                         // ACCESS = 0x00
        } finally {
            nfcA.close()
        }
    }

    /// Applies sector-level tamper protection to a MIFARE Classic tag: the NDEF
    /// payload stays readable via Key A while writing requires Key B. Sector 0
    /// (the MAD) is left untouched so Android can still locate the NDEF data.
    private fun protectClassic(tag: Tag, keyA: String, keyB: String) {
        val mfc = MifareClassic.get(tag) ?: return
        val keyABytes = passwordTo6Bytes(keyA)
        val keyBBytes = passwordTo6Bytes(keyB)
        Thread.sleep(50) // let the tag settle after the NDEF write
        mfc.connect()
        try {
            var changed = false
            for (sector in 1 until mfc.sectorCount) {
                val trailerBlock = mfc.sectorToBlock(sector) + mfc.getBlockCountInSector(sector) - 1
                if (!authenticateClassic(mfc, sector)) continue
                mfc.writeBlock(trailerBlock, buildClassicTrailer(keyABytes, classicProtectAccess, keyBBytes))
                changed = true
            }
            if (!changed) throw Exception("无法认证 MIFARE Classic 扇区，密钥未设置")
        } finally {
            mfc.close()
        }
    }

    /// Removes the MIFARE Classic protection by authenticating with Key B and
    /// restoring the factory transport configuration.
    private fun unprotectClassic(tag: Tag, keyB: String) {
        val mfc = MifareClassic.get(tag) ?: return
        val keyBBytes = passwordTo6Bytes(keyB)
        mfc.connect()
        try {
            for (sector in 1 until mfc.sectorCount) {
                val trailerBlock = mfc.sectorToBlock(sector) + mfc.getBlockCountInSector(sector) - 1
                if (!mfc.authenticateSectorWithKeyB(sector, keyBBytes)) continue
                mfc.writeBlock(trailerBlock, buildClassicTrailer(classicFactoryKey, classicFactoryAccess, classicFactoryKey))
            }
        } finally {
            mfc.close()
        }
    }

    /// Authenticates a sector, trying the NDEF, MAD and factory keys on both Key
    /// A and Key B so a freshly-formatted tag can be reached regardless of the
    /// exact key layout the platform's NDEF formatter produced.
    private fun authenticateClassic(mfc: MifareClassic, sector: Int): Boolean {
        val keys = listOf(classicFormatKeyA, classicMadKey, classicFactoryKey)
        for (key in keys) {
            if (mfc.authenticateSectorWithKeyA(sector, key)) return true
            if (mfc.authenticateSectorWithKeyB(sector, key)) return true
        }
        return false
    }

    /// Builds a 16-byte MIFARE Classic sector trailer from key A, access bits
    /// (4 bytes) and key B.
    private fun buildClassicTrailer(keyA: ByteArray, access: ByteArray, keyB: ByteArray): ByteArray {
        val trailer = ByteArray(16)
        System.arraycopy(keyA, 0, trailer, 0, 6)
        System.arraycopy(access, 0, trailer, 6, 4)
        System.arraycopy(keyB, 0, trailer, 10, 6)
        return trailer
    }

    /// SHA-256 fingerprint of the app's first signing certificate.
    private fun appSignatureSha256(): String? {
        return try {
            val signers = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                    .signingInfo?.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures
            }
            val cert = signers?.firstOrNull() ?: return null
            MessageDigest.getInstance("SHA-256")
                .digest(cert.toByteArray())
                .joinToString("") { "%02x".format(it.toInt() and 0xFF) }
        } catch (_: Exception) {
            null
        }
    }

    /// An external-type NDEF record carrying this app's package name and
    /// signing-certificate fingerprint, used to recognise a tag on a later scan.
    private fun buildIdentityRecord(): NdefRecord {
        val json = JSONObject()
            .put("package", packageName)
            .put("signature", appSignatureSha256() ?: "")
            .toString()
        return NdefRecord.createExternal(identityDomain, identityType, json.toByteArray(Charsets.UTF_8))
    }

    /// True when the intent's NDEF payload carries our identity record with a
    /// matching package name and signature. Tags without an identity record are
    /// treated as legacy/foreign URIs and still allowed through.
    private fun matchesAppIdentity(intent: Intent): Boolean {
        val messages = intent.getParcelableArrayExtra(NfcAdapter.EXTRA_NDEF_MESSAGES) ?: return true
        for (item in messages) {
            val message = item as? NdefMessage ?: continue
            for (record in message.records) {
                if (record.tnf != NdefRecord.TNF_EXTERNAL_TYPE) continue
                if (String(record.type, Charsets.UTF_8) != identityFullType) continue
                val expected = appSignatureSha256() ?: return false
                return try {
                    val json = JSONObject(String(record.payload, Charsets.UTF_8))
                    json.optString("package") == packageName && json.optString("signature") == expected
                } catch (_: Exception) {
                    false
                }
            }
        }
        return true
    }

    private fun stopNfc() {
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
