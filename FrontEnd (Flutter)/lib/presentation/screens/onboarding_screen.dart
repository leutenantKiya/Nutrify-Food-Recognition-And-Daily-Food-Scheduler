import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/user_profile.dart';
import '../providers/user_provider.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Form data
  final _namaController = TextEditingController();
  final _umurController = TextEditingController();
  final _tinggiController = TextEditingController();
  final _beratController = TextEditingController();
  final _pantanganController = TextEditingController();
  String _gender = 'pria';
  String _targetDiet = 'maintain';
  String _aktivitas = 'sedang';
  final List<String> _pantanganList = [];

  @override
  void dispose() {
    _pageController.dispose();
    _namaController.dispose();
    _umurController.dispose();
    _tinggiController.dispose();
    _beratController.dispose();
    _pantanganController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() async {
    final profile = UserProfile(
      nama: _namaController.text.trim().isEmpty ? 'Pengguna' : _namaController.text.trim(),
      umur: int.tryParse(_umurController.text) ?? 20,
      tinggiBadan: double.tryParse(_tinggiController.text) ?? 170,
      beratBadan: double.tryParse(_beratController.text) ?? 65,
      gender: _gender,
      targetDiet: _targetDiet,
      aktivitas: _aktivitas,
      pantangan: _pantanganList,
    );

    await context.read<UserProvider>().completeOnboarding(profile);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: List.generate(4, (i) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i <= _currentPage
                            ? AppColors.primary
                            : AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildNamePage(),
                  _buildPhysicalPage(),
                  _buildGoalPage(),
                  _buildPreferencePage(),
                ],
              ),
            ),
            // Bottom buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        ),
                        child: const Text('Kembali'),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: _currentPage > 0 ? 2 : 1,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      child: Text(
                        _currentPage < 3 ? 'Lanjut' : 'Mulai!',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNamePage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text('Halo! 👋', style: AppTextStyles.heading1),
          const SizedBox(height: 8),
          Text('Siapa nama kamu?', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 32),
          TextField(
            controller: _namaController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Masukkan nama kamu',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhysicalPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text('Data Fisik 📏', style: AppTextStyles.heading1),
          const SizedBox(height: 8),
          Text('Kami butuh data ini untuk menghitung kebutuhan nutrisimu', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          TextField(
            controller: _umurController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Umur (tahun)', prefixIcon: Icon(Icons.cake_outlined)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tinggiController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Tinggi badan (cm)', prefixIcon: Icon(Icons.height)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _beratController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Berat badan (kg)', prefixIcon: Icon(Icons.monitor_weight_outlined)),
          ),
          const SizedBox(height: 20),
          Text('Jenis Kelamin', style: AppTextStyles.labelLarge),
          const SizedBox(height: 8),
          Row(
            children: AppConstants.genderOptions.map((g) {
              final isSelected = _gender == g;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _gender = g),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? AppColors.primary : AppColors.divider),
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
        ],
      ),
    );
  }

  Widget _buildGoalPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text('Target Diet 🎯', style: AppTextStyles.heading1),
          const SizedBox(height: 8),
          Text('Apa tujuan diet kamu?', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          ...AppConstants.dietTargets.map((d) {
            final isSelected = _targetDiet == d;
            return GestureDetector(
              onTap: () => setState(() => _targetDiet = d),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primarySurface : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.divider,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  AppConstants.dietTargetLabels[d]!,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
          Text('Tingkat Aktivitas', style: AppTextStyles.labelLarge),
          const SizedBox(height: 8),
          ...AppConstants.activityMultipliers.keys.map((a) {
            final isSelected = _aktivitas == a;
            return GestureDetector(
              onTap: () => setState(() => _aktivitas = a),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primarySurface : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.divider,
                    width: isSelected ? 2 : 1,
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
        ],
      ),
    );
  }

  Widget _buildPreferencePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text('Pantangan 🚫', style: AppTextStyles.heading1),
          const SizedBox(height: 8),
          Text('Ada makanan yang tidak boleh kamu makan?', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pantanganController,
                  decoration: const InputDecoration(hintText: 'Contoh: kacang, susu'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () {
                  if (_pantanganController.text.trim().isNotEmpty) {
                    setState(() {
                      _pantanganList.add(_pantanganController.text.trim());
                      _pantanganController.clear();
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
            children: _pantanganList.map((p) {
              return Chip(
                label: Text(p),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => setState(() => _pantanganList.remove(p)),
                backgroundColor: AppColors.surfaceVariant,
              );
            }).toList(),
          ),
          if (_pantanganList.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Tidak ada pantangan? Langsung tekan "Mulai!" 😊',
                style: AppTextStyles.bodySmall.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }
}
