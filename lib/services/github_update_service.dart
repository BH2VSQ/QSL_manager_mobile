import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class GitHubReleaseAsset {
  const GitHubReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });

  final String name;
  final String downloadUrl;
  final int size;
}

class GitHubReleaseInfo {
  const GitHubReleaseInfo({
    required this.tagName,
    required this.name,
    required this.body,
    required this.htmlUrl,
    required this.publishedAt,
    required this.assets,
  });

  final String tagName;
  final String name;
  final String body;
  final String htmlUrl;
  final DateTime? publishedAt;
  final List<GitHubReleaseAsset> assets;

  String get version => normalizeVersion(tagName);
  int get buildNumber => parseBuildNumber(tagName);
  String get versionWithBuild => buildNumber > 0 ? '${version}+$buildNumber' : version;

  GitHubReleaseAsset? get apkAsset {
    final apk = assets.where((asset) => asset.name.toLowerCase().endsWith('.apk')).toList(growable: false);
    if (apk.isEmpty) return null;
    final preferred = apk.where((asset) => asset.name.toLowerCase().contains('qslmm')).toList(growable: false);
    return preferred.isNotEmpty ? preferred.first : apk.first;
  }
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.release,
  });

  final String currentVersion;
  final int currentBuildNumber;
  final GitHubReleaseInfo? release;

  bool get hasUpdate {
    final latest = release;
    if (latest == null) return false;
    final versionComparison = compareVersions(latest.version, currentVersion);
    if (versionComparison != 0) return versionComparison > 0;
    return latest.buildNumber > currentBuildNumber;
  }
}

class GithubUpdateService {
  GithubUpdateService({http.Client? client}) : _client = client ?? http.Client();

  static const githubOwner = 'BH2VSQ';
  static const githubRepo = 'QSL_manager_mobile';
  static const apiVersion = '2026-03-10';

  final http.Client _client;

  void dispose() => _client.close();

  Uri get latestReleaseUri => Uri.parse('https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest');

  Future<UpdateCheckResult> checkLatest() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = normalizeVersion(packageInfo.version);
    final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? parseBuildNumber(packageInfo.version);
    final response = await _client.get(
      latestReleaseUri,
      headers: {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': apiVersion,
        'User-Agent': 'QSLMM/$currentVersion',
      },
    );

    if (response.statusCode == 404) {
      throw const GithubUpdateException('GitHub Release 尚未发布或仓库地址不存在。');
    }
    if (response.statusCode != 200) {
      String detail = 'HTTP ${response.statusCode}';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['message'] != null) detail = '$detail：${decoded['message']}';
      } catch (_) {}
      throw GithubUpdateException('检查更新失败：$detail');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw const GithubUpdateException('GitHub 返回的数据格式无效。');

    final assetsRaw = decoded['assets'];
    final assets = assetsRaw is List
        ? assetsRaw.whereType<Map>().map((raw) {
            return GitHubReleaseAsset(
              name: (raw['name'] ?? '').toString(),
              downloadUrl: (raw['browser_download_url'] ?? '').toString(),
              size: raw['size'] is num ? (raw['size'] as num).toInt() : 0,
            );
          }).where((asset) => asset.name.isNotEmpty && asset.downloadUrl.isNotEmpty).toList(growable: false)
        : const <GitHubReleaseAsset>[];

    final release = GitHubReleaseInfo(
      tagName: (decoded['tag_name'] ?? '').toString(),
      name: (decoded['name'] ?? decoded['tag_name'] ?? '').toString(),
      body: (decoded['body'] ?? '').toString(),
      htmlUrl: (decoded['html_url'] ?? '').toString(),
      publishedAt: DateTime.tryParse((decoded['published_at'] ?? '').toString()),
      assets: assets,
    );

    return UpdateCheckResult(
      currentVersion: currentVersion,
      currentBuildNumber: currentBuildNumber,
      release: release,
    );
  }

  Future<File> downloadApk(
    GitHubReleaseAsset asset, {
    required void Function(int received, int total) onProgress,
  }) async {
    final directory = await getTemporaryDirectory();
    final updateDir = Directory('${directory.path}${Platform.pathSeparator}qslmm_updates');
    await updateDir.create(recursive: true);

    final safeName = asset.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final target = File('${updateDir.path}${Platform.pathSeparator}$safeName');
    final partial = File('${target.path}.part');
    if (await partial.exists()) await partial.delete();

    final request = http.Request('GET', Uri.parse(asset.downloadUrl));
    request.headers.addAll(const {
      'Accept': 'application/octet-stream',
      'User-Agent': 'QSLMM',
    });

    final response = await _client.send(request);
    if (response.statusCode != 200) {
      throw GithubUpdateException('下载更新失败：HTTP ${response.statusCode}');
    }

    final total = response.contentLength ?? asset.size;
    var received = 0;
    final sink = partial.openWrite();
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, total);
      }
    } finally {
      await sink.close();
    }

    if (total > 0 && received != total) {
      throw const GithubUpdateException('更新文件下载不完整，请重试。');
    }

    if (await target.exists()) await target.delete();
    await partial.rename(target.path);
    return target;
  }

  Future<bool> installApk(File apk) async {
    try {
      final result = await const MethodChannel('qslmm/app_update').invokeMethod<bool>('installApk', {'path': apk.path});
      return result ?? false;
    } on PlatformException catch (error) {
      throw GithubUpdateException(error.message ?? error.code);
    }
  }
}

class GithubUpdateException implements Exception {
  const GithubUpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}

String normalizeVersion(String value) {
  var v = value.trim().toLowerCase();
  if (v.startsWith('v')) v = v.substring(1);
  final dash = v.indexOf('-');
  if (dash >= 0) v = v.substring(0, dash);
  final plus = v.indexOf('+');
  if (plus >= 0) v = v.substring(0, plus);
  return v;
}

int parseBuildNumber(String value) {
  final match = RegExp(r'\+(\d+)').firstMatch(value.trim());
  return int.tryParse(match?.group(1) ?? '') ?? 0;
}

int compareVersions(String a, String b) {
  final aa = normalizeVersion(a).split('.').map((part) => int.tryParse(part) ?? 0).toList();
  final bb = normalizeVersion(b).split('.').map((part) => int.tryParse(part) ?? 0).toList();
  final length = aa.length > bb.length ? aa.length : bb.length;
  for (var i = 0; i < length; i++) {
    final x = i < aa.length ? aa[i] : 0;
    final y = i < bb.length ? bb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}
