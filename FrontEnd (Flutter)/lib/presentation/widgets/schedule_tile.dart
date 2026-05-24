import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/services/hive_service.dart';
import '../../data/models/meal_schedule.dart';

class ScheduleTile extends StatelessWidget {
  final MealSchedule meal;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final ValueChanged<String>? onStatusChanged;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectedChanged;
  final VoidCallback? onLongPress;

  const ScheduleTile({
    super.key,
    required this.meal,
    this.onDelete,
    this.onTap,
    this.onStatusChanged,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectedChanged,
    this.onLongPress,
  });

  String? _getResolvedPhotoUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    
    if (path.startsWith('meal_photos/')) {
      return '${HiveService.localDocumentsDirPath}/$path';
    }

    String buildFullUrl(String relativePath) {
      final detectionUrl = ApiService.photoUrl;
      if (detectionUrl.isEmpty) return relativePath;
      final uri = Uri.parse(detectionUrl);
      String baseUrl;
      try {
        baseUrl = uri.origin;
      } catch (_) {
        baseUrl = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
      }
      final cleanPath = relativePath.startsWith('/') ? relativePath : '/$relativePath';
      return '$baseUrl$cleanPath';
    }

    if (path.startsWith('http')) {
      final uri = Uri.tryParse(path);
      if (uri != null && uri.path.contains('/uploads/')) {
        final uploadsIndex = uri.path.indexOf('/uploads/');
        final relativePath = uri.path.substring(uploadsIndex);
        return buildFullUrl(relativePath);
      }
      return path;
    }
    
