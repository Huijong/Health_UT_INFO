/// 환경별 설정 상수
///
/// 빌드 시 --dart-define으로 주입하세요:
///   flutter build apk \
///     --dart-define=SMS_RECIPIENT=01012345678 \
///     --dart-define=QUICK_SHARE_PATTERN=sharing.samsung
///
/// Quick Share 실제 링크 도메인은 테스트 단말에서 한 번 복사해 확인한 뒤
/// QUICK_SHARE_PATTERN 값을 그에 맞게 지정하세요.
/// 알려진 패턴 예시: sharing.samsung / samsungcloud.com / q1team.cc
class AppConfig {
  AppConfig._();

  /// Quick Share 링크 판별 패턴 — URL에 포함 여부로 검사 (대소문자 무시)
  static const quickSharePattern = String.fromEnvironment(
    'QUICK_SHARE_PATTERN',
    defaultValue: 'sharing.samsung',
  );

  /// SMS 수신 번호 (하이픈 없이, 예: 01012345678)
  static const smsRecipient = String.fromEnvironment(
    'SMS_RECIPIENT',
    defaultValue: '01096028934',
  );

  /// 발송용 Gmail 계정
  static const emailSender = String.fromEnvironment(
    'EMAIL_SENDER',
    defaultValue: 'huijonghealth@gmail.com',
  );

  /// 발송용 Gmail 앱 비밀번호 (16자리)
  static const emailAppPassword = String.fromEnvironment(
    'EMAIL_APP_PASSWORD',
    defaultValue: 'ajccuftyflmmhxso',
  );

  /// 수신용 관리자 이메일 주소
  static const emailRecipient = String.fromEnvironment(
    'EMAIL_RECIPIENT',
    defaultValue: 'huijongwpi2@gmail.com',
  );

  /// FastAPI 서버 주소 (공지사항 조회용)
  static const apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://health-port.work',
  );

  /// HealthPort 앱 버전
  static const appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.026',
  );
}
