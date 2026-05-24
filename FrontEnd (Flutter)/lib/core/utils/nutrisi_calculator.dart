import '../constants/app_constants.dart';

class NutrisiCalculator {
  NutrisiCalculator._();

  /// Hitung BMR menggunakan Harris-Benedict Formula
  static double hitungBMR({
    required double beratKg,
    required double tinggiCm,
    required int umur,
    required String gender,
  }) {
    if (gender == 'pria') {
      return 88.362 + (13.397 * beratKg) + (4.799 * tinggiCm) - (5.677 * umur);
    } else {
      return 447.593 + (9.247 * beratKg) + (3.098 * tinggiCm) - (4.330 * umur);
    }
  }

  /// Hitung TDEE (Total Daily Energy Expenditure)
  static double hitungTDEE({
    required double bmr,
    required String aktivitas,
  }) {
    final multiplier = AppConstants.activityMultipliers[aktivitas] ?? 1.2;
    return bmr * multiplier;
  }

  /// Hitung target kalori berdasarkan diet goal
  static double hitungTargetKalori({
    required double tdee,
    required String targetDiet,
  }) {
    final adjustment = AppConstants.dietCalorieAdjustment[targetDiet] ?? 0;
    return tdee + adjustment;
  }

  /// Hitung kebutuhan macro (protein, lemak, karbohidrat) dalam gram
  static Map<String, double> hitungMacro({
    required double targetKalori,
    required String targetDiet,
  }) {
    final splits = AppConstants.macroSplits[targetDiet] ??
        AppConstants.macroSplits['maintain']!;

    // Protein: 4 kcal/gram
    // Fat: 9 kcal/gram
    // Carbs: 4 kcal/gram
    final proteinGram = (targetKalori * splits['protein']!) / 4;
    final lemakGram = (targetKalori * splits['fat']!) / 9;
    final karboGram = (targetKalori * splits['carbs']!) / 4;

    return {
      'protein': proteinGram,
      'lemak': lemakGram,
      'karbo': karboGram,
    };
  }

  /// Hitung semua nutrisi dari data user
  static Map<String, double> hitungSemuaNutrisi({
    required double beratKg,
    required double tinggiCm,
    required int umur,
    required String gender,
    required String aktivitas,
    required String targetDiet,
  }) {
    final bmr = hitungBMR(
      beratKg: beratKg,
      tinggiCm: tinggiCm,
      umur: umur,
      gender: gender,
    );

    final tdee = hitungTDEE(bmr: bmr, aktivitas: aktivitas);
    final targetKalori = hitungTargetKalori(
      tdee: tdee,
      targetDiet: targetDiet,
    );
    final macro = hitungMacro(
      targetKalori: targetKalori,
      targetDiet: targetDiet,
    );

    return {
      'bmr': bmr,
      'tdee': tdee,
      'targetKalori': targetKalori,
      'protein': macro['protein']!,
      'lemak': macro['lemak']!,
      'karbo': macro['karbo']!,
    };
  }
}
