import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/primary_button.dart';
import 'logo_image_service.dart';

/// Pilih/ganti/hapus logo struk (opsional). Dipakai di Setup Resto & Edit Profil.
/// [picked] = file baru belum disimpan; [savedPath] = logo tersimpan (path DB).
class LogoPickerField extends StatelessWidget {
  final XFile? picked;
  final String? savedPath;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const LogoPickerField({
    super.key,
    required this.picked,
    required this.savedPath,
    required this.enabled,
    required this.onPick,
    required this.onRemove,
  });

  bool get _hasLogo => picked != null || savedPath != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Logo Struk (opsional)',
            style: AppTypography.textTheme.titleSmall),
        const SizedBox(height: 8),
        Center(
          child: Container(
            height: 96,
            width: 160,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: _preview(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: _hasLogo ? 'Ganti Logo' : 'Pilih Logo',
                icon: AppIcons.addPhoto,
                onPressed: enabled ? onPick : null,
              ),
            ),
            if (_hasLogo) ...[
              const SizedBox(width: 8),
              Expanded(
                child: SecondaryButton(
                  label: 'Hapus',
                  icon: AppIcons.delete,
                  onPressed: enabled ? onRemove : null,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _preview() {
    final placeholder = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          AppIcons.brokenImage,
          size: AppIcons.xl,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 4),
        Text(
          'Belum ada logo',
          style: AppTypography.textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
    if (picked != null) {
      return Image.file(
        File(picked!.path),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }
    final path = savedPath;
    if (path == null) return placeholder;
    return FutureBuilder<String>(
      future: LogoImageService.resolvePath(path),
      builder: (context, snap) {
        final abs = snap.data;
        if (abs == null) return placeholder;
        return Image.file(
          File(abs),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => placeholder,
        );
      },
    );
  }
}
