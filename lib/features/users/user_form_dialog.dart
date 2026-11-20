import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../users/users_providers.dart';
import '../../core/widgets/app_form_dialog.dart';
import '../activity_log/activity_log_providers.dart';

class UserFormDialog extends ConsumerStatefulWidget {
  const UserFormDialog({super.key});

  @override
  ConsumerState<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends ConsumerState<UserFormDialog> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  String _role = 'kasir';
  String? _error;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return AppFormDialog(
      title: 'Tambah Pengguna',
      saving: _saving,
      error: _error,
      onSubmit: _save,
      fields: [
        TextField(
          controller: _username,
          decoration: const InputDecoration(labelText: 'Username'),
        ),
        TextField(
          controller: _password,
          decoration: const InputDecoration(labelText: 'Password (min. 8 karakter)'),
          obscureText: true,
        ),
        DropdownButtonFormField<String>(
          initialValue: _role,
          decoration: const InputDecoration(labelText: 'Role'),
          items: const [
            DropdownMenuItem(value: 'owner', child: Text('Owner')),
            DropdownMenuItem(value: 'kasir', child: Text('Kasir')),
          ],
          onChanged: (v) => setState(() => _role = v ?? 'kasir'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(usersDaoProvider).add(username: _username.text, password: _password.text, role: _role);
      await logActivity(ref, 'user.add', _username.text.trim(), detail: 'role $_role');
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
