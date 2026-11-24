import 'package:flutter/material.dart';
import '../theme/app_icons.dart';

/// Field password dengan tombol lihat/sembunyikan. Dipakai di dialog
/// ganti/reset password agar bentuknya konsisten.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final IconData? prefixIcon;

  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.textInputAction,
    this.onSubmitted,
    this.prefixIcon,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      textInputAction: widget.textInputAction,
      autofillHints: const [AutofillHints.password],
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Tampilkan password' : 'Sembunyikan password',
          icon: Icon(_obscure ? AppIcons.visible : AppIcons.hidden),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}
