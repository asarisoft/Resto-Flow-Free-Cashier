import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/hero_layout.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/resto_profile.dart';
import '../auth/auth_controller.dart';
import '../settings/settings_providers.dart';
import '../../core/theme/app_icons.dart';
import '../settings/profile_fields.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _footerCtrl = TextEditingController();
  int _paperWidth = 58;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Selamat datang di KasirKita',
            style: textTheme.displaySmall?.copyWith(color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text('Kasir gratis untuk warung, toko & cafe. Bisa offline.',
            style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        for (final f in _features) ...[
          _featureRow(f, textTheme),
          const SizedBox(height: 12),
        ],
      ],
    );
    final form = AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pengaturan Awal', style: textTheme.headlineSmall?.copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Lengkapi profil restoran Anda untuk dicetak pada struk.',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          ProfileFields(
            name: _nameCtrl,
            address: _addressCtrl,
            phone: _phoneCtrl,
            footer: _footerCtrl,
            paperWidth: _paperWidth,
            onPaperWidth: (v) => setState(() => _paperWidth = v),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Simpan Profil & Mulai',
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToLogin();
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.arrowLeft),
          tooltip: 'Kembali ke login',
          onPressed: _backToLogin,
        ),
        title: const Text('Setup Resto'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: HeroLayout(
            wideLeft: intro,
            wideRight: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AppCard(
                padding: EdgeInsets.zero,
                child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: form.child),
              ),
            ),
            narrowChild: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(padding: const EdgeInsets.all(24), child: intro),
                const SizedBox(height: 16),
                form,
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  void _backToLogin() => ref.read(loginProvider).logout();

  static const _features = [
    'Kelola Produk Tanpa Batas',
    'Catat Pengeluaran & Pemasukan',
    'Cetak Struk Bluetooth Thermal',
    'Laporan Keuangan Realtime',
  ];

  Widget _featureRow(String text, TextTheme textTheme) {
    return Row(
      children: [
        const IconBadge(AppIcons.checkCircle),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(settingsRepositoryProvider);
      await repo.updateProfile(RestoProfile(
        name: _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty
            ? null
            : _phoneCtrl.text.trim(),
        footerNote: _footerCtrl.text.trim().isEmpty
            ? null
            : _footerCtrl.text.trim(),
        paperWidth: _paperWidth,
        createdAt: DateTime.now(),
      ));
      ref.invalidate(profileProvider);
    } catch (e) {
      // TODO: show error snackbar
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
