import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/clay.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/password_field.dart';
import '../../core/widgets/primary_button.dart';
import 'auth_controller.dart';
import '../../core/theme/app_icons.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _loading = false;
  String? _selectedUsername;
  final _passwordController = TextEditingController();
  List<String> _usernames = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final dao = ref.read(usersDaoProvider);
    await dao.seedDefaultOwnerIfEmpty();
    final users = await dao.getAll();
    if (!mounted) return;
    setState(() {
      _usernames = users.where((u) => u.active).map((u) => u.username).toList();
      if (_usernames.isNotEmpty && _selectedUsername == null) {
        _selectedUsername = _usernames.first;
      }
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  /// Lebar minimum untuk tata letak split (gambar kiri + form kanan).
  static const _splitBreakpoint = 600.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth >= _splitBreakpoint) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    const Expanded(child: _Hero()),
                    const SizedBox(width: 24),
                    Expanded(child: Center(child: SingleChildScrollView(child: _form(context)))),
                  ],
                ),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 220, width: double.infinity, child: _Hero()),
                  const SizedBox(height: 16),
                  _form(context),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: ClayDecoration.box(color: AppColors.peach, radius: 28),
              child: const Icon(AppIcons.receipt, color: AppColors.textPrimary, size: 36),
            ),
            const SizedBox(height: 20),
            Text('Halo, selamat datang!',
                style: textTheme.headlineSmall?.copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text('Masuk untuk mulai jualan hari ini',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _selectedUsername,
              items: _usernames
                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedUsername = v),
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(AppIcons.person),
              ),
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: _passwordController,
              label: 'Password',
              prefixIcon: AppIcons.lock,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _loading ? null : _submit(),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Masuk',
              icon: AppIcons.login,
              loading: _loading,
              onPressed: _loading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedUsername == null) return;
    setState(() => _loading = true);
    try {
      final ok = await ref.read(loginProvider).login(_selectedUsername!, _passwordController.text);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username atau password salah'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

/// Gambar dekoratif di sisi kiri (atau atas di layar sempit).
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ClayDecoration.box(radius: 28),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Image.asset(
          'assets/images/login_hero.webp',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
