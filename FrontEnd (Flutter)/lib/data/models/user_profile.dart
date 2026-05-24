class UserProfile {
  final String nama;
  final int umur;
  final double tinggiBadan;
  final double beratBadan;
  final String gender; // 'pria', 'wanita'
  final String targetDiet; // 'cutting', 'maintain', 'bulking'
  final String aktivitas; // 'sedentary', 'ringan', 'sedang', 'aktif', 'sangat_aktif'
  final List<String> pantangan;
  final bool isOnboarded;
  final String? photoPath;
  final String jamSarapan;
  final String jamMakanSiang;
  final String jamMakanMalam;
  final String jamTidur;

  UserProfile({
    required this.nama,
    required this.umur,
    required this.tinggiBadan,
    required this.beratBadan,
    required this.gender,
    required this.targetDiet,
    required this.aktivitas,
    this.pantangan = const [],
    this.isOnboarded = false,
    this.photoPath,
    this.jamSarapan = '08:00',
    this.jamMakanSiang = '13:00',
    this.jamMakanMalam = '19:00',
    this.jamTidur = '22:00',
  });

  UserProfile copyWith({
    String? nama,
    int? umur,
    double? tinggiBadan,
    double? beratBadan,
    String? gender,
    String? targetDiet,
    String? aktivitas,
    List<String>? pantangan,
    bool? isOnboarded,
    String? photoPath,
    String? jamSarapan,
    String? jamMakanSiang,
    String? jamMakanMalam,
    String? jamTidur,
  }) {
    return UserProfile(
      nama: nama ?? this.nama,
      umur: umur ?? this.umur,
      tinggiBadan: tinggiBadan ?? this.tinggiBadan,
      beratBadan: beratBadan ?? this.beratBadan,
      gender: gender ?? this.gender,
      targetDiet: targetDiet ?? this.targetDiet,
      aktivitas: aktivitas ?? this.aktivitas,
      pantangan: pantangan ?? this.pantangan,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      photoPath: photoPath ?? this.photoPath,
      jamSarapan: jamSarapan ?? this.jamSarapan,
      jamMakanSiang: jamMakanSiang ?? this.jamMakanSiang,
      jamMakanMalam: jamMakanMalam ?? this.jamMakanMalam,
      jamTidur: jamTidur ?? this.jamTidur,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'umur': umur,
      'tinggiBadan': tinggiBadan,
      'beratBadan': beratBadan,
      'gender': gender,
      'targetDiet': targetDiet,
      'aktivitas': aktivitas,
      'pantangan': pantangan,
      'isOnboarded': isOnboarded,
      'photoPath': photoPath,
      'jamSarapan': jamSarapan,
      'jamMakanSiang': jamMakanSiang,
      'jamMakanMalam': jamMakanMalam,
      'jamTidur': jamTidur,
    };
  }

  factory UserProfile.fromMap(Map<dynamic, dynamic> map) {
    return UserProfile(
      nama: map['nama'] ?? '',
      umur: map['umur'] ?? 20,
      tinggiBadan: (map['tinggiBadan'] ?? 170).toDouble(),
      beratBadan: (map['beratBadan'] ?? 65).toDouble(),
      gender: map['gender'] ?? 'pria',
      targetDiet: map['targetDiet'] ?? 'maintain',
      aktivitas: map['aktivitas'] ?? 'sedang',
      pantangan: List<String>.from(map['pantangan'] ?? []),
      isOnboarded: map['isOnboarded'] ?? false,
      photoPath: map['photoPath'],
      jamSarapan: map['jamSarapan'] ?? '08:00',
      jamMakanSiang: map['jamMakanSiang'] ?? '13:00',
      jamMakanMalam: map['jamMakanMalam'] ?? '19:00',
      jamTidur: map['jamTidur'] ?? '22:00',
    );
  }

  /// Context string untuk dikirim ke AI
  String toAiContext() {
    return 'Nama: $nama, Umur: $umur tahun, '
        'Tinggi: ${tinggiBadan.toStringAsFixed(0)} cm, '
        'Berat: ${beratBadan.toStringAsFixed(0)} kg, '
        'Gender: $gender, Target: $targetDiet, '
        'Aktivitas: $aktivitas'
        '${pantangan.isNotEmpty ? ", Pantangan: ${pantangan.join(', ')}" : ""}'
        '${photoPath != null ? ", Foto Profil Tersedia" : ""}, '
        'Jadwal Makan & Tidur - Sarapan: $jamSarapan, Siang: $jamMakanSiang, Malam: $jamMakanMalam, Tidur: $jamTidur';
  }
}
