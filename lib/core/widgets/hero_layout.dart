import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/clay.dart';
import 'app_logo.dart';

/// Gaya HP: [sheet] panel dari bawah; [card] kartu clay menimpa hero.
enum HeroNarrowStyle { sheet, card }

/// Tata letak halaman dengan gambar hero (login & onboarding).
///
/// Lebar (>= 900 dp): satu kartu clay besar, gambar full-bleed, logo + [wideLeft]
/// di kiri (di atas dinding polos gambar), [wideRight] opsional di kanan.
/// HP: gambar hero ~42% tinggi (220-380 dp) di atas; panel putih (sheet) naik
/// menimpa gambar 32 dp sampai dasar layar. [narrowChild] scroll di dalam panel,
/// [narrowAction] (tombol utama) disematkan di dasar panel, di luar scroll.
/// Gaya [HeroNarrowStyle.card]: hero ~38% (200-320 dp); kartu clay (margin 16)
/// menimpa hero 40 dp, [narrowAction] di dalam kartu, [narrowFooter] di bawah
/// kartu; semuanya scroll.
class HeroLayout extends StatelessWidget {
  final Widget wideLeft;
  final Widget? wideRight;
  final Widget narrowChild;
  final Widget? narrowAction;
  final HeroNarrowStyle narrowStyle;
  final Widget? narrowFooter;

  /// Hanya gaya sheet: saat scroll, panel naik menutupi hero sampai tepat di
  /// bawah baris brand, baru isi scroll di dalam panel.
  final bool narrowCollapsible;

  const HeroLayout({
    super.key,
    required this.wideLeft,
    this.wideRight,
    required this.narrowChild,
    this.narrowAction,
    this.narrowStyle = HeroNarrowStyle.sheet,
    this.narrowFooter,
    this.narrowCollapsible = false,
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

  static const _cardOverlap = 40.0;

  Widget _narrowCard(BuildContext context, BoxConstraints c) {
    final h = c.maxHeight;
    final heroH = h < 480 ? h * 0.3 : (h * 0.38).clamp(200.0, 320.0);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(top: 0, left: 0, right: 0, height: heroH, child: const _HeroImage(round: true)),
        const Positioned(top: 16, left: 16, child: _Brand(size: 40)),
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, heroH - _cardOverlap, 16, 16 + bottomInset),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: ClayDecoration.box(radius: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        narrowChild,
                        if (narrowAction != null) ...[
                          const SizedBox(height: 20),
                          narrowAction!,
                        ],
                      ],
                    ),
                  ),
                  if (narrowFooter != null)
                    Padding(padding: const EdgeInsets.only(top: 16), child: narrowFooter),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _narrow(BuildContext context, BoxConstraints c) {
    if (narrowStyle == HeroNarrowStyle.card) return _narrowCard(context, c);
    final h = c.maxHeight;
    // Keyboard terbuka (tinggi sempit): hero mengecil agar panel + tombol muat.
    final heroH = h < 480 ? h * 0.3 : (h * 0.42).clamp(220.0, 380.0);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    if (narrowCollapsible) {
      return _CollapsibleSheet(
        heroH: heroH,
        bottomInset: bottomInset,
        action: narrowAction,
        child: narrowChild,
      );
    }
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

/// Sheet HP yang naik menutupi hero saat scroll (lihat [HeroLayout.narrowCollapsible]).
/// Satu scroll: offset 0..spacer menaikkan panel, sisanya menggulir isi di dalam panel.
class _CollapsibleSheet extends StatefulWidget {
  final double heroH;
  final double bottomInset;
  final Widget? action;
  final Widget child;
  const _CollapsibleSheet({
    required this.heroH,
    required this.bottomInset,
    required this.action,
    required this.child,
  });

  @override
  State<_CollapsibleSheet> createState() => _CollapsibleSheetState();
}

class _CollapsibleSheetState extends State<_CollapsibleSheet> {
  static const _brandH = 64.0;
  static const _handleZone = 24.0;
  final _ctrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startTop = (widget.heroH - HeroLayout._sheetOverlap).clamp(_brandH, double.infinity);
    final travel = startTop - _brandH; // jarak panel naik sampai mentok
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(top: 0, left: 0, right: 0, height: widget.heroH, child: const _HeroImage()),
        ListenableBuilder(
          listenable: _ctrl,
          builder: (context, _) {
            final o = _ctrl.hasClients ? _ctrl.offset.clamp(0.0, travel) : 0.0;
            final t = travel == 0 ? 1.0 : o / travel;
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: startTop - o,
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
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: _brandH,
                  child: ColoredBox(
                    color: AppColors.surface.withValues(alpha: t),
                    child: const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(padding: EdgeInsets.only(left: 16), child: _Brand(size: 40)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        Positioned.fill(
          top: _brandH,
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    controller: _ctrl,
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight + travel),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, travel + _handleZone + 10, 20, 20),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: widget.child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.action != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + widget.bottomInset),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: widget.action,
                  ),
                ),
            ],
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
  final bool round; // sudut bawah radius 28 (HP gaya kartu)
  const _HeroImage({this.round = false});

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      'assets/images/login_hero.webp',
      fit: BoxFit.cover,
      alignment: Alignment.centerRight,
      excludeFromSemantics: true,
    );
    return round
        ? ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)), child: img)
        : img;
  }
}
