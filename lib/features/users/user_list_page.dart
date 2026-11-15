import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/daos/users_dao.dart';
import '../auth/auth_controller.dart' hide usersDaoProvider;
import 'users_providers.dart';
import 'user_form_dialog.dart';

class UserListPage extends ConsumerWidget {
  const UserListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(userListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(context: context, builder: (_) => const UserFormDialog()),
        child: const Icon(Icons.add),
      ),
      body: users.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final u = list[i];
            return ListTile(
              title: Text(u.username),
              subtitle: Text(u.role),
              trailing: Switch(
                value: u.active,
                onChanged: (v) async {
                  final dao = ref.read(usersDaoProvider);
                  await dao.setActive(u.id, v);
                  ref.invalidate(userListProvider);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}