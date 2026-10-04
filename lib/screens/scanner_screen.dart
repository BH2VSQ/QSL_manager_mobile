import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/app_controller.dart';
import '../core/app_theme.dart';
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

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  MobileScannerController get _scannerController => widget.scannerController;
  String? lastCode;
  String? result;
  bool busy = false;
  bool _starting = false;
  bool _tabActive = true;
  bool _lifecycleActive = true;

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
        setState(() => result = '扫码启动失败：${e.errorCode.name}');
      }
    } catch (e) {
      if (mounted) setState(() => result = '扫码启动失败：$e');
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
    if (busy || value.trim().isEmpty) return;
    setState(() {
      busy = true;
      lastCode = value.trim();
      result = null;
    });

    // Stop before touching the API so repeated camera callbacks do not trigger
    // duplicate scan operations and the controller cannot race another start.
    await _stopScanner();

    try {
      final raw = await widget.controller.api.scanCard(value.trim());
      result = raw['message']?.toString() ?? raw.toString();
    } catch (e) {
      result = '错误：$e';
    }

    if (!mounted) return;
    setState(() => busy = false);

    // Keep the scan page usable after a successful API operation.
    if (_tabActive && _lifecycleActive) {
      await _startIfNeeded();
    }
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
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const ConsoleTitle(kicker: '输入 / 库存', title: '二维码扫描'),
        const SizedBox(height: 14),
        ConsolePanel(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).width < 500 ? 310 : 380,
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
        const SizedBox(height: 12),
        if (lastCode != null)
          ConsolePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(label: '最近扫描内容'),
                const SizedBox(height: 9),
                SelectableText(
                  lastCode!,
                  style: const TextStyle(fontSize: 13, color: AppPalette.cyan),
                ),
                const SizedBox(height: 10),
                Text(
                  result ?? '处理中…',
                  style: TextStyle(
                    fontSize: 10,
                    color: result?.startsWith('错误') == true ? AppPalette.pink : Theme.of(context).colorScheme.onSurface,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
      ],
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
    final left = size.width * .17;
    final right = size.width * .83;
    final top = size.height * .25;
    final bottom = size.height * .75;
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
