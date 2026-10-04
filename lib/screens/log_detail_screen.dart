import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/app_theme.dart';
import '../models/models.dart';
import '../widgets/console_widgets.dart';

class LogDetailScreen extends StatefulWidget {
  const LogDetailScreen({super.key, required this.controller, required this.logId});

  final AppController controller;
  final int logId;

  @override
  State<LogDetailScreen> createState() => _LogDetailScreenState();
}

class _LogDetailScreenState extends State<LogDetailScreen> {
  QsoLog? log;
  bool loading = true;
  bool saving = false;
  String? error;
  late final TextEditingController station;
  late final TextEditingController date;
  late final TextEditingController timeOn;
  late final TextEditingController band;
  late final TextEditingController bandRx;
  late final TextEditingController freq;
  late final TextEditingController freqRx;
  late final TextEditingController mode;
  late final TextEditingController submode;
  late final TextEditingController rstSent;
  late final TextEditingController rstRcvd;
  late final TextEditingController myGrid;
  late final TextEditingController satName;
  late final TextEditingController propMode;
  late final TextEditingController comment;
  late final TextEditingController qslSentDate;
  late final TextEditingController qslRcvdDate;

  @override
  void initState() {
    super.initState();
    station = TextEditingController();
    date = TextEditingController();
    timeOn = TextEditingController();
    band = TextEditingController();
    bandRx = TextEditingController();
    freq = TextEditingController();
    freqRx = TextEditingController();
    mode = TextEditingController();
    submode = TextEditingController();
    rstSent = TextEditingController();
    rstRcvd = TextEditingController();
    myGrid = TextEditingController();
    satName = TextEditingController();
    propMode = TextEditingController();
    comment = TextEditingController();
    qslSentDate = TextEditingController();
    qslRcvdDate = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await widget.controller.api.getLog(widget.logId);
      if (!mounted) return;
      setState(() {
        log = loaded;
        _fill(loaded);
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _fill(QsoLog value) {
    station.text = value.stationCallsign;
    date.text = value.qsoDate;
    timeOn.text = value.timeOn;
    band.text = value.band;
    bandRx.text = value.bandRx;
    freq.text = value.freq?.toString() ?? '';
    freqRx.text = value.freqRx?.toString() ?? '';
    mode.text = value.mode;
    submode.text = value.submode;
    rstSent.text = value.rstSent;
    rstRcvd.text = value.rstRcvd;
    myGrid.text = value.myGridsquare;
    satName.text = value.satName;
    propMode.text = value.propMode;
    comment.text = value.comment;
    qslSentDate.text = value.qslSentDate;
    qslRcvdDate.text = value.qslRcvdDate;
  }

  String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();

  double? _number(String value) => double.tryParse(value.trim());

  Future<void> _save() async {
    final current = log;
    if (current == null || saving) return;
    if (station.text.trim().isEmpty || date.text.trim().isEmpty || timeOn.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写对方呼号、日期和时间')));
      return;
    }
    setState(() => saving = true);
    try {
      await widget.controller.api.updateLog(widget.logId, {
        'station_callsign': station.text.trim().toUpperCase(),
        'qso_date': date.text.trim(),
        'time_on': timeOn.text.trim(),
        'band': band.text.trim(),
        'band_rx': bandRx.text.trim(),
        'freq': _number(freq.text),
        'freq_rx': _number(freqRx.text),
        'mode': mode.text.trim(),
        'submode': _nullable(submode.text),
        'rst_sent': rstSent.text.trim(),
        'rst_rcvd': rstRcvd.text.trim(),
        'comment': comment.text,
        'sat_name': _nullable(satName.text),
        'prop_mode': _nullable(propMode.text),
        'my_gridsquare': _nullable(myGrid.text.toUpperCase()),
        'qsl_sent_date': _nullable(qslSentDate.text),
        'qsl_rcvd_date': _nullable(qslRcvdDate.text),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('日志已保存')));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    station.dispose();
    date.dispose();
    timeOn.dispose();
    band.dispose();
    bandRx.dispose();
    freq.dispose();
    freqRx.dispose();
    mode.dispose();
    submode.dispose();
    rstSent.dispose();
    rstRcvd.dispose();
    myGrid.dispose();
    satName.dispose();
    propMode.dispose();
    comment.dispose();
    qslSentDate.dispose();
    qslRcvdDate.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(labelText: label, hintText: hint);

  String _qslStatus(QslCard card) {
    if (card.status == 'pending') return card.direction == 'TC' ? '待出库' : '待入库';
    if (card.status == 'out_stock') return '已发出';
    if (card.status == 'in_stock') return '已收到';
    return card.status.isEmpty ? '—' : card.status;
  }

  @override
  Widget build(BuildContext context) {
    final current = log;
    return Scaffold(
      appBar: AppBar(
        title: Text(current == null ? '日志详情' : '日志 #${current.id}'),
        actions: [
          IconButton(onPressed: loading || saving ? null : _load, icon: const Icon(Icons.refresh_outlined)),
          IconButton(onPressed: loading || saving ? null : _save, icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined)),
        ],
      ),
      body: loading
          ? ListView(children: [consoleProgress()])
          : error != null
              ? ListView(padding: const EdgeInsets.all(14), children: [ConsolePanel(child: Text(error!, style: const TextStyle(color: AppPalette.pink, fontSize: 10)))])
              : current == null
                  ? const Center(child: Text('未找到日志'))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                      children: [
                        ConsolePanel(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const SectionHeader(label: '记录标识'),
                            const SizedBox(height: 12),
                            _readOnlyRow('日志 ID', '#${current.id}'),
                            _readOnlyRow('我方呼号', current.myCallsign),
                            _readOnlyRow('发卡状态', current.qslSent == 'Y' ? '已发' : '未发'),
                            _readOnlyRow('收卡状态', current.qslRcvd == 'Y' ? '已收' : '未收'),
                            if (current.createdAt.isNotEmpty) _readOnlyRow('创建时间', current.createdAt),
                            if (current.updatedAt.isNotEmpty) _readOnlyRow('更新时间', current.updatedAt),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        ConsolePanel(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const SectionHeader(label: 'QSO 基本信息'),
                            const SizedBox(height: 12),
                            TextField(controller: station, decoration: _dec('对方呼号')), 
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(child: TextField(controller: date, decoration: _dec('日期（UTC）', hint: 'YYYYMMDD'), keyboardType: TextInputType.datetime)),
                              const SizedBox(width: 8),
                              Expanded(child: TextField(controller: timeOn, decoration: _dec('时间（UTC）', hint: 'HHMM 或 HHMMSS'), keyboardType: TextInputType.datetime)),
                            ]),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(child: TextField(controller: mode, decoration: _dec('模式'))),
                              const SizedBox(width: 8),
                              Expanded(child: TextField(controller: submode, decoration: _dec('子模式'))),
                            ]),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(child: TextField(controller: rstSent, decoration: _dec('发送 RST'))),
                              const SizedBox(width: 8),
                              Expanded(child: TextField(controller: rstRcvd, decoration: _dec('接收 RST'))),
                            ]),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        ConsolePanel(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const SectionHeader(label: '频率 / 波段'),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(child: TextField(controller: band, decoration: _dec('发射波段'))),
                              const SizedBox(width: 8),
                              Expanded(child: TextField(controller: bandRx, decoration: _dec('接收波段'))),
                            ]),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(child: TextField(controller: freq, decoration: _dec('发射频率（MHz）'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                              const SizedBox(width: 8),
                              Expanded(child: TextField(controller: freqRx, decoration: _dec('接收频率（MHz）'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                            ]),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(child: TextField(controller: myGrid, decoration: _dec('我方网格'))),
                              const SizedBox(width: 8),
                              Expanded(child: _readOnlyField('对方网格', current.gridsquare)),
                            ]),
                          ]),
                        ),
                        if (current.satName.isNotEmpty || current.satMode.isNotEmpty || current.propMode.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ConsolePanel(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const SectionHeader(label: '卫星 / 传播信息'),
                              const SizedBox(height: 12),
                              TextField(controller: satName, decoration: _dec('卫星名称')),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(child: Text(current.satMode.isEmpty ? '—' : current.satMode, style: const TextStyle(fontSize: 11))),
                                const SizedBox(width: 8),
                                Expanded(child: TextField(controller: propMode, decoration: _dec('传播模式'))),
                              ]),
                            ]),
                          ),
                        ],
                        const SizedBox(height: 12),
                        ConsolePanel(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const SectionHeader(label: '备注 / QSL 日期'),
                            const SizedBox(height: 12),
                            TextField(controller: comment, minLines: 3, maxLines: 7, decoration: _dec('备注')),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(child: TextField(controller: qslSentDate, decoration: _dec('发卡日期', hint: 'YYYYMMDD'))),
                              const SizedBox(width: 8),
                              Expanded(child: TextField(controller: qslRcvdDate, decoration: _dec('收卡日期', hint: 'YYYYMMDD'))),
                            ]),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        ConsolePanel(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const SectionHeader(label: '完整记录信息'),
                            const SizedBox(height: 10),
                            _readOnlyRow('结束时间', current.timeOff),
                            _readOnlyRow('我方网格', current.myGridsquare),
                            _readOnlyRow('对方网格', current.gridsquare),
                            _readOnlyRow('笔记', current.notes),
                            _readOnlyRow('卫星模式', current.satMode),
                            _readOnlyRow('中继台', current.repeaterCallsign),
                            _readOnlyRow('中继位置', current.repeaterLocation),
                            _readOnlyRow('上行频率', current.uplinkFreq?.toString() ?? ''),
                            _readOnlyRow('下行频率', current.downlinkFreq?.toString() ?? ''),
                            _readOnlyRow('发射功率', current.txPwr?.toString() ?? ''),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        ConsolePanel(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const SectionHeader(label: '关联 QSL 卡片'),
                            const SizedBox(height: 10),
                            if (current.qslCards.isEmpty)
                              const Text('暂无关联 QSL 卡片', style: TextStyle(fontSize: 10, color: AppPalette.textDim))
                            else
                              ...current.qslCards.map((card) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(children: [
                                      Expanded(child: Text(card.qslId, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                                      StatusTag(_qslStatus(card), accent: card.direction == 'TC' ? AppPalette.cyan : AppPalette.pink),
                                    ]),
                                  )),
                          ]),
                        ),
                        if (_extraFields(current).isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ConsolePanel(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const SectionHeader(label: '其他 ADIF 字段'),
                              const SizedBox(height: 10),
                              ..._extraFields(current).entries.map((entry) => _readOnlyRow(entry.key, entry.value.toString())),
                            ]),
                          ),
                        ],
                        const SizedBox(height: 14),
                        FilledButton.icon(onPressed: saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(saving ? '保存中…' : '保存修改')),
                      ],
                    ),
    );
  }

  Map<String, dynamic> _extraFields(QsoLog value) {
    const known = {
      'id', 'my_callsign', 'station_callsign', 'qso_date', 'time_on', 'time_off', 'freq', 'freq_rx', 'band', 'band_rx',
      'mode', 'submode', 'rst_sent', 'rst_rcvd', 'qsl_sent', 'qsl_rcvd', 'qsl_sent_date', 'qsl_rcvd_date', 'my_gridsquare',
      'gridsquare', 'comment', 'notes', 'sat_name', 'sat_mode', 'prop_mode', 'repeater_callsign', 'repeater_location',
      'uplink_freq', 'downlink_freq', 'tx_pwr', 'created_at', 'updated_at', 'qsl_cards', 'adif_blob', 'sort_id',
    };
    return Map<String, dynamic>.fromEntries(value.raw.entries.where((e) => !known.contains(e.key) && e.value != null && e.value.toString().trim().isNotEmpty));
  }

  Widget _readOnlyField(String label, String value) {
    return InputDecorator(
      decoration: _dec(label),
      child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _readOnlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(children: [
        SizedBox(width: 82, child: Text(label, style: const TextStyle(fontSize: 9, color: AppPalette.textDim))),
        Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}
