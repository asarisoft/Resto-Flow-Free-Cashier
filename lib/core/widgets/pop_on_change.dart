import 'package:flutter/widgets.dart';
import '../theme/app_motion.dart';

/// Membungkus [child]; tiap [value] berubah, child "pop" kecil (1 → 1.2 → 1).
class PopOnChange extends StatefulWidget {
  final int value;
  final Widget child;

  const PopOnChange({super.key, required this.value, required this.child});

  @override
  State<PopOnChange> createState() => _PopOnChangeState();
}

class _PopOnChangeState extends State<PopOnChange>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  static final _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.2), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.2, end: 1), weight: 60),
  ]);

  @override
  void didUpdateWidget(PopOnChange old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _c.duration = AppMotion.of(context, AppMotion.fast);
      if (_c.duration == Duration.zero) return;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: _scale.animate(CurvedAnimation(parent: _c, curve: AppMotion.curve)),
        child: widget.child,
      );
}
