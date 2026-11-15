import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/daos/users_dao.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_provider.dart';
import '../../core/widgets/primary_button.dart';
import '../users/users_providers.dart';

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
    return AlertDialog(
      title: const Text('Tambah User'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _username, decoration: const InputDecoration(labelText: 'Username')),
          TextField(controller: _password, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: AppColors.error)),
            ),
          DropdownButton<String>(
            value: _role,
            items: const [
              DropdownMenuItem(value: 'owner', child: Text('Owner')),
              DropdownMenuItem(value: 'kasir', child: Text('Kasir')),
            ],
            onChanged: (v) => setState(() => _role = v ?? 'kasir'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        PrimaryButton(
          label: 'Simpan',
          onPressed: _saving ? null : _save,
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
