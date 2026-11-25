import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../settings/settings_providers.dart';
import '../users/users_providers.dart';
import 'demo_seeder.dart';

/// Tile debug "Isi data demo". Pemanggil WAJIB membungkus dengan `kDebugMode`.
class DemoSeedTile extends ConsumerWidget {
  const DemoSeedTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(AppIcons.demo, color: AppColors.textPrimary),
        title: Text('Isi data demo (debug)', style: AppTypography.textTheme.bodyLarge),
        onTap: () => _run(context, ref),
      ),
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Isi data demo'),
        content: const Text(
          'Mengisi produk, transaksi 60 hari, dan pengeluaran contoh. '
          'Ditolak bila sudah ada transaksi. Lanjutkan?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Isi')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    String message;
    try {
      await seedDemoData(ref.read(databaseProvider));
      ref.invalidate(profileProvider);
      ref.invalidate(userListProvider);
      message = 'Data demo terisi';
    } catch (e) {
      message = 'Gagal isi data demo: $e';
    }
    nav.pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
