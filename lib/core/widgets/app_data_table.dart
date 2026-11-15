import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'tap_area.dart';

class AppColumn<T> {
  final String label;
  final int flex;
  final double minWidth;
  final bool numeric;
  final Widget Function(T row) cell;

  const AppColumn({
    required this.label,
    required this.cell,
    this.flex = 1,
    this.minWidth = 100,
    this.numeric = false,
  });
}

/// Tabel data standar: header kolom, baris berpembatas, angka rata kanan,
/// scroll horizontal di layar sempit, dan "Tampilkan lebih banyak" per [pageSize] baris.
class AppDataTable<T> extends StatefulWidget {
  final List<AppColumn<T>> columns;
  final List<T> rows;
  final void Function(T row)? onRowTap;
  final String Function(T row)? rowLabel;
  final int pageSize;
  final Widget? empty;

  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onRowTap,
    this.rowLabel,
    this.pageSize = 25,
    this.empty,
  });

  @override
  State<AppDataTable<T>> createState() => _AppDataTableState<T>();
}

class _AppDataTableState<T> extends State<AppDataTable<T>> {
  late int _visible = widget.pageSize;

  @override
  void didUpdateWidget(covariant AppDataTable<T> old) {
    super.didUpdateWidget(old);
    // Filter berubah (jumlah baris beda) → mulai lagi dari halaman pertama.
    if (old.rows.length != widget.rows.length && widget.rows.length <= widget.pageSize) {
      _visible = widget.pageSize;
    }
  }

  double get _minWidth => widget.columns.fold(0.0, (s, c) => s + c.minWidth);

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    if (widget.rows.isEmpty && widget.empty != null) return widget.empty!;
    final shown = widget.rows.take(_visible).toList();
    final remaining = widget.rows.length - shown.length;

    Widget cellBox(AppColumn<T> c, Widget child) => Expanded(
          flex: c.flex,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Align(
              alignment: c.numeric ? Alignment.centerRight : Alignment.centerLeft,
              child: child,
            ),
          ),
        );

    final header = Container(
      color: AppColors.background,
      child: Row(
        children: [
          for (final c in widget.columns)
            cellBox(
              c,
              Text(
                c.label,
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );

    Widget rowFor(T r) {
      final row = Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(children: [for (final c in widget.columns) cellBox(c, c.cell(r))]),
      );
      if (widget.onRowTap == null) return row;
      return TapArea(
        label: widget.rowLabel?.call(r) ?? 'Baris tabel',
        onTap: () => widget.onRowTap!(r),
        child: row,
      );
    }

    final table = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, for (final r in shown) rowFor(r)],
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (_, constraints) {
              if (constraints.maxWidth >= _minWidth) return table;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: _minWidth, child: table),
              );
            },
          ),
          if (remaining > 0)
            TextButton(
              onPressed: () => setState(() => _visible += widget.pageSize),
              child: Text('Tampilkan lebih banyak ($remaining lagi)'),
            ),
        ],
      ),
    );
  }
}
