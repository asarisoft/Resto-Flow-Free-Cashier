import 'package:flutter/material.dart';
import '../theme/app_icons.dart';
import 'app_card.dart';

/// Kartu filter: baris atas ([top], mis. chip periode) + baris [fields].
/// Layar lebar: field sebaris, field TERAKHIR melebar mengisi sisa, Reset di ujung
/// (tanpa baris/ruang kosong). Layar sempit (HP): [top] membungkus ke baris
/// berikut, [fields] dilipat di balik "Filter lainnya" (terbuka sendiri bila
/// ada filter aktif, yaitu [onReset] tidak null).
class FilterPanel extends StatefulWidget {
  final Widget top;
  final List<Widget> fields;
  final VoidCallback? onReset;

  const FilterPanel({
    super.key,
    required this.top,
    required this.fields,
    this.onReset,
  });

  static const _wide = 640.0;

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final top = widget.top;
    final fields = widget.fields;
    final onReset = widget.onReset;
    final reset = onReset == null
        ? null
        : TextButton.icon(
            onPressed: onReset,
            icon: const Icon(AppIcons.filterReset, size: AppIcons.md),
            label: const Text('Reset filter'),
          );
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: LayoutBuilder(
        builder: (_, c) {
          final wide = c.maxWidth >= FilterPanel._wide;
          if (!wide) {
            final open = _open || onReset != null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                top,
                if (onReset == null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _open = !_open),
                      icon: Icon(
                        open ? AppIcons.close : AppIcons.search,
                        size: AppIcons.md,
                      ),
                      label: Text(open ? 'Tutup filter' : 'Filter lainnya'),
                    ),
                  ),
                if (open) ...[
                  if (onReset != null) const SizedBox(height: 12),
                  for (var i = 0; i < fields.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    fields[i],
                  ],
                  if (reset != null)
                    Align(alignment: Alignment.centerRight, child: reset),
                ],
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              top,
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var i = 0; i < fields.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    if (i == fields.length - 1)
                      Expanded(child: fields[i])
                    else
                      fields[i],
                  ],
                  if (reset != null) ...[const SizedBox(width: 12), reset],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
