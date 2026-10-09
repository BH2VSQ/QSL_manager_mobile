import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/qsl_api.dart';

class AppController extends ChangeNotifier {
  AppController({required this.preferences, required this.api});

  static const _baseUrlKey = 'api_base_url';
  static const _darkModeKey = 'dark_mode';
  static const _nfcEnabledKey = 'nfc_enabled';
  static const _queryBaseUrlKey = 'nfc_query_base_url';
  static const _nfcKeyAKey = 'nfc_key_a';
  static const _nfcKeyBKey = 'nfc_key_b';

  final SharedPreferencesAsync preferences;
  final QslApi api;

  String baseUrl = 'http://10.0.2.2:7055/api';
  String? lastHealthUrl;
  bool online = false;
  String? lastError;
  bool darkMode = true;
  int connectionRevision = 0;
  bool nfcEnabled = false;
  String queryBaseUrl = '';
  String nfcKeyA = '';
  String nfcKeyB = '';

  static Future<AppController> create() async {
    final prefs = SharedPreferencesAsync();
    final saved = await prefs.getString(_baseUrlKey);
    final baseUrl = normalizeApiBaseUrl(saved ?? 'http://10.0.2.2:7055/api');
    final darkMode = await prefs.getBool(_darkModeKey) ?? true;
    final nfcEnabled = await prefs.getBool(_nfcEnabledKey) ?? false;
    final queryBaseUrl = await prefs.getString(_queryBaseUrlKey) ?? '';
    final nfcKeyA = await prefs.getString(_nfcKeyAKey) ?? '';
    final nfcKeyB = await prefs.getString(_nfcKeyBKey) ?? '';
    return AppController(
      preferences: prefs,
      api: QslApi(baseUrl: baseUrl),
    )
      ..baseUrl = baseUrl
      ..darkMode = darkMode
      ..nfcEnabled = nfcEnabled
      ..queryBaseUrl = queryBaseUrl
      ..nfcKeyA = nfcKeyA
      ..nfcKeyB = nfcKeyB;
  }

  Future<void> setBaseUrl(String value) async {
    final normalized = value.trim().replaceFirst(RegExp(r'/+$'), '');
    if (normalized.isEmpty) {
      throw const FormatException('服务器地址不能为空');
    }
    baseUrl = normalizeApiBaseUrl(normalized);
    api.setBaseUrl(baseUrl);
    online = false;
    lastError = null;
    connectionRevision++;
    await preferences.setString(_baseUrlKey, baseUrl);
    notifyListeners();
  }


  Future<void> setDarkMode(bool value) async {
    darkMode = value;
    await preferences.setBool(_darkModeKey, value);
    notifyListeners();
  }

  Future<void> setNfcEnabled(bool value) async {
    nfcEnabled = value;
    await preferences.setBool(_nfcEnabledKey, value);
    notifyListeners();
  }

  Future<void> setQueryBaseUrl(String value) async {
    queryBaseUrl = value.trim().replaceFirst(RegExp(r'/+$'), '');
    await preferences.setString(_queryBaseUrlKey, queryBaseUrl);
    notifyListeners();
  }

  Future<void> setNfcKeyA(String value) async {
    nfcKeyA = value.trim();
    await preferences.setString(_nfcKeyAKey, nfcKeyA);
    notifyListeners();
  }

  Future<void> setNfcKeyB(String value) async {
    nfcKeyB = value.trim();
    await preferences.setString(_nfcKeyBKey, nfcKeyB);
    notifyListeners();
  }


  Future<bool> checkHealth() async {
    lastHealthUrl = api.healthUrl.toString();
    try {
      await api.health();
      online = true;
      lastError = null;
    } catch (error) {
      online = false;
      lastError = error.toString();
    }
    notifyListeners();
    return online;
  }
}
