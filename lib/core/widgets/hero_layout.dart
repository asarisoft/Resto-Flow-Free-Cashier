import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/clay.dart';
import 'app_logo.dart';

/// Tata letak halaman dengan gambar hero (login & onboarding).
///
/// Lebar (>= 900 dp): satu kartu clay besar, gambar full-bleed, logo + [wideLeft]
/// di kiri (di atas dinding polos gambar). Bila [wideRight] diisi, lebar =
/// dua kartu berdampingan: hero di kiri, [wideRight] di kanan.
/// HP: gambar di atas (<= 260 dp), [narrowChild] menumpuk di bawahnya, scroll.
class HeroLayout extends StatelessWidget {
  final Widget wideLeft;
  final Widget? wideRight;
  final Widget narrowChild;

  const HeroLayout({
    super.key,
    required this.wideLeft,
    this.wideRight,
    required this.narrowChild,
  });

  static const _wideBreakpoint = 900.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) =>
          c.maxWidth >= _wideBreakpoint ? _wide(c) : _narrow(c),
    );
  }

  Widget _wide(BoxConstraints c) {
    if (wideRight != null) return _wideSplit();
    final inner = c.maxWidth - 48;
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
          ],
        ),
      ),
    );
  }

  /// Dua kartu berdampingan: hero (teks di atas, karakter utuh di pojok
  /// kanan bawah) dan form. Form tidak menumpuk gambar.
  Widget _wideSplit() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: DecoratedBox(
              decoration: ClayDecoration.box(radius: 32),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Stack(
                  children: [
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _HeroImage(fit: BoxFit.fitWidth, alignment: Alignment.bottomRight),
                    ),
                    _scroll(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Brand(),
                          const SizedBox(height: 32),
                          wideLeft,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 6,
            child: _scroll(
              padding: EdgeInsets.zero,
              child: Center(child: wideRight),
            ),
          ),
        ],
      ),
    );
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

  Widget _narrow(BoxConstraints c) {
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
                child: narrowChild,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Logo + nama app.
class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppLogo(size: 56),
        const SizedBox(width: 12),
        Text('KasirKita',
            style: AppTypography.textTheme.titleLarge?.copyWith(color: AppColors.textPrimary)),
      ],
    );
  }
}

/// Gambar dekoratif: dinding kosong di kiri, karakter di kanan.
class _HeroImage extends StatelessWidget {
  final BoxFit fit;
  final Alignment alignment;
  const _HeroImage({this.fit = BoxFit.cover, this.alignment = Alignment.centerRight});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/login_hero.webp',
      fit: fit,
      alignment: alignment,
      excludeFromSemantics: true,
    );
  }
}
