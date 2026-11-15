import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/resto_profile.dart';
import '../settings/settings_providers.dart';
import '../../core/theme/app_icons.dart';
import '../../core/widgets/choice_segment.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Setup Resto')),
      body: SafeArea(child: Form(
        key: _formKey,
        child: Row(
          children: [
            // Left Column: Promo / Features
            Expanded(
              flex: 4,
              child: Container(
                color: AppColors.primary,
                padding: const EdgeInsets.all(48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.onPrimary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(AppIcons.star, color: Colors.white, size: AppIcons.hero),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Selamat Datang di\nRESTO FLOW FREE',
                      style: textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aplikasi kasir pintar untuk bisnis restoran dan kafe Anda. Didesain secara profesional, mudah digunakan, dan 100% GRATIS tanpa batasan fitur maupun biaya tersembunyi.',
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.onPrimary.withValues(alpha: 0.9),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 48),
                    _featureRow(AppIcons.checkCircle, 'Kelola Produk Tanpa Batas', textTheme),
                    const SizedBox(height: 12),
                    _featureRow(AppIcons.checkCircle, 'Catat Pengeluaran & Pemasukan', textTheme),
                    const SizedBox(height: 12),
                    _featureRow(AppIcons.checkCircle, 'Cetak Struk Bluetooth Thermal', textTheme),
                    const SizedBox(height: 12),
                    _featureRow(AppIcons.checkCircle, 'Laporan Keuangan Realtime', textTheme),
                  ],
                ),
              ),
            ),
            // Right Column: Form
            Expanded(
              flex: 5,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                children: [
                  Text('Pengaturan Awal', style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'Lengkapi profil restoran Anda untuk dicetak pada struk.',
                    style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nama Resto *'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(labelText: 'Alamat'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(labelText: 'No. Telepon'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _footerCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Pesan Footer Struk',
                      hintText: 'Misal: Terima kasih telah berkunjung',
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text('Ukuran Kertas Printer (Thermal)',
                      style: textTheme.titleMedium),
                  const SizedBox(height: 16),
                  ChoiceSegment<int>(
                    value: _paperWidth,
                    options: const [(58, '58 mm'), (80, '80 mm')],
                    onChanged: (v) => setState(() => _paperWidth = v),
                  ),
                  const SizedBox(height: 48),
                  PrimaryButton(
                    label: 'Simpan Profil & Mulai',
                    loading: _saving,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      )),
    );
  }

  Widget _featureRow(IconData icon, String text, TextTheme textTheme) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: AppIcons.lg),
        const SizedBox(width: 12),
        Text(
          text,
          style: textTheme.bodyLarge?.copyWith(
            color: AppColors.onPrimary.withValues(alpha: 0.9),
            fontWeight: FontWeight.w500,
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
