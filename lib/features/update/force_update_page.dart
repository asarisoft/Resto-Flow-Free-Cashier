import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/remote_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/primary_button.dart';
import 'version_check.dart';

/// Layar terkunci saat versi app di bawah minimal. Tanpa tombol kembali.
class ForceUpdatePage extends ConsumerWidget {
  final String message;
  const ForceUpdatePage({super.key, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTypography.textTheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AppCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppLogo(size: 72),
                      const SizedBox(height: 16),
                      Text('Update wajib', style: t.titleLarge),
                      const SizedBox(height: 8),
                      Text(
                        message.isEmpty
                            ? 'Versi baru KasirKita tersedia. Update dulu ya!'
                            : message,
                        textAlign: TextAlign.center,
                        style: t.bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: 'Update Sekarang',
                        onPressed: () => launchUrl(
                          Uri.parse(playStoreUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pembungkus root: status required -> ForceUpdatePage; selain itu (termasuk
/// loading / error) -> child. Tidak pernah memblokir saat fetch gagal.
class UpdateGate extends ConsumerWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(updateDecisionProvider).valueOrNull;
    if (d != null && d.status == UpdateStatus.required) {
      return ForceUpdatePage(message: d.message);
    }
    return child;
  }
}
