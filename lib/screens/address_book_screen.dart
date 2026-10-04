import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/app_theme.dart';
import '../models/address_entry.dart';
import '../widgets/console_widgets.dart';

class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  final search = TextEditingController();
  List<AddressEntry> entries = const [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      entries = (await widget.controller.api.addresses(search: search.text.trim())).entries;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败：$e')));
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _edit([AddressEntry? entry]) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => _AddressEditor(controller: widget.controller, entry: entry),
    );
    if (ok == true) _load();
  }

  Future<void> _printLabel(AddressEntry entry) async {
    if (entry.name.trim().isEmpty || entry.address.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先完善姓名和地址后再推送打印')),
      );
      return;
    }

    final direction = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => _AddressPrintDirectionSheet(entry: entry),
    );
    if (direction == null || !mounted) return;

    try {
      await widget.controller.api.printAddressLabel(entry, direction: direction);
      if (!mounted) return;
      final label = direction == 'FROM' ? 'FROM（发自）' : 'TO（发往）';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已将 ${entry.callsign} 的 $label 地址标签推送到服务器打印队列')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('推送打印失败：$e')));
      }
    }
  }

  Future<void> _delete(AddressEntry entry) async {
    final yes = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('删除联系人'), content: Text('删除 ${entry.callsign}？'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除'))]));
    if (yes != true) return;
    await widget.controller.api.deleteAddress(entry.callsign);
    await _load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('地址簿 // 联系人'),
        actions: [IconButton(onPressed: () => _edit(), icon: const Icon(Icons.person_add_alt_1_outlined))],
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 10), child: TextField(controller: search, textInputAction: TextInputAction.search, onSubmitted: (_) => _load(), decoration: const InputDecoration(hintText: '搜索：呼号 / 姓名', prefixIcon: Icon(Icons.search, size: 18)))),
        Expanded(child: loading ? consoleProgress() : RefreshIndicator(onRefresh: _load, child: ListView.separated(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), itemCount: entries.length, separatorBuilder: (_, _) => const SizedBox(height: 8), itemBuilder: (_, index) { final entry = entries[index]; return InkWell(onTap: () => _edit(entry), child: ConsolePanel(child: Row(children: [const Icon(Icons.contacts_outlined, size: 20, color: AppPalette.cyan), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(entry.callsign, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)), const SizedBox(height: 4), Text('${entry.name}  /  ${entry.country}', style: const TextStyle(fontSize: 9, color: AppPalette.textDim)), const SizedBox(height: 4), Text(entry.address, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, height: 1.35))])), Row(mainAxisSize: MainAxisSize.min, children: [IconButton(onPressed: () => _printLabel(entry), tooltip: '推送地址标签打印', icon: const Icon(Icons.print_outlined, size: 19)), PopupMenuButton<String>(onSelected: (v) { if (v == 'delete') _delete(entry); }, itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('删除'))], icon: const Icon(Icons.more_vert, size: 18))])]))); })))
      ]),
    );
  }
}

class _AddressEditor extends StatefulWidget {
  const _AddressEditor({required this.controller, this.entry});
  final AppController controller;
  final AddressEntry? entry;
  @override
  State<_AddressEditor> createState() => _AddressEditorState();
}

class _AddressEditorState extends State<_AddressEditor> {
  late final TextEditingController callsign;
  late final TextEditingController name;
  late final TextEditingController phone;
  late final TextEditingController address;
  late final TextEditingController postal;
  late final TextEditingController country;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    callsign = TextEditingController(text: e?.callsign ?? '');
    name = TextEditingController(text: e?.name ?? '');
    phone = TextEditingController(text: e?.phone ?? '');
    address = TextEditingController(text: e?.address ?? '');
    postal = TextEditingController(text: e?.postalCode ?? '');
    country = TextEditingController(text: e?.country ?? '');
  }

  Future<void> save() async {
    if (callsign.text.trim().isEmpty) return;
    setState(() => saving = true);
    final payload = {'callsign': callsign.text.trim().toUpperCase(), 'name': name.text.trim(), 'phone': phone.text.trim(), 'address': address.text.trim(), 'postal_code': postal.text.trim(), 'country': country.text.trim()};
    try {
      final targetCallsign = widget.entry?.callsign ?? payload['callsign'].toString();
      if (widget.entry == null) {
        await widget.controller.api.createAddress(payload);
      } else {
        await widget.controller.api.updateAddress(targetCallsign, Map.of(payload)..remove('callsign'));
      }

      // Confirm the server persisted the record before closing the editor.
      // This also makes failures visible instead of making a local-looking
      // save that disappears on the next refresh.
      await widget.controller.api.address(targetCallsign);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() { callsign.dispose(); name.dispose(); phone.dispose(); address.dispose(); postal.dispose(); country.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(padding: EdgeInsets.fromLTRB(14, 16, 14, bottom + 16), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.entry == null ? '新建联系人' : '编辑联系人', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)), const SizedBox(height: 12), TextField(controller: callsign, enabled: widget.entry == null, decoration: const InputDecoration(labelText: '呼号')), const SizedBox(height: 8), TextField(controller: name, decoration: const InputDecoration(labelText: '姓名')), const SizedBox(height: 8), TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '电话')), const SizedBox(height: 8), TextField(controller: address, maxLines: 3, decoration: const InputDecoration(labelText: '地址')), const SizedBox(height: 8), Row(children: [Expanded(child: TextField(controller: postal, decoration: const InputDecoration(labelText: '邮政编码'))), const SizedBox(width: 8), Expanded(child: TextField(controller: country, decoration: const InputDecoration(labelText: '国家 / 地区（可选）')))]), const SizedBox(height: 14), SizedBox(width: double.infinity, child: FilledButton(onPressed: saving ? null : save, child: Text(saving ? '保存中…' : '保存联系人')))])));
  }
}


class _AddressPrintDirectionSheet extends StatelessWidget {
  const _AddressPrintDirectionSheet({required this.entry});

  final AddressEntry entry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '选择地址标签类型',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${entry.callsign}  ·  ${entry.name}',
              style: const TextStyle(fontSize: 10, color: AppPalette.textDim),
            ),
            const SizedBox(height: 14),
            const _PrintDirectionOption(
              direction: 'FROM',
              title: 'FROM（发自）',
              description: '将此地址作为寄件/发信地址打印',
              icon: Icons.outbox_outlined,
            ),
            const SizedBox(height: 10),
            const _PrintDirectionOption(
              direction: 'TO',
              title: 'TO（发往）',
              description: '将此地址作为收件/目的地址打印',
              icon: Icons.move_to_inbox_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrintDirectionOption extends StatelessWidget {
  const _PrintDirectionOption({
    required this.direction,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String direction;
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = direction == 'FROM' ? AppPalette.cyan : AppPalette.pink;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.pop(context, direction),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(12),
          color: color.withValues(alpha: 0.06),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
                  const SizedBox(height: 3),
                  Text(description, style: const TextStyle(fontSize: 10, color: AppPalette.textDim)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}
