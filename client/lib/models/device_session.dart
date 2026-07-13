import 'dart:math';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/app_config.dart';

/// 앱 실행 시 자동으로 수집되는 기기·세션 정보
class DeviceSession {
  final String deviceModel;
  final String androidVersion;
  final String appVersion;
  final String shealthVersion;
  final String createdAt;
  final String sessionId;

  const DeviceSession({
    required this.deviceModel,
    required this.androidVersion,
    required this.appVersion,
    required this.shealthVersion,
    required this.createdAt,
    required this.sessionId,
  });

  static const _channel = MethodChannel('com.samsung.health.client/app_info');

  static Future<DeviceSession> collect() async {
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;

    String shealthVersion = '알 수 없음';
    try {
      shealthVersion = await _channel.invokeMethod<String>('getSamsungHealthVersion') ?? '알 수 없음';
    } catch (_) {}

    final now = DateTime.now();
    final stamp =
        '${now.year}${_p(now.month)}${_p(now.day)}'
        '_${_p(now.hour)}${_p(now.minute)}${_p(now.second)}';
    final rand = (Random().nextInt(9000) + 1000).toString();
    final sessionId = 'SH_${stamp}_$rand';

    final createdAt =
        '${now.year}-${_p(now.month)}-${_p(now.day)} '
        '${_p(now.hour)}:${_p(now.minute)}:${_p(now.second)}';

    return DeviceSession(
      deviceModel: '${androidInfo.manufacturer} ${androidInfo.model}',
      androidVersion: 'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})',
      appVersion: AppConfig.appVersion,
      shealthVersion: shealthVersion,
      createdAt: createdAt,
      sessionId: sessionId,
    );
  }

  static String _p(int n) => n.toString().padLeft(2, '0');
}
