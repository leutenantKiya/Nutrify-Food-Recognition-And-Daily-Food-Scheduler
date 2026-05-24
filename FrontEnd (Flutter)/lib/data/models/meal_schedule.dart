import '../repositories/ingredient_repository.dart';

class MealItem {
  final String ingredientId;
  final String ingredientNama;
  final double beratGram;
  final double kalori;
  final double protein;
  final double lemak;
  final double karbo;

  MealItem({
    required this.ingredientId,
    required this.ingredientNama,
    required this.beratGram,
    required this.kalori,
    required this.protein,
    required this.lemak,
    required this.karbo,
  });

  double get effectiveKalori {
    final ing = IngredientRepository.getById(ingredientId) ??
        IngredientRepository.getByName(ingredientNama);
    if (ing != null) {
      return ing.kaloriForWeight(beratGram);
    }
    return kalori;
  }

  double get effectiveProtein {
    final ing = IngredientRepository.getById(ingredientId) ??
        IngredientRepository.getByName(ingredientNama);
    if (ing != null) {
      return ing.proteinForWeight(beratGram);
    }
    return protein;
  }

  double get effectiveLemak {
    final ing = IngredientRepository.getById(ingredientId) ??
        IngredientRepository.getByName(ingredientNama);
    if (ing != null) {
      return ing.lemakForWeight(beratGram);
    }
    return lemak;
  }

  double get effectiveKarbo {
    final ing = IngredientRepository.getById(ingredientId) ??
        IngredientRepository.getByName(ingredientNama);
    if (ing != null) {
      return ing.karboForWeight(beratGram);
    }
    return karbo;
  }

  Map<String, dynamic> toMap() {
    return {
      'ingredientId': ingredientId,
      'ingredientNama': ingredientNama,
      'beratGram': beratGram,
      'kalori': kalori,
      'protein': protein,
      'lemak': lemak,
      'karbo': karbo,
    };
  }

  factory MealItem.fromMap(Map<dynamic, dynamic> map) {
    return MealItem(
      ingredientId: map['ingredientId'] ?? '',
      ingredientNama: map['ingredientNama'] ?? '',
      beratGram: (map['beratGram'] ?? 0).toDouble(),
      kalori: (map['kalori'] ?? 0).toDouble(),
      protein: (map['protein'] ?? 0).toDouble(),
      lemak: (map['lemak'] ?? 0).toDouble(),
      karbo: (map['karbo'] ?? 0).toDouble(),
    );
  }
}

class MealSchedule {
  final String id;
  final DateTime tanggal;
  final String sesi; // 'sarapan', 'makan_siang', 'makan_malam'
  final String namaMenu;
  final List<MealItem> items;
  final String status; // 'scheduled', 'eaten', 'canceled'
  final String? photoUrl;
  final DateTime? actualTime;
  final DateTime? scheduledTime;

  MealSchedule({
    required this.id,
    required this.tanggal,
    required this.sesi,
    required this.namaMenu,
    required this.items,
    this.status = 'scheduled',
    this.photoUrl,
    this.actualTime,
    this.scheduledTime,
  });

  double get totalKalori => items.fold(0.0, (sum, item) => sum + item.effectiveKalori);
  double get totalProtein => items.fold(0.0, (sum, item) => sum + item.effectiveProtein);
  double get totalLemak => items.fold(0.0, (sum, item) => sum + item.effectiveLemak);
  double get totalKarbo => items.fold(0.0, (sum, item) => sum + item.effectiveKarbo);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tanggal': tanggal.toIso8601String(),
      'sesi': sesi,
      'namaMenu': namaMenu,
      'items': items.map((e) => e.toMap()).toList(),
      'status': status,
      'photoUrl': photoUrl,
      'actualTime': actualTime?.toIso8601String(),
      'scheduledTime': scheduledTime?.toIso8601String(),
    };
  }

  factory MealSchedule.fromMap(Map<dynamic, dynamic> map) {
    return MealSchedule(
      id: map['id'] ?? '',
      tanggal: DateTime.parse(map['tanggal']),
      sesi: map['sesi'] ?? 'sarapan',
      namaMenu: map['namaMenu'] ?? '',
      items: (map['items'] as List?)
              ?.map((e) => MealItem.fromMap(Map<dynamic, dynamic>.from(e)))
              .toList() ??
          [],
      status: map['status'] ?? 'scheduled',
      photoUrl: map['photoUrl'],
      actualTime: map['actualTime'] != null ? DateTime.parse(map['actualTime']) : null,
      scheduledTime: map['scheduledTime'] != null ? DateTime.parse(map['scheduledTime']) : null,
    );
  }

  MealSchedule copyWith({
    String? id,
    DateTime? tanggal,
    String? sesi,
    String? namaMenu,
    List<MealItem>? items,
    String? status,
    String? photoUrl,
    DateTime? actualTime,
    DateTime? scheduledTime,
  }) {
    return MealSchedule(
      id: id ?? this.id,
      tanggal: tanggal ?? this.tanggal,
      sesi: sesi ?? this.sesi,
      namaMenu: namaMenu ?? this.namaMenu,
      items: items ?? this.items,
      status: status ?? this.status,
      photoUrl: photoUrl ?? this.photoUrl,
      actualTime: actualTime ?? this.actualTime,
      scheduledTime: scheduledTime ?? this.scheduledTime,
    );
  }
}
