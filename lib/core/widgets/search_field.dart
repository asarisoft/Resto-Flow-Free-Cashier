import 'package:flutter/material.dart';
import '../theme/app_icons.dart';

/// Kolom cari dengan ikon dan tombol hapus.
class SearchField extends StatefulWidget {
  final String hint;
  final String value;
  final ValueChanged<String> onChanged;

  const SearchField({super.key, required this.hint, required this.value, required this.onChanged});

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final _ctrl = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant SearchField old) {
    super.didUpdateWidget(old);
    if (widget.value != _ctrl.text) _ctrl.text = widget.value;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        labelText: widget.hint,
        prefixIcon: const Icon(AppIcons.search),
        suffixIcon: _ctrl.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Hapus pencarian',
                icon: const Icon(AppIcons.close),
                onPressed: () {
                  _ctrl.clear();
                  widget.onChanged('');
                  setState(() {});
                },
              ),
      ),
    );
  }
}
