import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';
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

/// Tabel data standar: header kolom, baris berpembatas, angka rata kanan.
/// Di layar sempit (< [cardBreakpoint]) tiap baris tampil sebagai kartu
/// (kolom pertama = judul, kolom lain = "label … nilai"), dan "Tampilkan lebih banyak" per [pageSize] baris.
class AppDataTable<T> extends StatefulWidget {
  final List<AppColumn<T>> columns;
  final List<T> rows;
  final void Function(T row)? onRowTap;
  final String Function(T row)? rowLabel;
  final int pageSize;
  final Widget? empty;

  /// Lebar di bawah ini → mode kartu (HP).
  static const cardBreakpoint = 600.0;

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
    if (old.rows.length != widget.rows.length &&
        widget.rows.length <= widget.pageSize) {
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
        child: Row(
          children: [for (final c in widget.columns) cellBox(c, c.cell(r))],
        ),
      );
      if (widget.onRowTap == null) return row;
      return TapArea(
        label: widget.rowLabel?.call(r) ?? 'Baris tabel',
        onTap: () => widget.onRowTap!(r),
        child: row,
      );
    }

    // Mode kartu untuk HP: tanpa scroll horizontal, tidak ada kolom terpotong.
    Widget cardFor(T r) {
      final first = widget.columns.first;
      final actions = widget.columns.skip(1).where((c) => c.label.isEmpty);
      final fields = widget.columns.skip(1).where((c) => c.label.isNotEmpty);
      final card = Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: DefaultTextStyle.merge(
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    child: first.cell(r),
                  ),
                ),
                for (final c in actions) c.cell(r),
              ],
            ),
            for (final c in fields)
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        c.label,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: c.cell(r),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
      if (widget.onRowTap == null) return card;
      return TapArea(
        label: widget.rowLabel?.call(r) ?? 'Baris data',
        onTap: () => widget.onRowTap!(r),
        child: card,
      );
    }

    final cards = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final r in shown) cardFor(r)],
    );

    final table = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, for (final r in shown) rowFor(r)],
    );

    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (_, constraints) {
                if (constraints.maxWidth < AppDataTable.cardBreakpoint)
                  return cards;
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
      ),
    );
  }
}
