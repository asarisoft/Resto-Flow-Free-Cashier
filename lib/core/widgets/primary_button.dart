import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_typography.dart';

class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final animate = !MediaQuery.disableAnimationsOf(context);
    final radius = BorderRadius.circular(20);
    final fg = enabled ? AppColors.onPrimary : AppColors.textSecondary;
    return Semantics(
      button: true,
      enabled: enabled,
      container: true,
      child: AnimatedScale(
      scale: enabled && _pressed ? 0.96 : 1,
      duration: animate ? const Duration(milliseconds: 200) : Duration.zero,
      curve: Curves.easeOutBack,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: enabled ? null : AppColors.border,
            gradient: enabled
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.primaryLight, AppColors.primary],
                  )
                : null,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      offset: const Offset(4, 6),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: enabled ? widget.onPressed : null,
            onHighlightChanged: _setPressed,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              alignment: Alignment.center,
              child: DefaultTextStyle(
                style: (AppTypography.textTheme.labelLarge ?? const TextStyle())
                    .copyWith(fontWeight: FontWeight.w600, color: fg),
                child: widget.loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, size: AppIcons.md, color: fg),
                            const SizedBox(width: 8),
                          ],
                          Text(widget.label),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    ));
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppIcons.md),
            const SizedBox(width: 8),
          ],
          Text(label),
        ],
      ),
    );
  }
}

class TextButtonCustom extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const TextButtonCustom({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: AppTypography.textTheme.bodyMedium
            ?.copyWith(color: AppColors.primary),
      ),
    );
  }
}
