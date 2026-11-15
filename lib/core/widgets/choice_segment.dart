import 'package:flutter/material.dart';

/// Pilihan 1-dari-N (mis. 58/80 mm, Hari Ini/Bulan Ini). Gaya dari `segmentedButtonTheme`.
class ChoiceSegment<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  const ChoiceSegment({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      showSelectedIcon: false,
      segments: [for (final o in options) ButtonSegment<T>(value: o.$1, label: Text(o.$2))],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
