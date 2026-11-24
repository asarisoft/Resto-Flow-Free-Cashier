import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/primary_button.dart';

const instagramUrl = 'https://www.instagram.com/ngodingdarirumah';
const tiktokUrl = 'https://www.tiktok.com/@ngodingdarirumah';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka tautan')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTypography.textTheme;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dukung Developer'),
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 40, 40),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Follow kami', style: t.titleMedium),
                    const SizedBox(height: 12),
                    SecondaryButton(
                      label: 'Instagram',
                      icon: AppIcons.instagram,
                      onPressed: () => _open(context, instagramUrl),
                    ),
                    const SizedBox(height: 8),
                    SecondaryButton(
                      label: 'TikTok',
                      icon: AppIcons.tiktok,
                      onPressed: () => _open(context, tiktokUrl),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Jasa Bikin Aplikasi', style: t.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Butuh aplikasi untuk usahamu? Kami bisa bantu buatkan.',
                      style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Hubungi via Instagram',
                      icon: AppIcons.instagram,
                      onPressed: () => _open(context, instagramUrl),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
