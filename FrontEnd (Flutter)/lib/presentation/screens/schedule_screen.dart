import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../providers/schedule_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/meal_card.dart';
import '../widgets/schedule_tile.dart';
import '../../data/repositories/user_repository.dart';

// Helper: format tanggal dalam Bahasa Indonesia tanpa locale plugin
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

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _isSelectionMode = false;
  Set<String> _selectedMealIds = {};
  DateTime? _lastSelectedDate;

  Future<void> _confirmDeleteSelected(ScheduleProvider prov) async {
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
                      
                      // Delete in a batch
                      for (final id in _selectedMealIds) {
                        await prov.deleteMeal(id);
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

  void _showSessionCustomizerDialog(BuildContext context, ScheduleProvider prov) {
    final selectedDate = prov.selectedDate;
    final currentSessions = UserRepository.getSessionsForDate(selectedDate);
    
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        List<String> tempSessions = List.from(currentSessions);
        
        return StatefulBuilder(
          builder: (context, setState) {
            final availableSessions = {'sarapan', 'makan_siang', 'snack_sore', 'makan_malam'};
            availableSessions.addAll(tempSessions);

            final orderedAll = <String>[];
            if (availableSessions.contains('sarapan')) orderedAll.add('sarapan');
            if (availableSessions.contains('makan_siang')) orderedAll.add('makan_siang');
            if (availableSessions.contains('snack_sore')) orderedAll.add('snack_sore');
            if (availableSessions.contains('makan_malam')) orderedAll.add('makan_malam');
            for (final s in availableSessions) {
              if (s != 'sarapan' && s != 'makan_siang' && s != 'snack_sore' && s != 'makan_malam') {
                orderedAll.add(s);
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: AppColors.surface,
              title: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kustomisasi Sesi',
                      style: AppTextStyles.heading3,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Text(
                      'Sesi Sarapan, Makan Siang, dan Makan Malam wajib ada untuk mendukung diet harian Anda.',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ...orderedAll.map((sesi) {
                      final isMandatory = sesi == 'sarapan' || sesi == 'makan_siang' || sesi == 'makan_malam';
                      final label = UserRepository.getSessionLabel(sesi);
                      final emoji = UserRepository.getSessionEmoji(sesi);
                      final isActive = tempSessions.contains(sesi);
                      
                      return CheckboxListTile(
                        activeColor: AppColors.primary,
                        title: Row(
                          children: [
                            Text(emoji, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                label,
                                style: AppTextStyles.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                        value: isActive,
                        onChanged: isMandatory ? null : (checked) {
                          setState(() {
                            if (checked == true) {
                              if (!tempSessions.contains(sesi)) {
                                tempSessions.add(sesi);
                              }
                            } else {
                              tempSessions.remove(sesi);
                            }
                          });
                        },
                      );
                    }),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.add_rounded, color: AppColors.primary),
                      title: Text(
                        'Tambah Sesi Kustom',
                        style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
                      ),
                      onTap: () {
                        _showAddCustomSessionDialog(context, (newSesiKey) {
                          if (newSesiKey.isNotEmpty && !tempSessions.contains(newSesiKey)) {
                            setState(() {
                              tempSessions.add(newSesiKey);
                            });
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    if (!tempSessions.contains('sarapan')) tempSessions.add('sarapan');
                    if (!tempSessions.contains('makan_siang')) tempSessions.add('makan_siang');
                    if (!tempSessions.contains('makan_malam')) tempSessions.add('makan_malam');
                    
                    final sortedSave = <String>[];
                    if (tempSessions.contains('sarapan')) sortedSave.add('sarapan');
                    if (tempSessions.contains('makan_siang')) sortedSave.add('makan_siang');
                    if (tempSessions.contains('snack_sore')) sortedSave.add('snack_sore');
                    if (tempSessions.contains('makan_malam')) sortedSave.add('makan_malam');
                    for (final s in tempSessions) {
                      if (s != 'sarapan' && s != 'makan_siang' && s != 'snack_sore' && s != 'makan_malam') {
                        sortedSave.add(s);
                      }
                    }

                    await UserRepository.saveSessionsForDate(selectedDate, sortedSave);
                    prov.loadSchedule();
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Template jadwal berhasil diperbarui'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppColors.success,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Simpan', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddCustomSessionDialog(BuildContext context, Function(String) onAdded) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Sesi Kustom Baru'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Masukkan nama sesi (misal: Camilan Siang)',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
                  onAdded(slug);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Tambah', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ScheduleProvider>(
      builder: (context, prov, _) {
        final currentDate = prov.selectedDate;
        if (_lastSelectedDate != null && _lastSelectedDate != currentDate) {
          _isSelectionMode = false;
          _selectedMealIds.clear();
        }
        _lastSelectedDate = currentDate;

        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_isSelectionMode) ...[
                      Expanded(
                        child: Text(
                          'Terpilih (${_selectedMealIds.length})',
                          style: AppTextStyles.heading2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            if (_selectedMealIds.length < prov.meals.length)
                              TextButton(
                                style: TextButton.styleFrom(
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  final allMeals = prov.meals;
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
                            icon: const Icon(Icons.delete_outline, color: AppColors.error),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                            onPressed: _selectedMealIds.isEmpty
                                ? null
                                : () => _confirmDeleteSelected(prov),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.close),
                            padding: const EdgeInsets.all(8),
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
                      Text('Jadwal Makan', style: AppTextStyles.heading2),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 24),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showSessionCustomizerDialog(context, prov),
                      ),
                    ],
                  ],
                ),
              ),

              // Date selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => prov.setDate(
                        prov.selectedDate.subtract(const Duration(days: 1)),
                      ),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: prov.selectedDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) prov.setDate(picked);
                      },
                      child: Text(
                        _formatTanggal(prov.selectedDate),
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => prov.setDate(
                        prov.selectedDate.add(const Duration(days: 1)),
                      ),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),

              // Meal sessions
              Expanded(
                child: ReorderableListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  onReorder: (oldIndex, newIndex) {
                    prov.reorderSessions(oldIndex, newIndex);
                  },
                  proxyDecorator: (Widget child, int index, Animation<double> animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (BuildContext context, Widget? child) {
                        return Material(
                          elevation: 4,
                          shadowColor: AppColors.shadow.withValues(alpha: 0.1),
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: child!,
                        );
                      },
                      child: child,
                    );
                  },
                  children: prov.sessions.map((sesi) {
                    final mealsForSession = prov.getMealsBySession(sesi);
                    final totalCal = mealsForSession.fold<double>(
                        0, (s, m) => s + m.totalKalori);
                    return MealCard(
                      key: ValueKey(sesi),
                      title: UserRepository.getSessionLabel(sesi),
                      emoji: UserRepository.getSessionEmoji(sesi),
                      itemCount: mealsForSession.length,
                      totalCalories: totalCal,
                      child: mealsForSession.isEmpty
                          ? null
                          : Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(8, 0, 8, 8),
                              child: Column(
                                children: mealsForSession
                                    .map((m) => ScheduleTile(
                                          meal: m,
                                          isSelectionMode: _isSelectionMode,
                                          isSelected: _selectedMealIds.contains(m.id),
                                          onSelectedChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedMealIds.add(m.id);
                                              } else {
                                                _selectedMealIds.remove(m.id);
                                                if (_selectedMealIds.isEmpty) {
                                                  _isSelectionMode = false;
                                                }
                                              }
                                            });
                                          },
                                          onLongPress: () {
                                            setState(() {
                                              _isSelectionMode = true;
                                              _selectedMealIds.add(m.id);
                                            });
                                          },
                                          onDelete: () async {
                                            await prov.deleteMeal(m.id);
                                            if (context.mounted) {
                                              context.read<DashboardProvider>().refresh();
                                            }
                                          },
                                          onStatusChanged: (status) async {
                                            await prov.updateMealStatus(m.id, status);
                                            if (context.mounted) {
                                              context.read<DashboardProvider>().refresh();
                                            }
                                          },
                                        ))
                                    .toList(),
                              ),
                            ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
