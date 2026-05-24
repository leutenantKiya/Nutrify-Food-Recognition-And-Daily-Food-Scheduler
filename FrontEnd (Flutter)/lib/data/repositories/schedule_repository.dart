import '../../core/services/hive_service.dart';
import '../models/meal_schedule.dart';

class ScheduleRepository {
  static List<MealSchedule> getAll() {
    return HiveService.scheduleBox.values
        .map((e) => MealSchedule.fromMap(Map<dynamic, dynamic>.from(e)))
        .toList();
  }

  static List<MealSchedule> getByDate(DateTime date) {
    final all = getAll();
    return all.where((m) {
      return m.tanggal.year == date.year &&
          m.tanggal.month == date.month &&
          m.tanggal.day == date.day;
    }).toList();
  }

  static List<MealSchedule> getByDateRange(DateTime start, DateTime end) {
    final all = getAll();
    return all.where((m) {
      final d = DateTime(m.tanggal.year, m.tanggal.month, m.tanggal.day);
      final s = DateTime(start.year, start.month, start.day);
      final e = DateTime(end.year, end.month, end.day);
      return !d.isBefore(s) && !d.isAfter(e);
    }).toList();
  }

  static List<MealSchedule> getByDateAndSession(DateTime date, String sesi) {
    return getByDate(date).where((m) => m.sesi == sesi).toList();
  }

  static Future<void> save(MealSchedule schedule) async {
    await HiveService.scheduleBox.put(schedule.id, schedule.toMap());
  }

  static Future<void> delete(String id) async {
    await HiveService.scheduleBox.delete(id);
  }

  static Future<void> deleteByDate(DateTime date) async {
    final meals = getByDate(date);
    for (final meal in meals) {
      await HiveService.scheduleBox.delete(meal.id);
    }
  }
}
