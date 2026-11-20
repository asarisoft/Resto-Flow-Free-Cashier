import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_resto/features/auth/auth_controller.dart';
import 'package:kasir_resto/features/auth/auto_lock.dart';
import 'package:kasir_resto/features/pos/cart_provider.dart';
import 'package:kasir_resto/models/app_user.dart';
import 'package:kasir_resto/models/product.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FixedMinutes extends AutoLockMinutes {
  final int minutes;
  _FixedMinutes(this.minutes);
  @override
  Future<int> build() async => minutes;
}

const _kasir =
    AppUser(id: 'u1', username: 'budi', role: 'kasir', active: true);

final _userSource = StateProvider<AppUser?>((ref) => _kasir);

Product _product() => Product(
      id: 'p1',
      name: 'Nasi Goreng',
      price: 20000,
      hpp: 8000,
      ready: true,
      archived: false,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  int minutes = 1,
  AppUser? user = _kasir,
  bool lockOnLaunch = false,
  List<String>? verifyCalls,
  DateTime Function()? now,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      autoLockMinutesProvider.overrideWith(() => _FixedMinutes(minutes)),
      _userSource.overrideWith((ref) => user),
      currentUserProvider.overrideWith((ref) async => ref.watch(_userSource)),
      unlockVerifierProvider.overrideWithValue((u, p) async {
        verifyCalls?.add(p);
        return p == 'rahasia123';
      }),
    ],
    child: MaterialApp(
      home: const Scaffold(body: Center(child: Text('HALAMAN KASIR'))),
      builder: (context, child) => AutoLockGate(
        lockOnLaunch: lockOnLaunch,
        now: now ?? DateTime.now,
        child: child!,
      ),
    ),
  ));
  await tester.pump(); // biarkan provider async selesai
  return ProviderScope.containerOf(tester.element(find.byType(AutoLockGate)));
}

