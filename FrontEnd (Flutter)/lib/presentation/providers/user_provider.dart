import 'package:flutter/material.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/user_repository.dart';
import '../../core/utils/nutrisi_calculator.dart';

class UserProvider extends ChangeNotifier {
  UserProfile? _profile;
  Map<String, double> _nutrisiTarget = {};

  UserProfile? get profile => _profile;
  Map<String, double> get nutrisiTarget => _nutrisiTarget;
  bool get isOnboarded => _profile?.isOnboarded ?? false;

  void loadProfile() {
    _profile = UserRepository.getProfile();
    if (_profile != null) {
      _hitungTarget();
    }
    notifyListeners();
  }

  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile;
    await UserRepository.saveProfile(profile);
    _hitungTarget();
    notifyListeners();
  }

  Future<void> completeOnboarding(UserProfile profile) async {
    final onboardedProfile = profile.copyWith(isOnboarded: true);
    await saveProfile(onboardedProfile);
  }

  void _hitungTarget() {
    if (_profile == null) return;
    _nutrisiTarget = NutrisiCalculator.hitungSemuaNutrisi(
      beratKg: _profile!.beratBadan,
      tinggiCm: _profile!.tinggiBadan,
      umur: _profile!.umur,
      gender: _profile!.gender,
      aktivitas: _profile!.aktivitas,
      targetDiet: _profile!.targetDiet,
    );
  }

  double get targetKalori => _nutrisiTarget['targetKalori'] ?? 2000;
  double get targetProtein => _nutrisiTarget['protein'] ?? 150;
  double get targetLemak => _nutrisiTarget['lemak'] ?? 65;
  double get targetKarbo => _nutrisiTarget['karbo'] ?? 250;
  double get targetTdee => _nutrisiTarget['tdee'] ?? 2000;

  Future<void> resetProfile() async {
    await UserRepository.clearProfile();
    _profile = null;
    _nutrisiTarget = {};
    notifyListeners();
  }
}
