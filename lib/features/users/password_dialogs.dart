import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/app_form_dialog.dart';
import '../../core/widgets/password_field.dart';
import '../../models/app_user.dart';
import '../activity_log/activity_log_providers.dart';
import '../auth/auth_controller.dart' show currentUserProvider;
import 'users_providers.dart';

/// Dialog "Ganti password" untuk user yang sedang login (semua role).
/// Wajib isi password lama.
class ChangePasswordDialog extends ConsumerStatefulWidget {
  final String userId;

  /// Wajib ganti (password bawaan): tanpa Batal, tidak bisa ditutup.
  const ChangePasswordDialog({super.key, required this.userId});

  @override
  ConsumerState<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      title: 'Ganti Password',
      saving: _saving,
      error: _error,
      onSubmit: _save,
      fields: [
        PasswordField(controller: _old, label: 'Password lama'),
        PasswordField(
          controller: _new,
          label: 'Password baru (min. 8 karakter)',
          textInputAction: TextInputAction.next,
        ),
        PasswordField(
          controller: _confirm,
          label: 'Konfirmasi password baru',
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_new.text != _confirm.text) {
      setState(() => _error = 'Konfirmasi password tidak sama');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(usersDaoProvider).changeOwnPassword(
            userId: widget.userId,
            oldPassword: _old.text,
            newPassword: _new.text,
          );
      await logActivity(ref, 'user.password_change',
          ref.read(currentUserProvider).valueOrNull?.username ?? '-');
      if (mounted) Navigator.pop(context);
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _error = '${e.message}');
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Dialog "Reset password" untuk Owner dari daftar pengguna.
class ResetPasswordDialog extends ConsumerStatefulWidget {
  final AppUser actor;
  final AppUser target;
  const ResetPasswordDialog({super.key, required this.actor, required this.target});

  @override
  ConsumerState<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends ConsumerState<ResetPasswordDialog> {
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      title: 'Reset Password ${widget.target.username}',
      saving: _saving,
      error: _error,
      onSubmit: _save,
      fields: [
        PasswordField(
          controller: _new,
          label: 'Password baru (min. 8 karakter)',
          textInputAction: TextInputAction.next,
        ),
        PasswordField(
          controller: _confirm,
          label: 'Konfirmasi password baru',
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_new.text != _confirm.text) {
      setState(() => _error = 'Konfirmasi password tidak sama');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(usersDaoProvider).resetPassword(
            actorRole: widget.actor.role,
            actorId: widget.actor.id,
            targetId: widget.target.id,
            newPassword: _new.text,
          );
      await logActivity(ref, 'user.password_reset', widget.target.username);
      if (mounted) Navigator.pop(context);
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _error = '${e.message}');
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