final _lockedText = find.text('Layar terkunci');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('terkunci setelah idle N menit, belum sebelumnya', (tester) async {
    await _pump(tester, minutes: 1);

    await tester.pump(const Duration(seconds: 50));
    expect(_lockedText, findsNothing);

    await tester.pump(const Duration(seconds: 20));
    await tester.pump();
    expect(_lockedText, findsOneWidget);
    expect(find.text('Masuk sebagai budi'), findsOneWidget);
  });

  testWidgets('sentuhan mereset hitungan idle', (tester) async {
    await _pump(tester, minutes: 1);

    await tester.pump(const Duration(seconds: 50));
    await tester.tap(find.text('HALAMAN KASIR'));
    await tester.pump(const Duration(seconds: 50));
    expect(_lockedText, findsNothing);

    await tester.pump(const Duration(seconds: 20));
    await tester.pump();
    expect(_lockedText, findsOneWidget);
  });

  testWidgets('nonaktif (0 menit) tidak pernah terkunci', (tester) async {
    await _pump(tester, minutes: 0);
    await tester.pump(const Duration(hours: 3));
    await tester.pump();
    expect(_lockedText, findsNothing);
  });

  testWidgets('belum login tidak pernah terkunci', (tester) async {
    await _pump(tester, minutes: 1, user: null);
    await tester.pump(const Duration(minutes: 10));
    await tester.pump();
    expect(_lockedText, findsNothing);
  });

  testWidgets('keranjang tetap utuh saat terkunci dan setelah dibuka',
      (tester) async {
    final c = await _pump(tester, minutes: 1);
    c.read(cartProvider.notifier).addItem(_product());
    c.read(cartProvider.notifier).setNote(0, 'tanpa sambal');

    await tester.pump(const Duration(minutes: 2));
    await tester.pump();
    expect(_lockedText, findsOneWidget);
    expect(c.read(cartProvider).single.note, 'tanpa sambal');

    await tester.enterText(find.byType(TextField), 'rahasia123');
    await tester.tap(find.text('Buka kunci'));
    await tester.pump();
    await tester.pump();

    expect(_lockedText, findsNothing);
    expect(c.read(cartProvider).single.note, 'tanpa sambal');
    expect(c.read(cartProvider).single.qty, 1);
  });

  testWidgets('password salah tetap terkunci, benar membuka', (tester) async {
    final calls = <String>[];
    await _pump(tester, minutes: 1, verifyCalls: calls);
    await tester.pump(const Duration(minutes: 2));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'salah');
    await tester.tap(find.text('Buka kunci'));
    await tester.pump();
    await tester.pump();
    expect(_lockedText, findsOneWidget);
    expect(find.text('Password salah'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'rahasia123');
    await tester.tap(find.text('Buka kunci'));
    await tester.pump();
    await tester.pump();
    expect(_lockedText, findsNothing);
    expect(calls, ['salah', 'rahasia123']);
  });

  testWidgets('5 kali salah → jeda 30 detik, verifikasi tidak dipanggil lagi',
      (tester) async {
    final calls = <String>[];
    await _pump(tester, minutes: 1, verifyCalls: calls);
    await tester.pump(const Duration(minutes: 2));
    await tester.pump();

    for (var i = 0; i < maxUnlockAttempts; i++) {
      await tester.enterText(find.byType(TextField), 'salah$i');
      await tester.tap(find.text('Buka kunci'));
      await tester.pump();
      await tester.pump();
    }
    expect(calls.length, maxUnlockAttempts);
    expect(find.textContaining('Terlalu banyak percobaan'), findsOneWidget);

    // Selama jeda, password benar pun tidak diperiksa.
    await tester.enterText(find.byType(TextField), 'rahasia123');
    await tester.tap(find.text('Buka kunci'), warnIfMissed: false);
    await tester.pump();
    expect(calls.length, maxUnlockAttempts);
    expect(_lockedText, findsOneWidget);

    await tester.pump(unlockCooldown + const Duration(seconds: 1));
    await tester.enterText(find.byType(TextField), 'rahasia123');
    await tester.tap(find.text('Buka kunci'));
    await tester.pump();
    await tester.pump();
    expect(_lockedText, findsNothing);
  });

  testWidgets('tombol Back tidak menembus layar kunci', (tester) async {
    final popCalls = <String>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      popCalls.add(call.method);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await _pump(tester, minutes: 1);

    // Tidak terkunci: Back diteruskan ke app (keluar dari root).
    await tester.binding.handlePopRoute();
    expect(popCalls, contains('SystemNavigator.pop'));
    popCalls.clear();

    await tester.pump(const Duration(minutes: 2));
    await tester.pump();
    expect(_lockedText, findsOneWidget);

    await tester.binding.handlePopRoute();
    expect(popCalls, isNot(contains('SystemNavigator.pop')));
    expect(_lockedText, findsOneWidget);
  });

  testWidgets('konten di bawah layar kunci tidak bisa disentuh', (tester) async {
    var taps = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        autoLockMinutesProvider.overrideWith(() => _FixedMinutes(1)),
        currentUserProvider.overrideWith((ref) async => _kasir),
        unlockVerifierProvider.overrideWithValue((u, p) async => false),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => taps++,
              child: const Text('BAYAR'),
            ),
          ),
        ),
        builder: (context, child) =>
            AutoLockGate(lockOnLaunch: false, child: child!),
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('BAYAR'));
    expect(taps, 1);

    await tester.pump(const Duration(minutes: 2));
    await tester.pump();
    expect(_lockedText, findsOneWidget);
    await tester.tap(find.text('BAYAR'), warnIfMissed: false);
    expect(taps, 1);
  });

  testWidgets('kembali dari background ≥ N menit mengunci, sebentar tidak',
      (tester) async {
    var t = DateTime(2026, 11, 20, 8, 0);
    await _pump(tester, minutes: 5, now: () => t);

    Future<void> toBackground() async {
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
    }

    Future<void> toForeground() async {
      for (final s in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pump();
    }

    await toBackground();
    t = t.add(const Duration(minutes: 2));
    await toForeground();
    expect(_lockedText, findsNothing);

    await toBackground();
    t = t.add(const Duration(minutes: 6));
    await toForeground();
    expect(_lockedText, findsOneWidget);
  });

  testWidgets('lockOnLaunch: terkunci saat start bila aktif & sudah login',
      (tester) async {
    await _pump(tester, minutes: 5, lockOnLaunch: true);
    await tester.pump();
    expect(_lockedText, findsOneWidget);
  });

  testWidgets('lockOnLaunch: tidak terkunci bila nonaktif atau belum login',
      (tester) async {
    await _pump(tester, minutes: 0, lockOnLaunch: true);
    await tester.pump();
    expect(_lockedText, findsNothing);

    await _pump(tester, minutes: 5, user: null, lockOnLaunch: true);
    await tester.pump();
    expect(_lockedText, findsNothing);
  });

  testWidgets('logout (sesi hilang) membuka kunci', (tester) async {
    final c = await _pump(tester, minutes: 1);
    await tester.pump(const Duration(minutes: 2));
    await tester.pump();
    expect(_lockedText, findsOneWidget);

    c.read(_userSource.notifier).state = null;
    await tester.pump();
    await tester.pump();
    expect(_lockedText, findsNothing);
    expect(c.read(lockedProvider), false);
  });

  test('pengaturan menit tersimpan di SharedPreferences', () async {
    final c1 = ProviderContainer();
    addTearDown(c1.dispose);
    expect(await c1.read(autoLockMinutesProvider.future), 0);
    await c1.read(autoLockMinutesProvider.notifier).set(10);
    expect(c1.read(autoLockMinutesProvider).value, 10);

    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    expect(await c2.read(autoLockMinutesProvider.future), 10);
  });
}
