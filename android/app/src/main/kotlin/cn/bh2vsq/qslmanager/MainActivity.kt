package cn.bh2vsq.qslmanager

import android.app.PendingIntent
import android.content.Intent
import android.content.IntentFilter
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

    // Active write/format session, delivered to onNewIntent via foreground
    // dispatch (reader mode is unreliable for MIFARE Classic writes).
    private var nfcOperation: String? = null // "write" or "format"
    private var nfcWriteUrl: String? = null
    private var nfcWritePassword: String? = null

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
    private val classicProtectAccess = byteArrayOf(0x78, 0x77, 0x88.toByte(), 0x00)
    private val classicFactoryAccess = byteArrayOf(0xFF.toByte(), 0x07, 0x80.toByte(), 0x69)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (nfcOperation != null) {
            handleNfcTag(intent)
        } else {
            handleIntent(intent)
        }
    }

    /// Forwards a tag detected during an active write/format session.
    private fun handleNfcTag(intent: Intent) {
        val operation = nfcOperation ?: return
        val tag: Tag? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(NfcAdapter.EXTRA_TAG, Tag::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
        }
        if (tag == null) return
        val url = nfcWriteUrl
        val password = nfcWritePassword ?: ""
        if (operation == "write") {
            stopNfc() // single-shot: stop accepting further tags
        }
        nfcHandler?.post { writeTag(tag, operation, url, password) }
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
                    val password = call.argument<String>("password") ?: ""
                    startNfcOperation("write", url, password, result)
                }
                "startNfcFormat" -> {
                    val password = call.argument<String>("password") ?: ""
                    startNfcOperation("format", null, password, result)
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

    private fun startNfcOperation(mode: String, url: String?, password: String, result: MethodChannel.Result) {
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
        nfcWritePassword = password

        val intent = Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val filters = arrayOf(
            IntentFilter(NfcAdapter.ACTION_TECH_DISCOVERED),
            IntentFilter(NfcAdapter.ACTION_NDEF_DISCOVERED).apply { addDataType("*/*") },
            IntentFilter(NfcAdapter.ACTION_TAG_DISCOVERED),
        )
        val techLists = arrayOf(
            arrayOf(NfcA::class.java.name),
            arrayOf(MifareClassic::class.java.name),
            arrayOf(MifareUltralight::class.java.name),
        )
        adapter.enableForegroundDispatch(this, pendingIntent, filters, techLists)

        result.success(null)
    }

    private fun writeTag(tag: Tag, mode: String, url: String?, password: String) {
        try {
            // For formatting, drop any password protection first so the empty
            // record below can be written back to a protected tag.
            if (mode == "format") {
                if (MifareClassic.get(tag) != null) {
                    unprotectClassic(tag, password)
                } else {
                    unprotectTag(tag, password)
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
            } else if (MifareClassic.get(tag) != null) {
                // MIFARE Classic: write directly (MAD + TLV) because
                // NdefFormatable.format() is unreliable on many devices.
                written = writeClassicNdef(tag, message)
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
                if (mode == "write" && password.isNotEmpty()) {
                    try {
                        if (MifareClassic.get(tag) != null) {
                            protectClassic(tag, password)
                        } else {
                            protectTag(tag, password)
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

    /// Derives the key from the user-entered password using MD5, matching NFC
    /// Tools. The first `length` bytes of the MD5 hash are used: 4 for NTAG's
    /// PWD, 6 for a MIFARE Classic sector key.
    private fun passwordToKey(password: String, length: Int): ByteArray =
        MessageDigest.getInstance("MD5")
            .digest(password.toByteArray(Charsets.UTF_8))
            .copyOf(length)

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
    private fun protectTag(tag: Tag, password: String) {
        if (!isNtag(tag)) return
        val nfcA = NfcA.get(tag) ?: return
        nfcA.connect()
        try {
            val cfg = readNtagConfig(nfcA) ?: return
            val pwd = passwordToKey(password, 4)
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
    private fun unprotectTag(tag: Tag, password: String) {
        if (!isNtag(tag)) return
        val nfcA = NfcA.get(tag) ?: return
        nfcA.connect()
        try {
            val cfg = readNtagConfig(nfcA) ?: return
            // READ cfg0 returns pages [cfg0..cfg0+3]; byte 3 is AUTH0.
            val cfgResp = nfcA.transceive(byteArrayOf(0x30.toByte(), cfg.cfg0.toByte())) ?: return
            val auth0 = cfgResp.getOrNull(3)?.toInt()?.and(0xFF) ?: return
            if (auth0 == 0xFF) return // already unprotected

            if (password.isEmpty()) {
                throw Exception("标签已加密，请先在设置中填写标签密码")
            }
            val pwd = passwordToKey(password, 4)
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
    private fun protectClassic(tag: Tag, password: String) {
        val mfc = MifareClassic.get(tag) ?: return
        val keyB = passwordToKey(password, 6)
        Thread.sleep(50) // let the tag settle after the NDEF write
        mfc.connect()
        try {
            var changed = false
            for (sector in 1 until mfc.sectorCount) {
                val trailerBlock = mfc.sectorToBlock(sector) + mfc.getBlockCountInSector(sector) - 1
                if (!authenticateClassic(mfc, sector)) continue
                // Keep Key A as the NDEF read key; Key B holds the password, so
                // data stays readable but writing requires the password.
                mfc.writeBlock(trailerBlock, buildClassicTrailer(classicFormatKeyA, classicProtectAccess, keyB))
                changed = true
            }
            if (!changed) throw Exception("无法认证 MIFARE Classic 扇区，密钥未设置")
        } finally {
            mfc.close()
        }
    }

    /// Removes the MIFARE Classic protection by authenticating with Key B and
    /// restoring the factory transport configuration.
    private fun unprotectClassic(tag: Tag, password: String) {
        val mfc = MifareClassic.get(tag) ?: return
        val keyB = passwordToKey(password, 6)
        mfc.connect()
        try {
            for (sector in 1 until mfc.sectorCount) {
                val trailerBlock = mfc.sectorToBlock(sector) + mfc.getBlockCountInSector(sector) - 1
                if (!mfc.authenticateSectorWithKeyB(sector, keyB)) continue
                mfc.writeBlock(trailerBlock, buildClassicTrailer(classicFormatKeyA, classicFactoryAccess, classicFormatKeyA))
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

    // MIFARE Classic NDEF (MAD) format: sector 0 holds the application directory,
    // data sectors 1..N-1 hold the NDEF TLV. All sectors are mapped to the NDEF
    // application (AID 0x0003 -> entry bytes 0x03 0x00).
    private val madBlock1 = byteArrayOf(
        0x01, 0x00, 0x00,
        0x03, 0x00, 0x03, 0x00, 0x03, 0x00, 0x03, 0x00, 0x03, 0x00, 0x03, 0x00,
        0x00
    )
    private val madBlock2 = ByteArray(16) { if (it % 2 == 0) 0x03 else 0x00 }

    /// Builds an NDEF TLV: 0x03, length (1 or 3 bytes), message, 0xFE terminator.
    private fun buildNdefTlv(ndef: ByteArray): ByteArray {
        val lengthBytes = if (ndef.size < 0xFF) {
            byteArrayOf(ndef.size.toByte())
        } else {
            byteArrayOf(0xFF.toByte(), (ndef.size shr 8).toByte(), ndef.size.toByte())
        }
        val tlv = ByteArray(1 + lengthBytes.size + ndef.size + 1)
        tlv[0] = 0x03.toByte()
        System.arraycopy(lengthBytes, 0, tlv, 1, lengthBytes.size)
        System.arraycopy(ndef, 0, tlv, 1 + lengthBytes.size, ndef.size)
        tlv[tlv.size - 1] = 0xFE.toByte()
        return tlv
    }

    /// Writes an NDEF message directly to a MIFARE Classic tag (MAD + TLV),
    /// bypassing NdefFormatable.format() which throws a spurious IOException on
    /// many devices. Returns true on success.
    private fun writeClassicNdef(tag: Tag, message: NdefMessage): Boolean {
        val mfc = MifareClassic.get(tag) ?: return false
        val tlv = buildNdefTlv(message.toByteArray())
        mfc.connect()
        try {
            // Sector 0: MAD in blocks 1-2 (block 0 is the read-only manufacturer
            // block, block 3 is the trailer).
            if (!authenticateClassic(mfc, 0)) return false
            mfc.writeBlock(mfc.sectorToBlock(0) + 1, madBlock1)
            mfc.writeBlock(mfc.sectorToBlock(0) + 2, madBlock2)

            // Data sectors 1..N-1: the TLV, three 16-byte data blocks per sector.
            var offset = 0
            for (sector in 1 until mfc.sectorCount) {
                if (!authenticateClassic(mfc, sector)) return false
                val base = mfc.sectorToBlock(sector)
                for (i in 0 until 3) {
                    val block = ByteArray(16)
                    for (b in 0 until 16) {
                        block[b] = if (offset < tlv.size) tlv[offset++] else 0x00
                    }
                    mfc.writeBlock(base + i, block)
                }
                if (offset >= tlv.size) break
            }
            return true
        } finally {
            mfc.close()
        }
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
        nfcOperation = null
        nfcWriteUrl = null
        nfcWritePassword = null
        val disable = Runnable {
            try {
                NfcAdapter.getDefaultAdapter(this@MainActivity)?.disableForegroundDispatch(this@MainActivity)
            } catch (_: Exception) {
            }
        }
        // disableForegroundDispatch must run on the main thread. When stopNfc()
        // is called from the main thread, run it synchronously so it cannot race
        // the enableForegroundDispatch that follows; otherwise post to main.
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
