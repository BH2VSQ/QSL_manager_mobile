import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class ConsolePanel extends StatelessWidget {
  const ConsolePanel({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: padding, child: child),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 18, color: AppPalette.cyan),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.4),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.label, required this.value, this.accent = AppPalette.cyan});

  final String label;
  final int? value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final outline = theme.dividerColor;
    final displayValue = value == null ? '—' : value.toString();

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: outline),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 22, height: 2, color: accent),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(fontSize: 9, color: theme.textTheme.bodySmall?.color?.withValues(alpha: .72), letterSpacing: 1.1)),
          const SizedBox(height: 4),
          FittedBox(
            alignment: Alignment.centerLeft,
            child: Text(
              displayValue,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700, color: accent),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusTag extends StatelessWidget {
  const StatusTag(this.text, {super.key, this.accent = AppPalette.cyan});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .10),
        border: Border.all(color: accent.withValues(alpha: .52)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text.isEmpty ? '—' : text,
        style: TextStyle(fontSize: 9, color: accent, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class ConsoleAction extends StatelessWidget {
  const ConsoleAction({super.key, required this.icon, required this.label, required this.onPressed, this.secondary = false});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 10, letterSpacing: .7)),
      style: OutlinedButton.styleFrom(
        foregroundColor: secondary ? AppPalette.pink : AppPalette.cyan,
        side: BorderSide(color: (secondary ? AppPalette.pink : AppPalette.cyan).withValues(alpha: .45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      ),
    );
  }
}

class ConsoleTitle extends StatelessWidget {
  const ConsoleTitle({super.key, required this.kicker, required this.title});

  final String kicker;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(kicker.toUpperCase(), style: const TextStyle(fontSize: 9, color: AppPalette.cyan, letterSpacing: 1.7)),
        const SizedBox(height: 3),
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: .5)),
      ],
    );
  }
}

Widget consoleProgress() => const Padding(
      padding: EdgeInsets.symmetric(vertical: 30),
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );

String cleanDate(String value) {
  if (value.length == 8) return '${value.substring(0, 4)}-${value.substring(4, 6)}-${value.substring(6, 8)}';
  return value;
}
