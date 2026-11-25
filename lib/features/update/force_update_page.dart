import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/hero_layout.dart';
import '../../core/widgets/primary_button.dart';
import '../shifts/shift_providers.dart';
import 'in_app_updater.dart';
import 'version_check.dart';

/// Layar terkunci saat versi app di bawah minimal. Tanpa tombol kembali.
class ForceUpdatePage extends ConsumerWidget {
  final RemoteVersion? remote;

  /// Bila ada: tampil tombol "Lanjut sementara" (dipakai saat shift terbuka
  /// supaya kasir bisa menutup shift, tidak terkunci di tengah jualan).
  final VoidCallback? onContinue;
  const ForceUpdatePage({super.key, this.remote, this.onContinue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTypography.textTheme;
    final r = remote;
    final critical = r?.level == UpdateLevel.critical;
    final accent = critical ? AppColors.error : AppColors.success;
    final soft = critical ? AppColors.errorSoft : AppColors.mint;
    final info = ref.watch(packageInfoProvider).valueOrNull;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(critical ? AppIcons.alert : AppIcons.sparkles,
                size: 16, color: accent),
            const SizedBox(width: 6),
            Text(critical ? 'Perbaikan penting' : 'Versi baru tersedia',
                style: t.labelLarge?.copyWith(
                    color: critical ? AppColors.error : AppColors.textPrimary)),
          ]),
        ),
        const SizedBox(height: 12),
        Text(
          (r?.title ?? '').isEmpty ? 'Update KasirKita dulu, ya' : r!.title,
          style: t.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          (r?.message ?? '').isEmpty
              ? 'Versi baru KasirKita tersedia. Update dulu ya!'
              : r!.message,
          style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        if (r != null && r.changes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: critical ? AppColors.errorSoft : AppColors.inset,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.changesTitle.isEmpty ? 'Yang baru' : r.changesTitle,
                    style: t.titleSmall),
                const SizedBox(height: 8),
                for (final c in r.changes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(AppIcons.checkCircle, size: 18, color: accent),
                        const SizedBox(width: 8),
                        Expanded(child: Text(c, style: t.bodyMedium)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (info != null) ...[
          const SizedBox(height: 16),
          Text(
            'Versi Anda ${info.version} (${info.buildNumber})'
            '${r == null ? '' : ' · minimal build ${r.minVersionCode}'}',
            style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ],
    );

    final actions = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryButton(
          label: 'Update Sekarang',
          onPressed: () => runRequiredUpdate(ref.read(inAppUpdaterProvider)),
        ),
        if (onContinue != null) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: onContinue, child: const Text('Lanjut sementara')),
        ],
      ],
    );

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: HeroLayout(
          heroTint: critical ? AppColors.error.withValues(alpha: 0.22) : null,
          wideLeft: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [body, const SizedBox(height: 20), actions],
          ),
          narrowChild: body,
          narrowAction: actions,
        ),
      ),
    );
  }
}

/// True = user memilih "Lanjut sementara" pada sesi app ini. Sengaja tidak
/// disimpan: buka ulang app → layar update wajib muncul lagi.
final forceUpdateDismissedProvider = StateProvider<bool>((_) => false);

/// Pembungkus root: status required -> ForceUpdatePage; selain itu (termasuk
/// loading / error) -> child. Tidak pernah memblokir saat fetch gagal.
class UpdateGate extends ConsumerWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(updateDecisionProvider, (_, next) async {
      if (next.valueOrNull?.status != UpdateStatus.optional) return;
      final updater = ref.read(inAppUpdaterProvider);
      final messenger = ScaffoldMessenger.of(context);
      if (!await runOptionalUpdate(updater)) return;
      messenger.showSnackBar(SnackBar(
        content: const Text('Update siap'),
        duration: const Duration(days: 1),
        action: SnackBarAction(label: 'Pasang', onPressed: updater.complete),
      ));
    });
    final d = ref.watch(updateDecisionProvider).valueOrNull;
    if (d != null && d.status == UpdateStatus.required) {
      final shiftOpen = ref.watch(openShiftProvider).valueOrNull != null;
      if (shiftOpen && ref.watch(forceUpdateDismissedProvider)) return child;
      return ForceUpdatePage(
        remote: d.remote,
        onContinue: shiftOpen
            ? () => ref.read(forceUpdateDismissedProvider.notifier).state = true
            : null,
      );
    }
    return child;
  }
}
