import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../models/address_entry.dart';

String normalizeApiBaseUrl(String input) {
  var value = input.trim();
  if (value.isEmpty) throw const FormatException('服务器地址不能为空');
  if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(value)) {
    value = 'http://$value';
  }

  final parsed = Uri.tryParse(value);
  if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
    throw const FormatException('服务器地址格式无效，例如 192.168.1.20:7055');
  }

  // The current server exposes the web UI on 7054 and the REST API on 7055.
  // Accepting the web port here is convenient for mobile users and avoids a
  // misleading 404 when they paste the browser address.
  var uri = parsed;
  if (uri.port == 7054 && (uri.path.isEmpty || uri.path == '/' || uri.path == '/api')) {
    uri = uri.replace(port: 7055);
  }

  var path = uri.path.replaceFirst(RegExp(r'/+$'), '');
  // Accept both the API root and a common health URL pasted from a browser.
  if (path.endsWith('/api/health')) {
    path = path.substring(0, path.length - '/health'.length);
  } else if (path == '/health') {
    path = '/api';
  } else if (path.isEmpty || path == '/') {
    path = '/api';
  } else if (path != '/api' && !path.endsWith('/api')) {
    path = '$path/api';
  }

  return uri.replace(path: path, query: '', fragment: '').toString().replaceFirst(RegExp(r'[/?#]+$'), '');
}

class QslApiException implements Exception {
  const QslApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => statusCode == null ? message : '$statusCode: $message';
}

class QslApi {
  QslApi({required String baseUrl}) : _baseUrl = normalizeApiBaseUrl(baseUrl);

  String _baseUrl;

  String get baseUrl => _baseUrl;

  Uri get healthUrl => _uri('/health');

  final http.Client _client = http.Client();

