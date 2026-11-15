import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import 'primary_button.dart';

/// Dialog form standar: judul, field berjarak 16, pesan error, lalu
/// [Batal] [Simpan] sebaris. Dipakai semua dialog form agar konsisten.
class AppFormDialog extends StatelessWidget {
  final String title;
  final List<Widget> fields;
  final String submitLabel;
  final VoidCallback? onSubmit;
  final bool saving;
  final String? error;
  final GlobalKey<FormState>? formKey;
  final VoidCallback? onDelete;

  const AppFormDialog({
    super.key,
    required this.title,
    required this.fields,
    required this.onSubmit,
    this.submitLabel = 'Simpan',
    this.saving = false,
    this.error,
    this.formKey,
    this.onDelete,
  });

  static double _width(BuildContext context) {
    final avail = MediaQuery.sizeOf(context).width - 96;
    return avail < 560 ? avail : 560;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      title: Text(title),
      content: SizedBox(
        // Kunci lebar (AlertDialog menyusut ke lebar intrinsik isi): 560 dp,
        // atau selebar layar dikurangi inset + padding.
        width: _width(context),
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < fields.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  fields[i],
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: AppColors.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actions: [
        SizedBox(
          width: _width(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: saving ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.inputBorder),
                  ),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: submitLabel,
                  loading: saving,
                  onPressed: onSubmit,
                ),
              ),
            ],
          ),
              if (onDelete != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton.icon(
                    onPressed: saving ? null : onDelete,
                    style: TextButton.styleFrom(foregroundColor: AppColors.error, minimumSize: const Size(0, 48)),
                    icon: const Icon(AppIcons.delete),
                    label: const Text('Hapus'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
