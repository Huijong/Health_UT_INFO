import 'package:shared_preferences/shared_preferences.dart';

/// 사용자 입력값 중 반복 사용하는 항목을 로컬에 저장/불러오기
class PrefsService {
  static const _keyName = 'tester_name';
  static const _keyHeight = 'height_cm';
  static const _keyWeight = 'weight_kg';

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

  Future<void> saveName(String value) => _prefs.setString(_keyName, value);
  Future<void> saveHeight(double value) => _prefs.setDouble(_keyHeight, value);
  Future<void> saveWeight(double value) => _prefs.setDouble(_keyWeight, value);
}
