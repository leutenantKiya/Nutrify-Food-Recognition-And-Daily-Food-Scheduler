import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/repositories/user_repository.dart';

class WeightCorrectionScreen extends StatefulWidget {
  const WeightCorrectionScreen({super.key});

  @override
  State<WeightCorrectionScreen> createState() => _WeightCorrectionScreenState();
}

class _WeightCorrectionScreenState extends State<WeightCorrectionScreen> {
  Map<String, double> _corrections = {};

  @override
  void initState() {
    super.initState();
    _loadCorrections();
  }

  void _loadCorrections() {
    setState(() {
      _corrections = UserRepository.getWeightCorrections();
    });
  }

  Future<void> _saveAndReload(Map<String, double> updated) async {
    await UserRepository.saveWeightCorrections(updated);
    _loadCorrections();
  }

  void _showAddOrEditDialog({String? existingKey, double? existingValue}) {
    final TextEditingController nameController = TextEditingController(text: existingKey);
    final TextEditingController weightController = TextEditingController(
      text: existingValue != null ? existingValue.toStringAsFixed(0) : '150',
    );
    final formKey = GlobalKey<FormState>();
    final isEdit = existingKey != null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.surface,
          title: Row(
            children: [
              Icon(
                isEdit ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(isEdit ? 'Edit Koreksi' : 'Tambah Koreksi'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  enabled: !isEdit,
                  decoration: InputDecoration(
                    labelText: 'Nama Makanan / Kata Kunci',
                    hintText: 'Misal: nasi goreng',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama tidak boleh kosong';
                    }
                    if (!isEdit && _corrections.containsKey(value.trim().toLowerCase())) {
                      return 'Makanan sudah terdaftar';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: weightController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Berat Minimal (gram)',
                    suffixText: 'g',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Masukkan berat minimal';
                    }
                    final val = double.tryParse(value);
                    if (val == null || val <= 0) {
                      return 'Masukkan angka positif yang valid';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final key = nameController.text.trim().toLowerCase();
                  final weight = double.parse(weightController.text.trim());
                  
                  final newMap = Map<String, double>.from(_corrections);
                  newMap[key] = weight;
                  await _saveAndReload(newMap);
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(isEdit ? 'Simpan' : 'Tambah'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(String key) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.surface,
          title: const Text('Hapus Koreksi?'),
          content: Text('Apakah Anda yakin ingin menghapus aturan koreksi untuk "$key"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final newMap = Map<String, double>.from(_corrections);
                newMap.remove(key);
                await _saveAndReload(newMap);
                
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _corrections.entries.toList();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Database Koreksi Berat'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: list.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.scale_outlined, size: 64, color: AppColors.textLight),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada aturan koreksi berat',
                      style: AppTextStyles.heading3.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Teknologi AI terkadang mendeteksi porsi makanan yang terlalu ringan (misal 1 gram nasi goreng). '
                      'Tambahkan batas minimum di sini agar berat otomatis dikoreksi secara eksponensial.',
                      style: AppTextStyles.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final item = list[index];
                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.divider),
                  ),
                  color: AppColors.surface,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: const Icon(Icons.fastfood_outlined, color: AppColors.primary),
                    ),
                    title: Text(
                      item.key.toUpperCase(),
                      style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Batas Minimum: ${item.value.toStringAsFixed(0)} gram',
                      style: AppTextStyles.bodySmall,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                          onPressed: () => _showAddOrEditDialog(
                            existingKey: item.key,
                            existingValue: item.value,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                          onPressed: () => _confirmDelete(item.key),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOrEditDialog(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Aturan Baru'),
      ),
    );
  }
}
