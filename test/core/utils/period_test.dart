import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/core/utils/period.dart';

void main() {
  final now = DateTime(2026, 11, 15, 10, 30);

  test('today = 00:00:00 .. 23:59:59 of today', () {
    final r = const PeriodSelection(PeriodPreset.today).range(now)!;
    expect(r.start, DateTime(2026, 11, 15));
    expect(r.end, DateTime(2026, 11, 15, 23, 59, 59));
  });

  test('thisMonth covers the whole month', () {
    final r = PeriodSelection.thisMonth.range(now)!;
    expect(r.start, DateTime(2026, 11, 1));
    expect(r.end, DateTime(2026, 11, 30, 23, 59, 59));
  });

  test('lastMonth rolls over the year in January', () {
    final r = const PeriodSelection(PeriodPreset.lastMonth).range(DateTime(2026, 1, 5))!;
    expect(r.start, DateTime(2025, 12, 1));
    expect(r.end, DateTime(2025, 12, 31, 23, 59, 59));
  });

  test('lastMonth handles February in March', () {
    final r = const PeriodSelection(PeriodPreset.lastMonth).range(DateTime(2026, 3, 10))!;
    expect(r.end, DateTime(2026, 2, 28, 23, 59, 59));
  });

  test('all has no range and contains everything', () {
    const all = PeriodSelection(PeriodPreset.all);
    expect(all.range(now), isNull);
    expect(all.contains(DateTime(1999), now), isTrue);
  });

  test('custom range is normalised to whole days and inclusive', () {
    final sel = PeriodSelection.custom(DateTimeRange(start: DateTime(2026, 11, 3, 14), end: DateTime(2026, 11, 5, 9)));
    final r = sel.range(now)!;
    expect(r.start, DateTime(2026, 11, 3));
    expect(r.end, DateTime(2026, 11, 5, 23, 59, 59));
    expect(sel.contains(DateTime(2026, 11, 5, 23, 59, 59), now), isTrue);
    expect(sel.contains(DateTime(2026, 11, 6), now), isFalse);
    expect(sel.contains(DateTime(2026, 11, 2, 23, 59), now), isFalse);
  });

  test('labels are Indonesian', () {
    expect(const PeriodSelection(PeriodPreset.today).label, 'Hari ini');
    expect(PeriodSelection.thisMonth.label, 'Bulan ini');
    expect(const PeriodSelection(PeriodPreset.lastMonth).label, 'Bulan lalu');
    expect(const PeriodSelection(PeriodPreset.all).label, 'Semua');
  });
}
