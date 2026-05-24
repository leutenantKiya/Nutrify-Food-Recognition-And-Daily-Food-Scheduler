import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class MealCard extends StatelessWidget {
  final String title;
  final String emoji;
  final int itemCount;
  final double totalCalories;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;
  final Widget? child;

  const MealCard({
    super.key,
    required this.title,
    required this.emoji,
    this.itemCount = 0,
    this.totalCalories = 0,
    this.onTap,
    this.onAdd,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final activeChild = child;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppTextStyles.labelLarge),
                        if (itemCount > 0)
                          Text(
                            '$itemCount menu • ${totalCalories.toStringAsFixed(0)} kkal',
                            style: AppTextStyles.bodySmall,
                          ),
                        if (itemCount == 0)
                          Text(
                            'Belum ada menu',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textLight,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (onAdd != null)
                    IconButton(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add_circle_outline),
                      color: AppColors.primary,
                      iconSize: 24,
                    ),
                ],
              ),
            ),
          ),
          // Child content
          // ignore: use_null_aware_elements
          if (activeChild != null) activeChild,
        ],
      ),
    );
  }
}
