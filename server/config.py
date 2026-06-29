import os

MONGO_URL = os.getenv("MONGO_URL", "mongodb://localhost:27017/")
DB_NAME = "sh_database"

# 수신 메일 계정 설정 (IMAP으로 메일을 읽어올 계정)
IMAP_SERVER = "imap.gmail.com"
EMAIL_ACCOUNT = os.getenv("EMAIL_ACCOUNT", "huijongwpi2@gmail.com")
EMAIL_PASSWORD = os.getenv("EMAIL_PASSWORD", "whho jyrh llab kqng")  # 수신용 메일 계정의 16자리 구글 앱 비밀번호

# 이메일 확인 주기 (초 단위)
CHECK_INTERVAL_SECONDS = 15
