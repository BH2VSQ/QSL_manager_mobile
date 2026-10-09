import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/app_theme.dart';
import '../models/models.dart';
import '../services/nfc_service.dart';
import '../widgets/console_widgets.dart';
import 'log_detail_screen.dart';
import 'nfc_tag_screen.dart';

class CardDetailScreen extends StatefulWidget {
  const CardDetailScreen({super.key, required this.controller, required this.qslId});

  final AppController controller;
  final String qslId;

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  QslCard? card;
  bool loading = true;
  bool reprinting = false;
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
      final fresh = await widget.controller.api.getCard(widget.qslId);
      if (mounted) setState(() => card = fresh);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _status(String status, String direction) {
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

  String _date(String value) {
    if (value.length == 8) return '${value.substring(0, 4)}-${value.substring(4, 6)}-${value.substring(6, 8)}';
    return value.isEmpty ? '—' : value;
  }

  Future<void> _reprint() async {
    final current = card;
    if (current == null || reprinting) return;
    String qslMessage = 'PSE';
    if (current.direction == 'TC') {
      final chosen = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('选择补打内容'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: const Text('PSE QSL'), subtitle: const Text('请对方回卡'), onTap: () => Navigator.pop(context, 'PSE')),
              ListTile(title: const Text('QSL TNX'), subtitle: const Text('感谢对方回卡'), onTap: () => Navigator.pop(context, 'TNX')),
            ],
          ),
        ),
      );
      if (chosen == null) return;
      qslMessage = chosen;
    }

    setState(() => reprinting = true);
    try {
      await widget.controller.api.addPrintQueue(
        qslId: current.qslId,
        direction: current.direction,
        logIds: current.logIds,
        qslMessage: qslMessage,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已加入服务器打印队列')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('补打失败：$e')));
    } finally {
      if (mounted) setState(() => reprinting = false);
    }
  }

  Future<void> _openLog(int id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LogDetailScreen(controller: widget.controller, logId: id)),
    );
  }

  Future<void> _writeNfc() async {
    final current = card;
    if (current == null || current.qslId.isEmpty) return;

    if (!await NfcService.isNfcSupported()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('此设备不支持 NFC')));
      return;
    }
    if (!await NfcService.isNfcUsable()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请在系统设置中开启 NFC 后重试')));
      return;
    }
    final base = widget.controller.queryBaseUrl.trim();
    if (base.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先在“设置”中配置 NFC 查询地址')));
      return;
    }

    final url = NfcService.buildQueryUrl(queryBaseUrl: base, qslId: current.qslId);

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NfcTagScreen(
          mode: NfcTagMode.write,
          title: '写入 NFC',
          instruction: '请将 NFC 标签靠近手机背部\n写入卡片 ${current.qslId} 的查询链接',
          url: url,
          keyA: widget.controller.nfcKeyA,
          keyB: widget.controller.nfcKeyB,
          successMessage: '写入成功：${current.qslId}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = card;
    return Scaffold(
      appBar: AppBar(
        title: Text(current == null ? '卡片详情' : current.qslId),
        actions: [
          IconButton(onPressed: loading || reprinting ? null : _load, icon: const Icon(Icons.refresh_outlined)),
        ],
      ),
      body: loading
          ? ListView(children: [consoleProgress()])
          : error != null
              ? ListView(padding: const EdgeInsets.all(14), children: [ConsolePanel(child: Text(error!, style: const TextStyle(fontSize: 10, color: AppPalette.pink)))])
              : current == null
                  ? const Center(child: Text('未找到卡片'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                        children: [
                          ConsolePanel(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(child: Text(current.qslId, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                                StatusTag(_status(current.status, current.direction), accent: current.direction == 'TC' ? AppPalette.cyan : AppPalette.pink),
                              ]),
                              const SizedBox(height: 10),
                              _row('方向', current.direction == 'TC' ? '发卡' : '收卡'),
                              _row('创建时间', current.createdAt),
                              _row('更新时间', current.updatedAt),
                              _row('关联日志', current.logCount.toString()),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: reprinting ? null : _reprint,
                                    icon: reprinting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.print_outlined),
                                    label: Text(reprinting ? '打印队列中…' : '补打标签'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: reprinting || current.qslId.isEmpty ? null : _writeNfc,
                                    icon: const Icon(Icons.nfc, size: 18),
                                    label: const Text('写入NFC'),
                                  ),
                                ),
                              ]),
                            ]),
                          ),
                          const SizedBox(height: 12),
                          ConsolePanel(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              SectionHeader(label: '关联日志（${current.logs.length}）'),
                              const SizedBox(height: 10),
                              if (current.logs.isEmpty)
                                const Text('暂无关联日志', style: TextStyle(fontSize: 10, color: AppPalette.textDim))
                              else
                                ...current.logs.map((log) {
                                  final id = int.tryParse(log['id']?.toString() ?? '') ?? 0;
                                  final callsign = log['station_callsign']?.toString() ?? '';
                                  final date = _date(log['qso_date']?.toString() ?? '');
                                  final mode = log['mode']?.toString() ?? '';
                                  final freq = log['freq']?.toString() ?? '';
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: InkWell(
                                      onTap: id > 0 ? () => _openLog(id) : null,
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .45),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Theme.of(context).dividerColor),
                                        ),
                                        child: Row(children: [
                                          Expanded(
                                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                              Text(callsign.isEmpty ? '未知呼号' : callsign, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .7)),
                                              const SizedBox(height: 3),
                                              Text('#$id  $date  ${mode.isEmpty ? '—' : mode}  ${freq.isEmpty ? '—' : '$freq MHz'}', style: const TextStyle(fontSize: 8.5, color: AppPalette.textDim)),
                                            ]),
                                          ),
                                          const Icon(Icons.chevron_right, size: 17, color: AppPalette.textDim),
                                        ]),
                                      ),
                                    ),
                                  );
                                }),
                            ]),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 74, child: Text(label, style: const TextStyle(fontSize: 9, color: AppPalette.textDim))),
        Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}
