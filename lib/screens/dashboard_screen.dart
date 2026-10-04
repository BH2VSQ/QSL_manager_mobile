import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/app_theme.dart';
import '../models/models.dart';
import '../services/qsl_api.dart';
import '../widgets/console_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardStats? stats;
  List<Map<String, dynamic>> activity = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final healthy = await widget.controller.checkHealth();
      if (!healthy) {
        throw QslApiException(widget.controller.lastError ?? '服务器连接失败');
      }
      final loadedStats = await widget.controller.api.dashboard();
      final loadedActivity = await widget.controller.api.recentActivity(limit: 8);
      if (mounted) {
        stats = loadedStats;
        activity = loadedActivity;
      }
    } catch (e) {
      if (mounted) {
        error = e.toString();
      }
    }
    if (mounted) setState(() => loading = false);
  }

  String _statusText(String status, String direction) {
    switch (status) {
      case 'pending':
        return direction == 'TC' ? '待出库' : '待入库';
      case 'out_stock':
        return '已发出';
      case 'in_stock':
        return '已收到';
      default:
        return status.isEmpty ? '—' : status;
    }
  }

  String _dateText(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.length == 8) return '${raw.substring(0, 4)}-${raw.substring(4, 6)}-${raw.substring(6, 8)}';
    return raw.isEmpty ? '—' : raw;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
        children: [
          const ConsoleTitle(kicker: '系统 / 总览', title: '运行总览'),
          const SizedBox(height: 14),
          if (error != null)
            ConsolePanel(
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: AppPalette.pink),
                const SizedBox(width: 10),
                Expanded(child: Text(error!, style: const TextStyle(fontSize: 11))),
                IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              ]),
            ),
          if (error != null) const SizedBox(height: 14),
          if (loading && error == null) consoleProgress(),
          if (!loading) ...[
            const SizedBox(height: 2),
            MetricTile(label: 'QSO 数量', value: stats?.totalLogs),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: MetricTile(label: '已发 QSL', value: stats?.sentCards, accent: AppPalette.pink)),
                const SizedBox(width: 8),
                Expanded(child: MetricTile(label: '已收 QSL', value: stats?.receivedCards)),
              ],
            ),
            const SizedBox(height: 8),
            MetricTile(
              label: '待处理',
              value: stats == null ? null : stats!.pendingOut + stats!.pendingIn,
              accent: AppPalette.pink,
            ),
          ],
          const SizedBox(height: 16),
          ConsolePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(label: '最近活动'),
                const SizedBox(height: 10),
                if (activity.isEmpty)
                  const Text('暂无活动记录', style: TextStyle(fontSize: 10, color: AppPalette.textDim))
                else
                  ...activity.take(8).map((item) {
                    final direction = item['direction']?.toString().toUpperCase() == 'RC' ? 'RC' : 'TC';
                    final callsign = item['station_callsign']?.toString().trim() ?? '';
                    final qslId = item['qsl_id']?.toString() ?? '';
                    final status = item['status']?.toString() ?? '';
                    final mode = item['mode']?.toString() ?? '';
                    final date = _dateText(item['qso_date']);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 5),
                            decoration: BoxDecoration(
                              color: direction == 'RC' ? AppPalette.pink : AppPalette.cyan,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${direction == 'RC' ? '收到' : '寄出'} ${callsign.isEmpty ? '未知呼号' : callsign} 的卡片',
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'QSL ID: ${qslId.isEmpty ? '—' : qslId} | 日期: $date | 模式: ${mode.isEmpty ? '—' : mode} | 状态: ${_statusText(status, direction)}',
                                  style: const TextStyle(fontSize: 8.5, color: AppPalette.textDim, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
