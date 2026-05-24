import 'dart:math' as math;
import '../../core/services/hive_service.dart';
import '../models/user_profile.dart';

class UserRepository {
  static UserProfile? getProfile() {
    final data = HiveService.userBox.get('profile');
    if (data == null) return null;
    return UserProfile.fromMap(Map<dynamic, dynamic>.from(data));
  }

  static Future<void> saveProfile(UserProfile profile) async {
    await HiveService.userBox.put('profile', profile.toMap());
  }

  static bool isOnboarded() {
    final data = HiveService.userBox.get('profile');
    if (data == null) return false;
    return data['isOnboarded'] == true;
  }

  static Future<void> clearProfile() async {
    await HiveService.userBox.delete('profile');
  }

  static List<String> getSessionsForDate(DateTime date) {
    final dateStr = _formatDateKey(date);
    final history = HiveService.userBox.get('sessions_history');
    if (history == null || history is! List) {
      return ['sarapan', 'makan_siang', 'snack_sore', 'makan_malam'];
    }
    
    String? bestDate;
    List<dynamic>? bestSessions;
    
    for (final item in history) {
      if (item is Map) {
        final d = item['date'] as String?;
        final s = item['sessions'] as List?;
        if (d != null && s != null) {
          if (d.compareTo(dateStr) <= 0) {
            if (bestDate == null || d.compareTo(bestDate) > 0) {
              bestDate = d;
              bestSessions = s;
            }
          }
        }
      }
    }
    
    if (bestSessions != null) {
      return List<String>.from(bestSessions);
    }
    return ['sarapan', 'makan_siang', 'snack_sore', 'makan_malam'];
  }

  static Future<void> saveSessionsForDate(DateTime date, List<String> sessions) async {
    final dateStr = _formatDateKey(date);
    final historyData = HiveService.userBox.get('sessions_history');
    List<Map<dynamic, dynamic>> history = [];
    if (historyData != null && historyData is List) {
      history = List<Map<dynamic, dynamic>>.from(
        historyData.map((e) => Map<dynamic, dynamic>.from(e as Map))
      );
    }
    
    final index = history.indexWhere((item) => item['date'] == dateStr);
    if (index != -1) {
      history[index]['sessions'] = sessions;
    } else {
      history.add({'date': dateStr, 'sessions': sessions});
    }
    
    await HiveService.userBox.put('sessions_history', history);
  }

  static String _formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static Map<String, double> getWeightCorrections() {
    final data = HiveService.userBox.get('weight_corrections');
    if (data == null || data is! Map) {
      return {
        'nasi goreng': 200.0,
        'mie instan': 150.0,
      };
    }
    return Map<String, double>.from(
      data.map((key, value) => MapEntry(key.toString(), (value as num).toDouble()))
    );
  }

  static Future<void> saveWeightCorrections(Map<String, double> corrections) async {
    await HiveService.userBox.put('weight_corrections', corrections);
  }

  static double correctWeight(String label, double scannedGrams) {
    final corrections = getWeightCorrections();
    final lowercaseLabel = label.trim().toLowerCase();
    
    double? minWeight;
    for (final entry in corrections.entries) {
      if (lowercaseLabel.contains(entry.key.trim().toLowerCase()) ||
          entry.key.trim().toLowerCase().contains(lowercaseLabel)) {
        minWeight = entry.value;
        break;
      }
    }
    
    if (minWeight == null) {
      return scannedGrams;
    }
    
    if (scannedGrams < minWeight) {
      final corrected = minWeight * (1.0 - math.exp(-0.15 * scannedGrams));
      return math.max(scannedGrams, corrected);
    }
    
    return scannedGrams;
  }

  static String getSessionLabel(String sessionKey) {
    final lowercaseKey = sessionKey.toLowerCase().trim();
    if (lowercaseKey == 'sarapan') return 'Sarapan';
    if (lowercaseKey == 'makan_siang') return 'Makan Siang';
    if (lowercaseKey == 'snack_sore') return 'Snack Sore';
    if (lowercaseKey == 'makan_malam') return 'Makan Malam';
    
    final words = sessionKey.split(RegExp(r'[-_ ]+'));
    return words.map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }

  static String getSessionEmoji(String sessionKey) {
    final lowercaseKey = sessionKey.toLowerCase().trim();
    if (lowercaseKey == 'sarapan') return '🌅';
    if (lowercaseKey == 'makan_siang') return '☀️';
    if (lowercaseKey == 'snack_sore') return '🍰';
    if (lowercaseKey == 'makan_malam') return '🌙';
    return '🍽️';
  }
}
