import 'package:flutter/material.dart';
import '../theme/app_icons.dart';
import 'app_card.dart';

/// Kartu berisi kontrol filter + tombol Reset (hanya tampil saat filter aktif).
class FilterPanel extends StatelessWidget {
  final List<Widget> children;
  final VoidCallback? onReset;

  const FilterPanel({super.key, required this.children, this.onReset});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
          if (onReset != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onReset,
                icon: const Icon(AppIcons.filterReset, size: AppIcons.md),
                label: const Text('Reset filter'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
