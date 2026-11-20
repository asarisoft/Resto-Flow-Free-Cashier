import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
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
  bool _obscurePassword = true;
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

  /// Lebar minimum untuk tata letak split (panel kiri + form kanan).
  static const _splitBreakpoint = 720.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= _splitBreakpoint) {
            return Row(
              children: [
                const Expanded(flex: 5, child: _BrandPanel()),
                Expanded(flex: 6, child: SafeArea(child: _form(context))),
              ],
            );
          }
          // HP portrait: panel jadi pita pendek di atas.
          return Column(
            children: [
              const _BrandPanel(compact: true),
              Expanded(child: SafeArea(top: false, child: _form(context))),
            ],
          );
        },
      ),
    );
  }

  Widget _form(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Masuk ke kasir',
                  style: textTheme.headlineSmall
                      ?.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('Pilih pengguna, lalu masukkan password.',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 28),
              DropdownButtonFormField<String>(
                initialValue: _selectedUsername,
                items: _usernames
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedUsername = v),
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _loading ? null : _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Tampilkan password'
                        : 'Sembunyikan password',
                    icon: Icon(
                        _obscurePassword ? AppIcons.visible : AppIcons.hidden),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
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

/// Panel brand oranye. Tepi yang berbatasan dengan form dibuat berlubang
/// seperti sobekan struk. [compact] = pita pendek untuk layar sempit.
class _BrandPanel extends StatelessWidget {
  final bool compact;
  const _BrandPanel({this.compact = false});

  static const _tagline = 'Kasir resto yang tetap jalan tanpa internet.';

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final mark = Container(
      width: compact ? 44 : 64,
      height: compact ? 44 : 64,
      decoration: BoxDecoration(
        color: AppColors.onPrimary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
      ),
      child: Icon(AppIcons.receipt,
          color: AppColors.onPrimary, size: compact ? AppIcons.md : 32),
    );

    final Widget content = compact
        ? Row(
            children: [
              mark,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Resto Flow',
                        style: textTheme.titleLarge
                            ?.copyWith(color: AppColors.onPrimary)),
                    Text(_tagline,
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppColors.onPrimary)),
                  ],
                ),
              ),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              mark,
              const SizedBox(height: 28),
              Text('Resto Flow',
                  style: textTheme.displaySmall
                      ?.copyWith(color: AppColors.onPrimary)),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(_tagline,
                    style: textTheme.bodyLarge
                        ?.copyWith(color: AppColors.onPrimary)),
              ),
            ],
          );

    return Container(
      color: AppColors.primary,
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: CustomPaint(
                painter: _PerforationPainter(
                  color: AppColors.background,
                  vertical: !compact,
                ),
              ),
            ),
          ),
          compact
              ? SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                    child: content,
                  ),
                )
              // Dipusatkan; bisa scroll supaya tidak overflow di layar pendek
              // (mis. landscape HP) atau teks sistem besar.
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(48, 32, 56, 32),
                    child: content,
                  ),
                ),
        ],
      ),
    );
  }
}

/// Lingkaran kecil sepanjang tepi (kanan untuk [vertical], bawah untuk pita)
/// berwarna latar form: tampak seperti perforasi struk.
class _PerforationPainter extends CustomPainter {
  final Color color;
  final bool vertical;
  const _PerforationPainter({required this.color, required this.vertical});

  static const _radius = 6.0;
  static const _step = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final length = vertical ? size.height : size.width;
    final count = (length / _step).floor();
    // Pusatkan deretan lubang di sepanjang tepi.
    final start = (length - (count - 1) * _step) / 2;
    for (var i = 0; i < count; i++) {
      final t = start + i * _step;
      canvas.drawCircle(
        vertical ? Offset(size.width, t) : Offset(t, size.height),
        _radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PerforationPainter old) =>
      old.color != color || old.vertical != vertical;
}
