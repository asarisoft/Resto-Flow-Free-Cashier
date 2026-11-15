import 'package:flutter/material.dart' show DateTimeRange;

enum PeriodPreset { today, thisMonth, lastMonth, all, custom }

/// Pilihan periode untuk filter (Laporan, Pengeluaran). Batas inklusif per hari.
class PeriodSelection {
  final PeriodPreset preset;
  final DateTimeRange? _custom;

  const PeriodSelection(this.preset) : _custom = null;

  PeriodSelection.custom(DateTimeRange range)
      : preset = PeriodPreset.custom,
        _custom = range;

  static const thisMonth = PeriodSelection(PeriodPreset.thisMonth);

  static DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _dayEnd(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);

  /// `null` = semua waktu.
  DateTimeRange? range(DateTime now) {
    switch (preset) {
      case PeriodPreset.today:
        return DateTimeRange(start: _dayStart(now), end: _dayEnd(now));
      case PeriodPreset.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: _dayEnd(DateTime(now.year, now.month + 1, 0)),
        );
      case PeriodPreset.lastMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month - 1, 1),
          end: _dayEnd(DateTime(now.year, now.month, 0)),
        );
      case PeriodPreset.all:
        return null;
      case PeriodPreset.custom:
        return DateTimeRange(start: _dayStart(_custom!.start), end: _dayEnd(_custom.end));
    }
  }

  bool contains(DateTime d, DateTime now) {
    final r = range(now);
    return r == null || (!d.isBefore(r.start) && !d.isAfter(r.end));
  }

  String get label {
    switch (preset) {
      case PeriodPreset.today:
        return 'Hari ini';
      case PeriodPreset.thisMonth:
        return 'Bulan ini';
      case PeriodPreset.lastMonth:
        return 'Bulan lalu';
      case PeriodPreset.all:
        return 'Semua';
      case PeriodPreset.custom:
        return 'Pilih tanggal';
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PeriodSelection && other.preset == preset && other._custom == _custom;

  @override
  int get hashCode => Object.hash(preset, _custom);
}
