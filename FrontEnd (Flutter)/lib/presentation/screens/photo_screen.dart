import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/api_service.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/rule_engine_service.dart';
import '../../data/models/meal_analysis_result.dart';
import '../../data/models/meal_schedule.dart';
import '../../data/models/ingredient.dart';
import '../../data/repositories/ingredient_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../providers/photo_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/user_provider.dart';
import '../providers/dashboard_provider.dart';

class PhotoScreen extends StatefulWidget {
  const PhotoScreen({super.key});

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isInitializingCamera = false;

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    if (_isInitializingCamera) return;
    setState(() {
      _isInitializingCamera = true;
    });

    try {
      if (_cameraController != null) {
        await _cameraController!.dispose();
        _cameraController = null;
      }

      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        final backCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras!.first,
        );

        final controller = CameraController(
          backCamera,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        _cameraController = controller;

        await controller.initialize();
        
        if (!mounted) {
          await controller.dispose();
          return;
        }

        if (_cameraController != controller) {
          await controller.dispose();
          return;
        }

        setState(() {
          _isCameraInitialized = true;
        });
      } else {
        _showError('Kamera tidak ditemukan di perangkat ini.');
      }
    } catch (e) {
      _showError('Gagal menginisialisasi kamera: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitializingCamera = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<Uint8List> _compressImage(Uint8List bytes) async {
    try {
      // flutter_image_compress only supports Android and iOS.
      // Skip on other platforms (like Windows desktop) to prevent native channel crashes/hangs.
      if (!Platform.isAndroid && !Platform.isIOS) {
        debugPrint('[Compression] Platform not supported for flutter_image_compress. Skipping.');
        return bytes;
      }
      var result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1024,
        minHeight: 1024,
        quality: 70,
        format: CompressFormat.jpeg,
      ).timeout(const Duration(milliseconds: 1500));

      // Safety check for 2MB limit: do second pass if needed
      if (result.length > 2 * 1024 * 1024) {
        debugPrint('[Compression] Saved image still > 2MB (${result.length} bytes). Doing second pass.');
        result = await FlutterImageCompress.compressWithList(
          Uint8List.fromList(result),
          minWidth: 800,
          minHeight: 800,
          quality: 40,
          format: CompressFormat.jpeg,
        ).timeout(const Duration(milliseconds: 1500));
      }

      return Uint8List.fromList(result);
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return bytes;
    }
  }

  Future<void> _capturePhoto(PhotoProvider photoProv) async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _cameraController!.value.isTakingPicture) {
      return;
    }

    try {
      final XFile photo = await _cameraController!.takePicture();
      final bytes = await photo.readAsBytes();
      photoProv.setImageBytes(bytes);
      _closeCamera();
    } catch (e) {
      _showError('Gagal mengambil gambar: $e');
    }
  }

  void _closeCamera() {
    _cameraController?.dispose();
    _cameraController = null;
    if (mounted) {
      setState(() {
        _isCameraInitialized = false;
      });
    }
  }

  String? _getAnnotatedUrl(MealAnalysisResult? result) {
    if (result == null || result.images == null || result.images!.annotated.isEmpty) return null;
    final annotated = result.images!.annotated;
    if (annotated.startsWith('http')) return annotated;
    
    final detectionUrl = ApiService.photoUrl;
    if (detectionUrl.isEmpty) return null;
    
    final uri = Uri.parse(detectionUrl);
    String baseUrl;
    try {
      baseUrl = uri.origin;
    } catch (_) {
      baseUrl = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    }
    
    final cleanAnnotated = annotated.startsWith('/') ? annotated : '/$annotated';
    return '$baseUrl$cleanAnnotated';
  }

  Future<void> _runDetection(PhotoProvider photoProv) async {
    await photoProv.detectIngredients();
    if (!mounted) return;
    
    if (photoProv.responseText == "Gambar Tidak Tersimpan") {
      return;
    }
    
    if (photoProv.errorMessage != null || !photoProv.isMealDetected) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.error_outline, color: AppColors.error),
              SizedBox(width: 8),
              Text('Gagal'),
            ],
          ),
          content: Text(
            photoProv.errorMessage ?? 'Makanan tidak ditemukan. Silakan coba ambil foto dari sudut lain.',
            style: AppTextStyles.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      );
    } else {
      final meal = photoProv.analysisResult!.meal!;
      final confidence = meal.dishPrediction?.confidence ?? 0.0;
      final method = meal.portionEstimate?.method ?? '';
      if (confidence < 0.70 || method != 'reference_object') {
        await _showManualWeightDialog(context, photoProv);
      }
    }
  }

  Future<void> _showManualWeightDialog(BuildContext context, PhotoProvider photoProv) async {
    final TextEditingController controller = TextEditingController(
      text: (photoProv.analysisResult?.meal?.portionEstimate?.grams ?? 150.0).toStringAsFixed(0),
    );
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: const [
              Icon(Icons.scale_outlined, color: AppColors.primary),
              Text('Masukkan Berat Porsi'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimasi porsi otomatis kurang akurat karena confidence rendah atau reference object tidak terdeteksi. Silakan masukkan berat makanan secara manual.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Berat (gram)',
                    suffixText: 'g',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Masukkan berat porsi';
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final newWeight = double.parse(controller.text);
                  photoProv.updateAnalysisResult(newWeight);
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _showSessionSelection(BuildContext context, PhotoProvider photoProv) {
    if (context.read<ScheduleProvider>().isAddingLocked()) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: AppColors.error),
              SizedBox(width: 8),
              Text('Batas Terlampaui'),
            ],
          ),
          content: Text(
            'Kalori harian telah melampaui batas. Anda tidak dapat menambahkan makanan baru untuk hari ini.',
            style: AppTextStyles.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      );
      return;
    }

    final activeSessions = UserRepository.getSessionsForDate(DateTime.now());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (scrollCtx, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.divider,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        'Pilih Sesi Makan',
                        style: AppTextStyles.heading3,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Masukkan menu ini ke jadwal makan hari ini',
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: activeSessions.length + 1,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index < activeSessions.length) {
                              final sesi = activeSessions[index];
                              final label = UserRepository.getSessionLabel(sesi);
                              final emoji = UserRepository.getSessionEmoji(sesi);

                              IconData iconData = Icons.restaurant_outlined;
                              Color color = AppColors.primary;
                              if (sesi == 'sarapan') {
                                iconData = Icons.wb_sunny_outlined;
                                color = AppColors.fat;
                              } else if (sesi == 'makan_siang') {
                                iconData = Icons.lunch_dining_outlined;
                                color = AppColors.calories;
                              } else if (sesi == 'snack_sore') {
                                iconData = Icons.cookie_outlined;
                                color = AppColors.carbs;
                              } else if (sesi == 'makan_malam') {
                                iconData = Icons.nights_stay_outlined;
                                color = AppColors.protein;
                              }

                              return Container(
                                decoration: BoxDecoration(
                                  color: AppColors.scaffoldBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: color.withValues(alpha: 0.1),
                                    child: Icon(iconData, color: color),
                                  ),
                                  title: Text(label, style: AppTextStyles.labelLarge),
                                  subtitle: Text('$emoji Sesi aktif hari ini', style: AppTextStyles.bodySmall),
                                  trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                                  onTap: () async {
                                    Navigator.of(sheetContext).pop();
                                    await _addMealToSchedule(context, sesi, photoProv);
                                  },
                                ),
                              );
                            } else {
                              return Container(
                                decoration: BoxDecoration(
                                  color: AppColors.scaffoldBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                    child: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                                  ),
                                  title: Text(
                                    'Custom Sesi',
                                    style: AppTextStyles.labelLarge.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text('Tambahkan sesi makan baru buatanmu sendiri', style: AppTextStyles.bodySmall),
                                  trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
                                  onTap: () async {
                                    Navigator.of(sheetContext).pop();
                                    await _showCustomSessionDialog(context, photoProv);
                                  },
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showCustomSessionDialog(BuildContext context, PhotoProvider photoProv) async {
    final TextEditingController nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.add_box_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tambah Custom Sesi',
                  style: AppTextStyles.heading3,
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Masukkan nama sesi makan baru untuk ditambahkan pada hari ini dan seterusnya.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Nama Sesi',
                    hintText: 'Misal: Snack Malam',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama sesi tidak boleh kosong';
                    }
                    final name = value.trim().toLowerCase();
                    if (name == 'sarapan' || name == 'makan siang' || name == 'makan_siang' ||
                        name == 'snack sore' || name == 'snack_sore' || name == 'makan malam' || name == 'makan_malam') {
                      return 'Nama sesi sudah menjadi sesi default';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final name = nameController.text.trim();
                  final key = name.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
                  
                  final today = DateTime.now();
                  final current = UserRepository.getSessionsForDate(today);
                  if (!current.contains(key)) {
                    final updated = [...current, key];
                    await UserRepository.saveSessionsForDate(today, updated);
                  }
                  
                  if (dialogCtx.mounted) {
                    Navigator.of(dialogCtx).pop();
                    
                    // Add meal to this session
                    if (context.mounted) {
                      await _addMealToSchedule(context, key, photoProv);
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Tambah'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addMealToSchedule(
    BuildContext context,
    String sessionKey,
    PhotoProvider photoProv,
  ) async {
    final result = photoProv.analysisResult;
    if (result == null || result.meal == null) return;

    BuildContext? dialogContext;

    // Show loading indicator dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      },
    );

    bool isLoaderOpen = true;

    try {
      final dishLabel = result.meal!.dishPrediction?.label ?? 'Menu Sehat';
      // Format dish label: e.g. "fried_rice" -> "Fried Rice"
      final formattedDishLabel = dishLabel
          .split('_')
          .map((word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1)}'
              : '')
          .join(' ');

      // 1. Process and save ingredients to local database
      final mealItems = <MealItem>[];
      for (final ing in result.meal!.ingredients) {
        final name = ing.label;
        final grams = ing.grams;
        final nut = ing.nutrition;

        // Calculate nutrition per 100g based on actual grams
        double kaloriPer100g = 0;
        double proteinPer100g = 0;
        double lemakPer100g = 0;
        double karboPer100g = 0;

        if (nut != null && grams > 0) {
          kaloriPer100g = (nut.calories / grams) * 100;
          proteinPer100g = (nut.protein / grams) * 100;
          lemakPer100g = (nut.fat / grams) * 100;
          karboPer100g = (nut.carbs / grams) * 100;
        }

        // Check if ingredient exists, otherwise save it
        var existing = IngredientRepository.getByName(name);
        String ingId;
        if (existing == null) {
          ingId = const Uuid().v4();
          final newIng = Ingredient(
            id: ingId,
            nama: name,
            kaloriPer100g: kaloriPer100g,
            proteinPer100g: proteinPer100g,
            lemakPer100g: lemakPer100g,
            karboPer100g: karboPer100g,
            isCustom: true,
          );
          await IngredientRepository.save(newIng);
        } else {
          ingId = existing.id;
          // If existing is custom/empty, update its nutritional values
          if (existing.kaloriPer100g == 0 && kaloriPer100g > 0) {
            final updated = existing.copyWith(
              kaloriPer100g: kaloriPer100g,
              proteinPer100g: proteinPer100g,
              lemakPer100g: lemakPer100g,
              karboPer100g: karboPer100g,
            );
            await IngredientRepository.save(updated);
          }
        }

        mealItems.add(MealItem(
          ingredientId: ingId,
          ingredientNama: name,
          beratGram: grams,
          kalori: nut?.calories ?? 0,
          protein: nut?.protein ?? 0,
          lemak: nut?.fat ?? 0,
          karbo: nut?.carbs ?? 0,
        ));
      }

      // 2. Add hidden ingredients if they exist (assign dummy weights like 5g and 0 nutrition)
      for (final hiddenName in result.meal!.estimatedHiddenIngredients) {
        var existing = IngredientRepository.getByName(hiddenName);
        String ingId;
        if (existing == null) {
          ingId = const Uuid().v4();
          final newIng = Ingredient(
            id: hiddenName, // Use hiddenName or new uuid
            nama: hiddenName,
            kaloriPer100g: 0,
            proteinPer100g: 0,
            lemakPer100g: 0,
            karboPer100g: 0,
            isCustom: true,
          );
          await IngredientRepository.save(newIng);
          ingId = newIng.id;
        } else {
          ingId = existing.id;
        }
        mealItems.add(MealItem(
          ingredientId: ingId,
          ingredientNama: hiddenName,
          beratGram: 5,
          kalori: 0,
          protein: 0,
          lemak: 0,
          karbo: 0,
        ));
      }

      final scheduleId = const Uuid().v4();
      String? photoUrl;

      // Bypass network HTTP download of annotated image and use captured photo directly to avoid latency
      final Uint8List? finalImageBytes = photoProv.imageBytes;

      if (finalImageBytes != null) {
        try {
          final compressedBytes = await _compressImage(finalImageBytes);
          final mealPhotosDir = Directory('${HiveService.localDocumentsDirPath}/meal_photos');
          if (!await mealPhotosDir.exists()) {
            await mealPhotosDir.create(recursive: true);
          }
          final fileName = 'meal_$scheduleId.jpg';
          final absolutePath = '${mealPhotosDir.path}/$fileName';
          final file = File(absolutePath);
          await file.writeAsBytes(compressedBytes);
          photoUrl = 'meal_photos/$fileName';
        } catch (e) {
          debugPrint('Failed to save compressed image locally: $e');
        }
      }

      final annotatedUrl = _getAnnotatedUrl(result);
      photoUrl ??= annotatedUrl;

      // Create schedule (mark as eaten immediately since they photographed it)
      final schedule = MealSchedule(
        id: scheduleId,
        tanggal: DateTime.now(),
        sesi: sessionKey,
        namaMenu: formattedDishLabel,
        items: mealItems,
        status: 'eaten',
        photoUrl: photoUrl,
      );

      if (!context.mounted) {
        if (dialogContext != null && dialogContext!.mounted && isLoaderOpen) {
          Navigator.of(dialogContext!).pop();
          isLoaderOpen = false;
        }
        return;
      }
      // Call schedule provider to save and reload
      final scheduleProv = Provider.of<ScheduleProvider>(context, listen: false);
      final success = await scheduleProv.addMeal(schedule);

      if (dialogContext != null && dialogContext!.mounted && isLoaderOpen) {
        Navigator.of(dialogContext!).pop();
        isLoaderOpen = false;
      }

      // Show success or limit popup
      if (context.mounted) {
        if (success) {
          final sessionLabel = UserRepository.getSessionLabel(sessionKey);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$formattedDishLabel berhasil ditambahkan ke $sessionLabel!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          // Reset detection state
          photoProv.clearImage();
        } else {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: AppColors.error),
                  SizedBox(width: 8),
                  Text('Batas Terlampaui'),
                ],
              ),
              content: Text(
                'Kalori harian telah melampaui batas. Anda tidak dapat menambahkan makanan baru untuk hari ini.',
                style: AppTextStyles.bodyMedium,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK', style: TextStyle(color: AppColors.primary)),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (dialogContext != null && dialogContext!.mounted && isLoaderOpen) {
        Navigator.of(dialogContext!).pop();
        isLoaderOpen = false;
      }
      if (context.mounted) {
        _showError('Gagal menambahkan jadwal makan: $e');
      }
    }
  }

  Widget _buildMealDetailsWidget(MealAnalysisResult result, Map<String, dynamic>? inferenceResult) {
    final meal = result.meal!;
    final dishLabel = meal.dishPrediction?.label ?? 'Menu';
    final formattedDishLabel = dishLabel
        .split('_')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '')
        .join(' ');
    
    final total = result.nutritionTotal;
    final portion = meal.portionEstimate;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.divider),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (inferenceResult != null) ...[
              _buildInferenceBanner(inferenceResult),
              const SizedBox(height: 16),
            ],
            if (meal.ingredients.length > 5) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Piring memiliki variasi bahan tinggi, hasil estimasi kalori mungkin kurang akurat',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Header: Dish label and confidence match percentage
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formattedDishLabel,
                        style: AppTextStyles.heading2,
                      ),
                      if (portion != null)
                        Text(
                          'Estimasi Porsi: ${portion.size.toUpperCase()} (${portion.grams.toStringAsFixed(0)}g)',
                          style: AppTextStyles.bodySmall,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${((meal.dishPrediction?.confidence ?? 0.0) * 100).toStringAsFixed(0)}% Match',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32, color: AppColors.divider),

            // Total Nutrition Section
            if (total != null) ...[
              Text(
                'Total Nutrisi Hidangan',
                style: AppTextStyles.heading3.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNutritionCircle(
                    value: total.calories.toStringAsFixed(0),
                    unit: 'kkal',
                    label: 'Kalori',
                    color: AppColors.calories,
                  ),
                  _buildNutritionCircle(
                    value: total.protein.toStringAsFixed(1),
                    unit: 'g',
                    label: 'Protein',
                    color: AppColors.protein,
                  ),
                  _buildNutritionCircle(
                    value: total.fat.toStringAsFixed(1),
                    unit: 'g',
                    label: 'Lemak',
                    color: AppColors.fat,
                  ),
                  _buildNutritionCircle(
                    value: total.carbs.toStringAsFixed(1),
                    unit: 'g',
                    label: 'Karbo',
                    color: AppColors.carbs,
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Ingredients List Section
            Text(
              'Bahan Terdeteksi & Nutrisi',
              style: AppTextStyles.heading3.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: meal.ingredients.length,
              separatorBuilder: (context, index) => const Divider(height: 16, color: AppColors.divider),
              itemBuilder: (context, index) {
                final ing = meal.ingredients[index];
                final ingName = ing.label
                    .split('_')
                    .map((word) => word.isNotEmpty
                        ? '${word[0].toUpperCase()}${word.substring(1)}'
                        : '')
                    .join(' ');
                final nut = ing.nutrition;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ingName,
                          style: AppTextStyles.labelLarge,
                        ),
                        Text(
                          '${ing.grams.toStringAsFixed(0)}g',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (nut != null)
                      Row(
                        children: [
                          _buildMiniNutriTag('Kalori: ${nut.calories.toStringAsFixed(0)} kkal', AppColors.calories),
                          const SizedBox(width: 6),
                          _buildMiniNutriTag('P: ${nut.protein.toStringAsFixed(1)}g', AppColors.protein),
                          const SizedBox(width: 6),
                          _buildMiniNutriTag('L: ${nut.fat.toStringAsFixed(1)}g', AppColors.fat),
                          const SizedBox(width: 6),
                          _buildMiniNutriTag('K: ${nut.carbs.toStringAsFixed(1)}g', AppColors.carbs),
                        ],
                      ),
                  ],
                );
              },
            ),

            // Hidden ingredients estimate
            if (meal.estimatedHiddenIngredients.isNotEmpty) ...[
              const Divider(height: 32, color: AppColors.divider),
              Text(
                'Estimasi Bumbu/Bahan Tersembunyi',
                style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: meal.estimatedHiddenIngredients.map((hidden) {
                  final formattedHidden = hidden
                      .split('_')
                      .map((word) => word.isNotEmpty
                          ? '${word[0].toUpperCase()}${word.substring(1)}'
                          : '')
                      .join(' ');
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Text(
                      formattedHidden,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInferenceBanner(Map<String, dynamic> inferenceResult) {
    final decision = inferenceResult['decision'];
    final message = inferenceResult['message'] ?? '';
    final detail = inferenceResult['detail'] ?? '';

    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;

    switch (decision) {
      case 'TOLAK':
        bgColor = AppColors.error.withValues(alpha: 0.08);
        borderColor = AppColors.error.withValues(alpha: 0.3);
        textColor = AppColors.error;
        icon = Icons.dangerous_outlined;
        break;
      case 'PERINGATAN':
        bgColor = AppColors.warning.withValues(alpha: 0.08);
        borderColor = AppColors.warning.withValues(alpha: 0.3);
        textColor = AppColors.warning;
        icon = Icons.warning_amber_rounded;
        break;
      case 'TERIMA':
      default:
        bgColor = AppColors.success.withValues(alpha: 0.08);
        borderColor = AppColors.success.withValues(alpha: 0.3);
        textColor = AppColors.success;
        icon = Icons.check_circle_outline;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: textColor.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: textColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  detail,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsWidget(MealAnalysisResult result) {
    if (result.recommendations.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.divider),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wb_incandescent_outlined, color: AppColors.warning, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Rekomendasi & Analisis',
                  style: AppTextStyles.heading3.copyWith(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...result.recommendations.map((rec) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        child: const Icon(
                          Icons.check_circle_outline,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          rec,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            if (result.explanation.isNotEmpty) ...[
              const Divider(height: 24, color: AppColors.divider),
              Text(
                'Analisis Detail:',
                style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                result.explanation,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionCircle({
    required String value,
    required String unit,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.08),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: AppTextStyles.labelLarge.copyWith(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 10,
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
    return Consumer<PhotoProvider>(
      builder: (context, photoProv, _) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Deteksi Makanan', style: AppTextStyles.heading2),
                const SizedBox(height: 4),
                Text('Ambil foto makanan untuk menganalisis nutrisinya',
                    style: AppTextStyles.bodySmall),
                const SizedBox(height: 20),
                if (photoProv.responseText == "Gambar Tidak Tersimpan") ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBC02D),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFBC02D).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded, color: Colors.black87, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Gambar Tidak Tersimpan',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // If camera is initialized, show live preview & shutter button
                if (_isCameraInitialized) ...[
                  Container(
                    width: double.infinity,
                    height: 420,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: _cameraController != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: 1,
                                height: _cameraController!.value.aspectRatio,
                                child: CameraPreview(_cameraController!),
                              ),
                            ),
                          )
                        : const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: SizedBox(
                      width: 200,
                      child: ElevatedButton.icon(
                        onPressed: () => _capturePhoto(photoProv),
                        icon: const Icon(Icons.camera, size: 18),
                        label: const Text('Ambil Foto'),
                      ),
                    ),
                  ),
                ] else if (photoProv.imageBytes != null) ...[
                  // 1. Food Image Section (Annotated or Original)
                  const Text(
                    "Hasil Foto Makanan:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Builder(
                      builder: (context) {
                        final annotatedUrl = _getAnnotatedUrl(photoProv.analysisResult);
                        if (annotatedUrl != null) {
                          return Image.network(
                            annotatedUrl,
                            height: 300,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 300,
                                color: AppColors.surfaceVariant,
                                child: const Center(
                                  child: CircularProgressIndicator(color: AppColors.primary),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Image.memory(
                                photoProv.imageBytes!,
                                height: 300,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              );
                            },
                          );
                        } else {
                          return Image.memory(
                            photoProv.imageBytes!,
                            height: 300,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. Loading State / Results Display
                  if (photoProv.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Menganalisis nutrisi makanan...',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (photoProv.isMealDetected) ...[
                    Builder(
                      builder: (context) {
                        final result = photoProv.analysisResult!;
                        final meal = result.meal!;
                        final allIngs = [
                          ...meal.ingredients.map((i) => i.label),
                          ...meal.estimatedHiddenIngredients,
                        ];
                        final calories = result.nutritionTotal?.calories ?? 0.0;
                        final userProv = context.watch<UserProvider>();
                        final profile = userProv.profile;
                        final targetKalori = userProv.targetKalori;
                        final dashProv = context.watch<DashboardProvider>();
                        final todayMeals = dashProv.todayMeals;

                        Map<String, dynamic>? inferenceResult;
                        if (profile != null) {
                          inferenceResult = RuleEngineService.instance.evaluasiInferensi(
                            ingredients: allIngs,
                            calories: calories,
                            profile: profile,
                            targetKalori: targetKalori,
                            todayMeals: todayMeals,
                          );
                        }

                        final isAllergic = inferenceResult?['decision'] == 'TOLAK';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Widget 1: Detailed ingredients & macros
                            _buildMealDetailsWidget(result, inferenceResult),
                            
                            // Widget 2: Goal suggestions & recommendations
                            _buildRecommendationsWidget(result),

                            // Action buttons
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: isAllergic 
                                    ? null 
                                    : () => _showSessionSelection(context, photoProv),
                                icon: Icon(isAllergic ? Icons.block : Icons.add, size: 18),
                                label: Text(isAllergic 
                                    ? 'Ditolak: Mengandung Alergen' 
                                    : 'Tambah ke Jadwal Makan'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.textOnPrimary,
                                  disabledBackgroundColor: Colors.grey[300],
                                  disabledForegroundColor: Colors.grey[600],
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        );
                      }
                    ),
                  ] else ...[
                    // If image is picked but not analyzed yet
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _runDetection(photoProv),
                        icon: const Icon(Icons.analytics_outlined, size: 18),
                        label: const Text('Mulai Deteksi Makanan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.calories,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Options to Retake / Clear
                  if (!photoProv.isLoading)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              photoProv.clearImage();
                              _initializeCamera();
                            },
                            icon: const Icon(Icons.camera_alt, size: 16),
                            label: const Text('Ambil Ulang'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => photoProv.clearImage(),
                            icon: const Icon(Icons.delete_outline, size: 16),
                            label: const Text('Hapus Foto'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ] else ...[
                  // Default state when no photo is loaded and camera is not active
                  Container(
                    width: double.infinity,
                    height: 420,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _isInitializingCamera
                            ? const CircularProgressIndicator(
                                color: AppColors.primary,
                              )
                            : Icon(Icons.camera_alt_outlined,
                                size: 56, color: AppColors.textLight),
                        const SizedBox(height: 8),
                        Text(
                          _isInitializingCamera
                              ? 'Membuka kamera...'
                              : 'Ambil atau pilih foto makanan',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isInitializingCamera
                              ? null
                              : () {
                                  photoProv.clearImage();
                                  _initializeCamera();
                                },
                          icon: const Icon(Icons.camera_alt, size: 18),
                          label: const Text('Kamera'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isInitializingCamera
                              ? null
                              : () {
                                  _closeCamera();
                                  photoProv.pickFromGallery();
                                },
                          icon: const Icon(Icons.photo_library, size: 18),
                          label: const Text('Galeri'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
