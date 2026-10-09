import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/app_controller.dart';
import '../core/app_theme.dart';
import '../services/nfc_service.dart';
import '../widgets/console_widgets.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({
    super.key,
    required this.controller,
    required this.scannerController,
    required this.scannerActive,
  });

  final AppController controller;
  final MobileScannerController scannerController;
  final ValueListenable<bool> scannerActive;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScanEntry {
  const _ScanEntry({required this.time, required this.qslId, required this.outbound, required this.message});

  final DateTime time;
  final String qslId;
  final bool outbound;
  final String message;
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  MobileScannerController get _scannerController => widget.scannerController;
  bool busy = false;
  bool _starting = false;
  bool _tabActive = true;
  bool _lifecycleActive = true;

  // Session counters and operation log. These are plain instance fields so
  // they are naturally reset whenever the tab is re-entered (AppShell rebuilds
  // the page with a fresh State on every tab switch).
  int _outCount = 0;
  int _inCount = 0;
  final List<_ScanEntry> _entries = [];

  // Same-tag debounce: the camera can re-report the label still in view right
  // after a scan; ignore a repeat of the same code within this window.
  String? _lastScannedCode;
  DateTime? _lastScannedAt;

  @override
  void initState() {
    super.initState();
    _tabActive = widget.scannerActive.value;
    widget.scannerActive.addListener(_handleTabActiveChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startIfNeeded());
  }

  Future<void> _startIfNeeded() async {
    if (!mounted || !_tabActive || !_lifecycleActive || _starting) return;
    if (_scannerController.value.isRunning || _scannerController.value.isStarting) return;
    _starting = true;
    try {
      await _scannerController.start();
    } on MobileScannerException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('扫码启动失败：${e.errorCode.name}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('扫码启动失败：$e')));
    } finally {
      _starting = false;
    }
  }

  Future<void> _stopScanner() async {
    try {
      await _scannerController.stop();
    } catch (_) {
      // stop() is idempotent in current mobile_scanner releases.
    }
  }

  void _handleTabActiveChanged() {
    if (!mounted) return;
    _tabActive = widget.scannerActive.value;
    if (_tabActive && _lifecycleActive) {
      unawaited(_startIfNeeded());
    } else {
      unawaited(_stopScanner());
    }
  }

  Future<void> _process(String value) async {
    final code = value.trim();
    if (busy || code.isEmpty) return;

    // Ignore a rapid re-detection of the label that was just scanned.
    final lastAt = _lastScannedAt;
    if (code == _lastScannedCode && lastAt != null && DateTime.now().difference(lastAt) < const Duration(seconds: 3)) {
      return;
    }

    setState(() {
      busy = true;
    });

    // Stop before touching the API so repeated camera callbacks do not trigger
    // duplicate scan operations and the controller cannot race another start.
    await _stopScanner();

    var outbound = false;
    var success = false;
    String message;
    try {
      final raw = await widget.controller.api.scanCard(code);
      message = raw['message']?.toString() ?? raw.toString();
      outbound = _isOutbound(raw);
      success = true;
    } catch (e) {
      message = '错误：$e';
    }

    if (!mounted) return;
    setState(() {
      busy = false;
      _lastScannedCode = code;
      _lastScannedAt = DateTime.now();
      if (success) {
        if (outbound) {
          _outCount++;
        } else {
          _inCount++;
        }
        _entries.insert(0, _ScanEntry(time: DateTime.now(), qslId: code, outbound: outbound, message: message));
      }
    });

    if (success) {
      await NfcService.beep();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }

    // A 1-2s pause lets the operator swap the next label without the camera
    // immediately re-scanning the current one.
    if (_tabActive && _lifecycleActive) {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (mounted && _tabActive && _lifecycleActive) {
        await _startIfNeeded();
      }
    }
  }

  bool _isOutbound(Map<String, dynamic> raw) {
    final data = raw['data'];
    final direction = (data is Map ? data['direction'] : null)?.toString().toUpperCase();
    if (direction == 'TC') return true;
    if (direction == 'RC') return false;
    final status = (data is Map ? data['status'] : null)?.toString();
    if (status == 'out_stock') return true;
    if (status == 'in_stock') return false;
    final message = raw['message']?.toString() ?? '';
    if (message.contains('出库')) return true;
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lifecycleActive = true;
      unawaited(_startIfNeeded());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _lifecycleActive = false;
      unawaited(_stopScanner());
    }
  }

  @override
  void dispose() {
    _tabActive = false;
    widget.scannerActive.removeListener(_handleTabActiveChanged);
    WidgetsBinding.instance.removeObserver(this);
    // The controller belongs to AppShell. It is stopped before tab replacement
    // and disposed with the shell, so it can be reused safely on tab re-entry.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final squareSide = MediaQuery.sizeOf(context).width < 500 ? 280.0 : 340.0;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const ConsoleTitle(kicker: '输入 / 库存', title: '二维码扫描'),
        const SizedBox(height: 14),
        ConsolePanel(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Center(
              child: SizedBox(
                width: squareSide,
                height: squareSide,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _scannerController,
                      onDetect: (capture) {
                        if (capture.barcodes.isEmpty) return;
                        final value = capture.barcodes.first.rawValue;
                        if (value != null) unawaited(_process(value));
                      },
                      errorBuilder: (context, error) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              '相机不可用\n${error.errorCode.name}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11, color: AppPalette.pink, height: 1.5),
                            ),
                          ),
                        );
                      },
                    ),
                    IgnorePointer(child: CustomPaint(painter: _ScannerFramePainter())),
                    if (busy) const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ConsolePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(label: '本次操作'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _CounterTile(label: '已出库', value: _outCount, accent: AppPalette.cyan)),
                const SizedBox(width: 10),
                Expanded(child: _CounterTile(label: '已入库', value: _inCount, accent: AppPalette.pink)),
              ]),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              if (_entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('暂无操作记录', style: TextStyle(fontSize: 10, color: AppPalette.textDim)),
                )
              else
                SizedBox(
                  height: 180,
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: ListView.separated(
                      itemCount: _entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        return _ScanLogRow(entry: entry);
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CounterTile extends StatelessWidget {
  const _CounterTile({required this.label, required this.value, required this.accent});

  final String label;
  final int value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: .35)),
      ),
      child: Row(children: [
        Icon(label == '已出库' ? Icons.outbox_outlined : Icons.inbox_outlined, size: 18, color: accent),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 9, color: AppPalette.textDim)),
          const SizedBox(height: 2),
          Text(value.toString(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: accent)),
        ]),
      ]),
    );
  }
}

