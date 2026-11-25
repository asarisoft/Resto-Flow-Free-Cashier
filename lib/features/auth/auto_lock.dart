import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/password_field.dart';
import 'auth_controller.dart';
import 'login_throttle.dart';

/// Pilihan menit idle di Pengaturan (0 = nonaktif).
const autoLockChoices = [0, 1, 5, 10, 15, 30];

/// Detik per tick pemeriksa idle. Presisi kunci ±[autoLockTickSeconds] detik.
const autoLockTickSeconds = 10;

const _prefsKey = 'auto_lock_minutes';

/// Menit idle sebelum layar terkunci. 0 = nonaktif (default).
class AutoLockMinutes extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefsKey) ?? 0;
  }

  Future<void> set(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, minutes);
    state = AsyncData(minutes);
  }
}

final autoLockMinutesProvider = AsyncNotifierProvider<AutoLockMinutes, int>(
  AutoLockMinutes.new,
);

/// True = layar kunci tampil di atas seluruh app.
final lockedProvider = StateProvider<bool>((ref) => false);

/// Memeriksa password user yang sedang login. Bisa di-override di tes.
final unlockVerifierProvider =
    Provider<Future<bool> Function(String username, String password)>((ref) {
      return (username, password) async =>
          (await ref.read(usersDaoProvider).verify(username, password)) != null;
    });

/// Pembungkus seluruh app: kunci otomatis saat idle / app lama di background /
/// app dibuka ulang. Layar kunci menutup semua (termasuk dialog); state app
/// (keranjang dsb.) tetap utuh di bawahnya.
class AutoLockGate extends ConsumerStatefulWidget {
  final Widget child;

  /// Kunci saat app baru dibuka (bila fitur aktif & sudah login), supaya
  /// kunci tidak bisa dilewati dengan menutup paksa app.
  final bool lockOnLaunch;

  /// Dapat diganti di tes.
  final DateTime Function() now;

  const AutoLockGate({
    super.key,
    required this.child,
    this.lockOnLaunch = true,
    this.now = DateTime.now,
  });

  @override
  ConsumerState<AutoLockGate> createState() => _AutoLockGateState();
}

class _AutoLockGateState extends ConsumerState<AutoLockGate>
    with WidgetsBindingObserver {
  Timer? _timer;
  int _idleSeconds = 0;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(
      const Duration(seconds: autoLockTickSeconds),
      (_) => _tick(),
    );
    if (widget.lockOnLaunch) _lockIfEnabledOnLaunch();
  }

  Future<void> _lockIfEnabledOnLaunch() async {
    final minutes = await ref.read(autoLockMinutesProvider.future);
    final user = await ref.read(currentUserProvider.future);
    if (!mounted) return;
    if (minutes > 0 && user != null) {
      ref.read(lockedProvider.notifier).state = true;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  int get _minutes => ref.read(autoLockMinutesProvider).valueOrNull ?? 0;
  bool get _loggedIn => ref.read(currentUserProvider).valueOrNull != null;

  void _lock() => ref.read(lockedProvider.notifier).state = true;

  void _tick() {
    if (!mounted || ref.read(lockedProvider)) return;
    if (_minutes <= 0 || !_loggedIn) {
      _idleSeconds = 0;
      return;
    }
    _idleSeconds += autoLockTickSeconds;
    if (_idleSeconds >= _minutes * 60) _lock();
  }

  void _onActivity() => _idleSeconds = 0;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = widget.now();
    } else if (state == AppLifecycleState.resumed) {
      final since = _backgroundedAt;
      _backgroundedAt = null;
      if (since != null &&
          _minutes > 0 &&
          _loggedIn &&
          widget.now().difference(since) >= Duration(minutes: _minutes)) {
        _lock();
      }
    }
  }

  /// Saat terkunci, tombol Back tidak boleh menembus ke layar di bawahnya.
  @override
  Future<bool> didPopRoute() async => ref.read(lockedProvider);

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(currentUserProvider).valueOrNull != null;
    final locked = ref.watch(lockedProvider) && loggedIn;

    // Logout / ganti sesi membuka kunci (login berikutnya memakai password).
    ref.listen(currentUserProvider, (_, next) {
      if (next.valueOrNull == null) {
        ref.read(lockedProvider.notifier).state = false;
      }
    });
    // Mengubah pengaturan memulai hitungan idle dari awal.
    ref.listen(autoLockMinutesProvider, (_, __) => _idleSeconds = 0);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onActivity(),
      onPointerMove: (_) => _onActivity(),
      onPointerSignal: (_) => _onActivity(),
      child: Stack(
        children: [
          // Di bawah layar kunci: tidak bisa disentuh, difokuskan, atau dibaca
          // pembaca layar.
          Positioned.fill(
            child: IgnorePointer(
              ignoring: locked,
              child: ExcludeFocus(
                excluding: locked,
                child: ExcludeSemantics(excluding: locked, child: widget.child),
              ),
            ),
          ),
          if (locked) const Positioned.fill(child: LockScreen()),
        ],
      ),
    );
  }
}

class LockScreen extends StatelessWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Overlay sendiri: di atas Navigator app tidak ada Overlay untuk tooltip
    // dan sejenisnya. Isi di widget terpisah supaya ikut rebuild saat state
    // berubah (builder OverlayEntry hanya dipanggil ulang oleh Overlay).
    return Overlay(
      initialEntries: [OverlayEntry(builder: (_) => const _LockBody())],
    );
  }
}

class _LockBody extends ConsumerStatefulWidget {
  const _LockBody();

  @override
  ConsumerState<_LockBody> createState() => _LockBodyState();
}

class _LockBodyState extends ConsumerState<_LockBody> {
  final _pw = TextEditingController();
  bool _checking = false;
  bool _coolingDown = false;
  String? _error;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    final left = await ref.read(loginThrottleProvider).remaining(user.username);
    if (!mounted || left == null) return;
    setState(() => _lock(left));
  }

  void _lock(Duration d) {
    _coolingDown = true;
    _error = lockMessage(d);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(d, () {
      if (mounted) setState(() => _coolingDown = false);
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null || _checking || _coolingDown || _pw.text.isEmpty) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    final throttle = ref.read(loginThrottleProvider);
    bool? ok;
    Duration? locked;
    try {
      ok = await throttle.attempt(user.username, () async {
        final r = await ref.read(unlockVerifierProvider)(user.username, _pw.text);
        return r ? true : null;
      });
      if (ok == null) locked = await throttle.remaining(user.username);
    } on LoginLockedException catch (e) {
      locked = e.remaining;
    }
    if (!mounted) return;
    if (ok == true) {
      ref.read(lockedProvider.notifier).state = false;
      return;
    }
    _pw.clear();
    setState(() {
      _checking = false;
      if (locked != null) {
        _lock(locked);
      } else {
        _error = 'Password salah';
      }
    });
  }

  Future<void> _logout() async {
    await ref.read(loginProvider).logout();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = AppTypography.textTheme;
    final user = ref.watch(currentUserProvider).valueOrNull;

    // Overlay sendiri: di atas Navigator app tidak ada Overlay untuk tooltip
    // dan sejenisnya.
    return Material(
      color: AppColors.background,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    AppIcons.key,
                    size: 40,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Layar terkunci',
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user == null ? '' : 'Masuk sebagai ${user.username}',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  PasswordField(
                    controller: _pw,
                    label: 'Password',
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _unlock(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _checking || _coolingDown ? null : _unlock,
                    child: const Text('Buka kunci'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _logout,
                    child: const Text('Ganti pengguna (logout)'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
