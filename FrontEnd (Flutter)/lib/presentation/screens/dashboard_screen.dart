import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../providers/user_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/schedule_provider.dart';
import '../widgets/nutrition_card.dart';
import '../widgets/macro_bar.dart';
import '../widgets/schedule_tile.dart';
import '../widgets/meal_card.dart';
import '../../data/repositories/user_repository.dart';
import '../../core/services/rule_engine_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isSelectionMode = false;
  Set<String> _selectedMealIds = {};
  DateTime? _lastSelectedDate;

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  String _formatTanggal(DateTime date) {
    const hariIndo = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const bulanIndo = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final hari = hariIndo[date.weekday - 1];
    final bulan = bulanIndo[date.month];
    return '$hari, ${date.day} $bulan ${date.year}';
  }

  Future<void> _confirmDeleteSelected(DashboardProvider dashProv) async {
    final count = _selectedMealIds.length;
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: AppColors.surface,
          content: Text(
            'Hapus $count makanan terpilih?',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textPrimary,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      'Tidak',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      
                      final schedProv = context.read<ScheduleProvider>();
                      // Delete in a batch
                      for (final id in _selectedMealIds) {
                        await schedProv.deleteMeal(id);
                      }
                      
                      if (mounted) {
                        setState(() {
                          _isSelectionMode = false;
                          _selectedMealIds.clear();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$count makanan berhasil dihapus'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.success,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      }
                    },
                    child: Text(
                      'Ya',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProvider, DashboardProvider>(
      builder: (context, userProv, dashProv, _) {
        final name = userProv.profile?.nama ?? 'Pengguna';
        final greeting = _getGreeting();
        
        final currentDate = dashProv.selectedDate;
        if (_lastSelectedDate != null && _lastSelectedDate != currentDate) {
          _isSelectionMode = false;
          _selectedMealIds.clear();
        }
        _lastSelectedDate = currentDate;

        return SafeArea(
          child: RefreshIndicator(
            onRefresh: () async => dashProv.refresh(),
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting
                  Text(greeting, style: AppTextStyles.bodySmall),
                  Text(name, style: AppTextStyles.heading2),
                  const SizedBox(height: 20),

                  // Rule Warnings & Alerts
                  if (userProv.profile != null) ...[
                    Builder(
                      builder: (context) {
                        final alerts = RuleEngineService.instance.dapatkanPeringatanHarian(
                          userProv.profile!,
                          dashProv.todayMeals,
                          userProv.targetKalori,
                          userProv.targetTdee,
                        );
                        if (alerts.isEmpty) return const SizedBox.shrink();
                        return Column(
                          children: [
                            ...alerts.map((alert) {
                              final isCrit = alert.contains('🚨') || alert.contains('🚫');
                              final alertColor = isCrit ? AppColors.error : AppColors.warning;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: alertColor.withAlpha(20),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: alertColor.withAlpha(80),
                                  ),
                                ),
                                child: Text(
                                  alert,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: alertColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 12),
                          ],
                        );
                      }
                    ),
                  ],

                  // Nutrition card
                  NutritionCard(
                    currentCalories: dashProv.kaloriHariIni,
                    targetCalories: userProv.targetKalori,
                    protein: dashProv.proteinHariIni,
                    fat: dashProv.lemakHariIni,
                    carbs: dashProv.karboHariIni,
                  ),
                  const SizedBox(height: 20),

                  // Macro bars
                  Text('Detail Makro', style: AppTextStyles.heading3),
                  const SizedBox(height: 10),
                  MacroBar(
                    label: 'Protein',
                    current: dashProv.proteinHariIni,
                    target: userProv.targetProtein,
                    color: AppColors.protein,
                  ),
                  const SizedBox(height: 8),
                  MacroBar(
                    label: 'Lemak',
                    current: dashProv.lemakHariIni,
                    target: userProv.targetLemak,
                    color: AppColors.fat,
                  ),
                  const SizedBox(height: 8),
                  MacroBar(
                    label: 'Karbohidrat',
                    current: dashProv.karboHariIni,
                    target: userProv.targetKarbo,
                    color: AppColors.carbs,
                  ),
                  const SizedBox(height: 24),

                  // Today's meals
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_isSelectionMode) ...[
                        Expanded(
                          child: Text(
                            'Terpilih (${_selectedMealIds.length})',
                            style: AppTextStyles.heading3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_selectedMealIds.length < dashProv.todayMeals.length)
                              TextButton(
                                style: TextButton.styleFrom(
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  final allMeals = dashProv.todayMeals;
                                  setState(() {
                                    _selectedMealIds = allMeals.map((m) => m.id).toSet();
                                  });
                                },
                                child: const Text(
                                  'Pilih Semua',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              onPressed: _selectedMealIds.isEmpty
                                  ? null
                                  : () => _confirmDeleteSelected(dashProv),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setState(() {
                                  _isSelectionMode = false;
                                  _selectedMealIds.clear();
                                });
                              },
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          _isToday(dashProv.selectedDate)
                              ? 'Makanan Hari Ini'
                              : 'Makanan - ${_formatTanggal(dashProv.selectedDate)}',
                          style: AppTextStyles.heading3,
                        ),
                        Row(
                          children: [
                            Text(
                              '${dashProv.todayMeals.length} menu',
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (dashProv.todayMeals.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.restaurant_outlined,
                              size: 48, color: AppColors.textLight),
                          const SizedBox(height: 8),
                          Text(
                            'Belum ada makanan hari ini',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tambahkan lewat Jadwal atau Chat AI',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ...dashProv.sessions.map((sesi) {
                    final mealsForSession = dashProv.todayMeals.where((m) => m.sesi == sesi).toList();
                    if (mealsForSession.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final totalCal = mealsForSession.fold<double>(0.0, (sum, m) => sum + m.totalKalori);
                    final label = UserRepository.getSessionLabel(sesi);
                    final emoji = UserRepository.getSessionEmoji(sesi);

                    return MealCard(
                      title: label,
                      emoji: emoji,
                      itemCount: mealsForSession.length,
                      totalCalories: totalCal,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: Column(
                          children: mealsForSession.map((meal) => ScheduleTile(
                            meal: meal,
                            isSelectionMode: _isSelectionMode,
                            isSelected: _selectedMealIds.contains(meal.id),
                            onSelectedChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedMealIds.add(meal.id);
                                } else {
                                  _selectedMealIds.remove(meal.id);
                                  if (_selectedMealIds.isEmpty) {
                                    _isSelectionMode = false;
                                  }
                                }
                              });
                            },
                            onLongPress: () {
                              setState(() {
                                _isSelectionMode = true;
                                _selectedMealIds.add(meal.id);
                              });
                            },
                            onStatusChanged: (status) async {
                              await context.read<ScheduleProvider>().updateMealStatus(meal.id, status);
                              dashProv.refresh();
                            },
                            onDelete: () async {
                              await context.read<ScheduleProvider>().deleteMeal(meal.id);
                              dashProv.refresh();
                            },
                          )).toList(),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi 🌅';
    if (hour < 15) return 'Selamat Siang ☀️';
    if (hour < 18) return 'Selamat Sore 🌇';
    return 'Selamat Malam 🌙';
  }
}
