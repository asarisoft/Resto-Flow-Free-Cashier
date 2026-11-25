import 'package:flutter/animation.dart';
import 'package:flutter/widgets.dart';

/// Token gerak bersama. Singkat (kasir: cepat > cantik); semua durasi
/// lewat [AppMotion.of] agar mati otomatis saat `disableAnimations`.
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);

  static const Curve curve = Curves.easeOutCubic;

  /// Pegas teredam ringan untuk "pop" (badge keranjang).
  static const Curve pop = Curves.easeOutBack;

  /// [d] atau [Duration.zero] bila pengguna mematikan animasi.
  static Duration of(BuildContext context, [Duration d = normal]) =>
      MediaQuery.maybeDisableAnimationsOf(context) == true ? Duration.zero : d;
}
