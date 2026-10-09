import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:ndef/ndef.dart' as ndef;

/// Thin wrapper over the native NFC capabilities used by QSLMM.
///
/// NDEF tag read/write goes through the `flutter_nfc_kit` plugin, while a
/// small platform channel (`qslmm/nfc`) covers the pieces the plugin does not
/// expose: a confirmation beep and the deep-link URI handed to the app when a
/// written tag is scanned back with QSLMM installed.
class NfcService {
  NfcService._();

  static const MethodChannel _channel = MethodChannel('qslmm/nfc');

  /// Whether the device has NFC hardware that the OS exposes to us.
  static Future<NFCAvailability> availability() => FlutterNfcKit.nfcAvailability;

  /// Whether the device has NFC hardware at all.
  static Future<bool> isNfcSupported() async =>
      (await availability()) != NFCAvailability.not_supported;

  /// Whether NFC hardware is present and switched on.
  static Future<bool> isNfcUsable() async =>
      (await availability()) == NFCAvailability.available;

  /// Whether NFC is currently switched on in system settings.
  static Future<bool> isNfcEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isNfcEnabled') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Plays a short confirmation beep after a card operation finishes.
  static Future<void> beep() async {
    try {
      await _channel.invokeMethod<void>('beep');
    } on MissingPluginException {
      // No-op where the native channel is unavailable (e.g. tests).
    }
  }

  /// Returns and clears any pending NFC/deep-link URI delivered to the app.
  static Future<String?> consumeLaunchUri() async {
    try {
      return await _channel.invokeMethod<String>('consumeLaunchUri');
    } on MissingPluginException {
      return null;
    }
  }

  /// Builds the two-layer NDEF message written to a QSL tag:
  ///
  /// 1. A web query URI (`<queryBaseUrl>/?q=<qslId>`) that any phone can open
  ///    in a browser when the recipient has no management client installed.
  /// 2. An Android Application Record carrying QSLMM's package name, so that a
  ///    phone with QSLMM installed routes the scan straight into the app
  ///    instead of the browser. Android verifies this using the package name
  ///    and its signing signature.
  static List<ndef.NDEFRecord> buildQslLinkMessage({
    required String queryBaseUrl,
    required String qslId,
    required String packageName,
  }) {
    final base = queryBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final url = '$base/?q=${Uri.encodeComponent(qslId)}';
    return <ndef.NDEFRecord>[
      ndef.UriRecord.fromString(url),
      ndef.AARRecord(packageName: packageName),
    ];
  }
}
