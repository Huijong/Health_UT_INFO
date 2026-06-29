import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';
import '../config/app_config.dart';

/// Gmail SMTP를 사용하여 수집 데이터를 이메일로 전송하는 서비스
class EmailService {
  EmailService._();

  /// 메일 전송
  static Future<void> send({
    required String link,
    required String sessionId,
    required String testerName,
    required String deviceModel,
    required String androidVersion,
  }) async {
    final sender = AppConfig.emailSender;
    final password = AppConfig.emailAppPassword;
    final recipient = AppConfig.emailRecipient;

    if (sender.isEmpty ||
        sender == 'your_sender_gmail@gmail.com' ||
        password.isEmpty ||
        password == 'your_app_password' ||
        recipient.isEmpty ||
        recipient == 'your_recipient_email@gmail.com') {
      throw const EmailConfigException();
    }

    // Gmail SMTP 서버 설정
    final smtpServer = gmail(sender, password);

    // 본문 생성
    final body = '''
■ 테스터 정보
- 이름: $testerName
- 세션 ID: $sessionId
- 기기 모델: $deviceModel
- Android 버전: $androidVersion

■ 수집 데이터 링크 (Quick Share)
$link
''';

    final message = mailer.Message()
      ..from = mailer.Address(sender, 'SH 수집기 ($testerName)')
      ..recipients.add(recipient)
      ..subject = '[SH 수집] $testerName - $sessionId'
      ..text = body;

    try {
      await mailer.send(message, smtpServer);
    } catch (e) {
      throw Exception('SMTP 메일 발송 중 오류가 발생했습니다: $e');
    }
  }
}

/// 이메일 설정 정보 미비 예외
class EmailConfigException implements Exception {
  const EmailConfigException();

  @override
  String toString() =>
      '이메일 설정 정보가 올바르지 않거나 기본 플레이스홀더 상태입니다.\n'
      'AppConfig의 이메일 설정(sender, password, recipient)을 입력하세요.';
}
