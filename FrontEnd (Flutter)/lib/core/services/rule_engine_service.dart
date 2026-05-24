import 'dart:math';
import '../../data/models/user_profile.dart';
import '../../data/models/meal_schedule.dart';
import '../../core/constants/app_constants.dart';

class RuleEngineService {
  RuleEngineService._();

  static final RuleEngineService instance = RuleEngineService._();

  /// Menghitung durasi jeda pencernaan (LAMA_WAKTU) secara dinamis
  /// Aturan 2: Base 4 jam, disesuaikan berdasarkan gender dan umur
  Duration hitungLamaWaktu(UserProfile profile) {
    int minutes = 4 * 60; // Base 4 jam (240 menit)
    if (profile.gender.toLowerCase() == 'wanita') {
      minutes += 30; // Wanita +30 menit
    }
    if (profile.umur > 50) {
      minutes += 30; // Umur > 50 tahun +30 menit
    } else if (profile.umur < 18) {
      minutes -= 30; // Umur < 18 tahun -30 menit
    }
    return Duration(minutes: minutes);
  }

  /// Mendapatkan waktu default terjadwal untuk sesi tertentu pada tanggal tertentu
  DateTime getSessionDefaultTime(DateTime date, String session, UserProfile profile) {
    String hourStr = '12:00';
    switch (session) {
      case 'sarapan':
        hourStr = profile.jamSarapan;
        break;
      case 'makan_siang':
        hourStr = profile.jamMakanSiang;
        break;
      case 'snack_sore':
        hourStr = '16:00'; // Default Snack Sore
        break;
      case 'makan_malam':
        hourStr = profile.jamMakanMalam;
        break;
    }

    final parts = hourStr.split(':');
    final hour = int.tryParse(parts[0]) ?? 12;
    final minute = int.tryParse(parts[1]) ?? 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// Menghitung jadwal makan yang disesuaikan secara dinamis (Rule 2)
  Map<String, DateTime> hitungSchedulesHariIni(UserProfile profile, List<MealSchedule> meals, DateTime date) {
    final sessions = AppConstants.mealSessions;
    final scheduledTimes = <String, DateTime>{};

    // 1. Tentukan waktu default awal
    for (final session in sessions) {
      scheduledTimes[session] = getSessionDefaultTime(date, session, profile);
    }

    // 2. Sesuaikan jadwal berikutnya jika ada makan yang telat > 2 jam (Aturan 2)
    final lamaWaktu = hitungLamaWaktu(profile);

    for (int i = 0; i < sessions.length; i++) {
      final currentSession = sessions[i];
      final sessionMeals = meals.where((m) => m.sesi == currentSession).toList();
      
      if (sessionMeals.isNotEmpty) {
        final meal = sessionMeals.first;
        // Gunakan actualTime jika sudah dimakan, jika tidak gunakan scheduledTime di database atau default
        final actualTime = meal.status == 'eaten' ? meal.actualTime : null;
        final baseSchedTime = meal.scheduledTime ?? scheduledTimes[currentSession]!;
        scheduledTimes[currentSession] = baseSchedTime;

        if (actualTime != null) {
          final diff = actualTime.difference(baseSchedTime);
          if (diff > const Duration(hours: 2)) {
            // Geser semua sesi setelah sesi ini
            DateTime lastActual = actualTime;
            for (int j = i + 1; j < sessions.length; j++) {
              final nextSession = sessions[j];
              final nextOriginalSched = scheduledTimes[nextSession]!;
              final minTime = lastActual.add(lamaWaktu);

              if (nextOriginalSched.isBefore(minTime)) {
                scheduledTimes[nextSession] = minTime;
                lastActual = minTime;
              } else {
                lastActual = nextOriginalSched;
              }
            }
          }
        }
      }
    }

    return scheduledTimes;
  }

  /// Mendapatkan batas kalori sesi tertentu berdasarkan aturan nutrisi
  double dapatkanBatasKaloriSesi(
    String session, 
    UserProfile profile, 
    List<MealSchedule> todayMeals, 
    double targetKalori, 
    double targetTdee
  ) {
    final now = DateTime.now();

    // Hitung total kalori yang dikonsumsi hari ini dari makanan yang berstatus 'eaten'
    final eatenMeals = todayMeals.where((m) => m.status == 'eaten').toList();
    final totalKaloriEaten = eatenMeals.fold(0.0, (sum, m) => sum + m.totalKalori);
    final sisaKaloriHarian = max(0.0, targetKalori - totalKaloriEaten);

    // Aturan 3: Makan Malam dekat jam tidur (Bedtime - 2 jam)
    if (session == 'makan_malam') {
      final parts = profile.jamTidur.split(':');
      final hour = int.tryParse(parts[0]) ?? 22;
      final minute = int.tryParse(parts[1]) ?? 0;
      final bedtime = DateTime(now.year, now.month, now.day, hour, minute);
      final bedLimitTime = bedtime.subtract(const Duration(hours: 2));

      if (now.isAfter(bedLimitTime)) {
        return min(sisaKaloriHarian, targetTdee * 0.15);
      }
    }

    // Aturan 6: Waktu < 14:00 (setelah makan siang) tapi total kalori > 80% target
    if (session == 'makan_malam' && now.hour < 14) {
      if (totalKaloriEaten > (targetKalori * 0.80)) {
        return targetTdee * 0.10; // porsi kecil (maksimal 10% TDEE)
      }
    }

    // Aturan 5: Jika Snack Sore direkomendasikan, set makan malam menjadi rendah kalori (maksimal 15% TDEE atau sisa kalori)
    if (session == 'makan_malam') {
      final hasSnackSore = todayMeals.any((m) => m.sesi == 'snack_sore' && m.status != 'canceled');
      if (hasSnackSore) {
        return min(sisaKaloriHarian, targetTdee * 0.15);
      }
    }

    return sisaKaloriHarian;
  }

  /// Menghasilkan daftar peringatan/alert berdasarkan kondisi harian user
  List<String> dapatkanPeringatanHarian(
    UserProfile profile, 
    List<MealSchedule> todayMeals, 
    double targetKalori, 
    double targetTdee
  ) {
    final alerts = <String>[];
    final now = DateTime.now();

    // Hitung nutrisi hari ini (hanya yang sudah 'eaten')
    final eatenMeals = todayMeals.where((m) => m.status == 'eaten').toList();
    final totalKaloriEaten = eatenMeals.fold(0.0, (sum, m) => sum + m.totalKalori);
    final totalProteinEaten = eatenMeals.fold(0.0, (sum, m) => sum + m.totalProtein);
    final totalKarboEaten = eatenMeals.fold(0.0, (sum, m) => sum + m.totalKarbo);

    // Aturan 7: Kalori Terlampaui
    if (totalKaloriEaten >= targetKalori && targetKalori > 0) {
      alerts.add("🚨 Kalori harian telah melampaui batas target harian Anda!");
    }

    // Hitung jadwal dinamis untuk cek keterlambatan makan
    final scheduledTimes = hitungSchedulesHariIni(profile, todayMeals, now);

    // Aturan 1: Telat makan > 1 jam AND belum makan (masih 'scheduled')
    for (final session in AppConstants.mealSessions) {
      final mealsInSession = todayMeals.where((m) => m.sesi == session).toList();
      final targetTime = scheduledTimes[session] ?? getSessionDefaultTime(now, session, profile);
      
      // Jika sesi ini terjadwal tapi belum makan dan telat > 1 jam
      final isSessionScheduledAndNotEaten = mealsInSession.any((m) => m.status == 'scheduled');
      if (isSessionScheduledAndNotEaten && now.difference(targetTime) > const Duration(hours: 1)) {
        final label = AppConstants.mealSessionLabels[session] ?? session;
        alerts.add("⚠️ Anda terlambat makan $label lebih dari 1 jam. Segera konsumsi makanan Anda!");
      }
    }

    // Aturan 3: Makan malam dekat jam tidur (Bedtime - 2 jam)
    final bedtimeParts = profile.jamTidur.split(':');
    final bedtimeHour = int.tryParse(bedtimeParts[0]) ?? 22;
    final bedtimeMinute = int.tryParse(bedtimeParts[1]) ?? 0;
    final bedtime = DateTime(now.year, now.month, now.day, bedtimeHour, bedtimeMinute);
    final bedLimitTime = bedtime.subtract(const Duration(hours: 2));

    final hasDinnerEaten = todayMeals.any((m) => m.sesi == 'makan_malam' && m.status == 'eaten');
    if (!hasDinnerEaten && now.isAfter(bedLimitTime) && now.isBefore(bedtime)) {
      alerts.add("🌙 Sudah mendekati waktu tidur. Makan malam dibatasi maksimal ${(targetTdee * 0.15).toStringAsFixed(0)} kkal dan pilihlah makanan yang mudah dicerna.");
    }

    // Aturan 5: Snack Sore otomatis (15:00 - 17:00 dan belum makan siang)
    final hasEatenLunch = todayMeals.any((m) => m.sesi == 'makan_siang' && m.status == 'eaten');
    if (now.hour >= 15 && now.hour < 17) {
      if (!hasEatenLunch) {
        final hasSnack = todayMeals.any((m) => m.sesi == 'snack_sore');
        if (!hasSnack) {
          alerts.add("🍰 Anda belum makan siang hingga sore hari. Jadwal 'Snack Sore' ditambahkan sebagai pengganti porsi makan siang Anda.");
        }
      }
    }

    // Jika Snack Sore aktif dan makan malam belum dikonsumsi, ingatkan batas rendah kalori untuk makan malam
    final hasSnackSoreActive = todayMeals.any((m) => m.sesi == 'snack_sore' && m.status != 'canceled');
    if (hasSnackSoreActive) {
      final hasDinnerEaten = todayMeals.any((m) => m.sesi == 'makan_malam' && m.status == 'eaten');
      if (!hasDinnerEaten) {
        alerts.add("🌙 Karena sesi Snack Sore aktif, porsi makan malam Anda dibatasi maksimal ${(targetTdee * 0.15).toStringAsFixed(0)} kkal (rendah kalori).");
      }
    }

    // Aturan 6: Kalori > 80% sebelum jam 14:00
    if (now.hour < 14 && totalKaloriEaten > (targetKalori * 0.80)) {
      alerts.add("🥗 Asupan kalori Anda hari ini sangat tinggi sebelum jam 14.00. Porsi makan malam Anda dibatasi maksimal ${(targetTdee * 0.10).toStringAsFixed(0)} kkal (salad atau sup sangat direkomendasikan).");
    }

    // Aturan 10: Defisit protein di malam hari (waktu malam >= 18:00)
    final proteinRequired = 0.8 * profile.beratBadan;
    if (now.hour >= 18 && totalProteinEaten < proteinRequired) {
      alerts.add("🥚 Asupan protein Anda masih kurang dari target minimum (${proteinRequired.toStringAsFixed(1)}g). Pilihlah makan malam tinggi protein seperti dada ayam, telur, atau tempe.");
    }

    // Aturan 11: Karbohidrat dikunci pada target cutting
    if (profile.targetDiet == 'cutting' && totalKaloriEaten > 0) {
      final batasKarbo = 0.35 * totalKaloriEaten / 4;
      if (totalKarboEaten >= batasKarbo) {
        alerts.add("🚫 Batas karbohidrat Anda untuk diet cutting hari ini telah tercapai. Karbohidrat dikunci untuk sisa hari ini.");
      }
    }

    return alerts;
  }

  /// Dictionary translasi alergi pintar untuk mendukung masukan multibahasa (Indonesian <-> English)
  static const Map<String, List<String>> _allergyTranslations = {
    'kacang': ['peanut', 'nut', 'almond', 'cashew', 'hazelnut', 'legume'],
    'telur': ['egg'],
    'udang': ['shrimp', 'prawn'],
    'susu': ['milk', 'dairy', 'cheese', 'yogurt', 'butter'],
    'terigu': ['wheat', 'gluten', 'flour'],
    'gandum': ['wheat', 'gluten', 'oat'],
    'seafood': ['shrimp', 'prawn', 'crab', 'lobster', 'fish', 'octopus', 'squid', 'clam', 'mussel'],
    'makanan laut': ['shrimp', 'prawn', 'crab', 'lobster', 'fish', 'octopus', 'squid', 'clam', 'mussel'],
    'ikan': ['fish', 'salmon', 'tuna'],
    'kedelai': ['soy', 'tofu', 'tempeh', 'edamame'],
    'kacang tanah': ['peanut'],
  };

  /// Memvalidasi persinggungan alergi secara case-insensitive dan mendalam (menggunakan terjemahan dasar)
  bool _checkAllergyIntersection(List<String> ingredients, List<String> allergies, List<String> matchedAllergies) {
    for (final ingredient in ingredients) {
      final normIng = ingredient.replaceAll('_', ' ').toLowerCase().trim();
      for (final allergy in allergies) {
        final normAllergy = allergy.replaceAll('_', ' ').toLowerCase().trim();
        if (normAllergy.isEmpty) continue;

        // 1. Pencocokan langsung (case-insensitive contains)
        if (normIng.contains(normAllergy) || normAllergy.contains(normIng)) {
          if (!matchedAllergies.contains(allergy)) {
            matchedAllergies.add(allergy);
          }
          continue;
        }

        // 2. Pencocokan melalui kamus translasi pintar
        bool matched = false;
        _allergyTranslations.forEach((key, translations) {
          if (normAllergy.contains(key) || key.contains(normAllergy)) {
            for (final trans in translations) {
              if (normIng.contains(trans) || trans.contains(normIng)) {
                matched = true;
              }
            }
          }
        });

        if (matched) {
          if (!matchedAllergies.contains(allergy)) {
            matchedAllergies.add(allergy);
          }
        }
      }
    }
    return matchedAllergies.isNotEmpty;
  }

  /// Mengevaluasi keputusan inferensi berdasarkan kecocokan alergi dan sisa kalori harian
  /// Mengembalikan Map yang berisi status keputusan ('TOLAK', 'TERIMA', atau 'PERINGATAN') dan pesan visualnya.
  Map<String, dynamic> evaluasiInferensi({
    required List<String> ingredients,
    required double calories,
    required UserProfile profile,
    required double targetKalori,
    required List<MealSchedule> todayMeals,
  }) {
    // 1. Hitung sisa kalori harian
    final eatenMeals = todayMeals.where((m) => m.status == 'eaten').toList();
    final totalKaloriEaten = eatenMeals.fold(0.0, (sum, m) => sum + m.totalKalori);
    final sisaKaloriHarian = targetKalori - totalKaloriEaten;

    // 2. Cek persinggungan alergi (Ingredients INTERSECT User_Data.Allergies)
    final matchedAllergies = <String>[];
    final hasAllergy = _checkAllergyIntersection(ingredients, profile.pantangan, matchedAllergies);

    if (hasAllergy) {
      return {
        'decision': 'TOLAK',
        'message': 'TOLAK: Peringatan Bahaya Alergi!',
        'detail': 'Bahan terdeteksi mengandung alergen yang Anda hindari: ${matchedAllergies.join(", ")}.',
        'allergies': matchedAllergies,
      };
    } else if (calories <= (sisaKaloriHarian + 100)) {
      return {
        'decision': 'TERIMA',
        'message': 'TERIMA: Tambahkan ke Jadwal',
        'detail': 'Kalori hidangan (${calories.toStringAsFixed(0)} kkal) sesuai dengan sisa target kalori harian Anda.',
        'allergies': <String>[],
      };
    } else {
      return {
        'decision': 'PERINGATAN',
        'message': 'PERINGATAN: Melebihi Target Kalori Harian',
        'detail': 'Porsi hidangan (${calories.toStringAsFixed(0)} kkal) melebihi sisa batas kalori harian Anda (${sisaKaloriHarian.toStringAsFixed(0)} kkal + toleransi 100 kkal).',
        'allergies': <String>[],
      };
    }
  }
}
