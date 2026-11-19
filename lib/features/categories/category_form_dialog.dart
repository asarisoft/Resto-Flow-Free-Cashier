import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/daos/categories_dao.dart';
import '../../core/widgets/app_form_dialog.dart';
import 'category_providers.dart';

/// Tambah ([entry] null) atau ubah nama kategori. Menutup dengan nama baru.
class CategoryFormDialog extends ConsumerStatefulWidget {
  final String type;
  final CategoryEntry? entry;

  const CategoryFormDialog({super.key, required this.type, this.entry});

  @override
  ConsumerState<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends ConsumerState<CategoryFormDialog> {
  late final _name = TextEditingController(text: widget.entry?.name ?? '');
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final dao = ref.read(categoriesDaoProvider);
    try {
      final name = _name.text.trim();
      if (widget.entry == null) {
        await dao.add(widget.type, name);
      } else {
        await dao.rename(widget.entry!.id, name);
      }
      if (mounted) Navigator.of(context).pop(name);
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _error = '${e.message}');
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.type == CategoryType.product ? 'Produk' : 'Pengeluaran';
    return AppFormDialog(
      title: widget.entry == null ? 'Tambah Kategori' : 'Ubah Kategori',
      saving: _saving,
      error: _error,
      onSubmit: _save,
      fields: [
        TextFormField(
          controller: _name,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _saving ? null : _save(),
          decoration: InputDecoration(labelText: 'Nama kategori $label', counterText: ''),
        ),
      ],
    );
  }
}
