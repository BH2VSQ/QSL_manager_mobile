import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/app_theme.dart';
import '../widgets/console_widgets.dart';
import 'address_book_screen.dart';
import 'settings_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.controller});

  final AppController controller;

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
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddressBookScreen(controller: controller))),
        ),
        const SizedBox(height: 8),
        _ControlTile(
          icon: Icons.settings_outlined,
          title: '设置',
          detail: '服务器地址 / 连接诊断',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(controller: controller))),
        ),
      ],
    );
  }
}

class _ControlTile extends StatelessWidget {
  const _ControlTile({required this.icon, required this.title, required this.detail, required this.onTap});

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
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
          const Icon(Icons.chevron_right, color: AppPalette.textDim),
        ]),
      ),
    );
  }
}

