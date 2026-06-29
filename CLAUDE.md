## 프로젝트 개요
- 목적: Samsung Health 앱 검증을 위해 테스터 단말에서 FIT / Cola.zip / 운동 캡처 + 사용자 정보를 수집
- 모듈 구성: 
  1. **client 앱** (테스터용, Flutter)
  2. **server** (FastAPI + MongoDB 기반 수집 서버 및 대시보드 웹)
  3. **admin 앱** (관리자용, Flutter)
  4. **relay** (FCM 공지 중계, Cloud Functions)

## 기술 스택
- **Client**: Flutter (Dart), `flutter build apk --release` 빌드
  * 주요 패키지: mailer, file_picker, image_picker, archive, share_plus, url_launcher, shared_preferences
- **Server**: Python, FastAPI, MongoDB (Motor 비동기 드라이버), Uvicorn

## 환경 제약 및 파일 전송 방식 (매우 중요)
- **회사 보안 규정**: 서버로의 직접적인 파일 업로드(인바운드) 및 외부 퍼블릭 클라우드 스토리지 사용이 불가합니다.
  * **우회 해결책**: 테스터 단말에서 ZIP 패키징 후 **삼성 Quick Share의 "링크 공유" 기능**을 이용해 삼성 클라우드에 업로드하고 생성된 다운로드 링크를 획득합니다.
- **전송 및 데이터 수집 흐름**:
  1. 클라이언트 앱에서 Quick Share 링크를 복사하고 앱으로 복귀하면 이를 자동 감지합니다.
  2. 단말에 등록된 Gmail 계정(SMTP)을 이용해 백그라운드에서 즉시 수신 메일 계정(`huijongwpi2@gmail.com`)으로 전송 메일을 보냅니다. (이메일 발송 중 로딩 팝업 표시)
  3. **server** 모듈이 수신 메일함을 백그라운드(IMAP)에서 실시간으로 감시 및 파싱하여 추출한 테스터 데이터(이름, 세션 ID, 기기 모델, OS 버전, Quick Share 링크)를 **MongoDB**에 적재하고 대시보드에 표출합니다.
  4. 중복 수집 방지를 위해 `session_id` 기준으로 유니크 제약(Unique Index) 처리가 되어 있으며, 테스터가 앱에서 새로운 전송을 시도할 때마다 세션 ID가 자동으로 갱신됩니다.

## 실행 및 배포 방법

### 1. Client 앱 빌드
- 수신 번호, 발신 계정 등의 하드코딩을 방지하기 위해 환경 변수나 `AppConfig` 기본값을 이용해 설정합니다.
- 빌드 명령어:
  ```bash
  cd client
  flutter build apk --release
  ```

### 2. Server 및 웹 대시보드 구동
- **의존성 설치**:
  ```bash
  cd server
  pip install -r requirements.txt
  ```
- **환경 설정**: `server/config.py`에 MongoDB 연결 정보 및 이메일을 수집할 계정(`huijongwpi2@gmail.com`)의 16자리 구글 앱 비밀번호를 기입합니다.
- **서버 실행**:
  ```bash
  cd server
  python main.py
  ```
  *(기본 접속 주소: http://localhost:8000)*

### 3. Cloudflare Tunnel을 통한 외부망 공유
- 로컬 PC에서 구동 중인 대시보드 서버(`http://localhost:8000`)를 외부 테스터나 다른 지역의 관리자에게 공유하기 위해 Cloudflare 로컬 터널을 이용합니다.
- **터널 실행**:
  ```bash
  # 'health-server' 터널 구동 (health-port.work 도메인 연결)
  cloudflared tunnel run health-server
  ```

### 4. 보안 설정 (특정 IP 진입 차단)
- 대시보드 주소(`https://health-port.work`)가 외부에 노출되어 있으므로, 보안 유지를 위해 **특정 허용된 IP를 가진 사용자만 접속 가능하도록** Cloudflare에서 방화벽 통제를 설정합니다.
- **WAF 설정 방법**:
  1. Cloudflare 대시보드 진입 ➡️ `health-port.work` 선택 ➡️ **[Security]** ➡️ **[WAF]** ➡️ **[Custom rules]** 클릭.
  2. 규칙 추가 (**[Create rule]**):
     - 조건(If): `IP Source Address` (IP 발신 주소) ➡️ `does not equal` (같지 않음) ➡️ **[허용할 IP 주소들 입력]**
     - 동작(Then): `Block` (차단) 선택 후 저장(Deploy).
  3. 이 규칙이 활성화되면 등록되지 않은 IP를 가진 모든 접근은 자동으로 차단됩니다.

## 코딩 규칙
- 한국어 주석 사용 권장. 작은 단위의 커밋을 유지합니다.
- 민감정보(비밀번호, 서비스 계정 키 등)는 절대 저장소에 커밋하지 않으며, `.gitignore`를 통해 관리합니다.
