import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_logo.dart';

/// Data dibuat oleh versi app lebih baru: DB tidak dibuka, user diminta update.
class DatabaseTooNewPage extends StatelessWidget {
  const DatabaseTooNewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTypography.textTheme;
    return Scaffold(
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
                    Text('Update aplikasi dulu', style: t.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Data dibuat oleh versi KasirKita yang lebih baru. '
                      'Install versi terbaru. Data Anda tidak diubah.',
                      textAlign: TextAlign.center,
                      style: t.bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