  void setBaseUrl(String value) {
    _baseUrl = normalizeApiBaseUrl(value);
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    // Never concatenate a route onto a raw URI string. In Dart, a URI
    // containing '#...' treats that portion as a fragment, which can turn
    // '/health' into '/api?#/health' instead of '/api/health'. Build the
    // request from the parsed API root and append only to the URI path.
    final root = Uri.parse(_baseUrl).replace(query: '', fragment: '');
    final cleanPath = path.replaceFirst(RegExp(r'^/+'), '');
    final rootPath = root.path.replaceFirst(RegExp(r'/+$'), '');
    final joinedPath = cleanPath.isEmpty
        ? (rootPath.isEmpty ? '/' : rootPath)
        : '${rootPath.isEmpty ? '' : rootPath}/$cleanPath';

    final filtered = <String, String>{};
    if (query != null) {
      for (final entry in query.entries) {
        if (entry.value == null || entry.value.toString().isEmpty) continue;
        filtered[entry.key] = entry.value.toString();
      }
    }

    return root.replace(
      path: joinedPath,
      queryParameters: filtered.isEmpty ? null : filtered,
      query: filtered.isEmpty ? '' : null,
      fragment: '',
    );
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    final uri = _uri(path, query);
    late http.Response response;

    if (fileBytes != null) {
      final request = http.MultipartRequest('POST', uri);
      request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName ?? 'import.adi'));
      final streamed = await request.send();
      response = await http.Response.fromStream(streamed);
    } else {
      final headers = <String, String>{'Accept': 'application/json'};
      if (body != null) headers['Content-Type'] = 'application/json';
      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: headers);
        case 'POST':
          response = await _client.post(uri, headers: headers, body: body == null ? null : jsonEncode(body));
        case 'PUT':
          response = await _client.put(uri, headers: headers, body: body == null ? null : jsonEncode(body));
        case 'DELETE':
          response = await _client.delete(uri, headers: headers, body: body == null ? null : jsonEncode(body));
        default:
          throw UnsupportedError('HTTP method: $method');
      }
    }

    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = response.body;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (decoded is Map<String, dynamic>) {
        throw QslApiException(
          '${(decoded['error'] ?? decoded['message'] ?? '请求失败')}\n${uri.toString()}',
          statusCode: response.statusCode,
        );
      }
      throw QslApiException('请求失败：HTTP ${response.statusCode}\n${uri.toString()}', statusCode: response.statusCode);
    }
    if (decoded is Map<String, dynamic> && decoded['success'] == false) {
      throw QslApiException((decoded['error'] ?? decoded['message'] ?? '操作失败').toString());
    }
    return decoded;
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  dynamic _data(dynamic value) {
    final map = _map(value);
    return map.containsKey('data') ? map['data'] : value;
  }

  Future<Map<String, dynamic>> health() async => _map(await _request('GET', '/health'));

  Future<DashboardStats> dashboard() async {
    final data = _map(_data(await _request('GET', '/stats/dashboard')));
    return DashboardStats.fromJson(data);
  }

  Future<List<Map<String, dynamic>>> recentActivity({int limit = 10}) async {
    final raw = _data(await _request('GET', '/stats/recent-activity', query: {'limit': limit}));
    if (raw is List) return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final map = _map(raw);
    final list = map['activities'] ?? map['items'] ?? [];
    if (list is! List) return const [];
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<({List<QsoLog> logs, int total, int pages})> logs({
    int page = 1,
    int limit = 30,
    String myCallsign = '',
    String stationCallsign = '',
    String mode = '',
    String band = '',
    String qslId = '',
  }) async {
    final raw = _map(await _request('GET', '/logs', query: {
      'page': page,
      'limit': limit,
      'my_callsign': myCallsign,
      'station_callsign': stationCallsign,
      'mode': mode,
      'band': band,
      'qsl_id': qslId,
    }));
    final data = _map(_data(raw));
    final list = data['logs'] is List ? data['logs'] as List : const [];
    final pagination = _map(raw['pagination']);
    return (
      logs: list.whereType<Map>().map((e) => QsoLog.fromJson(Map<String, dynamic>.from(e))).toList(),
      total: (pagination['total'] ?? data['total'] ?? list.length) is num
          ? ((pagination['total'] ?? data['total'] ?? list.length) as num).toInt()
          : 0,
      pages: (pagination['pages'] ?? 1) is num ? ((pagination['pages'] ?? 1) as num).toInt() : 1,
    );
  }

  Future<QsoLog> getLog(int id) async {
    final data = _map(_data(await _request('GET', '/logs/$id')));
    return QsoLog.fromJson(data);
  }

  Future<void> updateLog(int id, Map<String, dynamic> payload) async {
    await _request('PUT', '/logs/$id', body: payload);
  }

  Future<List<QslCard>> cardsForLog(int logId) async {
    final raw = _data(await _request('GET', '/qsl/by-log/$logId'));
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => QslCard.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
  }

  Future<List<QsoLog>> logsForCard(String qslId) async {
    final raw = _data(await _request('GET', '/qsl/${Uri.encodeComponent(qslId)}/logs'));
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => QsoLog.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
  }

  /// Upload an ADIF file to the server.
  ///
  /// The QSLCard-Manager API expects the file as a multipart field named
  /// `file` at POST /api/logs/import.
  Future<void> importAdifFromBytes(Uint8List bytes, String fileName) async {
    await _request(
      'POST',
      '/logs/import',
      fileBytes: bytes,
      fileName: fileName,
    );
  }

  Future<List<QslCard>> searchCards({String prefix = '', String status = ''}) async {
    final raw = _data(await _request('GET', '/qsl/search', query: {'prefix': prefix, 'status': status}));
    final list = raw is List ? raw : _map(raw)['cards'] ?? [];
    if (list is! List) return const [];
    return list.whereType<Map>().map((e) => QslCard.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<QslCard> getCard(String qslId) async => QslCard.fromJson(_map(_data(await _request('GET', '/qsl/${Uri.encodeComponent(qslId)}'))));

  Future<Map<String, dynamic>> generateCards({
    required List<int> logIds,
    required String direction,
    required String mode,
    String qslMessage = 'PSE',
  }) async {
    return _map(await _request('POST', '/qsl/generate', body: {
      'log_ids': logIds,
      'direction': direction,
      'mode': mode,
      if (direction == 'TC') 'qsl_message': qslMessage,
    }));
  }

  Future<Map<String, dynamic>> addPrintQueue({
    required String qslId,
    required String direction,
    required List<int> logIds,
    String qslMessage = 'PSE',
  }) async {
    return _map(await _request('POST', '/print/queue', body: {
      'type': 'qsl_label',
      'qsl_id': qslId,
      'layout': direction == 'TC' ? 1 : 2,
      'log_ids': logIds,
      'qsl_message': qslMessage,
    }));
  }

  Future<Map<String, dynamic>> scanCard(String qslId) async => _map(await _request('POST', '/qsl/scan', body: {'qsl_id': qslId}));

  Future<void> removeCardLog(String qslId, int logId) async {
    await _request('DELETE', '/qsl/$qslId/log/$logId');
  }


  Future<({List<AddressEntry> entries, int total, int pages})> addresses({int page = 1, int limit = 30, String search = ''}) async {
    final raw = await _request('GET', '/address', query: {
      'page': page,
      'limit': limit,
      'search': search,
    });

    // The web client receives response.data directly as an array.  Accept
    // both that shape and an object wrapper such as {addresses: [...]} so
    // the mobile client stays compatible with the current API.
    final unwrapped = _data(raw);
    final rawMap = _map(raw);
    final dataMap = _map(unwrapped);
    final rows = unwrapped is List
        ? unwrapped
        : (dataMap['addresses'] ?? dataMap['items'] ?? []);
    final pagination = _map(rawMap['pagination'] ?? dataMap['pagination']);
    final list = rows is List ? rows : const [];
    final totalValue = pagination['total'] ?? dataMap['total'] ?? rawMap['total'] ?? list.length;
    final pagesValue = pagination['pages'] ?? dataMap['pages'] ?? rawMap['pages'] ?? 1;
    return (
      entries: list
          .whereType<Map>()
          .map((e) => AddressEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      total: totalValue is num ? totalValue.toInt() : int.tryParse(totalValue.toString()) ?? list.length,
      pages: pagesValue is num ? pagesValue.toInt() : int.tryParse(pagesValue.toString()) ?? 1,
    );
  }

  Future<AddressEntry> address(String callsign) async => AddressEntry.fromJson(_map(_data(await _request('GET', '/address/callsign/${Uri.encodeComponent(callsign)}'))));

  Future<void> createAddress(Map<String, dynamic> payload) async => _request('POST', '/address', body: payload);

  Future<void> updateAddress(String callsign, Map<String, dynamic> payload) async => _request('POST', '/address', body: {'callsign': callsign, ...payload});

  Future<void> deleteAddress(String callsign) async => _request('DELETE', '/address/$callsign');

  Future<AddressEntry?> defaultSender() async {
    try {
      final map = _map(_data(await _request('GET', '/address/sender/default')));
      if (map.isEmpty) return null;
      return AddressEntry.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> setDefaultSender(Map<String, dynamic> payload) async => _request('PUT', '/address/sender/default', body: payload);

  /// Push an address label to the server-side print queue.
  ///
  /// `address` and `country` are independent address-book fields.
  /// The mobile client never derives one from the other. The address is
  /// submitted exactly as entered; `country` is included only when the user
  /// actually provided a non-empty country/region value.
  Future<Map<String, dynamic>> printAddressLabel(
    AddressEntry entry, {
    required String direction,
  }) async {
    if (direction != 'FROM' && direction != 'TO') {
      throw ArgumentError.value(direction, 'direction', '必须为 FROM 或 TO');
    }

    final address = <String, dynamic>{
      'name': entry.name.trim(),
      'address': entry.address.trim(),
      'zip': entry.postalCode.trim(),
      'phone': entry.phone.trim(),
      'type': direction == 'FROM' ? 'sender' : 'receiver',
      'direction': direction,
    };

    final country = entry.country.trim();
    if (country.isNotEmpty) {
      address['country'] = country;
    }

    return _map(await _request('POST', '/print/queue', body: {
      'type': 'address_label',
      'direction': direction,
      if (direction == 'FROM') 'sender': address,
      if (direction == 'TO') 'receiver': address,
    }));
  }

  Future<Map<String, dynamic>> config() async => _map(_data(await _request('GET', '/config')));

  Future<void> updateConfig(Map<String, dynamic> payload) async => _request('PUT', '/config', body: payload);

  Future<List<String>> callsigns() async {
    final raw = _data(await _request('GET', '/config/callsigns'));
    if (raw is List) return raw.map((e) => e.toString()).toList();
    final list = _map(raw)['callsigns'] ?? [];
    if (list is! List) return const [];
    return list.map((e) => e.toString()).toList();
  }

}
