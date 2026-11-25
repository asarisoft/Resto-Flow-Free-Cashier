import 'package:flutter/material.dart';
import '../theme/app_icons.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';

/// Kartu filter: baris atas ([top], mis. chip periode) + baris [fields].
/// Panel LIPAT di semua lebar, default tertutup: header "Filter · [summary]" +
/// chevron; ketuk membuka [top] + [fields]. Layar lebar (>= 600 dp): field
/// sebaris, field TERAKHIR melebar, Reset di ujung. HP: field bertumpuk.
class FilterPanel extends StatefulWidget {
  final Widget top;
  final List<Widget> fields;
  final VoidCallback? onReset;

  /// Ringkasan filter aktif (mis. label periode) di header saat tertutup.
  final String? summary;

  const FilterPanel({
    super.key,
    required this.top,
    required this.fields,
    this.onReset,
    this.summary,
  });

  static const _wide = 600.0;

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
          final s = widget.summary;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                button: true,
                expanded: _open,
                label: _open ? 'Sembunyikan filter' : 'Tampilkan filter',
                excludeSemantics: true,
                onTap: () => setState(() => _open = !_open),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _open = !_open),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Row(
                      children: [
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            s == null || s.isEmpty ? 'Filter' : 'Filter · $s',
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.textTheme.titleSmall,
                          ),
                        ),
                        Icon(_open ? AppIcons.chevronUp : AppIcons.chevronDown),
                      ],
                    ),
                  ),
                ),
              ),
              if (_open) ...[
                const SizedBox(height: 8),
                top,
                if (wide) ...[
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
                ] else ...[
                  for (final f in fields) ...[const SizedBox(height: 12), f],
                  if (reset != null)
                    Align(alignment: Alignment.centerRight, child: reset),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}
