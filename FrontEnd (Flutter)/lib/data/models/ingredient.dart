class Ingredient {
  final String id;
  final String nama;
  final double kaloriPer100g;
  final double proteinPer100g;
  final double lemakPer100g;
  final double karboPer100g;
  final bool isCustom;
  final bool isAvoided;

  Ingredient({
    required this.id,
    required this.nama,
    required this.kaloriPer100g,
    required this.proteinPer100g,
    required this.lemakPer100g,
    required this.karboPer100g,
    this.isCustom = false,
    this.isAvoided = false,
  });

  /// Hitung nutrisi berdasarkan berat tertentu
  double kaloriForWeight(double gramWeight) =>
      (kaloriPer100g / 100) * gramWeight;
  double proteinForWeight(double gramWeight) =>
      (proteinPer100g / 100) * gramWeight;
  double lemakForWeight(double gramWeight) =>
      (lemakPer100g / 100) * gramWeight;
  double karboForWeight(double gramWeight) =>
      (karboPer100g / 100) * gramWeight;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'kaloriPer100g': kaloriPer100g,
      'proteinPer100g': proteinPer100g,
      'lemakPer100g': lemakPer100g,
      'karboPer100g': karboPer100g,
      'isCustom': isCustom,
      'isAvoided': isAvoided,
    };
  }

  factory Ingredient.fromMap(Map<dynamic, dynamic> map) {
    return Ingredient(
      id: map['id'] ?? '',
      nama: map['nama'] ?? '',
      kaloriPer100g: (map['kaloriPer100g'] ?? 0).toDouble(),
      proteinPer100g: (map['proteinPer100g'] ?? 0).toDouble(),
      lemakPer100g: (map['lemakPer100g'] ?? 0).toDouble(),
      karboPer100g: (map['karboPer100g'] ?? 0).toDouble(),
      isCustom: map['isCustom'] ?? false,
      isAvoided: map['isAvoided'] ?? false,
    );
  }

  Ingredient copyWith({
    String? id,
    String? nama,
    double? kaloriPer100g,
    double? proteinPer100g,
    double? lemakPer100g,
    double? karboPer100g,
    bool? isCustom,
    bool? isAvoided,
  }) {
    return Ingredient(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      kaloriPer100g: kaloriPer100g ?? this.kaloriPer100g,
      proteinPer100g: proteinPer100g ?? this.proteinPer100g,
      lemakPer100g: lemakPer100g ?? this.lemakPer100g,
      karboPer100g: karboPer100g ?? this.karboPer100g,
      isCustom: isCustom ?? this.isCustom,
      isAvoided: isAvoided ?? this.isAvoided,
    );
  }
}
