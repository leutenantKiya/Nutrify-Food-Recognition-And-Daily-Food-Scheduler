import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/user_profile.dart';
import '../providers/user_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedFile = await File(pickedFile.path).copy('${appDir.path}/$fileName');

      if (!mounted) return;
      final userProv = Provider.of<UserProvider>(context, listen: false);

      // Hapus file lama jika ada
      final oldPath = userProv.profile!.photoPath;
      if (oldPath != null && oldPath.isNotEmpty) {
        final oldFile = File(oldPath);
        if (await oldFile.exists()) {
          try {
            await oldFile.delete();
          } catch (e) {
            debugPrint('Gagal menghapus foto profil lama: $e');
          }
        }
      }

      final updatedProfile = userProv.profile!.copyWith(photoPath: savedFile.path);
      await userProv.saveProfile(updatedProfile);

      setState(() {});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Foto profil berhasil diperbarui!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showPersonalSheet(UserProfile profile) {
    final nameCtrl = TextEditingController(text: profile.nama);
    final ageCtrl = TextEditingController(text: profile.umur.toString());
    String genderVal = profile.gender;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Data Personal', style: AppTextStyles.heading3),
                  const SizedBox(height: 4),
                  Text('Ubah nama, umur, dan jenis kelamin Anda',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 20),

                  // Nama
                  TextFormField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Nama tidak boleh kosong' : null,
                  ),
                  const SizedBox(height: 16),

                  // Umur
                  TextFormField(
                    controller: ageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Umur (tahun)',
                      prefixIcon: Icon(Icons.cake_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Umur tidak boleh kosong';
                      final val = int.tryParse(v);
                      if (val == null || val <= 0) return 'Umur harus angka valid';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Gender
                  Text('Jenis Kelamin', style: AppTextStyles.labelLarge),
                  const SizedBox(height: 8),
                  Row(
                    children: AppConstants.genderOptions.map((g) {
                      final isSelected = genderVal == g;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(() => genderVal = g),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: isSelected ? AppColors.primary : AppColors.divider),
                            ),
                            child: Center(
                              child: Text(
                                AppConstants.genderLabels[g]!,
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: isSelected ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

                  // Simpan Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final userProv = Provider.of<UserProvider>(ctx, listen: false);
                        final updated = profile.copyWith(
                          nama: nameCtrl.text.trim(),
                          umur: int.parse(ageCtrl.text.trim()),
                          gender: genderVal,
                        );
                        await userProv.saveProfile(updated);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _showSuccessSnackbar('Data Personal diperbarui!');
                      },
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Simpan Perubahan'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPhysicalSheet(UserProfile profile) {
    final heightCtrl = TextEditingController(text: profile.tinggiBadan.toStringAsFixed(0));
    final weightCtrl = TextEditingController(text: profile.beratBadan.toStringAsFixed(0));
    String activityVal = profile.aktivitas;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Fisik & Aktivitas', style: AppTextStyles.heading3),
                    const SizedBox(height: 4),
                    Text('Sesuaikan ukuran fisik dan tingkat aktivitas harian Anda',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 20),

                    // Tinggi
                    TextFormField(
                      controller: heightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Tinggi Badan (cm)',
                        prefixIcon: Icon(Icons.height),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Tinggi badan tidak boleh kosong';
                        final val = double.tryParse(v);
                        if (val == null || val <= 0) return 'Tinggi badan harus angka valid';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Berat
                    TextFormField(
                      controller: weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Berat Badan (kg)',
                        prefixIcon: Icon(Icons.monitor_weight_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Berat badan tidak boleh kosong';
                        final val = double.tryParse(v);
                        if (val == null || val <= 0) return 'Berat badan harus angka valid';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Tingkat Aktivitas
                    Text('Tingkat Aktivitas', style: AppTextStyles.labelLarge),
                    const SizedBox(height: 8),
                    ...AppConstants.activityMultipliers.keys.map((a) {
                      final isSelected = activityVal == a;
                      return GestureDetector(
                        onTap: () => setSheetState(() => activityVal = a),
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primarySurface : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.divider,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            AppConstants.activityLabels[a]!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 20),

                    // Simpan Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final userProv = Provider.of<UserProvider>(ctx, listen: false);
                          final updated = profile.copyWith(
                            tinggiBadan: double.parse(heightCtrl.text.trim()),
                            beratBadan: double.parse(weightCtrl.text.trim()),
                            aktivitas: activityVal,
                          );
                          await userProv.saveProfile(updated);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          _showSuccessSnackbar('Fisik & Aktivitas diperbarui!');
                        },
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Simpan Perubahan'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showTargetPantanganSheet(UserProfile profile) {
    String targetVal = profile.targetDiet;
    final restrictCtrl = TextEditingController();
    final List<String> restrictions = List.from(profile.pantangan);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Target & Pantangan', style: AppTextStyles.heading3),
                    const SizedBox(height: 4),
                    Text('Ubah target kalori dan bahan makanan pantangan Anda',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 20),

                    // Target Diet
                    Text('Target Diet', style: AppTextStyles.labelLarge),
                    const SizedBox(height: 8),
                    ...AppConstants.dietTargets.map((d) {
                      final isSelected = targetVal == d;
                      return GestureDetector(
                        onTap: () => setSheetState(() => targetVal = d),
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primarySurface : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.divider,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            AppConstants.dietTargetLabels[d]!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 20),

                    // Pantangan
                    Text('Pantangan Makanan', style: AppTextStyles.labelLarge),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: restrictCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Tambah pantangan (misal: kacang, udang)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: () {
                            if (restrictCtrl.text.trim().isNotEmpty) {
                              setSheetState(() {
                                restrictions.add(restrictCtrl.text.trim());
                                restrictCtrl.clear();
                              });
                            }
                          },
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: restrictions.map((p) {
                        return Chip(
                          label: Text(p),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => setSheetState(() => restrictions.remove(p)),
                          backgroundColor: AppColors.surfaceVariant,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),

                    // Simpan Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: () async {
                          final userProv = Provider.of<UserProvider>(ctx, listen: false);
                          final updated = profile.copyWith(
                            targetDiet: targetVal,
                            pantangan: restrictions,
                          );
                          await userProv.saveProfile(updated);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          _showSuccessSnackbar('Target & Pantangan diperbarui!');
                        },
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Simpan Perubahan'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profil', style: AppTextStyles.heading3),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProv, _) {
          final profile = userProv.profile;
          if (profile == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final bool hasPhoto = profile.photoPath != null && profile.photoPath!.isNotEmpty;
          final bool fileExists = hasPhoto && File(profile.photoPath!).existsSync();

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              // Avatar Section
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadow.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: ClipOval(
                        child: fileExists
                            ? Image.file(
                                File(profile.photoPath!),
                                fit: BoxFit.cover,
                              )
                            : Center(
                                child: Text(
                                  profile.nama.isNotEmpty ? profile.nama[0].toUpperCase() : 'U',
                                  style: AppTextStyles.heading1.copyWith(
                                    fontSize: 42,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Ubah Foto Profil',
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 36),

              // Categories List
              _categoryCard(
                icon: Icons.badge_outlined,
                title: 'Data Personal',
                description: 'Nama, Umur, dan Jenis Kelamin',
                color: Colors.blue.shade700,
                onTap: () => _showPersonalSheet(profile),
              ),
              const SizedBox(height: 16),

              _categoryCard(
                icon: Icons.accessibility_new_outlined,
                title: 'Fisik & Aktivitas',
                description: 'Tinggi Badan, Berat Badan, dan Aktivitas Harian',
                color: Colors.teal.shade700,
                onTap: () => _showPhysicalSheet(profile),
              ),
              const SizedBox(height: 16),

              _categoryCard(
                icon: Icons.track_changes_outlined,
                title: 'Target & Pantangan',
                description: 'Tujuan Diet, dan Bahan Makanan yang dihindari',
                color: Colors.orange.shade700,
                onTap: () => _showTargetPantanganSheet(profile),
              ),
              const SizedBox(height: 16),
              _categoryCard(
                icon: Icons.access_time_outlined,
                title: 'Jadwal Makan & Tidur',
                description: 'Atur waktu Sarapan, Makan Siang, Makan Malam, dan Tidur',
                color: Colors.purple.shade700,
                onTap: () => _showJadwalMakanTidurSheet(profile),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showJadwalMakanTidurSheet(UserProfile profile) {
    String sarapanVal = profile.jamSarapan;
    String siangVal = profile.jamMakanSiang;
    String malamVal = profile.jamMakanMalam;
    String tidurVal = profile.jamTidur;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> selectTime(String type, String currentVal, Function(String) onSelected) async {
            final parts = currentVal.split(':');
            final initialHour = int.tryParse(parts[0]) ?? 8;
            final initialMin = int.tryParse(parts[1]) ?? 0;
            final TimeOfDay? picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: initialHour, minute: initialMin),
            );
            if (picked != null) {
              final hourStr = picked.hour.toString().padLeft(2, '0');
              final minStr = picked.minute.toString().padLeft(2, '0');
              onSelected('$hourStr:$minStr');
            }
          }

          Widget timeRow(String label, String icon, String timeStr, VoidCallback onTap) {
            return InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                child: Row(
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        timeStr,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Jadwal Makan & Tidur', style: AppTextStyles.heading3),
                const SizedBox(height: 4),
                Text('Sesuaikan jam makan dan waktu tidur harian Anda',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                timeRow('Sarapan', '🌅', sarapanVal, () {
                  selectTime('sarapan', sarapanVal, (newTime) {
                    setSheetState(() => sarapanVal = newTime);
                  });
                }),
                const Divider(),
                timeRow('Makan Siang', '☀️', siangVal, () {
                  selectTime('makan_siang', siangVal, (newTime) {
                    setSheetState(() => siangVal = newTime);
                  });
                }),
                const Divider(),
                timeRow('Makan Malam', '🌙', malamVal, () {
                  selectTime('makan_malam', malamVal, (newTime) {
                    setSheetState(() => malamVal = newTime);
                  });
                }),
                const Divider(),
                timeRow('Waktu Tidur', '🛌', tidurVal, () {
                  selectTime('jam_tidur', tidurVal, (newTime) {
                    setSheetState(() => tidurVal = newTime);
                  });
                }),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: () async {
                      final userProv = Provider.of<UserProvider>(ctx, listen: false);
                      final updated = profile.copyWith(
                        jamSarapan: sarapanVal,
                        jamMakanSiang: siangVal,
                        jamMakanMalam: malamVal,
                        jamTidur: tidurVal,
                      );
                      await userProv.saveProfile(updated);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      _showSuccessSnackbar('Jadwal Makan & Tidur diperbarui!');
                    },
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Simpan Perubahan'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _categoryCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.textLight,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