class _ScanLogRow extends StatelessWidget {
  const _ScanLogRow({required this.entry});

  final _ScanEntry entry;

  String _time(DateTime t) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(t.hour)}:${p(t.minute)}:${p(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final accent = entry.outbound ? AppPalette.cyan : AppPalette.pink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: .22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_time(entry.time), style: const TextStyle(fontSize: 9, color: AppPalette.textDim)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(
                    entry.qslId,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .5),
                  ),
                ),
                StatusTag(entry.outbound ? '出库' : '入库', accent: accent),
              ]),
              if (entry.message.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(entry.message, style: const TextStyle(fontSize: 8.5, color: AppPalette.textDim, height: 1.4)),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

class _ScannerFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppPalette.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    // Draw a centered square frame that matches the square camera view.
    final side = size.shortestSide * 0.66;
    final left = (size.width - side) / 2;
    final right = left + side;
    final top = (size.height - side) / 2;
    final bottom = top + side;
    const length = 26.0;
    canvas.drawLine(Offset(left, top), Offset(left + length, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left, top + length), paint);
    canvas.drawLine(Offset(right, top), Offset(right - length, top), paint);
    canvas.drawLine(Offset(right, top), Offset(right, top + length), paint);
    canvas.drawLine(Offset(left, bottom), Offset(left + length, bottom), paint);
    canvas.drawLine(Offset(left, bottom), Offset(left, bottom - length), paint);
    canvas.drawLine(Offset(right, bottom), Offset(right - length, bottom), paint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - length), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
