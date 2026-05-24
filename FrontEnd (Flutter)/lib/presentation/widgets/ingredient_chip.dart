import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class IngredientChip extends StatelessWidget {
  final String name;
  final String weight;
  final VoidCallback? onRemove;

  const IngredientChip({
    super.key,
    required this.name,
    required this.weight,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$name • $weight',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryDark,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close, size: 14, color: AppColors.primary.withValues(alpha: 0.6)),
            ),
          ],
        ],
      ),
    );
  }
}
