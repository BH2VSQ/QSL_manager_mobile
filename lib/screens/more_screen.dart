import 'dart:io';

import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/app_theme.dart';
import '../services/github_update_service.dart';
import '../widgets/console_widgets.dart';
import 'address_book_screen.dart';
import 'nfc_tag_screen.dart';
import 'settings_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final GithubUpdateService _updateService = GithubUpdateService();
  bool checkingUpdate = false;

  @override
  void dispose() {
    _updateService.dispose();
    super.dispose();
  }

  Future<void> _checkForUpdate() async {
    if (checkingUpdate) return;
    setState(() => checkingUpdate = true);
    try {
      final result = await _updateService.checkLatest();
      if (!mounted) return;
      await _showUpdateResult(result);
    } catch (error) {
      if (!mounted) return;
      await _showMessage('检查更新失败', error.toString());
    } finally {
      if (mounted) setState(() => checkingUpdate = false);
    }
  }

  Future<void> _showMessage(String title, String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message, style: const TextStyle(fontSize: 11, height: 1.5)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))],
      ),
    );
  }

  Future<void> _showUpdateResult(UpdateCheckResult result) async {
    final release = result.release;
    if (release == null || !result.hasUpdate) {
      await _showMessage('检查更新', '当前已是最新版本\n\n当前版本：${result.currentVersion}');
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _UpdateDialog(
        result: result,
        service: _updateService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
      children: [
        const ConsoleTitle(kicker: '控制 / 服务', title: '系统功能'),
        const SizedBox(height: 14),
        _ControlTile(
          icon: Icons.contacts_outlined,
          title: '地址簿',
          detail: '台站资料 / 默认寄件信息',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddressBookScreen(controller: widget.controller))),
        ),
        const SizedBox(height: 8),
        _ControlTile(
          icon: Icons.settings_outlined,
          title: '设置',
          detail: '服务器地址 / 连接诊断 / 显示模式 / NFC',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(controller: widget.controller))),
        ),
        if (widget.controller.nfcEnabled) ...[
          const SizedBox(height: 8),
          _ControlTile(
            icon: Icons.nfc,
            title: 'Tag 格式化',
            detail: '清空已写入数据的 NFC 标签',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NfcTagScreen(
                  mode: NfcTagMode.format,
                  title: 'Tag 格式化',
                  instruction: '将已写入数据的 Tag 贴至手机线圈处\n检测到标签后将自动清空',
                  successMessage: '格式化完毕',
                  password: widget.controller.nfcPassword,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        _ControlTile(
          icon: Icons.system_update_outlined,
          title: '检查更新',
          detail: checkingUpdate ? '正在检查 GitHub Release…' : '检查 GitHub Release 是否有新版本',
          onTap: checkingUpdate ? null : _checkForUpdate,
          trailing: checkingUpdate ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : null,
        ),
      ],
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.result, required this.service});

  final UpdateCheckResult result;
  final GithubUpdateService service;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool downloading = false;
  int received = 0;
  int total = 0;
  File? apk;
  String? error;

  GitHubReleaseInfo get release => widget.result.release!;
  GitHubReleaseAsset? get asset => release.apkAsset;

  Future<void> _download() async {
    final selected = asset;
    if (selected == null) {
      setState(() => error = '该 Release 没有 APK 文件。请在 GitHub Release 页面确认已经上传 APK。');
      return;
    }

    setState(() {
      downloading = true;
      error = null;
      received = 0;
      total = selected.size;
    });

    try {
      final file = await widget.service.downloadApk(selected, onProgress: (got, length) {
        if (!mounted) return;
        setState(() {
          received = got;
          total = length;
        });
      });
      if (!mounted) return;
      setState(() {
        apk = file;
        downloading = false;
      });
      await _confirmInstall();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        downloading = false;
        error = e.toString();
      });
    }
  }

  Future<void> _confirmInstall() async {
    final file = apk;
    if (file == null || !mounted) return;
    final install = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('更新已下载'),
        content: Text('${file.path}\n\n是否立即安装 ${release.versionWithBuild}？', style: const TextStyle(fontSize: 10, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('稍后安装')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('安装更新')),
        ],
      ),
    );
    if (install != true) return;

    try {
      final launched = await widget.service.installApk(file);
      if (!mounted) return;
      if (!launched) {
        await _showInstallPermissionHint();
      }
    } catch (e) {
      if (!mounted) return;
      await _showInstallPermissionHint(error: e.toString());
    }
  }

  Future<void> _showInstallPermissionHint({String? error}) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要允许安装未知应用'),
        content: Text(
          [
            ?error,
            'Android 需要允许 QSLMM 安装来自其他来源的 APK。请在系统设置中允许后，再返回本页面点击“安装更新”。',
          ].join('\n\n'),
          style: const TextStyle(fontSize: 11, height: 1.5),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedAsset = asset;
    final progress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.system_update_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('发现新版本 ${release.versionWithBuild}')),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前版本：${widget.result.currentVersion}', style: const TextStyle(fontSize: 10)),
              const SizedBox(height: 4),
              Text('最新版本：${release.versionWithBuild}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
              if (release.publishedAt != null) ...[
                const SizedBox(height: 4),
                Text('发布时间：${release.publishedAt!.toLocal()}', style: const TextStyle(fontSize: 9)),
              ],
              const SizedBox(height: 12),
              const SectionHeader(label: 'Release Notes'),
              const SizedBox(height: 8),
              Text(
                release.body.trim().isEmpty ? '该 Release 未填写更新说明。' : release.body.trim(),
                style: const TextStyle(fontSize: 10, height: 1.5),
              ),
              const SizedBox(height: 12),
              if (selectedAsset == null)
                const StatusTag('未找到 APK', accent: AppPalette.pink)
              else ...[
                Text('安装包：${selectedAsset.name}', style: const TextStyle(fontSize: 9)),
                if (downloading) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: total > 0 ? progress : null),
                  const SizedBox(height: 6),
                  Text('${_formatBytes(received)} / ${_formatBytes(total)}', style: const TextStyle(fontSize: 9, color: AppPalette.textDim)),
                ],
              ],
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: const TextStyle(fontSize: 9, color: AppPalette.pink, height: 1.4)),
              ],
              if (apk != null) ...[
                const SizedBox(height: 10),
                const StatusTag('APK 已下载', accent: AppPalette.cyan),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: downloading ? null : () => Navigator.pop(context), child: const Text('关闭')),
        if (apk != null)
          FilledButton.icon(
            onPressed: downloading ? null : _confirmInstall,
            icon: const Icon(Icons.install_mobile_outlined),
            label: const Text('安装更新'),
          )
        else
          FilledButton.icon(
            onPressed: downloading ? null : _download,
            icon: const Icon(Icons.download_outlined),
            label: Text(downloading ? '下载中…' : '下载更新'),
          ),
      ],
    );
  }

  String _formatBytes(int value) {
    if (value < 1024) return '$value B';
    if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _ControlTile extends StatelessWidget {
  const _ControlTile({required this.icon, required this.title, required this.detail, required this.onTap, this.trailing});

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: enabled ? 1 : .65,
        child: ConsolePanel(
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppPalette.cyan.withValues(alpha: .08),
                border: Border.all(color: AppPalette.cyan.withValues(alpha: .25)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: AppPalette.cyan, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(detail, style: const TextStyle(fontSize: 8, color: AppPalette.textDim)),
            ])),
            ?trailing,
            if (trailing == null) const Icon(Icons.chevron_right, color: AppPalette.textDim),
          ]),
        ),
      ),
    );
  }
}
