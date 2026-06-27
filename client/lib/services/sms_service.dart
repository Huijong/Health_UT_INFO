import 'dart:io' show Platform;
import 'package:android_intent_plus/android_intent.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

/// Quick Share 링크를 문자(SMS)로 전송
class SmsService {
  SmsService._();

  static Future<void> send({
    required String link,
    required String sessionId,
    required String testerName,
  }) async {
    final recipient = AppConfig.smsRecipient;
    if (recipient.isEmpty) throw const SmsConfigException();

    final body =
        '검증데이터 링크: $link\n세션: $sessionId\n테스터: $testerName';

    if (Platform.isAndroid) {
      // android_intent_plus ACTION_SENDTO — Android에서 body 자동채움이 안정적
      await _sendWithAndroidIntent(recipient, body);
    } else {
      // iOS 등 폴백: url_launcher sms: 스킴
      await _sendWithUrlLauncher(recipient, body);
    }
  }

  static Future<void> _sendWithAndroidIntent(
      String recipient, String body) async {
    final intent = AndroidIntent(
      action: 'android.intent.action.SENDTO',
      data: 'smsto:$recipient',
      arguments: <String, dynamic>{'sms_body': body},
    );
    await intent.launch();
  }

  static Future<void> _sendWithUrlLauncher(
      String recipient, String body) async {
    final uri = Uri(
      scheme: 'sms',
      path: recipient,
      queryParameters: {'body': body},
    );
    if (!await canLaunchUrl(uri)) {
      throw Exception('SMS 앱을 열 수 없습니다');
    }
    await launchUrl(uri);
  }
}

/// SMS 수신 번호 미설정 예외
class SmsConfigException implements Exception {
  const SmsConfigException();

  @override
  String toString() =>
      'SMS 수신 번호가 설정되지 않았습니다.\n'
      '빌드 시 --dart-define=SMS_RECIPIENT=번호 를 추가하세요.';
}
