import 'package:flutter/material.dart';
import '../../data/repositories/nutrition_repository.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/models/meal_schedule.dart';

class DashboardProvider extends ChangeNotifier {
  DateTime _selectedDate = DateTime.now();
  Map<String, double> _dailyNutrition = {};
  List<MealSchedule> _todayMeals = [];
  List<String> _sessions = [];

  DateTime get selectedDate => _selectedDate;
  Map<String, double> get dailyNutrition => _dailyNutrition;
  List<MealSchedule> get todayMeals => _todayMeals;
  List<String> get sessions => _sessions;

  double get kaloriHariIni => _dailyNutrition['kalori'] ?? 0;
  double get proteinHariIni => _dailyNutrition['protein'] ?? 0;
  double get lemakHariIni => _dailyNutrition['lemak'] ?? 0;
  double get karboHariIni => _dailyNutrition['karbo'] ?? 0;

  void loadDashboard() {
    _dailyNutrition = NutritionRepository.getDailyNutrition(_selectedDate);
    _todayMeals = ScheduleRepository.getByDate(_selectedDate);
    _sessions = UserRepository.getSessionsForDate(_selectedDate);
    
    // Sort today's meals based on dynamic session order
    _todayMeals.sort((a, b) {
      final indexA = _sessions.indexOf(a.sesi);
      final indexB = _sessions.indexOf(b.sesi);
      if (indexA == -1 && indexB == -1) return 0;
      if (indexA == -1) return 1;
      if (indexB == -1) return -1;
      return indexA.compareTo(indexB);
    });
    
    notifyListeners();
  }

  void setDate(DateTime date) {
    _selectedDate = date;
    loadDashboard();
  }

  void refresh() {
    loadDashboard();
  }
}
