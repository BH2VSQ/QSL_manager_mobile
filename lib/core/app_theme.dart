import 'package:flutter/material.dart';

class AppPalette {
  static const cyan = Color(0xFF5BCFFA);
  static const pink = Color(0xFFF5ABB9);
  static const white = Color(0xFFFFFFFF);

  // Night console palette.
  static const canvas = Color(0xFF0A1016);
  static const panel = Color(0xFF111A22);
  static const panelRaised = Color(0xFF15212B);
  static const line = Color(0x263C5868);
  static const textDim = Color(0xFF8CA2AE);

  // Day console palette.
  static const dayCanvas = Color(0xFFF3F7F9);
  static const dayPanel = Color(0xFFFFFFFF);
  static const dayPanelRaised = Color(0xFFEAF1F4);
  static const dayLine = Color(0xFFC4D5DC);
  static const dayText = Color(0xFF1D2A31);
  static const dayTextDim = Color(0xFF607681);
}

ThemeData buildConsoleTheme() => _buildConsoleTheme(dark: true);
ThemeData buildConsoleLightTheme() => _buildConsoleTheme(dark: false);

ThemeData _buildConsoleTheme({required bool dark}) {
  final canvas = dark ? AppPalette.canvas : AppPalette.dayCanvas;
  final panel = dark ? AppPalette.panel : AppPalette.dayPanel;
  final panelRaised = dark ? AppPalette.panelRaised : AppPalette.dayPanelRaised;
  final line = dark ? AppPalette.line : AppPalette.dayLine;
  final text = dark ? AppPalette.white : AppPalette.dayText;
  final textDim = dark ? AppPalette.textDim : AppPalette.dayTextDim;

  final scheme = ColorScheme.fromSeed(
    seedColor: AppPalette.cyan,
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: AppPalette.cyan,
    secondary: AppPalette.pink,
    surface: panel,
    onSurface: text,
    onPrimary: AppPalette.canvas,
    onSecondary: AppPalette.canvas,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    fontFamily: 'monospace',
    textTheme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light).textTheme.apply(
      bodyColor: text,
      displayColor: text,
    ),
    dividerTheme: DividerThemeData(color: line, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: panel,
      labelStyle: TextStyle(color: textDim),
      hintStyle: TextStyle(color: textDim.withValues(alpha: .8)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppPalette.cyan, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    cardTheme: CardThemeData(
      color: panel,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: line),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: panel,
      indicatorColor: AppPalette.cyan.withValues(alpha: .18),
      labelTextStyle: WidgetStateProperty.all(
        TextStyle(fontFamily: 'monospace', fontSize: 10, color: text),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'monospace',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: text,
        letterSpacing: .6,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: panelRaised,
      contentTextStyle: TextStyle(color: text, fontFamily: 'monospace'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      behavior: SnackBarBehavior.floating,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: panelRaised,
      side: BorderSide(color: line),
      labelStyle: TextStyle(fontFamily: 'monospace', fontSize: 10, color: text),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: AppPalette.cyan,
      textColor: text,
    ),
  );
}
