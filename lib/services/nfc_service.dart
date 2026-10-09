import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

/// Whether this device has NFC hardware and whether it is switched on.
enum NfcAvailability { notSupported, disabled, available }

/// A single result event emitted while a write/format session is active.
class NfcTagEvent {
  const NfcTagEvent.success(this.mode) : message = null;

  const NfcTagEvent.error(String this.message) : mode = null;

  /// 'write' or 'format', matching the operation that produced a success.
  final String? mode;
  final String? message;

  bool get isSuccess => message == null;
}

/// Thin wrapper over the native NFC capabilities used by QSLMM.
///
/// NDEF writing goes through the `qslmm/nfc` method channel plus the
/// `qslmm/nfc_events` event channel. Unlike `flutter_nfc_kit`, the native side
/// falls back to `NdefFormatable` so MIFARE Classic tags (SAK 0x08) as well as
/// native-NDEF tags (SAK 0x00 / NTAG) can both be written.
class NfcService {
  NfcService._();

  static const MethodChannel _channel = MethodChannel('qslmm/nfc');
  static const EventChannel _eventChannel = EventChannel('qslmm/nfc_events');

  static Stream<NfcTagEvent>? _events;

  /// Broadcast stream of write/format results for the currently active session.
  static Stream<NfcTagEvent> get events {
    _events ??= _eventChannel.receiveBroadcastStream().map((dynamic event) {
      final map = jsonDecode(event as String) as Map<String, dynamic>;
      if (map['type'] == 'success') {
        return NfcTagEvent.success(map['mode']?.toString() ?? '');
      }
      return NfcTagEvent.error(map['message']?.toString() ?? '操作失败');
    });
    return _events!;
  }

  static Future<NfcAvailability> availability() async {
    try {
      final value = await _channel.invokeMethod<String>('getNfcAvailability');
      switch (value) {
        case 'available':
          return NfcAvailability.available;
        case 'disabled':
          return NfcAvailability.disabled;
        default:
          return NfcAvailability.notSupported;
      }
    } on MissingPluginException {
      return NfcAvailability.notSupported;
    }
  }

  /// Whether the device has NFC hardware at all.
  static Future<bool> isNfcSupported() async =>
      (await availability()) != NfcAvailability.notSupported;

  /// Whether NFC hardware is present and switched on.
  static Future<bool> isNfcUsable() async =>
      (await availability()) == NfcAvailability.available;

  /// Starts a one-shot write of a QSL query link (a bare web URI) to the next
  /// tag brought near the phone.
  static Future<void> writeQslTag({required String url}) async {
    await _channel.invokeMethod<void>('startNfcWrite', {'url': url});
  }

  /// Starts a persistent clear/format session; each new tag is cleared until
  /// [stop] is called.
  static Future<void> formatTag() async {
    await _channel.invokeMethod<void>('startNfcFormat');
  }

  /// Stops the current write/format session.
  static Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stopNfc');
    } on MissingPluginException {
      // No-op where the native channel is unavailable (e.g. tests).
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

  /// Builds the web query URL written to the tag: `<queryBaseUrl>/?q=<qslId>`.
  static String buildQueryUrl({required String queryBaseUrl, required String qslId}) {
    final base = queryBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    return '$base/?q=${Uri.encodeComponent(qslId)}';
  }
}
