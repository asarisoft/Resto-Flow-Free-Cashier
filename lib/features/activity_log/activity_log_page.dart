import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../models/activity_log.dart';
import 'activity_log_providers.dart';

/// Log aktivitas (Owner only; digate dari Pengaturan lewat canManageSettings).
class ActivityLogPage extends ConsumerWidget {
  const ActivityLogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = AppTypography.textTheme;
    final range = ref.watch(activityLogRangeProvider);
    final logs = ref.watch(activityLogsProvider);
    final fmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Log Aktivitas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(AppIcons.calendar, size: AppIcons.sm),
                  label: Text(range == null
                      ? 'Semua tanggal'
                      : '${fmt.format(range.start)} – ${fmt.format(range.end)}'),
                  onPressed: () => _pick(context, ref, range),
                ),
                if (range != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () =>
                        ref.read(activityLogRangeProvider.notifier).state = null,
                    child: const Text('Reset'),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: logs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat log: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: AppIcons.receipt,
                    title: 'Belum ada aktivitas',
                    subtitle: 'Aksi penting akan tercatat di sini.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _LogTile(log: list[i], textTheme: textTheme),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref,
      ({DateTime start, DateTime end})? current) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: current == null
          ? null
          : DateTimeRange(start: current.start, end: current.end),
    );
    if (picked == null) return;
    ref.read(activityLogRangeProvider.notifier).state = (
      start: DateTime(picked.start.year, picked.start.month, picked.start.day),
      end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
    );
  }
}

class _LogTile extends StatelessWidget {
  final ActivityLog log;
  final TextTheme textTheme;
  const _LogTile({required this.log, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    final when = DateFormat('dd/MM/yyyy HH:mm').format(log.createdAt);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(activityLabel(log.action),
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(log.target, style: textTheme.bodyMedium),
          if (log.detail != null && log.detail!.isNotEmpty)
            Text(log.detail!,
                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text('${log.username} · $when',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
