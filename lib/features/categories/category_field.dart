import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'category_form_dialog.dart';
import 'category_providers.dart';

const _newMarker = '\u0000new_category';

/// Dropdown kategori dari daftar master + "+ Kategori baru" (buat & langsung pilih).
/// Nilai lama yang belum ada di daftar tetap ditampilkan (tidak crash).
class CategoryField extends ConsumerWidget {
  final String type;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;

  const CategoryField({
    super.key,
    required this.type,
    required this.value,
    required this.onChanged,
    this.label = 'Kategori',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = (ref.watch(categoryListProvider(type)).valueOrNull ?? const []).map((c) => c.name).toList();
    final current = (value ?? '').trim();
    final shown = [
      ...names,
      if (current.isNotEmpty && !names.any((n) => n.toLowerCase() == current.toLowerCase())) current,
    ];
    final selected = current.isEmpty
        ? null
        : shown.firstWhere((n) => n.toLowerCase() == current.toLowerCase());

    return DropdownButtonFormField<String?>(
      key: ValueKey('$type|$selected|${shown.length}'),
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Tanpa kategori')),
        for (final n in shown) DropdownMenuItem<String?>(value: n, child: Text(n)),
        const DropdownMenuItem<String?>(value: _newMarker, child: Text('+ Kategori baru')),
      ],
      onChanged: (v) async {
        if (v == _newMarker) {
          final created = await showDialog<String>(
            context: context,
            builder: (_) => CategoryFormDialog(type: type),
          );
          if (created != null) onChanged(created);
          return;
        }
        onChanged(v);
      },
    );
  }
}
