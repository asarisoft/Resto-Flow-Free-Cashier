import 'package:flutter/material.dart';
import '../theme/app_icons.dart';
import 'app_card.dart';

/// Kartu filter: baris atas ([top], mis. chip periode) + baris [fields].
/// Layar lebar: field sebaris, field TERAKHIR melebar mengisi sisa, Reset di ujung
/// (tanpa baris/ruang kosong). Layar sempit: ditumpuk penuh lebar.
class FilterPanel extends StatelessWidget {
  final Widget top;
  final List<Widget> fields;
  final VoidCallback? onReset;

  const FilterPanel({super.key, required this.top, required this.fields, this.onReset});

  static const _wide = 640.0;

  @override
  Widget build(BuildContext context) {
    final reset = onReset == null
        ? null
        : TextButton.icon(
            onPressed: onReset,
            icon: const Icon(AppIcons.filterReset, size: AppIcons.md),
            label: const Text('Reset filter'),
          );
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (_, c) {
          final wide = c.maxWidth >= _wide;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              top,
              const SizedBox(height: 12),
              if (wide)
                Row(
                  children: [
                    for (var i = 0; i < fields.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      if (i == fields.length - 1) Expanded(child: fields[i]) else fields[i],
                    ],
                    if (reset != null) ...[const SizedBox(width: 12), reset],
                  ],
                )
              else ...[
                for (var i = 0; i < fields.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  fields[i],
                ],
                if (reset != null) Align(alignment: Alignment.centerRight, child: reset),
              ],
            ],
          );
        },
      ),
    );
  }
}
