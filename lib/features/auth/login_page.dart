import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/clay.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/icon_badge.dart';
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

  /// Lebar minimum untuk tata letak satu kartu besar (gambar full-bleed).
  static const _wideBreakpoint = 900.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) =>
              c.maxWidth >= _wideBreakpoint ? _wide(context, c) : _narrow(context, c),
        ),
      ),
    );
  }

  Widget _wide(BuildContext context, BoxConstraints c) {
    final textTheme = AppTypography.textTheme;
    return Container(
      margin: const EdgeInsets.all(24),
      decoration: ClayDecoration.box(radius: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            const Positioned.fill(child: _HeroImage()),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: (c.maxWidth - 48) * 0.42,
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    padding: const EdgeInsets.all(40),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight - 80),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Brand(),
                          const SizedBox(height: 32),
                          Text('Halo, selamat datang!',
                              style: textTheme.displaySmall?.copyWith(color: AppColors.textPrimary)),
                          const SizedBox(height: 8),
                          Text('Masuk untuk mulai jualan hari ini',
                              style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary)),
                          const SizedBox(height: 24),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: AppCard(padding: const EdgeInsets.all(24), child: _fields()),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _narrow(BuildContext context, BoxConstraints c) {
    final textTheme = AppTypography.textTheme;
    final heroH = c.maxWidth * 0.5 < 260 ? c.maxWidth * 0.5 : 260.0;
    return SingleChildScrollView(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroH,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
              child: const _HeroImage(),
            ),
          ),
          const Positioned(top: 16, left: 16, child: _Brand()),
          Padding(
            padding: EdgeInsets.fromLTRB(16, heroH - 32, 16, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Halo, selamat datang!',
                          style: textTheme.headlineSmall?.copyWith(color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Masuk untuk mulai jualan hari ini',
                          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 24),
                      _fields(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fields() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedUsername,
          items: _usernames.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
          onChanged: (v) => setState(() => _selectedUsername = v),
          decoration: const InputDecoration(
            labelText: 'Username',
            prefixIcon: IconBadge(AppIcons.person),
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

/// Logo + nama app (placeholder ikon, diganti logo asli di Task 14).
class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: ClayDecoration.box(color: AppColors.peach, radius: 18),
          child: const Icon(AppIcons.pos, color: AppColors.textPrimary, size: 28),
        ),
        const SizedBox(width: 12),
        Text('KasirKita',
            style: AppTypography.textTheme.titleLarge?.copyWith(color: AppColors.textPrimary)),
      ],
    );
  }
}

/// Gambar dekoratif: dinding kosong di kiri, karakter di kanan.
class _HeroImage extends StatelessWidget {
  const _HeroImage();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/login_hero.webp',
      fit: BoxFit.cover,
      alignment: Alignment.centerRight,
      excludeFromSemantics: true,
    );
  }
}
