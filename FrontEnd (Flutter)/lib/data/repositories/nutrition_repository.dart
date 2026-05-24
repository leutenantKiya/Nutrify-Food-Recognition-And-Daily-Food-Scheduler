import '../repositories/schedule_repository.dart';

class NutritionRepository {
  /// Hitung total nutrisi hari ini dari semua jadwal makan
  static Map<String, double> getDailyNutrition(DateTime date) {
    final meals = ScheduleRepository.getByDate(date);
    double totalKalori = 0;
    double totalProtein = 0;
    double totalLemak = 0;
    double totalKarbo = 0;

    for (final meal in meals) {
      if (meal.status != 'eaten') continue;
      totalKalori += meal.totalKalori;
      totalProtein += meal.totalProtein;
      totalLemak += meal.totalLemak;
      totalKarbo += meal.totalKarbo;
    }

    return {
      'kalori': totalKalori,
      'protein': totalProtein,
      'lemak': totalLemak,
      'karbo': totalKarbo,
    };
  }

  /// Hitung total nutrisi mingguan
  static Map<String, double> getWeeklyNutrition(DateTime startOfWeek) {
    final end = startOfWeek.add(const Duration(days: 6));
    final meals = ScheduleRepository.getByDateRange(startOfWeek, end);

    double totalKalori = 0;
    double totalProtein = 0;
    double totalLemak = 0;
    double totalKarbo = 0;

    for (final meal in meals) {
      if (meal.status != 'eaten') continue;
      totalKalori += meal.totalKalori;
      totalProtein += meal.totalProtein;
      totalLemak += meal.totalLemak;
      totalKarbo += meal.totalKarbo;
    }

    return {
      'kalori': totalKalori,
      'protein': totalProtein,
      'lemak': totalLemak,
      'karbo': totalKarbo,
    };
  }

  /// Rata-rata nutrisi harian dalam seminggu
  static Map<String, double> getWeeklyAverage(DateTime startOfWeek) {
    final weekly = getWeeklyNutrition(startOfWeek);
    return {
      'kalori': weekly['kalori']! / 7,
      'protein': weekly['protein']! / 7,
      'lemak': weekly['lemak']! / 7,
      'karbo': weekly['karbo']! / 7,
    };
  }
}
