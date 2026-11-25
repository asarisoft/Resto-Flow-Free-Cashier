import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/clay.dart';
import 'app_logo.dart';

/// Tata letak halaman dengan gambar hero (login & onboarding).
///
/// Lebar (>= 900 dp): satu kartu clay besar, gambar full-bleed, logo + [wideLeft]
/// di kiri (di atas dinding polos gambar), [wideRight] opsional di kanan.
/// HP: gambar hero ~42% tinggi (220-380 dp) di atas; panel putih (sheet) naik
/// menimpa gambar 32 dp sampai dasar layar. [narrowChild] scroll di dalam panel,
/// [narrowAction] (tombol utama) disematkan di dasar panel, di luar scroll.
class HeroLayout extends StatelessWidget {
  final Widget wideLeft;
  final Widget? wideRight;
  final Widget narrowChild;
  final Widget? narrowAction;

  const HeroLayout({
    super.key,
    required this.wideLeft,
    this.wideRight,
    required this.narrowChild,
    this.narrowAction,
  });

  static const _wideBreakpoint = 900.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) =>
          c.maxWidth >= _wideBreakpoint ? _wide(c) : _narrow(context, c),
    );
  }

  Widget _wide(BoxConstraints c) {
    final inner = c.maxWidth - 48;
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: Container(
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
                width: inner * 0.42,
                child: _scroll(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Brand(),
                      const SizedBox(height: 32),
                      wideLeft,
                    ],
                  ),
                ),
              ),
            ),
            if (wideRight != null)
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: inner * 0.46,
                  // Tanpa scroll luar: kartu tetap utuh (bayangan tidak terpotong),
                  // isi kartu yang scroll sendiri.
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 24, 24, 24),
                    child: Center(child: wideRight),
                  ),
                ),
              ),
          ],
        ),
      ),
    ));
  }

  Widget _scroll({required EdgeInsets padding, required Widget child}) {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - padding.vertical),
          child: child,
        ),
      ),
    );
  }

  static const _sheetOverlap = 32.0;

  Widget _narrow(BuildContext context, BoxConstraints c) {
    final h = c.maxHeight;
    // Keyboard terbuka (tinggi sempit): hero mengecil agar panel + tombol muat.
    final heroH = h < 480 ? h * 0.3 : (h * 0.42).clamp(220.0, 380.0);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: heroH,
          child: const _HeroImage(),
        ),
        const Positioned(top: 16, left: 16, child: _Brand(size: 40)),
        Positioned(
          top: heroH - _sheetOverlap,
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(color: AppColors.clayShadow, offset: Offset(0, -6), blurRadius: 18),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: narrowChild,
                      ),
                    ),
                  ),
                ),
                if (narrowAction != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + bottomInset),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: narrowAction,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Logo + nama app.
class _Brand extends StatelessWidget {
  final double size;
  const _Brand({this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLogo(size: size),
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
