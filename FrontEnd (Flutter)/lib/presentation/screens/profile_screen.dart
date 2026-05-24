import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../providers/user_provider.dart';
import 'onboarding_screen.dart';
import 'ingredient_screen.dart';
import 'secret_settings_screen.dart';
import 'edit_profile_screen.dart';
import 'weight_correction_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProv, _) {
        final profile = userProv.profile;
        if (profile == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // ── Header Avatar ──────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 2),
                        ),
                        child: ClipOval(
                          child: (profile.photoPath != null &&
                                  profile.photoPath!.isNotEmpty &&
                                  File(profile.photoPath!).existsSync())
                              ? Image.file(
                                  File(profile.photoPath!),
                                  fit: BoxFit.cover,
                                )
                              : Center(
                                  child: Text(
                                    profile.nama.isNotEmpty
                                        ? profile.nama[0].toUpperCase()
                                        : 'U',
                                    style: AppTextStyles.splashTitle.copyWith(
                                      fontSize: 32,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        profile.nama,
                        style: AppTextStyles.heading2
                            .copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          AppConstants.dietTargetLabels[profile.targetDiet] ??
                              '',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Kartu Target Nutrisi ───────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.local_fire_department_rounded,
                                color: AppColors.primary, size: 18),
                            const SizedBox(width: 6),
                            Text('Target Nutrisi Harian',
                                style: AppTextStyles.labelLarge
                                    .copyWith(color: AppColors.primary)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _nutriChip(
                                userProv.targetKalori.toStringAsFixed(0),
                                'kkal',
                                AppColors.primary),
                            const SizedBox(width: 8),
                            _nutriChip(
                                userProv.targetProtein.toStringAsFixed(0),
                                'protein',
                                Colors.orange),
                            const SizedBox(width: 8),
                            _nutriChip(
                                userProv.targetLemak.toStringAsFixed(0),
                                'lemak',
                                Colors.redAccent),
                            const SizedBox(width: 8),
                            _nutriChip(
                                userProv.targetKarbo.toStringAsFixed(0),
                                'karbo',
                                Colors.teal),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Section: Data Diri ─────────────────────
                _sectionLabel('Data Diri', context),
                _menuCard(children: [
                  _infoRow(Icons.cake_outlined, 'Umur',
                      '${profile.umur} tahun'),
                  _divider(),
                  _infoRow(Icons.height, 'Tinggi Badan',
                      '${profile.tinggiBadan.toStringAsFixed(0)} cm'),
                  _divider(),
                  _infoRow(Icons.monitor_weight_outlined, 'Berat Badan',
                      '${profile.beratBadan.toStringAsFixed(0)} kg'),
                  _divider(),
                  _infoRow(
                      Icons.person_outline,
                      'Jenis Kelamin',
                      AppConstants.genderLabels[profile.gender] ?? ''),
                  _divider(),
                  _infoRow(
                      Icons.directions_run,
                      'Aktivitas',
                      AppConstants.activityLabels[profile.aktivitas] ?? ''),
                  if (profile.pantangan.isNotEmpty) ...[
                    _divider(),
                    _infoRow(Icons.block, 'Pantangan',
                        profile.pantangan.join(', '), wrapText: true),
                  ],
                ]),

                const SizedBox(height: 8),

                // ── Section: Pengaturan ────────────────────
                _sectionLabel('Pengaturan', context),
                _menuCard(children: [
                  _actionRow(
                    icon: Icons.edit_rounded,
                    label: 'Edit Profil',
                    color: AppColors.primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const EditProfileScreen()),
                    ),
                  ),
                  _divider(),
                  _actionRow(
                    icon: Icons.restaurant_menu_rounded,
                    label: 'Database Bahan Makanan',
                    color: AppColors.primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const IngredientScreen()),
                    ),
                  ),
                  _divider(),
                  _actionRow(
                    icon: Icons.scale_outlined,
                    label: 'Database Koreksi Berat Makanan',
                    subtitle: 'Batas gram minimum & koreksi eksponensial',
                    color: AppColors.primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const WeightCorrectionScreen()),
                    ),
                  ),
                ]),

                const SizedBox(height: 8),

                // ── Section: Konfigurasi Rahasia ───────────
                _sectionLabel('Konfigurasi AI', context),
                _menuCard(children: [
                  _actionRow(
                    icon: Icons.vpn_key_rounded,
                    label: 'Hugging Face Token & Endpoint',
                    subtitle: 'API Key, Model ID, Base URL',
                    color: const Color(0xFFFF6B35),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SecretSettingsScreen()),
                    ),
                  ),
                ]),

                const SizedBox(height: 8),

                // ── Section: Zona Berbahaya ────────────────
                _sectionLabel('Lainnya', context),
                _menuCard(children: [
                  _actionRow(
                    icon: Icons.delete_forever_rounded,
                    label: 'Reset Semua Data',
                    subtitle: 'Hapus profil, jadwal, dan riwayat chat',
                    color: AppColors.error,
                    onTap: () => _showResetDialog(context, userProv),
                  ),
                ]),

                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────

  Widget _sectionLabel(String label, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textLight,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _menuCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {bool wrapText = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        crossAxisAlignment: wrapText ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(label, style: AppTextStyles.labelMedium),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.left,
              overflow: wrapText ? null : TextOverflow.ellipsis,
              maxLines: wrapText ? null : 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.labelMedium),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.textLight),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textLight, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Divider(
        height: 1,
        indent: 64,
        color: AppColors.divider.withValues(alpha: 0.6),
      );

  Widget _nutriChip(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTextStyles.labelLarge.copyWith(
                color: color,
                fontSize: 15,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: color.withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context, UserProvider prov) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Semua Data'),
        content: const Text(
            'Profil, jadwal makan, dan riwayat chat akan dihapus permanen. Lanjutkan?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              await prov.resetProfile();
              if (!context.mounted) return;
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => const OnboardingScreen()),
              );
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
