import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';
import 'tap_area.dart';

class AppColumn<T> {
  final String label;
  final int flex;
  final double minWidth;
  final bool numeric;

  /// Mode kartu (HP): kolom ini ikut tampil saat kartu diciutkan.
  final bool primary;
  final Widget Function(T row) cell;

  const AppColumn({
    required this.label,
    required this.cell,
    this.flex = 1,
    this.minWidth = 100,
    this.numeric = false,
    this.primary = false,
  });
}

/// Tabel data standar: header kolom, baris berpembatas, angka rata kanan.
/// Di layar sempit (< [cardBreakpoint]) tiap baris tampil sebagai kartu
/// (kolom pertama = judul, kolom lain = "label … nilai"). Kartu ciut: hanya
/// kolom pertama + kolom [AppColumn.primary]; chevron membuka sisanya.
/// Baris dimuat [pageSize] dulu, sisanya otomatis saat scroll mendekati ujung.
class AppDataTable<T> extends StatefulWidget {
  final List<AppColumn<T>> columns;
  final List<T> rows;
  final void Function(T row)? onRowTap;
  final String Function(T row)? rowLabel;
  final int pageSize;
  final Widget? empty;

  /// Lebar di bawah ini → mode kartu (HP).
  static const cardBreakpoint = 600.0;

  /// Gutter halaman yang memuat tabel/kartu clay: 36 dp di layar lebar, >=
  /// jangkauan bayangan clay terbesar (offset 12 + blur 24 = 36; lihat
  /// `ClayDecoration`) agar tidak terpotong tepi viewport ListView.
  static const wideGutter = 36.0;
  static double gutter(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= cardBreakpoint ? wideGutter : 16;

  /// Tinggi minimum baris mode tabel (seragam di semua halaman).
  static const rowHeight = 56.0;

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
  static const _nearEnd = 300.0;
  late int _visible = widget.pageSize;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pos = Scrollable.maybeOf(context)?.position;
    if (pos != _position) {
      _position?.removeListener(_check);
      _position = pos?..addListener(_check);
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AppDataTable<T> old) {
    super.didUpdateWidget(old);
    // Data/filter berubah → mulai lagi dari batch pertama.
    final a = old.rows, b = widget.rows;
    if (a.length != b.length ||
        (b.isNotEmpty && !identical(a.first, b.first))) {
      _visible = widget.pageSize;
    }
  }

  void _check() {
    final pos = _position;
    if (!mounted || pos == null || !pos.hasContentDimensions) return;
    if (_visible < widget.rows.length && pos.extentAfter < _nearEnd) {
      setState(() => _visible += widget.pageSize);
    }
  }

  double get _minWidth => widget.columns.fold(0.0, (s, c) => s + c.minWidth);

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    if (widget.rows.isEmpty && widget.empty != null) return widget.empty!;
    final shown = widget.rows.take(_visible).toList();
    final remaining = widget.rows.length - shown.length;
    // Bila konten belum memenuhi layar, lanjutkan memuat setelah frame ini.
    if (remaining > 0) WidgetsBinding.instance.addPostFrameCallback((_) => _check());

    Widget cellBox(AppColumn<T> c, Widget child, {double vPad = 12}) => Expanded(
      flex: c.flex,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: vPad),
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppDataTable.rowHeight),
          child: Row(
            children: [
              for (final c in widget.columns) cellBox(c, c.cell(r), vPad: 4),
            ],
          ),
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
    Widget cardFor(T r) => _CardRow<T>(
      key: ObjectKey(r),
      row: r,
      columns: widget.columns,
      onTap: widget.onRowTap == null ? null : () => widget.onRowTap!(r),
      label: widget.rowLabel?.call(r) ?? 'Baris data',
    );

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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Memuat…',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Satu kartu HP: judul + aksi + chevron, lalu field (ciut = hanya primary).
class _CardRow<T> extends StatefulWidget {
  final T row;
  final List<AppColumn<T>> columns;
  final VoidCallback? onTap;
  final String label;

  const _CardRow({
    super.key,
    required this.row,
    required this.columns,
    required this.onTap,
    required this.label,
  });

  @override
  State<_CardRow<T>> createState() => _CardRowState<T>();
}

class _CardRowState<T> extends State<_CardRow<T>> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final r = widget.row;
    final first = widget.columns.first;
    final actions = widget.columns.skip(1).where((c) => c.label.isEmpty);
    final fields = widget.columns.skip(1).where((c) => c.label.isNotEmpty);
    final hasMore = fields.any((c) => !c.primary);
    final shown = _open ? fields : fields.where((c) => c.primary);

    Widget tappable(Widget child) => widget.onTap == null
        ? child
        : TapArea(label: widget.label, onTap: widget.onTap, child: child);

    final title = tappable(
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
        child: DefaultTextStyle.merge(
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          child: first.cell(r),
        ),
      ),
    );

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: title),
              for (final c in actions) c.cell(r),
              if (hasMore)
                IconButton(
                  tooltip: _open ? 'Sembunyikan detail' : 'Tampilkan detail',
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: Icon(_open ? AppIcons.chevronUp : AppIcons.chevronDown),
                  onPressed: () => setState(() => _open = !_open),
                )
              else
                const SizedBox(width: 8),
            ],
          ),
          if (shown.isNotEmpty)
            tappable(
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  children: [
                    for (final c in shown)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
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
              ),
            ),
        ],
      ),
    );
  }
}
