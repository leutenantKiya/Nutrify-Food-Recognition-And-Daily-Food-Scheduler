import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/ingredient.dart';
import '../providers/ingredient_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/dashboard_provider.dart';

class IngredientScreen extends StatelessWidget {
  const IngredientScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<IngredientProvider>(
      builder: (context, prov, _) {
        final items = prov.ingredients;
        return Scaffold(
          appBar: AppBar(title: Text('Database Bahan Makanan', style: AppTextStyles.heading3)),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddDialog(context, prov),
            child: const Icon(Icons.add),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  onChanged: prov.setSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'Cari bahan makanan...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: prov.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => prov.setSearchQuery(''),
                          )
                        : null,
                  ),
                ),
              ),
              // Filter chips bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    _filterChip(context, prov, 'all', 'Semua'),
                    const SizedBox(width: 8),
                    _filterChip(context, prov, 'avoided', 'Dihindari'),
                    const SizedBox(width: 8),
                    _filterChip(context, prov, 'custom', 'Kustom'),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final ing = items[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: ing.isCustom ? AppColors.calories.withValues(alpha: 0.1) : AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            ing.isCustom ? Icons.edit_note : Icons.eco,
                            color: ing.isCustom ? AppColors.calories : AppColors.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(ing.nama, style: AppTextStyles.labelLarge),
                        subtitle: Text(
                          '${ing.kaloriPer100g.toStringAsFixed(0)} kkal • P:${ing.proteinPer100g}g • L:${ing.lemakPer100g}g • K:${ing.karboPer100g}g',
                          style: AppTextStyles.labelSmall,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.block,
                                color: ing.isAvoided ? AppColors.error : AppColors.textLight.withValues(alpha: 0.3),
                              ),
                              onPressed: () => prov.toggleAvoidIngredient(ing.id),
                              tooltip: ing.isAvoided ? 'Batal Hindari' : 'Hindari Bahan Ini',
                            ),
                            PopupMenuButton<String>(
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                const PopupMenuItem(value: 'delete', child: Text('Hapus')),
                              ],
                              onSelected: (v) {
                                if (v == 'delete') {
                                  prov.deleteIngredient(ing.id).then((_) {
                                    if (context.mounted) {
                                      context.read<ScheduleProvider>().loadSchedule();
                                      context.read<DashboardProvider>().refresh();
                                    }
                                  });
                                }
                                if (v == 'edit') {
                                  _showEditDialog(context, prov, ing);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddDialog(BuildContext context, IngredientProvider prov) {
    final namaC = TextEditingController();
    final kaloriC = TextEditingController();
    final proteinC = TextEditingController();
    final lemakC = TextEditingController();
    final karboC = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Bahan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Masukkan nilai nutrisi untuk setiap 100 gram bahan makanan.',
                style: AppTextStyles.labelMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: namaC,
                decoration: const InputDecoration(
                  labelText: 'Nama Bahan',
                  hintText: 'Masukkan nama bahan makanan',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: kaloriC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kalori',
                  suffixText: 'kkal',
                  hintText: '0',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: proteinC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Protein',
                  suffixText: 'g',
                  hintText: '0',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lemakC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Lemak',
                  suffixText: 'g',
                  hintText: '0',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: karboC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Karbohidrat',
                  suffixText: 'g',
                  hintText: '0',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              prov.addIngredient(Ingredient(
                id: const Uuid().v4(),
                nama: namaC.text.trim(),
                kaloriPer100g: double.tryParse(kaloriC.text) ?? 0,
                proteinPer100g: double.tryParse(proteinC.text) ?? 0,
                lemakPer100g: double.tryParse(lemakC.text) ?? 0,
                karboPer100g: double.tryParse(karboC.text) ?? 0,
                isCustom: true,
              ));
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, IngredientProvider prov, Ingredient ing) {
    final namaC = TextEditingController(text: ing.nama);
    final kaloriC = TextEditingController(text: ing.kaloriPer100g.toString());
    final proteinC = TextEditingController(text: ing.proteinPer100g.toString());
    final lemakC = TextEditingController(text: ing.lemakPer100g.toString());
    final karboC = TextEditingController(text: ing.karboPer100g.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Bahan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Masukkan nilai nutrisi untuk setiap 100 gram bahan makanan.',
                style: AppTextStyles.labelMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: namaC,
                decoration: const InputDecoration(
                  labelText: 'Nama Bahan',
                  hintText: 'Masukkan nama bahan makanan',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: kaloriC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kalori',
                  suffixText: 'kkal',
                  hintText: '0',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: proteinC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Protein',
                  suffixText: 'g',
                  hintText: '0',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lemakC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Lemak',
                  suffixText: 'g',
                  hintText: '0',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: karboC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Karbohidrat',
                  suffixText: 'g',
                  hintText: '0',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              await prov.updateIngredient(ing.copyWith(
                nama: namaC.text.trim(),
                kaloriPer100g: double.tryParse(kaloriC.text) ?? 0,
                proteinPer100g: double.tryParse(proteinC.text) ?? 0,
                lemakPer100g: double.tryParse(lemakC.text) ?? 0,
                karboPer100g: double.tryParse(karboC.text) ?? 0,
              ));
              if (context.mounted) {
                context.read<ScheduleProvider>().loadSchedule();
                context.read<DashboardProvider>().refresh();
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(BuildContext context, IngredientProvider prov, String filter, String label) {
    final isSelected = prov.selectedFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => prov.setFilter(filter),
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      checkmarkColor: AppColors.primary,
      backgroundColor: AppColors.surfaceVariant,
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.divider,
        width: 1,
      ),
      labelStyle: AppTextStyles.labelMedium.copyWith(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}
