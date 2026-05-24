import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/api_service.dart';
import '../../data/models/meal_analysis_result.dart';
import '../../data/repositories/user_repository.dart';

class PhotoProvider extends ChangeNotifier {
  Uint8List? _imageBytes;
  bool _isLoading = false;
  String? _errorMessage;
  String _responseText = "Belum ada response";
  MealAnalysisResult? _analysisResult;

  Uint8List? get imageBytes => _imageBytes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get responseText => _responseText;
  MealAnalysisResult? get analysisResult => _analysisResult;

  // Check if a valid meal is detected
  bool get isMealDetected =>
      _analysisResult != null &&
      _analysisResult!.status.toLowerCase() == 'success' &&
      _analysisResult!.meal != null &&
      _analysisResult!.meal!.dishPrediction != null &&
      _analysisResult!.meal!.dishPrediction!.label.isNotEmpty;

  final ImagePicker _picker = ImagePicker();

  Future<void> pickFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (photo != null) {
        _imageBytes = await photo.readAsBytes();
        _analysisResult = null;
        _responseText = "Belum ada response";
        _errorMessage = null;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Gagal mengambil foto: $e';
      _responseText = 'Error: $e';
      notifyListeners();
    }
  }

  Future<void> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        _imageBytes = await image.readAsBytes();
        _analysisResult = null;
        _responseText = "Belum ada response";
        _errorMessage = null;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Gagal memilih gambar: $e';
      _responseText = 'Error: $e';
      notifyListeners();
    }
  }

  Future<void> detectIngredients() async {
    if (_imageBytes == null) return;

    _isLoading = true;
    _errorMessage = null;
    _responseText = "Mengompres & Menganalisis...";
    _analysisResult = null;
    notifyListeners();

    try {
      await Future(() async {
        // 1. Compression in background (native thread) if supported
        Uint8List compressedBytes = _imageBytes!;
        try {
          if (Platform.isAndroid || Platform.isIOS) {
            compressedBytes = await FlutterImageCompress.compressWithList(
              _imageBytes!,
              quality: 80,
              minWidth: 1024,
              minHeight: 1024,
            ).timeout(const Duration(milliseconds: 1500));

            // Safety check for 2MB limit: do second pass if needed
            if (compressedBytes.length > 2 * 1024 * 1024) {
              debugPrint('[Compression] Image still > 2MB (${compressedBytes.length} bytes). Doing second pass.');
              compressedBytes = await FlutterImageCompress.compressWithList(
                compressedBytes,
                quality: 50,
                minWidth: 800,
                minHeight: 800,
              ).timeout(const Duration(milliseconds: 1500));
            }
          } else {
            debugPrint('[Compression] Platform not supported for flutter_image_compress. Skipping.');
          }
        } catch (e) {
          debugPrint('Error compressing image: $e');
        }

        // 2. Upload to API
        final responseMap = await ApiService.uploadPhotoForDetection(
          imageBytes: compressedBytes,
        );
        
        final result = MealAnalysisResult.fromJson(responseMap);

        if (result.status.toLowerCase() != 'success' ||
            result.meal == null ||
            result.meal!.dishPrediction == null ||
            result.meal!.dishPrediction!.label.isEmpty) {
          _analysisResult = null;
          _errorMessage = 'Makanan Tidak Ditemukan';
          _responseText = 'Makanan Tidak Ditemukan';
        } else {
          _analysisResult = result;
          _responseText = 'Berhasil mendeteksi: ${result.meal!.dishPrediction!.label}';
          _errorMessage = null;

          final label = result.meal!.dishPrediction!.label;
          final originalGrams = result.meal!.portionEstimate?.grams ?? 0.0;
          final correctedGrams = UserRepository.correctWeight(label, originalGrams);
          if (correctedGrams != originalGrams) {
            updateAnalysisResult(correctedGrams);
          }
        }
      }).timeout(const Duration(seconds: 15));
    } catch (e) {
      if (e is TimeoutException || e.toString().contains('TimeoutException')) {
        _imageBytes = null; // "dan gambar Hilangkan"
        _analysisResult = null;
        _responseText = "Gambar Tidak Tersimpan"; // "indicator menjadi 'Gambar Tidak Tersimpan'"
        _errorMessage = "Waktu habis (lebih dari 15 detik)";
      } else {
        _errorMessage = e.toString();
        _responseText = 'Error: $e';
        _analysisResult = null;
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  void setImageBytes(Uint8List bytes) {
    _imageBytes = bytes;
    _analysisResult = null;
    _responseText = "Belum ada response";
    _errorMessage = null;
    notifyListeners();
  }

  void updateAnalysisResult(double newWeight) {
    if (_analysisResult == null || _analysisResult!.meal == null) return;
    final meal = _analysisResult!.meal!;
    final double oldWeight = meal.portionEstimate?.grams ?? 0.0;
    
    double ingredientSum = 0.0;
    for (var ing in meal.ingredients) {
      ingredientSum += ing.grams;
    }
    
    final double divisor = oldWeight > 0 ? oldWeight : (ingredientSum > 0 ? ingredientSum : 1.0);
    final double scale = newWeight / divisor;
    
    final int count = meal.ingredients.length;
    final updatedIngredients = meal.ingredients.map((ing) {
      double newGrams;
      double scaleForThisIng;
      if (ing.grams > 0) {
        newGrams = ing.grams * scale;
        scaleForThisIng = scale;
      } else {
        newGrams = count > 0 ? (newWeight / count) : 0.0;
        // Jika berat awal 0, asumsikan nutrisi di JSON adalah untuk 100g, maka skala = newGrams / 100
        scaleForThisIng = newGrams / 100.0;
      }

      NutritionInfo? newNutrition;
      if (ing.nutrition != null) {
        newNutrition = NutritionInfo(
          calories: ing.nutrition!.calories * scaleForThisIng,
          protein: ing.nutrition!.protein * scaleForThisIng,
          carbs: ing.nutrition!.carbs * scaleForThisIng,
          fat: ing.nutrition!.fat * scaleForThisIng,
          fiber: ing.nutrition!.fiber * scaleForThisIng,
        );
      }
      return IngredientAnalysis(
        label: ing.label,
        confidence: ing.confidence,
        grams: newGrams,
        source: ing.source,
        nutrition: newNutrition,
      );
    }).toList();
    
    NutritionInfo? newTotalNutrition;
    if (_analysisResult!.nutritionTotal != null) {
      final total = _analysisResult!.nutritionTotal!;
      newTotalNutrition = NutritionInfo(
        calories: total.calories * scale,
        protein: total.protein * scale,
        carbs: total.carbs * scale,
        fat: total.fat * scale,
        fiber: total.fiber * scale,
      );
    } else {
      // Re-calculate total nutrition by summing up ingredient nutrition
      double calories = 0;
      double protein = 0;
      double carbs = 0;
      double fat = 0;
      double fiber = 0;
      bool hasNutrition = false;
      for (var ing in updatedIngredients) {
        if (ing.nutrition != null) {
          hasNutrition = true;
          calories += ing.nutrition!.calories;
          protein += ing.nutrition!.protein;
          carbs += ing.nutrition!.carbs;
          fat += ing.nutrition!.fat;
          fiber += ing.nutrition!.fiber;
        }
      }
      if (hasNutrition) {
        newTotalNutrition = NutritionInfo(
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
          fiber: fiber,
        );
      }
    }
    
    final updatedMeal = MealDetails(
      dishPrediction: meal.dishPrediction,
      ingredients: updatedIngredients,
      estimatedHiddenIngredients: meal.estimatedHiddenIngredients,
      portionEstimate: PortionEstimate(
        size: meal.portionEstimate?.size ?? 'custom',
        grams: newWeight,
        areaCm2: meal.portionEstimate?.areaCm2 ?? 0.0,
        method: meal.portionEstimate?.method ?? 'manual',
      ),
    );
    
    _analysisResult = MealAnalysisResult(
      status: _analysisResult!.status,
      meal: updatedMeal,
      nutritionTotal: newTotalNutrition,
      goalAnalysis: _analysisResult!.goalAnalysis,
      recommendations: _analysisResult!.recommendations,
      detailedSuggestions: _analysisResult!.detailedSuggestions,
      explanation: _analysisResult!.explanation,
      images: _analysisResult!.images,
    );
    
    notifyListeners();
  }

  void clearImage() {
    _imageBytes = null;
    _analysisResult = null;
    _responseText = "Belum ada response";
    _errorMessage = null;
    notifyListeners();
  }
}
