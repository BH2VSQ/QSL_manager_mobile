import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/nfc_service.dart';

enum NfcTagMode { write, format }

/// Holds the phone in NFC reader mode and writes to tags the user brings near.
///
/// [NfcTagMode.write] writes a single QSL link tag then stops; [NfcTagMode.format]
/// keeps the reader active and clears each successive tag until the user exits.
class NfcTagScreen extends StatefulWidget {
  const NfcTagScreen({
    super.key,
    required this.mode,
    required this.title,
    required this.instruction,
    required this.successMessage,
    this.url,
    this.packageName,
  });

  final NfcTagMode mode;
  final String title;
  final String instruction;
  final String successMessage;
  final String? url;
  final String? packageName;

  @override
  State<NfcTagScreen> createState() => _NfcTagScreenState();
}

class _NfcTagScreenState extends State<NfcTagScreen> {
  StreamSubscription<NfcTagEvent>? _sub;
  bool _starting = true;
  String? _message;
  String? _error;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _sub = NfcService.events.listen(_onEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    try {
      if (widget.mode == NfcTagMode.write) {
        await NfcService.writeQslTag(url: widget.url ?? '', packageName: widget.packageName ?? '');
      } else {
        await NfcService.formatTag();
      }
      if (mounted) {
        setState(() => _starting = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _starting = false;
          _error = '启动失败：$e';
        });
      }
    }
  }

  void _onEvent(NfcTagEvent event) {
    if (!mounted) return;
    setState(() {
      _starting = false;
      if (event.isSuccess) {
        _message = widget.successMessage;
        _error = null;
        _count++;
      } else {
        _error = event.message;
      }
    });
  }

  void _exit() {
    unawaited(NfcService.stop());
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _sub?.cancel();
    unawaited(NfcService.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFormat = widget.mode == NfcTagMode.format;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AppPalette.cyan.withValues(alpha: .08),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppPalette.cyan.withValues(alpha: .35)),
                      ),
                      child: const Icon(Icons.nfc, size: 52, color: AppPalette.cyan),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      widget.instruction,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, height: 1.6),
                    ),
                    if (_starting) ...[
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(strokeWidth: 2),
                    ],
                    if (_message != null) ...[
                      const SizedBox(height: 18),
                      Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: AppPalette.cyan, fontWeight: FontWeight.w700, height: 1.5),
                      ),
                    ],
                    if (isFormat && _count > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        '已格式化 $_count 个标签',
                        style: const TextStyle(fontSize: 10, color: AppPalette.textDim),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 18),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, color: AppPalette.pink, height: 1.5),
                      ),
                    ],
                    if (!isFormat && _message != null) ...[
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _exit,
                        icon: const Icon(Icons.check),
                        label: const Text('完成'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _exit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: Text(isFormat ? '退出' : '取消'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
