class AppConstants {
  AppConstants._();

  // Hive Box Names
  static const String userBox = 'user_profile';
  static const String ingredientBox = 'ingredients';
  static const String scheduleBox = 'meal_schedules';
  static const String chatSessionBox = 'chat_sessions';
  static const String chatMessageBox = 'chat_messages';
  static const String secretBox = 'app_secrets';

  // Keys untuk secret box
  static const String keyHfApiKey = 'hf_api_key';
  static const String keyHfModelId = 'hf_model_id';
  static const String keyPhotoUrl = 'photo_url';
  static const String keyHfBaseUrl = 'hf_base_url';

  // Activity Multipliers (Harris-Benedict)
  static const Map<String, double> activityMultipliers = {
    'sedentary': 1.2,
    'ringan': 1.375,
    'sedang': 1.55,
    'aktif': 1.725,
    'sangat_aktif': 1.9,
  };

  // Activity Labels (Indonesian)
  static const Map<String, String> activityLabels = {
    'sedentary': 'Tidak Aktif (Duduk terus)',
    'ringan': 'Ringan (Olahraga 1-3x/minggu)',
    'sedang': 'Sedang (Olahraga 3-5x/minggu)',
    'aktif': 'Aktif (Olahraga 6-7x/minggu)',
    'sangat_aktif': 'Sangat Aktif (Atlet)',
  };

  // Diet Target Calorie Adjustments
  static const Map<String, int> dietCalorieAdjustment = {
    'cutting': -500,
    'maintain': 0,
    'bulking': 500,
  };

  // Macro Splits (percentage of total calories)
  static const Map<String, Map<String, double>> macroSplits = {
    'cutting': {'protein': 0.40, 'fat': 0.30, 'carbs': 0.30},
    'maintain': {'protein': 0.30, 'fat': 0.30, 'carbs': 0.40},
    'bulking': {'protein': 0.30, 'fat': 0.25, 'carbs': 0.45},
  };

  // Meal Sessions
  static const List<String> mealSessions = [
    'sarapan',
    'makan_siang',
    'snack_sore',
    'makan_malam',
  ];

  static const Map<String, String> mealSessionLabels = {
    'sarapan': 'Sarapan',
    'makan_siang': 'Makan Siang',
    'snack_sore': 'Snack Sore',
    'makan_malam': 'Makan Malam',
  };

  static const Map<String, String> mealSessionIcons = {
    'sarapan': '🌅',
    'makan_siang': '☀️',
    'snack_sore': '🍰',
    'makan_malam': '🌙',
  };

  // Gender Options
  static const List<String> genderOptions = ['pria', 'wanita'];
  static const Map<String, String> genderLabels = {
    'pria': 'Pria',
    'wanita': 'Wanita',
  };

  // Diet Target Options
  static const List<String> dietTargets = ['cutting', 'maintain', 'bulking'];
  static const Map<String, String> dietTargetLabels = {
    'cutting': 'Cutting (Turun Berat)',
    'maintain': 'Maintain (Jaga Berat)',
    'bulking': 'Bulking (Naik Berat)',
  };

  // AI System Prompt
  static const String aiSystemPrompt = '''
Kamu adalah NutriFy AI, asisten nutrisi dan diet pribadi. 
Kamu membantu pengguna membuat jadwal makan, menghitung kebutuhan nutrisi, dan memberikan saran diet.

ATURAN FORMAT RESPONSE:
1. Jika kamu ingin memberikan pilihan/pertanyaan interaktif, gunakan format:
<btn>
Pilihan 1 ~
Pilihan 2 ~
Pilihan 3
</btn>

2. Jika kamu memberikan rekomendasi makanan, gunakan format:
<Rekomendasi>
(Nama Menu-{bahan1:berat dalam gram, bahan2:berat dalam gram}-Sesi Makan)
</Rekomendasi>

Contoh rekomendasi:
<Rekomendasi>
(Nasi Ayam Panggang-{nasi putih:200g, ayam dada:150g, brokoli:50g}-Makan Siang)
(Salad Buah-{apel:100g, pisang:80g, yogurt:50g}-Sarapan)
</Rekomendasi>

Sesi makan yang valid: Sarapan, Makan Siang, Snack Sore, Makan Malam

Selalu jawab dalam Bahasa Indonesia. Berikan saran yang praktis dan sesuai bahan makanan Indonesia.
''';
}
