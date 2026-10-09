import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:ndef/ndef.dart' as ndef;

import '../core/app_theme.dart';
import '../services/nfc_service.dart';

/// Writes an NDEF message to a tag the user holds against the phone.
///
/// Used for both writing a QSL link tag ([repeat] = false, single write) and
/// clearing/formatting a tag ([repeat] = true, loops over tags until the user
/// exits). When [records] is empty the tag is written with an empty NDEF
/// message, which clears its content.
class NfcTagScreen extends StatefulWidget {
  const NfcTagScreen({
    super.key,
    required this.title,
    required this.instruction,
    required this.records,
    required this.successMessage,
    this.repeat = false,
  });

  final String title;
  final String instruction;
  final List<ndef.NDEFRecord> records;
  final String successMessage;
  final bool repeat;

  @override
  State<NfcTagScreen> createState() => _NfcTagScreenState();
}

class _NfcTagScreenState extends State<NfcTagScreen> {
  bool _running = false;
  bool _writing = false;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (_running || !mounted) return;
    setState(() => _running = true);
    while (mounted && _running) {
      final ok = await _pollAndWrite();
      if (!ok || !widget.repeat) break;
      // Short pause so the user can swap the next tag onto the coil.
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    if (mounted) setState(() => _running = false);
  }

  Future<bool> _pollAndWrite() async {
    if (mounted) {
      setState(() {
        _writing = false;
        _message = null;
        _error = null;
      });
    }

    try {
      await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 20),
        androidPlatformSound: false,
      );
    } catch (e) {
      if (mounted) setState(() => _error = '未检测到标签：$e');
      return false;
    }

    if (mounted) setState(() => _writing = true);
    try {
      await FlutterNfcKit.writeNDEFRecords(widget.records);
      await FlutterNfcKit.finish();
      await NfcService.beep();
      if (mounted) {
        setState(() {
          _writing = false;
          _message = widget.successMessage;
          _error = null;
        });
      }
      return true;
    } catch (e) {
      try {
        await FlutterNfcKit.finish();
      } catch (_) {}
      if (mounted) setState(() => _error = '写入失败：$e');
      return false;
    }
  }

  void _exit() {
    _running = false;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _running = false;
    unawaited(FlutterNfcKit.finish().catchError((_) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                      child: Icon(
                        widget.repeat ? Icons.nfc : Icons.nfc_outlined,
                        size: 52,
                        color: AppPalette.cyan,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      widget.instruction,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, height: 1.6),
                    ),
                    if (_writing) ...[
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
                    if (_error != null) ...[
                      const SizedBox(height: 18),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, color: AppPalette.pink, height: 1.5),
                      ),
                    ],
                    if (!widget.repeat && _message != null) ...[
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
                  child: Text(widget.repeat ? '退出' : '取消'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
