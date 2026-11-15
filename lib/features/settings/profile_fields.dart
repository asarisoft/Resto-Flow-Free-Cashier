import 'package:flutter/material.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/choice_segment.dart';
import '../../models/resto_profile.dart';
import 'receipt_preview.dart';

/// Field profil resto + preview nota langsung. Dipakai dialog Edit Profil
/// dan Pengaturan Awal agar bentuknya sama.
class ProfileFields extends StatelessWidget {
  final TextEditingController name;
  final TextEditingController address;
  final TextEditingController phone;
  final TextEditingController footer;
  final int paperWidth;
  final ValueChanged<int> onPaperWidth;

  const ProfileFields({
    super.key,
    required this.name,
    required this.address,
    required this.phone,
    required this.footer,
    required this.paperWidth,
    required this.onPaperWidth,
  });

  String? _opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  RestoProfile _profile() => RestoProfile(
        name: name.text.trim().isEmpty ? 'NAMA RESTO' : name.text.trim(),
        address: _opt(address),
        phone: _opt(phone),
        footerNote: _opt(footer),
        paperWidth: paperWidth,
        createdAt: DateTime(2026),
      );

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Nama Resto *'),
          validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: address,
          decoration: const InputDecoration(labelText: 'Alamat'),
          keyboardType: TextInputType.multiline,
          minLines: 2,
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: phone,
          decoration: const InputDecoration(labelText: 'No. Telepon'),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: footer,
          decoration: const InputDecoration(
            labelText: 'Pesan Footer Struk',
            hintText: 'Misal: Terima kasih telah berkunjung',
            helperText: 'Boleh lebih dari satu baris (tekan Enter)',
            alignLabelWithHint: true,
          ),
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          minLines: 3,
          maxLines: 5,
        ),
        const SizedBox(height: 16),
        Text('Ukuran Kertas Printer (Thermal)', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        ChoiceSegment<int>(
          value: paperWidth,
          options: const [(58, '58 mm'), (80, '80 mm')],
          onChanged: onPaperWidth,
        ),
        const SizedBox(height: 16),
        Text('Preview Nota', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ListenableBuilder(
              listenable: Listenable.merge([name, address, phone, footer]),
              builder: (_, __) => ReceiptPreview(profile: _profile()),
            ),
          ),
        ),
      ],
    );
  }
}
