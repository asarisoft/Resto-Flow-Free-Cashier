import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/auth/auto_lock.dart';
import 'printer/printer_service.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final shortest = view.physicalSize.shortestSide / view.devicePixelRatio;
  await SystemChrome.setPreferredOrientations(orientationsFor(shortest));
  runApp(const ProviderScope(child: KasirRestoApp()));
}

class KasirRestoApp extends ConsumerStatefulWidget {
  const KasirRestoApp({super.key});

  @override
  ConsumerState<KasirRestoApp> createState() => _KasirRestoAppState();
}

class _KasirRestoAppState extends ConsumerState<KasirRestoApp> {
  @override
  void initState() {
    super.initState();
    // Auto-reconnect printer terakhir diam-diam; gagal = abaikan.
    unawaited(ref.read(printerServiceProvider).tryAutoConnect());
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'KasirKita',
      theme: AppTheme.light,
      builder: (context, child) => clampTextScale(
        context,
        AutoLockGate(child: child ?? const SizedBox.shrink()),
      ),
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Batasi ukuran teks sistem (maks 1.3x) supaya layout kasir tidak pecah.
Widget clampTextScale(BuildContext context, Widget? child) {
  final mq = MediaQuery.of(context);
  return MediaQuery(
    data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3)),
    child: child ?? const SizedBox.shrink(),
  );
}

/// HP (sisi terpendek < 600 dp): bebas portrait & landscape.
/// Tablet: dikunci landscape (dipakai di meja kasir).
List<DeviceOrientation> orientationsFor(double shortestSideDp) =>
    shortestSideDp < 600
        ? DeviceOrientation.values
        : const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight];
