/// Model untuk rekomendasi makanan yang di-parse dari AI response
class FoodRecommendation {
  final String namaMenu;
  final Map<String, String> ingredients; // nama -> berat (e.g., "nasi putih" -> "200g")
  final String sesiMakan;

  FoodRecommendation({
    required this.namaMenu,
    required this.ingredients,
    required this.sesiMakan,
  });

  Map<String, dynamic> toMap() {
    return {
      'namaMenu': namaMenu,
      'ingredients': ingredients,
      'sesiMakan': sesiMakan,
    };
  }

  factory FoodRecommendation.fromMap(Map<String, dynamic> map) {
    return FoodRecommendation(
      namaMenu: map['namaMenu'] ?? '',
      ingredients: Map<String, String>.from(map['ingredients'] ?? {}),
      sesiMakan: map['sesiMakan'] ?? '',
    );
  }
}

/// Parser untuk AI response tags
class AiResponseParser {
  AiResponseParser._();

  /// Parse tombol interaktif dari tag `<btn>...</btn>`
  static List<String> parseButtons(String response) {
    final btnRegex = RegExp(r'<btn>(.*?)<\/btn>', dotAll: true);
    final match = btnRegex.firstMatch(response);

    if (match == null) return [];

    final content = match.group(1)!.trim();
    final buttons = content
        .split('~')
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();

    return buttons;
  }

  /// Parse rekomendasi makanan dari tag `<Rekomendasi>...</Rekomendasi>`
  static List<FoodRecommendation> parseRekomendasi(String response) {
    final rekomendasiRegex =
        RegExp(r'<Rekomendasi>(.*?)<\/Rekomendasi>', dotAll: true);
    final match = rekomendasiRegex.firstMatch(response);

    if (match == null) return [];

    final content = match.group(1)!.trim();
    final List<FoodRecommendation> recommendations = [];

    // Pattern: (Nama Menu-{bahan1:berat, bahan2:berat}-Sesi Makan)
    final itemRegex = RegExp(r'\((.+?)-\{(.+?)\}-(.+?)\)');
    final items = itemRegex.allMatches(content);

    for (final item in items) {
      final namaMenu = item.group(1)!.trim();
      final ingredientStr = item.group(2)!.trim();
      final sesiMakan = item.group(3)!.trim();

      // Parse ingredients: "nasi putih:200g, ayam dada:150g"
      // atau "nasi putih:berat dalam gram" → ambil semua setelah ':' pertama
      final ingredients = <String, String>{};
      final parts = ingredientStr.split(',');
      for (final part in parts) {
        final colonIdx = part.trim().indexOf(':');
        if (colonIdx != -1) {
          final key = part.trim().substring(0, colonIdx).trim();
          final val = part.trim().substring(colonIdx + 1).trim();
          if (key.isNotEmpty) {
            ingredients[key] = val.isEmpty ? '-' : val;
          }
        }
      }

      recommendations.add(FoodRecommendation(
        namaMenu: namaMenu,
        ingredients: ingredients,
        sesiMakan: sesiMakan,
      ));
    }

    return recommendations;
  }

  /// Hapus semua tag dari response untuk ditampilkan sebagai teks biasa
  static String stripTags(String response) {
    String cleaned = response;
    cleaned = cleaned.replaceAll(
        RegExp(r'<btn>.*?<\/btn>', dotAll: true), '');
    cleaned = cleaned.replaceAll(
        RegExp(r'<Rekomendasi>.*?<\/Rekomendasi>', dotAll: true), '');
    cleaned = cleaned.trim();
    return cleaned;
  }

  /// Cek apakah response mengandung tombol
  static bool hasButtons(String response) {
    return RegExp(r'<btn>.*?<\/btn>', dotAll: true).hasMatch(response);
  }

  /// Cek apakah response mengandung rekomendasi
  static bool hasRekomendasi(String response) {
    return RegExp(r'<Rekomendasi>.*?<\/Rekomendasi>', dotAll: true)
        .hasMatch(response);
  }
}
