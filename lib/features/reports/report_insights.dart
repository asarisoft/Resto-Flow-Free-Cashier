import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/daos/reports_dao.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/amount_text.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/bar_chart.dart';
import '../../core/widgets/choice_segment.dart';
import 'report_providers.dart';

/// "Jam 12.00" untuk jam 12 (0–23).
String hourLabel(int h) => '${h.toString().padLeft(2, '0')}.00';

/// Menu terlaris (top 5) pada rentang laporan, urut qty atau omzet.
class TopProductsCard extends ConsumerStatefulWidget {
  final DateTimeRange range;
  const TopProductsCard({super.key, required this.range});

  @override
  ConsumerState<TopProductsCard> createState() => _TopProductsCardState();
}

class _TopProductsCardState extends ConsumerState<TopProductsCard> {
  TopBy _by = TopBy.qty;

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final async = ref.watch(topProductsProvider((range: widget.range, by: _by)));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Menu Terlaris', style: textTheme.titleMedium)),
              ChoiceSegment<TopBy>(
                value: _by,
                options: const [(TopBy.qty, 'Terjual'), (TopBy.revenue, 'Omzet')],
                onChanged: (v) => setState(() => _by = v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          async.when(
            loading: () => const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error: $e'),
            data: (list) {
              if (list.isEmpty) {
                return Text('Belum ada penjualan pada periode ini.',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary));
              }
              return Column(
                children: [
                  for (var i = 0; i < list.length; i++)
                    _ProductRow(rank: i + 1, stat: list[i]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final int rank;
  final ProductStat stat;
  const _ProductRow({required this.rank, required this.stat});

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('$rank',
                style: textTheme.titleSmall
                    ?.copyWith(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(stat.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyLarge),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${stat.qty} terjual',
                  style: textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              Text(formatRupiah(stat.revenue),
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Omzet per jam (0–23) + jam teramai, pada rentang laporan.
class HourlyCard extends ConsumerWidget {
  final DateTimeRange range;
  const HourlyCard({super.key, required this.range});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = AppTypography.textTheme;
    final async = ref.watch(hourlyStatsProvider(range));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Jam Ramai', style: textTheme.titleMedium),
          const SizedBox(height: 4),
          async.when(
            loading: () => const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error: $e'),
            data: (s) {
              final busiest = s.busiestHour;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    busiest == null
                        ? 'Belum ada penjualan pada periode ini.'
                        : 'Paling ramai: jam ${hourLabel(busiest)} (${s.count[busiest]} transaksi)',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  BarChart(
                    data: [
                      for (var h = 0; h < 24; h++)
                        BarChartDatum(
                          label: '$h',
                          value: s.revenue[h],
                          detail:
                              'Jam ${hourLabel(h)} · ${s.count[h]} transaksi · ${formatRupiah(s.revenue[h])}',
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
