import imaplib
import email
from email.header import decode_header
import re
import time
import logging
from pymongo import MongoClient
from config import MONGO_URL, DB_NAME, IMAP_SERVER, EMAIL_ACCOUNT, EMAIL_PASSWORD

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

def parse_email_body(body_text):
    # 정규식 패턴을 통한 데이터 추출
    name_match = re.search(r"이름:\s*(.*)", body_text)
    session_match = re.search(r"세션 ID:\s*(.*)", body_text)
    model_match = re.search(r"기기 모델:\s*(.*)", body_text)
    version_match = re.search(r"Android 버전:\s*(.*)", body_text)
    
    # http로 시작하는 다운로드 링크 추출
    link_match = re.search(r"(https?://[^\s\r\n]+)", body_text)
    
    return {
        "tester_name": name_match.group(1).strip() if name_match else "알 수 없음",
        "session_id": session_match.group(1).strip() if session_match else "알 수 없음",
        "device_model": model_match.group(1).strip() if model_match else "알 수 없음",
        "android_version": version_match.group(1).strip() if version_match else "알 수 없음",
        "share_link": link_match.group(1).strip() if link_match else "",
    }

def fetch_and_parse_emails():
    if not EMAIL_PASSWORD or EMAIL_PASSWORD == "your_receiver_app_password":
        logging.warning("수신인 Gmail 앱 비밀번호가 설정되지 않아 메일 확인을 건너뜁니다.")
        return

    mail = None
    try:
        # MongoDB 연결
        mongo_client = MongoClient(MONGO_URL)
        db = mongo_client[DB_NAME]
        collection = db["verification_emails"]
        
        # 중복 방지를 위한 session_id 인덱스 생성
        collection.create_index("session_id", unique=True)
        
        # IMAP 연결
        mail = imaplib.IMAP4_SSL(IMAP_SERVER)
        mail.login(EMAIL_ACCOUNT, EMAIL_PASSWORD)
        mail.select("inbox")
        
        # 모든 읽지 않은 메일 검색 (순수 아스키이므로 무조건 성공)
        status, response = mail.search(None, 'UNSEEN')
        if status != "OK":
            return
            
        mail_ids = response[0].split()
        if not mail_ids:
            return
            
        for m_id in mail_ids:
            # 먼저 이메일의 제목(Subject)만 가져옴
            status, header_data = mail.fetch(m_id, "(BODY[HEADER.FIELDS (SUBJECT)])")
            if status != "OK" or not header_data[0]:
                continue
                
            header_text = header_data[0][1].decode('utf-8', errors='ignore')
            msg_temp = email.message_from_string(header_text)
            subject_header = msg_temp["Subject"]
            if not subject_header:
                continue
                
            subject, encoding = decode_header(subject_header)[0]
            if isinstance(subject, bytes):
                subject = subject.decode(encoding or "utf-8", errors="ignore")
                
            # '[SH 수집]'이 들어간 이메일만 대상
            if '[SH 수집]' not in subject:
                continue
                
            # 매칭될 경우에만 전체 메일 본문 조회 및 파싱 진행
            status, data = mail.fetch(m_id, "(RFC822)")
            if status != "OK":
                continue
                
            raw_email = data[0][1]
            msg = email.message_from_bytes(raw_email)
                
            # 메일 본문 추출
            body = ""
            if msg.is_multipart():
                for part in msg.walk():
                    content_type = part.get_content_type()
                    content_disp = str(part.get("Content-Disposition"))
                    if content_type == "text/plain" and "attachment" not in content_disp:
                        payload = part.get_payload(decode=True)
                        body = payload.decode("utf-8", errors="ignore")
                        break
            else:
                body = msg.get_payload(decode=True).decode("utf-8", errors="ignore")
                
            # 본문 파싱
            parsed_data = parse_email_body(body)
            parsed_data["subject"] = subject
            parsed_data["received_at"] = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
            
            if parsed_data["share_link"]:
                try:
                    # DB 저장 (session_id 고유값 보장으로 중복 삽입 자동 차단)
                    collection.insert_one(parsed_data)
                    logging.info(f"성공적으로 DB 저장: {parsed_data['tester_name']} ({parsed_data['session_id']})")
                except Exception:
                    logging.info(f"이미 존재하는 세션이거나 저장 오류 건너뜀: {parsed_data['session_id']}")
            
            # 메일을 읽음(Seen) 상태로 업데이트
            mail.store(m_id, "+FLAGS", "\\Seen")
            
    except Exception as e:
        logging.error(f"이메일 파싱 루프 중 에러 발생: {e}")
    finally:
        if mail:
            try:
                mail.close()
            except Exception:
                pass
            try:
                mail.logout()
            except Exception:
                pass

def start_mail_parser_loop(interval):
    logging.info("배경 이메일 감시 스레드가 시작되었습니다.")
    while True:
        fetch_and_parse_emails()
        time.sleep(interval)
