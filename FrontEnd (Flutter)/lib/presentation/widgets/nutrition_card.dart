import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class NutritionCard extends StatelessWidget {
  final double currentCalories;
  final double targetCalories;
  final double protein;
  final double fat;
  final double carbs;

  const NutritionCard({
    super.key,
    required this.currentCalories,
    required this.targetCalories,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  @override
  Widget build(BuildContext context) {
    final isWarning = targetCalories > 0 && currentCalories >= targetCalories * 0.80;
    final progress = targetCalories > 0
        ? (currentCalories / targetCalories).clamp(0.0, 1.0)
        : 0.0;
    final remaining = (targetCalories - currentCalories).clamp(0, targetCalories);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isWarning ? AppColors.errorGradient : AppColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isWarning ? AppColors.error : AppColors.primary).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Circular progress
              SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: _CalorieRingPainter(progress: progress),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentCalories.toStringAsFixed(0),
                          style: AppTextStyles.nutriValue.copyWith(
                            color: Colors.white,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          'kkal',
                          style: AppTextStyles.nutriLabel.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kalori Hari Ini',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sisa ${remaining.toStringAsFixed(0)} kkal',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Target: ${targetCalories.toStringAsFixed(0)} kkal',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Macro summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MacroMini(
                label: 'Protein',
                value: protein,
                color: AppColors.protein,
              ),
              _MacroMini(
                label: 'Lemak',
                value: fat,
                color: AppColors.fat,
              ),
              _MacroMini(
                label: 'Karbo',
                value: carbs,
                color: AppColors.carbs,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroMini extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MacroMini({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(1)}g',
          style: AppTextStyles.labelLarge.copyWith(
            color: Colors.white,
            fontSize: 13,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: Colors.white60,
          ),
        ),
      ],
    );
  }
}

class _CalorieRingPainter extends CustomPainter {
  final double progress;

  _CalorieRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    // Background ring
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress ring
    final progressPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
