import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_controller.dart';
import '../core/app_theme.dart';
import '../models/models.dart';
import '../widgets/console_widgets.dart';

class PrintQueueScreen extends StatefulWidget {
  const PrintQueueScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<PrintQueueScreen> createState() => _PrintQueueScreenState();
}

class _PrintQueueScreenState extends State<PrintQueueScreen> {
  List<PrintQueueItem> items = const [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      items = await widget.controller.api.printQueue();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('获取队列失败：$e')));
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _clear() async {
    final yes = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('CLEAR QUEUE'), content: const Text('确认清空整个打印队列？'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('清空'))]));
    if (yes != true) return;
    await widget.controller.api.clearPrintQueue();
    await _load();
  }

  Future<void> _remove(PrintQueueItem item) async {
    try {
      await widget.controller.api.removePrintQueue(item.id);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PRINT // QUEUE'),
        actions: [IconButton(onPressed: _clear, icon: const Icon(Icons.delete_sweep_outlined))],
      ),
      body: loading
          ? consoleProgress()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ConsolePanel(
                    child: Column(children: [
                      Row(children: [
                        Expanded(child: Text(item.type.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppPalette.cyan, letterSpacing: 1))),
                        StatusTag(item.status, accent: AppPalette.pink),
                        PopupMenuButton<String>(onSelected: (v) { if (v == 'remove') _remove(item); }, itemBuilder: (_) => const [PopupMenuItem(value: 'remove', child: Text('移除'))], icon: const Icon(Icons.more_vert, size: 18)),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [Expanded(child: Text(item.qslId, style: const TextStyle(fontWeight: FontWeight.w800))), Text('L${item.layout}', style: const TextStyle(fontSize: 9, color: AppPalette.textDim))]),
                      if (item.logs.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Align(alignment: Alignment.centerLeft, child: Text('${item.logs.length} LOG  /  ${item.createdAt}', style: const TextStyle(fontSize: 9, color: AppPalette.textDim))),
                      ],
                      const SizedBox(height: 10),
                      Align(alignment: Alignment.centerRight, child: ConsoleAction(icon: Icons.open_in_new, label: 'HTML', onPressed: () => launchUrl(widget.controller.api.printHtmlUrl(item.id), mode: LaunchMode.externalApplication))),
                    ]),
                  );
                },
              ),
            ),
    );
  }
}
