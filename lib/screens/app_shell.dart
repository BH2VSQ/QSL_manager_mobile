import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/app_controller.dart';
import '../core/app_theme.dart';
import '../services/nfc_service.dart';
import 'card_detail_screen.dart';
import 'cards_screen.dart';
import 'dashboard_screen.dart';
import 'logs_screen.dart';
import 'more_screen.dart';
import 'scanner_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int index = 0;
  late final MobileScannerController _scannerController = MobileScannerController(
    autoStart: false,
    detectionTimeoutMs: 500,
  );
  late final ValueNotifier<bool> _scannerTabActive = ValueNotifier(index == 3);

  // Each tab gets a fresh State on entry so it performs one automatic refresh
  // and its transient search/selection state is cleared.
  final List<int> _refreshTokens = List<int>.filled(5, 0);

  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkNfcLaunch());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkNfcLaunch());
    }
  }

  /// Handles a URI delivered by scanning a previously-written NFC tag. When
  /// QSLMM is installed, the NDEF_DISCOVERED filter routes the scan here
  /// instead of the browser; the `q` query parameter holds the QSL id.
  Future<void> _checkNfcLaunch() async {
    final uri = await NfcService.consumeLaunchUri();
    if (!mounted || uri == null || uri.isEmpty) return;
    final qslId = Uri.tryParse(uri)?.queryParameters['q']?.trim();
    if (qslId == null || qslId.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CardDetailScreen(controller: widget.controller, qslId: qslId),
      ),
    );
  }

  Future<void> _selectTab(int value) async {
    if (value < 0 || value >= _refreshTokens.length || value == index) return;

    // Tell the scanner page that it is no longer visible before stopping the
    // camera. This also prevents an in-flight scan request from restarting the
    // old scanner after the user has already moved to another tab.
    if (index == 3) {
      _scannerTabActive.value = false;
      try {
        await _scannerController.stop();
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      index = value;
      _refreshTokens[value]++;
    });
    if (value == 3) _scannerTabActive.value = true;
  }

  Future<void> _handleBack() async {
    // Back first returns to the overview tab instead of exiting the app.
    if (index != 0) {
      await _selectTab(0);
      return;
    }

    final now = DateTime.now();
    final last = _lastBackPressed;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPressed = now;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('再次返回退出应用'), duration: Duration(seconds: 2)),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerTabActive.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Widget _buildPage() {
    switch (index) {
      case 0:
        return DashboardScreen(controller: widget.controller);
      case 1:
        return LogsScreen(controller: widget.controller);
      case 2:
        return CardsScreen(controller: widget.controller);
      case 3:
        return ScannerScreen(
          controller: widget.controller,
          scannerController: _scannerController,
          scannerActive: _scannerTabActive,
        );
      case 4:
      default:
        return MoreScreen(controller: widget.controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = widget.controller.online;
    final revision = widget.controller.connectionRevision;
    final pageKey = ValueKey('${revision}_${index}_${_refreshTokens[index]}');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('QSL // 移动控制台'),
          actions: [
            InkWell(
              onTap: widget.controller.checkHealth,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: online ? AppPalette.cyan : AppPalette.pink,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      online ? '已连接' : '未连接',
                      style: const TextStyle(fontSize: 9, letterSpacing: 1.1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: KeyedSubtree(key: pageKey, child: _buildPage()),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: _selectTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard),
              label: '概览',
            ),
            NavigationDestination(
              icon: Icon(Icons.table_rows_outlined),
              selectedIcon: Icon(Icons.table_rows),
              label: '日志',
            ),
            NavigationDestination(
              icon: Icon(Icons.style_outlined),
              selectedIcon: Icon(Icons.style),
              label: 'QSL',
            ),
            NavigationDestination(
              icon: Icon(Icons.qr_code_scanner_outlined),
              selectedIcon: Icon(Icons.qr_code_scanner),
              label: '扫码',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune),
              label: '控制',
            ),
          ],
        ),
      ),
    );
  }
}
