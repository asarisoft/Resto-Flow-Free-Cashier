import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Bar langkah: [total] segmen bulat 6 dp; segmen ke-1..[step] berwarna primary.
class StepProgress extends StatelessWidget {
  final int step;
  final int total;
  const StepProgress({super.key, required this.step, this.total = 2});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= total; i++) ...[
          if (i > 1) const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: i <= step ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
