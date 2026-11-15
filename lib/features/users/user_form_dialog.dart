import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/daos/users_dao.dart';
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah User'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _username, decoration: const InputDecoration(labelText: 'Username')),
          TextField(controller: _password, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
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
          onPressed: () async {
            final dao = ref.read(usersDaoProvider);
            await dao.add(username: _username.text, password: _password.text, role: _role);
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    );
  }
}