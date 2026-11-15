import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const ProviderScope(child: KasirRestoApp()));
}

class KasirRestoApp extends ConsumerWidget {
  const KasirRestoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Resto Flow Free',
      theme: AppTheme.light,
      builder: clampTextScale,
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
