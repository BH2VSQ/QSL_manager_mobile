import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/app_theme.dart';
import '../models/models.dart';
import '../widgets/console_widgets.dart';
import 'card_detail_screen.dart';
import 'qsl_id_scanner_screen.dart';

class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  final searchController = TextEditingController();
  List<QslCard> cards = const [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    setState(() => loading = true);
    try {
      cards = await widget.controller.api.searchCards(prefix: searchController.text.trim());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('查询失败：$e')));
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _scanQslId() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QslIdScannerScreen()),
    );
    if (!mounted || scanned == null || scanned.trim().isEmpty) return;
    searchController
      ..text = scanned.trim()
      ..selection = TextSelection.collapsed(offset: scanned.trim().length);
    await _search();
  }

  Future<void> _openCard(QslCard card) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CardDetailScreen(controller: widget.controller, qslId: card.qslId)),
    );
    await _search();
  }

  String _statusText(QslCard card) {
    switch (card.status) {
      case 'pending':
        return card.direction == 'TC' ? '待出库' : '待入库';
      case 'out_stock':
        return '已发出';
      case 'in_stock':
        return '已收到';
      default:
        return card.status.isEmpty ? '—' : card.status;
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Row(
            children: [
              const Expanded(child: ConsoleTitle(kicker: '流程 / QSL', title: '卡片管理')),
              IconButton(onPressed: _search, icon: const Icon(Icons.refresh_outlined), tooltip: '刷新'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    hintText: '搜索 QSL 编号',
                    prefixIcon: Icon(Icons.search, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: IconButton(
                  onPressed: _scanQslId,
                  tooltip: '扫码输入 QSL 编号',
                  icon: const Icon(Icons.qr_code_scanner_outlined, size: 20),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: loading
              ? ListView(children: [consoleProgress()])
              : RefreshIndicator(
                  onRefresh: _search,
                  child: cards.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            Center(child: Text('暂无卡片', style: TextStyle(fontSize: 10, color: AppPalette.textDim))),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
                          itemCount: cards.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final card = cards[index];
                            return _CardRow(
                              card: card,
                              statusText: _statusText(card),
                              onOpen: () => _openCard(card),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({required this.card, required this.statusText, required this.onOpen});

  final QslCard card;
  final String statusText;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final accent = card.direction == 'RC' ? AppPalette.pink : AppPalette.cyan;
    return ConsolePanel(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
          child: Row(
            children: [
              Container(width: 3, height: 54, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            card.qslId.isEmpty ? '—' : card.qslId,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                        ),
                        StatusTag(statusText, accent: accent),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${card.direction == 'RC' ? '收卡' : '发卡'}  /  ${card.logCount} 条日志',
                      style: const TextStyle(fontSize: 8.5, color: AppPalette.textDim),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 17, color: AppPalette.textDim),
            ],
          ),
        ),
      ),
    );
  }
}
