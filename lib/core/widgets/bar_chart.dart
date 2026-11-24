import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Satu batang di [BarChart].
class BarChartDatum {
  const BarChartDatum({
    required this.label,
    required this.value,
    required this.detail,
  });

  /// Label sumbu bawah (mis. "1".."31" atau "Jan".."Des").
  final String label;

  /// Nilai batang (rupiah), >= 0.
  final int value;

  /// Teks saat batang diketuk/ditekan lama (tanggal + nominal).
  final String detail;
}

/// Grafik batang sederhana tanpa dependency chart.
/// Batang tertinggi ditandai warna aksen; batang lain biru muda (sky).
/// Scroll horizontal agar banyak batang (28–31 hari) tetap muat di HP.
class BarChart extends StatelessWidget {
  final List<BarChartDatum> data;
  final double height;

  const BarChart({super.key, required this.data, this.height = 180});

  @override
  Widget build(BuildContext context) {
    final max = data.fold<int>(0, (m, d) => d.value > m ? d.value : m);
    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [for (final d in data) _Bar(datum: d, max: max, height: height)],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final BarChartDatum datum;
  final int max;
  final double height;

  const _Bar({required this.datum, required this.max, required this.height});

  static const double _labelSpace = 28;
  static const double _barWidth = 28;

  @override
  Widget build(BuildContext context) {
    final areaH = height - _labelSpace;
    final barH = max == 0 ? 0.0 : datum.value / max * areaH;
    final isMax = datum.value > 0 && datum.value == max;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showDetail(context),
      onLongPress: () => _showDetail(context),
      child: SizedBox(
        width: _barWidth,
        height: height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: barH,
              decoration: BoxDecoration(
                color: isMax
                    ? AppColors.primary
                    : AppColors.sky,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              datum.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              textAlign: TextAlign.center,
              style: AppTypography.textTheme.labelSmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(datum.detail),
        duration: const Duration(seconds: 2),
      ));
  }
}