    return buildFullUrl(path);
  }

  void _showMealDetailBottomSheet(BuildContext context) {
    final isEaten = meal.status == 'eaten';
    final isCanceled = meal.status == 'canceled';
    final formattedSesi = meal.sesi == 'sarapan' 
        ? 'Sarapan' 
        : meal.sesi == 'makan_siang' 
            ? 'Makan Siang' 
            : 'Makan Malam';
    final resolvedUrl = _getResolvedPhotoUrl(meal.photoUrl);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: AppColors.surface,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: resolvedUrl != null && resolvedUrl.isNotEmpty ? 0.85 : 0.6,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title: Sesi and status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            AppConstants.mealSessionIcons[meal.sesi] ?? '🍽️',
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formattedSesi,
                            style: AppTextStyles.heading3.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isEaten 
                              ? AppColors.success.withValues(alpha: 0.1) 
                              : (isCanceled ? AppColors.error.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isEaten 
                                ? AppColors.success.withValues(alpha: 0.3) 
                                : (isCanceled ? AppColors.error.withValues(alpha: 0.3) : AppColors.warning.withValues(alpha: 0.3)),
                          ),
                        ),
                        child: Text(
                          isEaten 
                              ? 'Sudah Dimakan' 
                              : (isCanceled ? 'Dibatalkan' : 'Direncanakan'),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isEaten 
                                ? AppColors.success 
                                : (isCanceled ? AppColors.error : AppColors.warning),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Photo if available
                  if (resolvedUrl != null && resolvedUrl.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: resolvedUrl.startsWith('http')
                          ? Image.network(
                              resolvedUrl,
                              height: 240,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 240,
                                  color: AppColors.surfaceVariant,
                                  child: const Center(
                                    child: CircularProgressIndicator(color: AppColors.primary),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 240,
                                  color: AppColors.surfaceVariant,
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.broken_image_outlined, size: 48, color: AppColors.textLight),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Gagal memuat gambar',
                                        style: AppTextStyles.bodySmall,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                          : Image.file(
                              File(resolvedUrl),
                              height: 240,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 240,
                                  color: AppColors.surfaceVariant,
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.broken_image_outlined, size: 48, color: AppColors.textLight),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Gagal memuat gambar',
                                        style: AppTextStyles.bodySmall,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Menu Name
                  Text(
                    meal.namaMenu,
                    style: AppTextStyles.heading2,
                  ),
                  const SizedBox(height: 20),

                  // Nutrition Summary Card
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.divider),
                    ),
                    color: AppColors.scaffoldBg,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildNutritionItem(
                            value: meal.totalKalori.toStringAsFixed(0),
                            unit: 'kkal',
                            label: 'Kalori',
                            color: AppColors.calories,
                          ),
                          _buildNutritionItem(
                            value: meal.totalProtein.toStringAsFixed(1),
                            unit: 'g',
                            label: 'Protein',
                            color: AppColors.protein,
                          ),
                          _buildNutritionItem(
                            value: meal.totalLemak.toStringAsFixed(1),
                            unit: 'g',
                            label: 'Lemak',
                            color: AppColors.fat,
                          ),
                          _buildNutritionItem(
                            value: meal.totalKarbo.toStringAsFixed(1),
                            unit: 'g',
                            label: 'Karbo',
                            color: AppColors.carbs,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Ingredients/Items List
                  Text(
                    'Bahan & Detail Porsi',
                    style: AppTextStyles.heading3.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: meal.items.length,
                    separatorBuilder: (context, index) => const Divider(height: 16, color: AppColors.divider),
                    itemBuilder: (context, index) {
                      final item = meal.items[index];
                      final name = item.ingredientNama
                          .split('_')
                          .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
                          .join(' ');
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(name, style: AppTextStyles.labelLarge),
                              Text(
                                '${item.beratGram.toStringAsFixed(0)}g',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildMiniNutriTag('Kalori: ${item.effectiveKalori.toStringAsFixed(0)} kkal', AppColors.calories),
                              const SizedBox(width: 6),
                              _buildMiniNutriTag('P: ${item.effectiveProtein.toStringAsFixed(1)}g', AppColors.protein),
                              const SizedBox(width: 6),
                              _buildMiniNutriTag('L: ${item.effectiveLemak.toStringAsFixed(1)}g', AppColors.fat),
                              const SizedBox(width: 6),
                              _buildMiniNutriTag('K: ${item.effectiveKarbo.toStringAsFixed(1)}g', AppColors.carbs),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNutritionItem({
    required String value,
    required String unit,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.08),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: AppTextStyles.labelLarge.copyWith(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: AppTextStyles.nutriLabel.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniNutriTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emoji = AppConstants.mealSessionIcons[meal.sesi] ?? '🍽️';
    final isCanceled = meal.status == 'canceled';
    final isEaten = meal.status == 'eaten';
    final resolvedUrl = _getResolvedPhotoUrl(meal.photoUrl);
    final hasPhoto = resolvedUrl != null && resolvedUrl.isNotEmpty &&
        (resolvedUrl.startsWith('http') || File(resolvedUrl).existsSync());

    final dismissDirection = isSelectionMode
        ? DismissDirection.none
        : (isEaten ? DismissDirection.none : DismissDirection.horizontal);

    return Dismissible(
      key: Key(meal.id),
      direction: dismissDirection,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onStatusChanged?.call('eaten');
          return false;
        } else if (direction == DismissDirection.endToStart) {
          onDelete?.call();
          return true;
        }
        return false;
      },
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.success),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      child: GestureDetector(
        onTap: isSelectionMode
            ? () => onSelectedChanged?.call(!isSelected)
            : (onTap ?? () => _showMealDetailBottomSheet(context)),
        onLongPress: isSelectionMode
            ? () => onSelectedChanged?.call(!isSelected)
            : onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isEaten
                ? AppColors.success.withValues(alpha: 0.1)
                : (isCanceled ? AppColors.surfaceVariant.withValues(alpha: 0.3) : AppColors.surface),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isEaten ? AppColors.success.withValues(alpha: 0.3) : AppColors.divider,
            ),
          ),
          child: Row(
            children: [
              if (isSelectionMode) ...[
                Checkbox(
                  value: isSelected,
                  activeColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onChanged: onSelectedChanged,
                ),
                const SizedBox(width: 8),
              ],
              // Thumbnail (Photo or Emoji fallback)
              Opacity(
                opacity: isCanceled ? 0.5 : 1.0,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: hasPhoto
                        ? (resolvedUrl.startsWith('http')
                            ? Image.network(
                                resolvedUrl,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Center(
                                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                                ),
                              )
                            : Image.file(
                                File(resolvedUrl),
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Center(
                                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                                ),
                              ))
                        : Center(
                            child: Text(emoji, style: const TextStyle(fontSize: 22)),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            meal.namaMenu,
                            style: AppTextStyles.labelLarge.copyWith(
                              color: isCanceled ? AppColors.textLight.withValues(alpha: 0.6) : AppColors.textPrimary,
                              decoration: isCanceled ? TextDecoration.lineThrough : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (resolvedUrl != null && resolvedUrl.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.camera_alt_rounded, size: 10, color: AppColors.primary),
                                SizedBox(width: 2),
                                Text(
                                  'Foto',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meal.items.map((i) {
                        final formattedName = i.ingredientNama
                            .split('_')
                            .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
                            .join(' ');
                        return '$formattedName ${i.beratGram.toStringAsFixed(0)}g';
                      }).join(', '),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isCanceled ? AppColors.textLight.withValues(alpha: 0.4) : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Calories
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    meal.totalKalori.toStringAsFixed(0),
                    style: AppTextStyles.labelLarge.copyWith(
                      color: isCanceled ? AppColors.textLight.withValues(alpha: 0.5) : AppColors.calories,
                      decoration: isCanceled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(
                    'kkal',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isCanceled ? AppColors.textLight.withValues(alpha: 0.5) : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
