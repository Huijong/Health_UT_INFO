## 프로젝트 개요
- 목적: Samsung Health 앱 검증을 위해 테스터 단말에서 FIT / Cola.zip / 운동 캡처 + 사용자 정보를 수집
- 3개 모듈: client 앱(테스터용, Flutter), admin 앱(관리자용, Flutter), relay(FCM 공지 중계, Cloud Functions)

## 기술 스택
- 앱은 Flutter(Dart)로 개발, `flutter build apk --release`로 빌드
- 주요 패키지: file_picker, image_picker, archive, share_plus, url_launcher,
  firebase_core, firebase_messaging, shared_preferences, path_provider

## 환경 제약 (매우 중요)
- 회사 보안: 서버로의 인바운드 업로드 차단. 외부 클라우드 스토리지 사용 불가.
  → 파일 전송은 삼성 Quick Share의 "링크 공유"(삼성클라우드 경유) + 문자(SMS)로 우회한다.
- 다운로드(아웃바운드)는 허용.
- client 단말들은 모바일 데이터 또는 외부 Wi-Fi 사용(사내망 아님). 인터넷이면 Quick Share/문자/FCM 동작.
  단, 일부 외부/공용 Wi-Fi가 FCM 포트를 막을 수 있어 공지 수동 새로고침(pull) 보조 경로를 둔다.
- FCM 인증은 HTTP v1 API + service account JSON 키 (legacy 서버키 금지, 2024.6 폐기됨).
- service account JSON 키는 APK에 넣지 않는다. relay 함수에만 둔다.

## 빌드/배포
- client/admin은 사이드로딩(APK 직접 배포). Play Store 미사용.
- 수신 번호, 함수 URL, 시크릿 등은 하드코딩 금지. --dart-define 또는 설정 파일로 분리.

## 코딩 규칙
- 한국어 주석 OK. 작은 단위로 커밋.
- 민감정보 커밋 금지. .gitignore에 google-services.json, service-account.json, 시크릿 추가.
