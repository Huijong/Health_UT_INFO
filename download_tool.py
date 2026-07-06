import os
import json
import re
import urllib.parse
import configparser
import requests
import threading
from datetime import datetime
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
from tkinter.scrolledtext import ScrolledText

# 설정 파일 경로
CONFIG_FILE = "config.ini"

class DownloadToolApp:
    def __init__(self, root):
        self.root = root
        self.root.title("HealthPort Lab 로컬 다운로드 수납 툴 🚀")
        self.root.geometry("620x520")
        self.root.minsize(580, 450)
        
        # 기본 변수 초기화
        self.json_path = tk.StringVar()
        self.save_dir = tk.StringVar()
        self.is_running = False
        
        # 설정 로드
        self.load_config()
        
        # UI 구성
        self.create_widgets()

    def create_widgets(self):
        # 1. 파일/폴더 선택 섹션
        input_frame = ttk.LabelFrame(self.root, text=" 설정 및 경로 지정 ", padding=15)
        input_frame.pack(fill="x", padx=15, pady=10)
        
        # JSON 파일 선택
        ttk.Label(input_frame, text="JSON 파일:").grid(row=0, column=0, sticky="w", pady=5)
        ttk.Entry(input_frame, textvariable=self.json_path, width=50).grid(row=0, column=1, padx=5, pady=5)
        ttk.Button(input_frame, text="파일 선택 📄", command=self.browse_json).grid(row=0, column=2, padx=5, pady=5)
        
        # 저장 폴더 선택
        ttk.Label(input_frame, text="저장 폴더:").grid(row=1, column=0, sticky="w", pady=5)
        ttk.Entry(input_frame, textvariable=self.save_dir, width=50).grid(row=1, column=1, padx=5, pady=5)
        ttk.Button(input_frame, text="폴더 선택 📁", command=self.browse_folder).grid(row=1, column=2, padx=5, pady=5)
        
        # 2. 진행률 표시줄 섹션 (Progress Bar)
        progress_frame = ttk.LabelFrame(self.root, text=" 전체 진행 상황 ", padding=10)
        progress_frame.pack(fill="x", padx=15, pady=5)
        
        self.progress_bar = ttk.Progressbar(progress_frame, orient="horizontal", mode="determinate")
        self.progress_bar.pack(fill="x", side="left", expand=True, padx=5)
        
        self.progress_label = ttk.Label(progress_frame, text="대기 중 (0 / 0 건 - 0%)", font=("Helvetica", 9, "bold"))
        self.progress_label.pack(side="right", padx=10)
        
        # 3. 실시간 로그 영역
        log_frame = ttk.LabelFrame(self.root, text=" 실시간 실행 로그 ", padding=5)
        log_frame.pack(fill="both", expand=True, padx=15, pady=5)
        
        self.log_area = ScrolledText(log_frame, height=12, wrap="word", bg="#1E1E1E", fg="#D4D4D4", insertbackground="white", font=("Consolas", 10))
        self.log_area.pack(fill="both", expand=True)
        self.log("💡 프로그램을 실행했습니다. JSON 파일과 저장 폴더를 지정한 후 다운로드를 시작하세요.")
        
        # 4. 실행 버튼
        btn_frame = ttk.Frame(self.root, padding=10)
        btn_frame.pack(fill="x", padx=15)
        
        self.start_btn = ttk.Button(btn_frame, text="다운로드 시작 🚀", command=self.start_download_thread, style="Accent.TButton")
        self.start_btn.pack(fill="x", ipady=5)
        
        # ttk 스타일 조정 (심플)
        style = ttk.Style()
        style.configure("Accent.TButton", font=("Helvetica", 11, "bold"))

    # ── 설정 파일 관련 ──────────────────────────────────────────
    def load_config(self):
        config = configparser.ConfigParser()
        if os.path.exists(CONFIG_FILE):
            try:
                config.read(CONFIG_FILE, encoding='utf-8')
                self.save_dir.set(config.get("Settings", "save_dir", fallback=""))
                self.json_path.set(config.get("Settings", "last_json_path", fallback=""))
            except Exception:
                pass

    def save_config(self):
        config = configparser.ConfigParser()
        config["Settings"] = {
            "save_dir": self.save_dir.get(),
            "last_json_path": self.json_path.get()
        }
        try:
            with open(CONFIG_FILE, "w", encoding='utf-8') as f:
                config.write(f)
        except Exception:
            pass

    # ── 브라우즈 이벤트 ──────────────────────────────────────────
    def browse_json(self):
        path = filedialog.askopenfilename(
            title="대시보드 내보내기 JSON 선택",
            filetypes=[("JSON Files", "*.json"), ("All Files", "*.*")]
        )
        if path:
            self.json_path.set(path)
            self.save_config()

    def browse_folder(self):
        path = filedialog.askdirectory(title="저장할 루트 폴더 선택")
        if path:
            # 윈도우 경로 포맷 보존
            normalized = os.path.normpath(path)
            self.save_dir.set(normalized)
            self.save_config()

    # ── 로그 기록 ──────────────────────────────────────────────
    def log(self, message):
        timestamp = datetime.now().strftime("%H:%M:%S")
        self.log_area.insert(tk.END, f"[{timestamp}] {message}\n")
        self.log_area.see(tk.END)

    # ── 백그라운드 스레드 시작 ──────────────────────────────────────
    def start_download_thread(self):
        if self.is_running:
            return
        
        json_file = self.json_path.get().strip()
        save_folder = self.save_dir.get().strip()
        
        if not json_file or not os.path.exists(json_file):
            messagebox.showerror("오류", "유효한 JSON 파일을 지정해 주세요.")
            return
        if not save_folder:
            messagebox.showerror("오류", "저장할 루트 폴더를 지정해 주세요.")
            return
            
        self.is_running = True
        self.start_btn.config(state="disabled", text="다운로드 중... ⏳")
        
        # 메인 스레드 블로킹 방지를 위한 백그라운드 스레드 가동
        threading.Thread(target=self.run_download_process, args=(json_file, save_folder), daemon=True).start()

    # ── 퀵 쉐어 파일 진짜 다운로드 URL 및 원본 파일명 찾기 ───────────
    def parse_quickshare(self, share_url):
        """
        Samsung Quick Share 페이지에서 실제 다이렉트 파일 주소 및 파일명을 정규식으로 파싱
        """
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }
        
        try:
            res = requests.get(share_url, headers=headers, timeout=10)
            if res.status_code != 200:
                return []
            
            html = res.text
            
            # 1단계: window.__INITIAL_STATE__ 검색 시도
            state_match = re.search(r'window\.__INITIAL_STATE__\s*=\s*(\{.+?\});?$', html, re.MULTILINE)
            if state_match:
                try:
                    state_json = json.loads(state_match.group(1))
                    file_list = state_json.get("shareInfo", {}).get("fileList", [])
                    resolved = []
                    for f in file_list:
                        name = f.get("fileName")
                        url = f.get("downloadUrl")
                        if name and url:
                            resolved.append((name, url))
                    if resolved:
                        return resolved
                except Exception:
                    pass
            
            # 2단계: 폴백 - HTML 본문에서 downloadUrl 혹은 raw cdn URL 패턴 일괄 검색
            urls = re.findall(r'"downloadUrl"\s*:\s*"(https://[^"]+)"', html)
            names = re.findall(r'"fileName"\s*:\s*"([^"]+)"', html)
            
            if urls and names and len(urls) == len(names):
                return list(zip(names, urls))
            elif urls:
                # 파일명이 없을 경우 URL 주소에서 추출 시도
                resolved = []
                for url in urls:
                    decoded_url = urllib.parse.unquote(url)
                    parsed_path = urllib.parse.urlparse(decoded_url).path
                    name = os.path.basename(parsed_path) or "downloaded_file.zip"
                    resolved.append((name, url))
                return resolved
                
        except Exception as e:
            self.log(f"❌ 퀵 쉐어 페이지 주소 해독 중 실패: {e}")
            
        return []

    # ── 핵심 파일 수납 및 다운로드 루프 ──────────────────────────────
    def run_download_process(self, json_file, save_folder):
        try:
            self.log("🚀 다운로드 수납 작업을 시작하겠습니다...")
            
            with open(json_file, "r", encoding="utf-8") as f:
                records = json.load(f)
                
            if not isinstance(records, list):
                self.log("❌ 오류: 올바른 대시보드 JSON 형식이 아닙니다. (리스트 타입 아님)")
                self.reset_state()
                return
                
            total_records = len(records)
            self.log(f"📊 총 {total_records}건의 레코드를 분석합니다.")
            
            success_count = 0
            fail_count = 0
            
            for index, item in enumerate(records):
                # UI 진행률 및 텍스트 즉각 반영
                percentage = int(((index + 1) / total_records) * 100)
                self.progress_bar["value"] = percentage
                self.progress_label.config(text=f"진행 중 ({index + 1} / {total_records} 건 - {percentage}%)")
                
                tester_name = item.get("tester_name", "이름없음").strip()
                received_at = item.get("received_at", "").strip()
                watch = item.get("watch", "워치미지정").strip()
                share_link = item.get("share_link", "").strip()
                
                # 수신날짜 YYYYMMDD 파싱
                date_folder = "날짜미상"
                if received_at:
                    try:
                        parsed_date = re.search(r'(\d{4})-(\d{2})-(\d{2})', received_at)
                        if parsed_date:
                            date_folder = f"{parsed_date.group(1)}{parsed_date.group(2)}{parsed_date.group(3)}"
                    except Exception:
                        pass
                
                self.log(f"⏳ [{index + 1}/{total_records}] 테스터: {tester_name} (수신일: {date_folder}) 처리 중...")
                
                if not share_link:
                    self.log(f"⚠️ {tester_name}: 퀵 쉐어 다운로드 링크가 존재하지 않아 스킵합니다.")
                    fail_count += 1
                    continue
                
                # 퀵 쉐어 파일 주소 파싱
                self.log(f"🔍 퀵 쉐어 주소 해독 중: {share_link}")
                files_to_download = self.parse_quickshare(share_link)
                
                if not files_to_download:
                    self.log(f"❌ {tester_name}: 다운로드 가능한 파일을 찾지 못했거나 만료된 링크입니다.")
                    fail_count += 1
                    continue
                
                # 타겟 폴더 생성 (예: Z:\20260703\홍길동\Galaxy Watch 6)
                clean_watch = re.sub(r'[\/:*?"<>|]', '_', watch) # 윈도우 폴더 금지문자 치환
                clean_name = re.sub(r'[\/:*?"<>|]', '_', tester_name)
                
                target_dir = os.path.join(save_folder, date_folder, clean_name, clean_watch)
                try:
                    os.makedirs(target_dir, exist_ok=True)
                except Exception as e:
                    self.log(f"❌ 폴더 생성 실패 ({target_dir}): {e}")
                    fail_count += 1
                    continue
                
                # 파일별 다운로드 실행
                record_success = True
                for filename, download_url in files_to_download:
                    clean_filename = re.sub(r'[\/:*?"<>|]', '_', filename)
                    file_save_path = os.path.join(target_dir, clean_filename)
                    
                    self.log(f"📥 파일 다운로드 시도: {clean_filename}")
                    try:
                        res = requests.get(download_url, stream=True, timeout=30)
                        if res.status_code == 200:
                            with open(file_save_path, 'wb') as out_f:
                                for chunk in res.iter_content(chunk_size=8192):
                                    if chunk:
                                        out_f.write(chunk)
                            self.log(f"✅ 완료: {clean_filename} ➡️ {file_save_path}")
                        else:
                            self.log(f"❌ 다운로드 오류 (HTTP {res.status_code}): {clean_filename}")
                            record_success = False
                    except Exception as e:
                        self.log(f"❌ 다운로드 중 에러 발생 ({clean_filename}): {e}")
                        record_success = False
                
                if record_success:
                    success_count += 1
                else:
                    fail_count += 1
            
            # 최종 정산 리포트
            self.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            self.log("🏁 모든 다운로드 수납 작업이 완료되었습니다!")
            self.log(f"📊 최종 정산: 총 {total_records}건 중 [성공: {success_count}건], [실패/누락: {fail_count}건]")
            self.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            
            # 팝업 알림
            messagebox.showinfo("완료", f"수납 처리가 끝났습니다!\n성공: {success_count}건, 실패: {fail_count}건")
            
        except Exception as e:
            self.log(f"❌ 치명적 프로세스 에러 발생: {e}")
            messagebox.showerror("오류", f"진행 도중 치명적 에러 발생:\n{e}")
        finally:
            self.reset_state()

    def reset_state(self):
        self.is_running = False
        self.start_btn.config(state="normal", text="다운로드 시작 🚀")


# ── 실행 진입점 ─────────────────────────────────────────────
if __name__ == "__main__":
    root = tk.Tk()
    app = DownloadToolApp(root)
    root.mainloop()
