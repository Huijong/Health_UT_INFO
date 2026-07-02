import 'package:shared_preferences/shared_preferences.dart';

/// 사용자 입력값 중 반복 사용하는 항목을 로컬에 저장/불러오기
class PrefsService {
  static const _keyName = 'tester_name';
  static const _keyHeight = 'height_cm';
  static const _keyWeight = 'weight_kg';
  static const _keyWatch = 'watch_model';
  static const _keyCustomWatch = 'custom_watch';
  static const _keyStrap = 'strap_model';
  static const _keyCustomStrap = 'custom_strap';
  static const _keyOnboardingComplete = 'onboarding_complete';
  static const _keyHasWatchedGuide = 'has_watched_guide';

  final SharedPreferences _prefs;

  PrefsService._(this._prefs);

  static Future<PrefsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PrefsService._(prefs);
  }

  String get name => _prefs.getString(_keyName) ?? '';
  double? get height {
    final v = _prefs.getDouble(_keyHeight);
    return v == 0.0 ? null : v;
  }

  double? get weight {
    final v = _prefs.getDouble(_keyWeight);
    return v == 0.0 ? null : v;
  }

  String get watch => _prefs.getString(_keyWatch) ?? '';
  String get customWatch => _prefs.getString(_keyCustomWatch) ?? '';
  String get strap => _prefs.getString(_keyStrap) ?? '';
  String get customStrap => _prefs.getString(_keyCustomStrap) ?? '';
  bool get onboardingComplete => _prefs.getBool(_keyOnboardingComplete) ?? false;
  bool get hasWatchedGuide => _prefs.getBool(_keyHasWatchedGuide) ?? false;

  Future<void> saveName(String value) => _prefs.setString(_keyName, value);
  Future<void> saveHeight(double value) => _prefs.setDouble(_keyHeight, value);
  Future<void> saveWeight(double value) => _prefs.setDouble(_keyWeight, value);
  Future<void> saveWatch(String value) => _prefs.setString(_keyWatch, value);
  Future<void> saveCustomWatch(String value) => _prefs.setString(_keyCustomWatch, value);
  Future<void> saveStrap(String value) => _prefs.setString(_keyStrap, value);
  Future<void> saveCustomStrap(String value) => _prefs.setString(_keyCustomStrap, value);
  Future<void> saveOnboardingComplete(bool value) => _prefs.setBool(_keyOnboardingComplete, value);
  Future<void> saveHasWatchedGuide(bool value) => _prefs.setBool(_keyHasWatchedGuide, value);
}
