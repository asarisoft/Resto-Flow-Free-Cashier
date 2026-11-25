import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/daos/users_dao.dart';
import '../../core/services/database.dart' show isDatabaseTooNew;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/hero_layout.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/password_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/step_progress.dart';
import '../backup/restore_flow.dart';
import 'auth_controller.dart';
import 'database_too_new_page.dart';
import 'login_page.dart';

/// Belum ada user → Register; sudah ada → Login.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(hasAnyUserProvider).when(
          data: (has) => has ? const LoginPage() : const RegisterPage(),
          loading: () => const Scaffold(backgroundColor: AppColors.background),
          error: (e, _) => isDatabaseTooNew(e)
              ? const DatabaseTooNewPage()
              : const LoginPage(),
        );
  }
}

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _usernameError;
  String? _passwordError;
  String? _confirmError;

  static const _info = 'Akun disimpan hanya di HP ini (offline). Catat password Anda — '
      'tidak bisa dipulihkan lewat internet. Gunakan Backup agar data aman.';

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final u = _username.text.trim();
    final p = _password.text;
    setState(() {
      _usernameError = RegExp(r'^[A-Za-z0-9_]{3,20}$').hasMatch(u)
          ? null
          : 'Nama pengguna 3–20 karakter: huruf, angka, underscore';
      _passwordError = p.length >= UsersDao.minPasswordLength
          ? null
          : 'Password minimal ${UsersDao.minPasswordLength} karakter';
      _confirmError = p == _confirm.text ? null : 'Password tidak sama';
    });
    if (_usernameError != null || _passwordError != null || _confirmError != null) return;
    setState(() => _loading = true);
    try {
      await ref.read(loginProvider).register(u, p);
    } on StateError {
      // Sudah ada akun (mis. balapan) → gate menampilkan Login.
      ref.invalidate(hasAnyUserProvider);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Pulihkan dari Backup'),
        content: const Text('Data dari backup akan dipakai di HP ini.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Lanjut')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final path = await ref.read(backupZipPickerProvider)();
    if (path == null || !mounted) return;
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Sukses: user dari backup terbaca → AuthGate pindah ke Login (sesi dihapus).
      await restoreBackupFromZip(ref, path);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(restoreErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _restoreLink() => TextButton(
        onPressed: _loading ? null : _restore,
        child: const Text('Pindah dari HP lama? Pulihkan dari Backup', textAlign: TextAlign.center),
      );

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: HeroLayout(
          wideLeft: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Buat akun Owner', style: textTheme.displaySmall?.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: AppCard(padding: const EdgeInsets.all(24), child: _fields()),
              ),
            ],
          ),
          narrowChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StepProgress(step: 1),
              const SizedBox(height: 16),
              Text('Buat akun Owner', style: textTheme.headlineSmall?.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('Langkah 1 dari 2 · lalu atur toko',
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              _fields(withInfoAndButton: false),
              const SizedBox(height: 16),
              const _OfflineInfo(),
              Center(child: _restoreLink()),
            ],
          ),
          narrowAction: PrimaryButton(label: 'Buat Akun', loading: _loading, onPressed: _loading ? null : _submit),
        ),
      ),
    );
  }

  Widget _fields({bool withInfoAndButton = true}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _username,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Nama pengguna',
            prefixIcon: const IconBadge(AppIcons.person),
            errorText: _usernameError,
            errorMaxLines: 2,
          ),
        ),
        const SizedBox(height: 16),
        _FieldError(
          error: _passwordError,
          child: PasswordField(
            controller: _password,
            label: 'Password',
            prefixIcon: AppIcons.lock,
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 16),
        _FieldError(
          error: _confirmError,
          child: PasswordField(
            controller: _confirm,
            label: 'Ulangi password',
            prefixIcon: AppIcons.lock,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _loading ? null : _submit(),
          ),
        ),
        if (withInfoAndButton) ...[
          const SizedBox(height: 16),
          Text(_info, style: AppTypography.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Buat Akun', loading: _loading, onPressed: _loading ? null : _submit),
          _restoreLink(),
        ],
      ],
    );
  }
}

/// PasswordField belum punya errorText; tampilkan pesan tepat di bawahnya.
class _FieldError extends StatelessWidget {
  final String? error;
  final Widget child;
  const _FieldError({required this.error, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        child,
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: Text(error!, style: AppTypography.textTheme.bodySmall?.copyWith(color: AppColors.error)),
          ),
      ],
    );
  }
}

/// Info offline (HP): kotak peach, teks gelap (kontras tinggi), ikon gembok.
class _OfflineInfo extends StatelessWidget {
  const _OfflineInfo();

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.textTheme.bodySmall?.copyWith(color: AppColors.textPrimary);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.peach, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(AppIcons.lock, size: AppIcons.md, color: AppColors.textPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(style: style, children: const [
                TextSpan(text: 'Tersimpan hanya di HP ini.', style: TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: ' Catat password Anda dan rutin Backup.'),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
