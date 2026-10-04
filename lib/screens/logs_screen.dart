import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/app_theme.dart';
import '../models/models.dart';
import '../widgets/console_widgets.dart';
import 'log_detail_screen.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final searchController = TextEditingController();
  List<QsoLog> logs = const [];
  final Set<int> selectedIds = <int>{};
  bool loading = false;
  bool generating = false;
  int page = 1;
  int pages = 1;
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
      selectedIds.clear();
    });
    try {
      final result = await widget.controller.api.logs(
        page: page,
        limit: 30,
        stationCallsign: searchController.text.trim().toUpperCase(),
      );
      logs = result.logs;
      pages = result.pages < 1 ? 1 : result.pages;
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _importAdif() async {
    try {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['adi', 'adif']);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      await widget.controller.api.importAdifFromBytes(bytes, file.name);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ADIF 导入完成')));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败：$e')));
    }
  }

  void _toggleSelected(QsoLog log) {
    setState(() {
      if (selectedIds.contains(log.id)) {
        selectedIds.remove(log.id);
      } else {
        selectedIds.add(log.id);
      }
    });
  }

  Future<void> _openDetail(QsoLog log) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LogDetailScreen(controller: widget.controller, logId: log.id),
      ),
    );
    await _load();
  }

  Future<void> _generateQsl(String initialDirection) async {
    if (selectedIds.isEmpty || generating) return;
    final selected = logs.where((log) => selectedIds.contains(log.id)).toList(growable: false);
    if (selected.isEmpty) return;

    final sameCallsign = selected.every((e) => e.stationCallsign.trim().toUpperCase() == selected.first.stationCallsign.trim().toUpperCase());
    String direction = initialDirection;
    String mode = selected.length > 1 ? (sameCallsign ? 'single' : 'multi') : 'multi';
    String qslMessage = 'PSE';

    final result = await showDialog<({String direction, String mode, String qslMessage})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('颁发 QSL 编号'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('已选择 ${selected.length} 条日志', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    selected.length > 1
                        ? (sameCallsign ? '对方呼号：${selected.first.stationCallsign}' : '已选择多个不同呼号')
                        : '对方呼号：${selected.first.stationCallsign}',
                    style: const TextStyle(fontSize: 9, color: AppPalette.textDim),
                  ),
                  const SizedBox(height: 14),
                  ConsolePanel(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    child: Row(children: [
                      Icon(direction == 'TC' ? Icons.outbox_outlined : Icons.inbox_outlined, size: 17, color: direction == 'TC' ? AppPalette.cyan : AppPalette.pink),
                      const SizedBox(width: 8),
                      Text(direction == 'TC' ? '发卡（TC）' : '收卡（RC）', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  if (selected.length > 1) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: mode,
                      decoration: const InputDecoration(labelText: '编号方式'),
                      items: const [
                        DropdownMenuItem(value: 'single', child: Text('合并为一张卡（一个 QSL 编号）')),
                        DropdownMenuItem(value: 'multi', child: Text('每条日志一张卡（多个 QSL 编号）')),
                      ],
                      onChanged: (value) => setDialogState(() => mode = value ?? 'single'),
                    ),
                    if (mode == 'single' && !sameCallsign)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('合并为一张卡要求所有选中日志为同一对方呼号。', style: TextStyle(fontSize: 9, color: AppPalette.pink)),
                      ),
                  ],
                  if (direction == 'TC') ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: qslMessage,
                      decoration: const InputDecoration(labelText: '卡片消息'),
                      items: const [
                        DropdownMenuItem(value: 'PSE', child: Text('PSE QSL')),
                        DropdownMenuItem(value: 'TNX', child: Text('QSL TNX')),
                      ],
                      onChanged: (value) => setDialogState(() => qslMessage = value ?? 'PSE'),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
              FilledButton(
                onPressed: selected.length > 1 && mode == 'single' && !sameCallsign
                    ? null
                    : () => Navigator.pop(dialogContext, (direction: direction, mode: mode, qslMessage: qslMessage)),
                child: const Text('颁发编号'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null) return;

    final eligible = selected.where((log) => result.direction == 'TC' ? log.qslSent.toUpperCase() != 'Y' : log.qslRcvd.toUpperCase() != 'Y').toList(growable: false);
    final skipped = selected.length - eligible.length;
    if (eligible.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('所选日志已经全部存在对应卡片记录')));
      return;
    }

    setState(() => generating = true);
    try {
      final response = await widget.controller.api.generateCards(
        logIds: eligible.map((e) => e.id).toList(growable: false),
        direction: result.direction,
        mode: result.mode,
        qslMessage: result.qslMessage,
      );
      final data = response['data'];
      final cards = data is List ? data.whereType<Map>().toList() : const [];
      final ids = cards.map((e) => e['qsl_id']?.toString()).whereType<String>().where((e) => e.isNotEmpty).toList();
      final message = StringBuffer('已成功颁发 ${ids.length} 个 QSL 编号，并加入服务器打印队列');
      if (ids.isNotEmpty) message.write('\n${ids.join('、')}');
      if (skipped > 0) message.write('\n已跳过 $skipped 条已有对应卡片的日志');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message.toString()), duration: const Duration(seconds: 4)));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('颁发失败：$e')));
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = selectedIds.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Row(children: [
            const Expanded(child: ConsoleTitle(kicker: '数据 / 日志本', title: 'QSO 记录')),
            IconButton(onPressed: _importAdif, tooltip: '上传 ADIF', icon: const Icon(Icons.file_upload_outlined)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) { page = 1; _load(); },
            decoration: InputDecoration(
              hintText: '搜索：对方呼号',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: IconButton(onPressed: () { searchController.clear(); page = 1; _load(); }, icon: const Icon(Icons.clear, size: 16)),
            ),
          ),
        ),
        if (selectedCount > 0) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ConsolePanel(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(children: [
                Text('已选 $selectedCount 条', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                const Spacer(),
                ConsoleAction(icon: Icons.outbox_outlined, label: '发卡', onPressed: generating ? null : () => _generateQsl('TC')),
                const SizedBox(width: 6),
                ConsoleAction(icon: Icons.inbox_outlined, label: '收卡', secondary: true, onPressed: generating ? null : () => _generateQsl('RC')),
                const SizedBox(width: 6),
                IconButton(onPressed: () => setState(() => selectedIds.clear()), icon: const Icon(Icons.clear, size: 18), tooltip: '取消选择'),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ConsolePanel(child: Text(error!, style: const TextStyle(fontSize: 10, color: AppPalette.pink))),
          ),
        Expanded(
          child: loading
              ? ListView(children: [consoleProgress()])
              : RefreshIndicator(
                  onRefresh: _load,
                  child: logs.isEmpty
                      ? ListView(children: const [SizedBox(height: 80), Center(child: Text('暂无日志', style: TextStyle(fontSize: 10, color: AppPalette.textDim)))])
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
                          itemCount: logs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            return _LogCard(
                              log: log,
                              selected: selectedIds.contains(log.id),
                              onSelected: () => _toggleSelected(log),
                              onOpen: () => _openDetail(log),
                            );
                          },
                        ),
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('第 ${page.toString().padLeft(2, '0')} / ${pages.toString().padLeft(2, '0')} 页', style: const TextStyle(fontSize: 9, color: AppPalette.textDim)),
              Row(children: [
                IconButton(onPressed: page > 1 ? () { page--; _load(); } : null, icon: const Icon(Icons.chevron_left)),
                IconButton(onPressed: page < pages ? () { page++; _load(); } : null, icon: const Icon(Icons.chevron_right)),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.log, required this.selected, required this.onSelected, required this.onOpen});

  final QsoLog log;
  final bool selected;
  final VoidCallback onSelected;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return ConsolePanel(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(7, 9, 8, 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 36,
                child: Checkbox(value: selected, onChanged: (_) => onSelected(), visualDensity: VisualDensity.compact),
              ),
              Container(width: 3, height: 60, color: AppPalette.cyan),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(log.stationCallsign.isEmpty ? '未知台站' : log.stationCallsign, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1.1))),
                    if (log.qslCards.isNotEmpty)
                      StatusTag(log.qslCards.first.qslId, accent: AppPalette.pink),
                  ]),
                  const SizedBox(height: 7),
                  Wrap(spacing: 9, runSpacing: 5, children: [
                    Text('${cleanDate(log.qsoDate)} ${_formatTime(log.timeOn)}', style: const TextStyle(fontSize: 9, color: AppPalette.textDim)),
                    Text(log.freq == null ? '— MHz' : '${log.freq!.toStringAsFixed(3)} MHz', style: const TextStyle(fontSize: 9, color: AppPalette.cyan)),
                    Text(log.band.isEmpty ? '—' : log.band, style: const TextStyle(fontSize: 9)),
                    Text(log.mode.isEmpty ? '—' : log.mode, style: const TextStyle(fontSize: 9)),
                    Text('${log.rstSent.isEmpty ? '—' : log.rstSent}/${log.rstRcvd.isEmpty ? '—' : log.rstRcvd}', style: const TextStyle(fontSize: 9)),
                  ]),
                ]),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 45,
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  _QslState(label: '发', ok: log.qslSent.toUpperCase() == 'Y', accent: AppPalette.cyan),
                  const SizedBox(height: 6),
                  _QslState(label: '收', ok: log.qslRcvd.toUpperCase() == 'Y', accent: AppPalette.pink),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTime(String value) {
    if (value.isEmpty) return '—';
    final normalized = value.padLeft(6, '0');
    if (normalized.length == 6) return '${normalized.substring(0, 2)}:${normalized.substring(2, 4)}:${normalized.substring(4, 6)}';
    return value;
  }
}

class _QslState extends StatelessWidget {
  const _QslState({required this.label, required this.ok, required this.accent});

  final String label;
  final bool ok;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final color = ok ? accent : Theme.of(context).colorScheme.onSurface.withValues(alpha: .35);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
      const SizedBox(width: 3),
      Icon(ok ? Icons.check_circle_outline : Icons.cancel_outlined, size: 15, color: color),
    ]);
  }
}
