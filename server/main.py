from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse
from motor.motor_asyncio import AsyncIOMotorClient
from contextlib import asynccontextmanager
import threading
import uvicorn
from config import MONGO_URL, DB_NAME, CHECK_INTERVAL_SECONDS
from mail_parser import start_mail_parser_loop


# MongoDB 비동기 연결 객체
db_client = None
db = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global db_client, db
    # Startup: 데이터베이스 클라이언트 및 백그라운드 이메일 수신 스레드 시작
    db_client = AsyncIOMotorClient(MONGO_URL)
    db = db_client[DB_NAME]
    
    parser_thread = threading.Thread(
        target=start_mail_parser_loop, 
        args=(CHECK_INTERVAL_SECONDS,), 
        daemon=True
    )
    parser_thread.start()
    
    yield
    
    # Shutdown: 데이터베이스 연결 종료
    if db_client:
        db_client.close()

app = FastAPI(title="Samsung Health 검증 메일 모니터 대시보드", lifespan=lifespan)

@app.get("/api/emails")
async def get_emails():
    try:
        cursor = db["verification_emails"].find({}).sort("received_at", -1)
        emails = await cursor.to_list(length=100)
        for email_item in emails:
            email_item["_id"] = str(email_item["_id"])
        return JSONResponse(content={"status": "success", "data": emails})
    except Exception as e:
        return JSONResponse(content={"status": "error", "message": str(e)}, status_code=500)

@app.get("/", response_class=HTMLResponse)
async def get_dashboard(request: Request):
    # 프리미엄 다크/블루 계열 현대적 웹 대시보드 화면
    html_content = """
    <!DOCTYPE html>
    <html lang="ko">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>SH 검증 이메일 모니터 대시보드</title>
        <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;800&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
        <style>
            :root {
                --primary: #1429A0;
                --primary-light: #E8EBF5;
                --bg: #F5F7FB;
                --card-bg: #FFFFFF;
                --text: #1E293B;
                --text-muted: #64748B;
                --success: #10B981;
                --border: #E2E8F0;
                --font-primary: 'Inter', sans-serif;
                --font-display: 'Outfit', sans-serif;
            }
            body {
                font-family: var(--font-primary);
                background-color: var(--bg);
                color: var(--text);
                margin: 0;
                padding: 40px 20px;
                display: flex;
                flex-direction: column;
                align-items: center;
            }
            .container {
                max-width: 1200px;
                width: 100%;
            }
            header {
                display: flex;
                justify-content: space-between;
                align-items: center;
                margin-bottom: 30px;
            }
            h1 {
                font-family: var(--font-display);
                font-size: 28px;
                font-weight: 800;
                color: var(--primary);
                margin: 0;
            }
            .refresh-btn {
                background-color: var(--primary);
                color: white;
                border: none;
                padding: 10px 22px;
                border-radius: 8px;
                font-weight: 600;
                font-size: 14px;
                cursor: pointer;
                transition: background-color 0.2s, transform 0.1s;
            }
            .refresh-btn:hover {
                background-color: #0E1E7A;
            }
            .refresh-btn:active {
                transform: scale(0.98);
            }
            .card {
                background-color: var(--card-bg);
                border-radius: 14px;
                box-shadow: 0 4px 20px rgba(148, 163, 184, 0.08);
                border: 1px solid var(--border);
                overflow: hidden;
            }
            table {
                width: 100%;
                border-collapse: collapse;
                text-align: left;
            }
            th, td {
                padding: 18px 24px;
                border-bottom: 1px solid var(--border);
                font-size: 14px;
            }
            th {
                background-color: var(--primary-light);
                color: var(--primary);
                font-weight: 700;
                text-transform: uppercase;
                font-size: 12px;
                letter-spacing: 0.8px;
            }
            tr:last-child td {
                border-bottom: none;
            }
            tr:hover {
                background-color: #F8FAFC;
            }
            .badge {
                display: inline-block;
                padding: 6px 10px;
                border-radius: 6px;
                font-size: 12px;
                font-weight: 600;
                background-color: #F1F5F9;
                color: #475569;
            }
            .link-btn {
                display: inline-flex;
                align-items: center;
                background-color: var(--primary-light);
                color: var(--primary);
                text-decoration: none;
                padding: 8px 14px;
                border-radius: 6px;
                font-weight: 600;
                font-size: 13px;
                transition: background-color 0.2s;
            }
            .link-btn:hover {
                background-color: #D5DBEC;
            }
            .copy-btn {
                background: none;
                border: none;
                color: var(--primary);
                cursor: pointer;
                font-size: 13px;
                font-weight: 600;
                margin-left: 10px;
                text-decoration: underline;
            }
            .copy-btn:hover {
                color: #0E1E7A;
            }
            .no-data {
                text-align: center;
                padding: 50px;
                color: var(--text-muted);
                font-style: italic;
                font-size: 15px;
            }
        </style>
        <script>
            async function fetchEmails() {
                try {
                    const res = await fetch('/api/emails');
                    const json = await res.json();
                    if (json.status === 'success') {
                        renderTable(json.data);
                    }
                } catch (e) {
                    console.error("데이터 로드 중 오류 발생:", e);
                }
            }

            function copyToClipboard(text) {
                navigator.clipboard.writeText(text);
                alert("Quick Share 링크가 클립보드에 복사되었습니다!");
            }

            function renderTable(data) {
                const tbody = document.getElementById('table-body');
                if (data.length === 0) {
                    tbody.innerHTML = `<tr><td colspan="6" class="no-data">수신 대기 중... 새로운 검증 데이터가 이메일로 인입되면 자동 추가됩니다.</td></tr>`;
                    return;
                }
                
                let html = '';
                data.forEach(item => {
                    html += `
                        <tr>
                            <td><strong style="font-size: 15px;">${item.tester_name}</strong></td>
                            <td><span class="badge">${item.device_model}</span></td>
                            <td>Android ${item.android_version}</td>
                            <td><code style="font-size: 12px; background: #F1F5F9; padding: 4px 8px; border-radius: 4px; color: #0F172A; font-family: monospace;">${item.session_id}</code></td>
                            <td>
                                ${item.share_link ? `
                                    <a href="${item.share_link}" target="_blank" class="link-btn">Quick Share 다운로드</a>
                                    <button class="copy-btn" onclick="copyToClipboard('${item.share_link}')">주소 복사</button>
                                ` : '<span style="color: var(--text-muted);">링크 없음</span>'}
                            </td>
                            <td style="color: var(--text-muted); font-size: 13px;">${item.received_at}</td>
                        </tr>
                    `;
                });
                tbody.innerHTML = html;
            }

            window.onload = () => {
                fetchEmails();
                setInterval(fetchEmails, 10000); // 10초마다 자동 새로고침
            }
        </script>
    </head>
    <body>
        <div class="container">
            <header>
                <h1>📊 Samsung Health 검증 모니터 대시보드</h1>
                <button class="refresh-btn" onclick="fetchEmails()">새로고침</button>
            </header>
            <div class="card">
                <table>
                    <thead>
                        <tr>
                            <th>테스터 이름</th>
                            <th>기기 모델</th>
                            <th>OS 버전</th>
                            <th>세션 ID</th>
                            <th>Quick Share 링크</th>
                            <th>수신 일시</th>
                        </tr>
                    </thead>
                    <tbody id="table-body">
                        <tr>
                            <td colspan="6" style="text-align: center; padding: 50px; color: var(--text-muted);">데이터를 불러오는 중입니다...</td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
