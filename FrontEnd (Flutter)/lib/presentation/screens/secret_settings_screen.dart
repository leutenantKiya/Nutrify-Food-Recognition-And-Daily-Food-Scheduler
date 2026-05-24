import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/hive_service.dart';

class SecretSettingsScreen extends StatefulWidget {
  const SecretSettingsScreen({super.key});

  @override
  State<SecretSettingsScreen> createState() => _SecretSettingsScreenState();
}

class _SecretSettingsScreenState extends State<SecretSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _hfApiKeyCtrl;
  late final TextEditingController _hfModelCtrl;
  late final TextEditingController _hfBaseUrlCtrl;
  late final TextEditingController _photoUrlCtrl;

  bool _obscureKey = true;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    final box = HiveService.secretBox;
    _hfApiKeyCtrl = TextEditingController(
        text: box.get(AppConstants.keyHfApiKey) as String? ?? '');
    _hfModelCtrl = TextEditingController(
        text: box.get(AppConstants.keyHfModelId) as String? ?? '');
    _hfBaseUrlCtrl = TextEditingController(
        text: box.get(AppConstants.keyHfBaseUrl) as String? ?? '');
    _photoUrlCtrl = TextEditingController(
        text: box.get(AppConstants.keyPhotoUrl) as String? ?? '');

    _hfApiKeyCtrl.addListener(_onApiKeyChanged);
  }

  void _onApiKeyChanged() {
    setState(() {});
  }

  String _detectProvider(String key) {
    if (key.startsWith('sk-or-')) {
      return 'OpenRouter AI 🚀';
    } else if (key.startsWith('hf_')) {
      return 'Hugging Face 🌌';
    } else if (key.isNotEmpty) {
      return 'Provider Kustom ⚙️';
    }
    return 'Belum Diisi ❓';
  }

  Color _getProviderColor(String key) {
    if (key.startsWith('sk-or-')) {
      return Colors.orange.shade700;
    } else if (key.startsWith('hf_')) {
      return Colors.blue.shade700;
    } else if (key.isNotEmpty) {
      return Colors.purple.shade700;
    }
    return AppColors.textSecondary;
  }

  @override
  void dispose() {
    _hfApiKeyCtrl.removeListener(_onApiKeyChanged);
    _hfApiKeyCtrl.dispose();
    _hfModelCtrl.dispose();
    _hfBaseUrlCtrl.dispose();
    _photoUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final box = HiveService.secretBox;
    await box.put(AppConstants.keyHfApiKey, _hfApiKeyCtrl.text.trim());
    await box.put(AppConstants.keyHfModelId, _hfModelCtrl.text.trim());
    await box.put(AppConstants.keyHfBaseUrl, _hfBaseUrlCtrl.text.trim());
    await box.put(AppConstants.keyPhotoUrl, _photoUrlCtrl.text.trim());

    if (!mounted) return;
    setState(() => _isSaved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isSaved = false);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✅ Konfigurasi tersimpan!'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Konfigurasi'),
        content: const Text(
            'Semua token dan endpoint akan dihapus. App akan kembali menggunakan nilai dari .env'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final box = HiveService.secretBox;
      await box.delete(AppConstants.keyHfApiKey);
      await box.delete(AppConstants.keyHfModelId);
      await box.delete(AppConstants.keyHfBaseUrl);
      await box.delete(AppConstants.keyPhotoUrl);
      _hfApiKeyCtrl.clear();
      _hfModelCtrl.clear();
      _hfBaseUrlCtrl.clear();
      _photoUrlCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Konfigurasi dihapus, kembali ke .env'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Konfigurasi Rahasia', style: AppTextStyles.heading3),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            tooltip: 'Hapus semua',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Banner info
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Nilai yang diisi di sini akan menggantikan konfigurasi dari file .env. '
                      'Jika kosong, app menggunakan nilai default dari .env.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                ],
              ),
            ),

            // ── Section: AI Provider ──────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionHeader('AI Provider & LLM', Icons.smart_toy_outlined),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getProviderColor(_hfApiKeyCtrl.text.trim()).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getProviderColor(_hfApiKeyCtrl.text.trim()).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _detectProvider(_hfApiKeyCtrl.text.trim()),
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _getProviderColor(_hfApiKeyCtrl.text.trim()),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // API Key
            _buildField(
              controller: _hfApiKeyCtrl,
              label: 'API Key / Token',
              hint: 'hf_... atau sk-or-...',
              icon: Icons.key_rounded,
              obscure: _obscureKey,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureKey ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscureKey = !_obscureKey),
              ),
              helper:
                  'Mendukung HuggingFace (awalan hf_) & OpenRouter (awalan sk-or-).',
              keyboardType: TextInputType.visiblePassword,
            ),
            const SizedBox(height: 12),

            // Base URL
            _buildField(
              controller: _hfBaseUrlCtrl,
              label: 'Custom Base URL',
              hint: _hfApiKeyCtrl.text.trim().startsWith('sk-or-')
                  ? 'https://openrouter.ai/api/v1/chat/completions'
                  : 'https://router.huggingface.co/v1/chat/completions',
              icon: Icons.link_rounded,
              helper: 'Gunakan jika ingin override endpoint default provider.',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),

            // Model ID
            _buildField(
              controller: _hfModelCtrl,
              label: 'Model ID',
              hint: _hfApiKeyCtrl.text.trim().startsWith('sk-or-')
                  ? 'google/gemini-2.5-flash'
                  : 'deepseek-ai/DeepSeek-V4-Pro:novita',
              icon: Icons.settings_suggest_rounded,
              helper: _hfApiKeyCtrl.text.trim().startsWith('sk-or-')
                  ? 'ID Model OpenRouter. Contoh: google/gemini-2.5-flash'
                  : 'ID Model HuggingFace. Contoh: deepseek-ai/DeepSeek-V4-Pro:novita',
            ),

            const SizedBox(height: 28),

            // ── Section: Backend ───────────────────────────
            _sectionHeader('Backend Deteksi Foto', Icons.camera_alt_outlined),
            const SizedBox(height: 12),

            _buildField(
              controller: _photoUrlCtrl,
              label: 'Endpoint Deteksi Foto',
              hint: 'http://10.0.2.2:8000/api/detect',
              icon: Icons.api_rounded,
              helper:
                  'Di emulator Android, gunakan 10.0.2.2 sebagai localhost.',
              keyboardType: TextInputType.url,
            ),

            const SizedBox(height: 32),

            // Tombol Simpan
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _save,
                icon: Icon(_isSaved
                    ? Icons.check_circle_rounded
                    : Icons.save_rounded),
                label: Text(_isSaved ? 'Tersimpan!' : 'Simpan Konfigurasi'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: AppTextStyles.labelLarge,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: AppTextStyles.labelLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            )),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? helper,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: AppTextStyles.bodySmall.copyWith(
          fontFamily: 'monospace', color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 2,
        prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
        suffixIcon: suffixIcon ??
            (controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: controller.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Disalin ke clipboard'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  )
                : null),
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
