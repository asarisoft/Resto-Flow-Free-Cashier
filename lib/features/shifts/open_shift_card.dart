import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/primary_button.dart';
import '../auth/auth_controller.dart';
import 'shift_providers.dart';

/// Nominal kas (modal awal / uang di laci): int >= 0.
int? parseShiftCash(String raw) {
  final v = int.tryParse(raw.trim());
  if (v == null || v < 0) return null;
  return v;
}

/// Kartu "Buka shift": input modal awal (int rupiah >= 0) + tombol Buka Shift.
/// Dipakai di POS dan halaman Shift.
class OpenShiftCard extends ConsumerStatefulWidget {
  final String message;
  const OpenShiftCard({
    super.key,
    this.message = 'Buka shift dulu untuk mulai jualan',
  });

  @override
  ConsumerState<OpenShiftCard> createState() => _OpenShiftCardState();
}

class _OpenShiftCardState extends ConsumerState<OpenShiftCard> {
  final _formKey = GlobalKey<FormState>();
  final _cashCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _cashCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = parseShiftCash(_cashCtrl.text)!;
    setState(() => _saving = true);
    try {
      final username = ref.read(currentUserProvider).valueOrNull?.username ?? '';
      await ref.read(shiftsDaoProvider).open(openedBy: username, openingCash: amount);
      if (mounted) setState(() => _saving = false);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal buka shift: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return AppCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.message,
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cashCtrl,
              decoration: const InputDecoration(
                labelText: 'Modal awal laci (Rp) *',
                prefixIcon: IconBadge(AppIcons.wallet),
                prefixText: 'Rp ',
                hintText: '0',
              ),
              keyboardType: TextInputType.number,
              style: textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                if (parseShiftCash(v) == null) return 'Harus angka 0 atau lebih';
                return null;
              },
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Buka Shift',
              icon: AppIcons.add,
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
