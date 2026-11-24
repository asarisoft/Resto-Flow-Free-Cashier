import 'package:flutter/material.dart';
import '../theme/app_icons.dart';
import 'search_field.dart';

/// Kolom cari produk + tombol ganti tampilan grid/list.
class ProductSearchBar extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final bool isList;
  final VoidCallback onToggleView;

  const ProductSearchBar({
    super.key,
    required this.value,
    required this.onChanged,
    required this.isList,
    required this.onToggleView,
  });

  @override
  Widget build(BuildContext context) {
    final label = isList ? 'Tampilan grid' : 'Tampilan list';
    return Row(
      children: [
        Expanded(
          child: SearchField(hint: 'Cari produk', value: value, onChanged: onChanged),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: IconButton(
            tooltip: label,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(isList ? AppIcons.viewGrid : AppIcons.viewList),
            onPressed: onToggleView,
          ),
        ),
      ],
    );
  }
}
