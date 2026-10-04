import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/app_theme.dart';
import '../models/models.dart';
import '../widgets/console_widgets.dart';

class LogEditorScreen extends StatefulWidget {
  const LogEditorScreen({super.key, required this.controller, this.id});

  final AppController controller;
  final int? id;

  @override
  State<LogEditorScreen> createState() => _LogEditorScreenState();
}

class _LogEditorScreenState extends State<LogEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final station = TextEditingController();
  final date = TextEditingController();
  final time = TextEditingController();
  final freq = TextEditingController();
  final band = TextEditingController();
  final mode = TextEditingController();
  final rstSent = TextEditingController();
  final rstRcvd = TextEditingController();
  final grid = TextEditingController();
  final comment = TextEditingController();
  bool loading = false;
  bool initialized = false;

  bool get editing => widget.id != null;

  @override
  void initState() {
    super.initState();
    rstSent.text = widget.controller.defaultRstSent;
    rstRcvd.text = widget.controller.defaultRstRcvd;
    date.text = _today();
    time.text = _utcTime();
    if (editing) _load();
  }

  String _today() {
    final now = DateTime.now().toUtc();
    return '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  String _utcTime() {
    final now = DateTime.now().toUtc();
    return '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final log = await widget.controller.api.log(widget.id!);
      _fill(log);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败：$e')));
    }
    if (mounted) setState(() { loading = false; initialized = true; });
  }

  void _fill(QsoLog log) {
    station.text = log.stationCallsign;
    date.text = log.qsoDate;
    time.text = log.timeOn;
    freq.text = log.freq?.toString() ?? '';
    band.text = log.band;
    mode.text = log.mode;
    rstSent.text = log.rstSent;
    rstRcvd.text = log.rstRcvd;
    grid.text = log.myGridsquare;
    comment.text = log.comment;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);
    final payload = <String, dynamic>{
      'my_callsign': widget.controller.defaultCallsign,
      'station_callsign': station.text.trim().toUpperCase(),
      'qso_date': date.text.trim(),
      'time_on': time.text.trim(),
      'freq': double.tryParse(freq.text.trim()),
      'band': band.text.trim().toUpperCase(),
      'mode': mode.text.trim().toUpperCase(),
      'rst_sent': rstSent.text.trim(),
      'rst_rcvd': rstRcvd.text.trim(),
      'my_gridsquare': grid.text.trim().toUpperCase(),
      'comment': comment.text.trim(),
    };
    try {
      if (editing) {
        await widget.controller.api.updateLog(widget.id!, payload);
      } else {
        await widget.controller.api.createLog(payload);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(editing ? '日志已更新' : '日志已创建')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    for (final c in [station, date, time, freq, band, mode, rstSent, rstRcvd, grid, comment]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(editing ? '编辑 // QSO' : '新建 // QSO')),
      body: loading && !initialized
          ? consoleProgress()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  ConsolePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(label: 'QSO 基本信息'),
                        const SizedBox(height: 12),
                        _field(station, '对方呼号', required: true),
                        const SizedBox(height: 9),
                        Row(children: [
                          Expanded(child: _field(date, 'UTC 日期', required: true)),
                          const SizedBox(width: 8),
                          Expanded(child: _field(time, 'UTC 时间', required: true)),
                        ]),
                        const SizedBox(height: 9),
                        Row(children: [
                          Expanded(child: _field(freq, '频率 MHz', keyboard: TextInputType.number)),
                          const SizedBox(width: 8),
                          Expanded(child: _field(band, '波段')),
                        ]),
                        const SizedBox(height: 9),
                        Row(children: [
                          Expanded(child: _field(mode, 'MODE')),
                          const SizedBox(width: 8),
                          Expanded(child: _field(grid, '本方网格')),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ConsolePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(label: '信号报告'),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: _field(rstSent, '发出 RST')),
                          const SizedBox(width: 8),
                          Expanded(child: _field(rstRcvd, '收到 RST')),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _field(comment, '备注', maxLines: 4),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: loading ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(loading ? '保存中…' : '保存日志'),
                  ),
                  const SizedBox(height: 8),
                  const Text('服务端当前 API 无认证；APP 不在本地保存完整日志副本。', style: TextStyle(color: AppPalette.textDim, fontSize: 9)),
                ],
              ),
            ),
    );
  }

  Widget _field(TextEditingController controller, String label, {bool required = false, TextInputType? keyboard, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      validator: required ? (value) => value == null || value.trim().isEmpty ? '必填' : null : null,
      decoration: InputDecoration(labelText: label),
    );
  }
}
