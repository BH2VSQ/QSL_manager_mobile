import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/app_theme.dart';

class QslIdScannerScreen extends StatefulWidget {
  const QslIdScannerScreen({super.key});

  @override
  State<QslIdScannerScreen> createState() => _QslIdScannerScreenState();
}

class _QslIdScannerScreenState extends State<QslIdScannerScreen> with WidgetsBindingObserver {
  late final MobileScannerController _scannerController;
  String? detectedCode;
  bool _starting = false;
  bool _pageActive = true;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      autoStart: false,
      detectionTimeoutMs: 500,
    );
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScanner());
  }

  Future<void> _startScanner() async {
    if (!mounted || !_pageActive || _starting || detectedCode != null) return;
    if (_scannerController.value.isRunning || _scannerController.value.isStarting) return;
    _starting = true;
    try {
      await _scannerController.start();
    } catch (_) {
      // The preview's errorBuilder provides the visible failure state.
    } finally {
      _starting = false;
    }
  }

  Future<void> _stopScanner() async {
    try {
      await _scannerController.stop();
    } catch (_) {}
  }

  void _handleCapture(BarcodeCapture capture) {
    if (detectedCode != null || capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue?.trim();
    if (value == null || value.isEmpty) return;

    setState(() => detectedCode = value);
    unawaited(_stopScanner());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pageActive = true;
      unawaited(_startScanner());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pageActive = false;
      unawaited(_stopScanner());
    }
  }

  void _resumeScan() {
    setState(() => detectedCode = null);
    _pageActive = true;
    unawaited(_startScanner());
  }

  @override
  void dispose() {
    _pageActive = false;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_scannerController.stop());
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleCapture,
            errorBuilder: (context, error) {
              return const Center(
                child: Text(
                  '无法启动相机\n请检查相机权限',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.6),
                ),
              );
            },
          ),
          CustomPaint(painter: _WechatScanOverlayPainter()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                        tooltip: '关闭',
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            '扫一扫',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      ListenableBuilder(
                        listenable: _scannerController,
                        builder: (context, _) {
                          final state = _scannerController.value.torchState;
                          return IconButton(
                            onPressed: state == TorchState.unavailable ? null : () => _scannerController.toggleTorch(),
                            icon: Icon(
                              state == TorchState.on ? Icons.flash_on : Icons.flash_off,
                              color: state == TorchState.on ? AppPalette.cyan : Colors.white,
                            ),
                            tooltip: '手电筒',
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Text(
                  '将 QSL 二维码放入框内',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Text(
                  '扫描后可一键填入 QSL 编号并搜索',
                  style: TextStyle(color: Colors.white.withValues(alpha: .75), fontSize: 11),
                ),
                const SizedBox(height: 150),
              ],
            ),
          ),
          if (detectedCode != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: BoxDecoration(
                    color: const Color(0xF20E151B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppPalette.cyan.withValues(alpha: .65)),
                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, -4))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppPalette.cyan.withValues(alpha: .16),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.check_rounded, color: AppPalette.cyan, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              '已识别 QSL 编号',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .07),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          detectedCode!,
                          style: const TextStyle(color: AppPalette.cyan, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: .8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _resumeScan,
                              icon: const Icon(Icons.qr_code_scanner, size: 18),
                              label: const Text('重新扫描'),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: () => Navigator.pop(context, detectedCode),
                              icon: const Icon(Icons.search, size: 18),
                              label: const Text('填入并搜索'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WechatScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final boxSize = size.width < 420 ? size.width * .66 : 300.0;
    final center = Offset(size.width / 2, size.height * .43);
    final rect = Rect.fromCenter(center: center, width: boxSize, height: boxSize);

    final dimPaint = Paint()..color = Colors.black.withValues(alpha: .55);
    final cutout = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)));
    canvas.drawPath(cutout, dimPaint);

    final border = Paint()
      ..color = AppPalette.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), border);

    final corner = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.square;
    const length = 28.0;
    final l = rect.left;
    final r = rect.right;
    final t = rect.top;
    final b = rect.bottom;
    for (final line in [
      [Offset(l, t), Offset(l + length, t)],
      [Offset(l, t), Offset(l, t + length)],
      [Offset(r, t), Offset(r - length, t)],
      [Offset(r, t), Offset(r, t + length)],
      [Offset(l, b), Offset(l + length, b)],
      [Offset(l, b), Offset(l, b - length)],
      [Offset(r, b), Offset(r - length, b)],
      [Offset(r, b), Offset(r, b - length)],
    ]) {
      canvas.drawLine(line[0], line[1], corner);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
