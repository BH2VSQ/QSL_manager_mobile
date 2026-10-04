import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/app_theme.dart';
import '../widgets/console_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController baseUrl;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    baseUrl = TextEditingController(text: widget.controller.baseUrl);
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await widget.controller.setBaseUrl(baseUrl.text);
      baseUrl.text = widget.controller.baseUrl;
      final online = await widget.controller.checkHealth();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(online ? '服务器地址已保存，连接正常' : '服务器地址已保存，但当前无法连接')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    baseUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final online = widget.controller.online;
    return Scaffold(
      appBar: AppBar(title: const Text('设置 // 控制台')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const ConsoleTitle(kicker: '系统 / 设置', title: '服务器连接'),
          const SizedBox(height: 14),
          ConsolePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(label: '服务器地址'),
                const SizedBox(height: 11),
                TextField(
                  controller: baseUrl,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'API 地址',
                    hintText: '例如 192.168.1.20:7055',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '可填写 IP:端口、完整 API 地址或浏览器地址。未填写协议时默认使用 HTTP；本项目 Web 为 7054、API 为 7055。',
                  style: TextStyle(fontSize: 9, color: AppPalette.textDim, height: 1.5),
                ),
                const SizedBox(height: 10),
                Text(
                  '当前生效：${widget.controller.baseUrl}',
                  style: const TextStyle(fontSize: 9, color: AppPalette.cyan, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(saving ? '保存中…' : '保存并连接服务器'),
            ),
          ),
          const SizedBox(height: 16),
          ConsolePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(label: '连接诊断'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: online ? AppPalette.cyan : AppPalette.pink),
                    ),
                    const SizedBox(width: 7),
                    Text(online ? 'API 已连接' : 'API 未连接', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Flexible(
                      child: Text(widget.controller.api.baseUrl, textAlign: TextAlign.end, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8, color: AppPalette.textDim)),
                    ),
                  ],
                ),
                if (widget.controller.lastError != null) ...[
                  const SizedBox(height: 8),
                  Text(widget.controller.lastError!, style: const TextStyle(fontSize: 9, color: AppPalette.pink, height: 1.4)),
                ],
                if (widget.controller.lastHealthUrl != null) ...[
                  const SizedBox(height: 6),
                  Text('最近检测：${widget.controller.lastHealthUrl}', style: const TextStyle(fontSize: 8, color: AppPalette.textDim, height: 1.4)),
                ],
                const SizedBox(height: 10),
                ConsoleAction(icon: Icons.sync, label: '测试连接', onPressed: widget.controller.checkHealth),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ConsolePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(label: '显示模式'),
                const SizedBox(height: 6),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: widget.controller.darkMode,
                  onChanged: (value) => widget.controller.setDarkMode(value),
                  title: Text(widget.controller.darkMode ? '夜间模式' : '白天模式'),
                  subtitle: Text(widget.controller.darkMode ? '深色控制台配色，适合低光环境' : '浅色控制台配色，适合白天使用'),
                  secondary: Icon(widget.controller.darkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined, color: AppPalette.cyan),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'QSL Manager Mobile 0.1.5  •  REST API  •  无认证',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 8, color: AppPalette.textDim, letterSpacing: .5),
          ),
        ],
      ),
    );
  }
}
