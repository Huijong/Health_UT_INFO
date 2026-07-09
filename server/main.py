from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse
from motor.motor_asyncio import AsyncIOMotorClient
from contextlib import asynccontextmanager
import threading
import uvicorn
from config import MONGO_URL, DB_NAME, CHECK_INTERVAL_SECONDS
from mail_parser import start_mail_parser_loop
import firebase_admin
from firebase_admin import credentials, messaging
from pydantic import BaseModel
from datetime import datetime
import mimetypes

# APK MIME 타입 등록 (브라우저 다운로드 시 .zip으로 오인되는 것 방지)
mimetypes.add_type("application/vnd.android.package-archive", ".apk")


# MongoDB 비동기 연결 객체
db_client = None
db = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global db_client, db
    # Startup: 데이터베이스 클라이언트 및 백그라운드 이메일 수신 스레드 시작
    db_client = AsyncIOMotorClient(MONGO_URL)
    db = db_client[DB_NAME]
    
    import os
    os.makedirs("static/apks", exist_ok=True)

    # Firebase Admin SDK 초기화
    try:
        cred = credentials.Certificate("firebase-adminsdk.json")
        firebase_admin.initialize_app(cred)
        print("[INFO] Firebase Admin SDK initialized successfully.")
    except Exception as e:
        print(f"[ERROR] Failed to initialize Firebase Admin SDK: {e}")

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

app = FastAPI(title="HealthPort Lab", lifespan=lifespan)

from fastapi.responses import FileResponse
import os

@app.get("/static/apks/{filename}")
async def download_apk(filename: str):
    file_path = os.path.join("static", "apks", filename)
    if not os.path.exists(file_path):
        return JSONResponse(status_code=404, content={"message": "File not found"})
    return FileResponse(
        file_path,
        media_type="application/vnd.android.package-archive",
        filename=filename
    )

from fastapi.staticfiles import StaticFiles
app.mount("/static", StaticFiles(directory="static"), name="static")

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

class NoticeCreate(BaseModel):
    title: str
    content: str

class DevicePing(BaseModel):
    tester_name: str
    watch: str
    os_version: str

class NoticeAck(BaseModel):
    tester_name: str

@app.post("/api/devices/ping")
async def device_ping(ping: DevicePing):
    try:
        if db is None:
            return JSONResponse(content={"status": "error", "message": "Database not initialized"}, status_code=500)
        
        device_dict = {
            "tester_name": ping.tester_name,
            "watch": ping.watch,
            "os_version": ping.os_version,
            "last_active_at": datetime.utcnow()
        }
        
        await db["devices"].update_one(
            {"tester_name": ping.tester_name},
            {"$set": device_dict},
            upsert=True
        )
        return JSONResponse(content={"status": "success", "message": "Ping received"})
    except Exception as e:
        return JSONResponse(content={"status": "error", "message": str(e)}, status_code=500)

@app.get("/api/devices")
async def get_devices():
    try:
        if db is None:
            return JSONResponse(content={"status": "error", "message": "Database not initialized"}, status_code=500)
        cursor = db["devices"].find({}).sort("last_active_at", -1)
        devices = await cursor.to_list(length=100)
        for d in devices:
            d["_id"] = str(d["_id"])
            if isinstance(d.get("last_active_at"), datetime):
                d["last_active_at"] = d["last_active_at"].isoformat()
        return JSONResponse(content={"status": "success", "data": devices})
    except Exception as e:
        return JSONResponse(content={"status": "error", "message": str(e)}, status_code=500)

@app.post("/api/notices/{notice_id}/ack")
async def notice_ack(notice_id: str, ack: NoticeAck):
    try:
        if db is None:
            return JSONResponse(content={"status": "error", "message": "Database not initialized"}, status_code=500)
        from bson import ObjectId
        try:
            obj_id = ObjectId(notice_id)
        except Exception:
            return JSONResponse(content={"status": "error", "message": "Invalid notice_id format"}, status_code=400)
            
        await db["notices"].update_one(
            {"_id": obj_id},
            {"$addToSet": {"received_users": ack.tester_name}}
        )
        return JSONResponse(content={"status": "success", "message": "ACK recorded"})
    except Exception as e:
        return JSONResponse(content={"status": "error", "message": str(e)}, status_code=500)

@app.get("/api/notices")
async def get_all_notices():
    try:
        if db is None:
            return JSONResponse(content={"status": "error", "message": "Database not initialized"}, status_code=500)
        cursor = db["notices"].find({}).sort("created_at", -1)
        notices = await cursor.to_list(length=100)
        for notice in notices:
            notice["_id"] = str(notice["_id"])
            if isinstance(notice.get("created_at"), datetime):
                notice["created_at"] = notice["created_at"].isoformat()
            if "received_users" not in notice:
                notice["received_users"] = []
        return JSONResponse(content={"status": "success", "data": notices})
    except Exception as e:
        return JSONResponse(content={"status": "error", "message": str(e)}, status_code=500)

@app.get("/api/notices/latest")
async def get_latest_notice():
    try:
        if db is None:
            return JSONResponse(content={"status": "error", "message": "Database not initialized"}, status_code=500)
        notice = await db["notices"].find_one(sort=[("created_at", -1)])
        if notice:
            notice["_id"] = str(notice["_id"])
            if isinstance(notice.get("created_at"), datetime):
                notice["created_at"] = notice["created_at"].isoformat()
            if "received_users" not in notice:
                notice["received_users"] = []
            return JSONResponse(content={"status": "success", "data": notice})
        return JSONResponse(content={"status": "success", "data": None})
    except Exception as e:
        return JSONResponse(content={"status": "error", "message": str(e)}, status_code=500)

@app.post("/api/notices")
async def create_notice(notice: NoticeCreate):
    try:
        if db is None:
            return JSONResponse(content={"status": "error", "message": "Database not initialized"}, status_code=500)
        
        notice_dict = {
            "title": notice.title,
            "content": notice.content,
            "created_at": datetime.utcnow(),
            "received_users": []
        }
        
        result = await db["notices"].insert_one(notice_dict)
        notice_id = str(result.inserted_id)
        
        # 실시간 FCM 토픽 푸시 알림 발송
        try:
            message = messaging.Message(
                notification=messaging.Notification(
                    title=notice.title,
                    body=notice.content[:100] + ("..." if len(notice.content) > 100 else ""),
                ),
                topic="notices",
                data={
                    "notice_id": notice_id,
                    "title": notice.title,
                }
            )
            response = messaging.send(message)
            print(f"[INFO] FCM 푸시 메시지 전송 성공: {response}")
        except Exception as fcm_err:
            print(f"[WARNING] FCM 푸시 발송 실패 (DB 저장은 완료됨): {fcm_err}")
            
        return JSONResponse(content={"status": "success", "data": {"id": notice_id}})
    except Exception as e:
        return JSONResponse(content={"status": "error", "message": str(e)}, status_code=500)

@app.get("/", response_class=HTMLResponse)
async def get_dashboard(request: Request):
    # 프리미엄 다크/블루 계열 현대적 웹 대시보드 화면 및 상단 통합 필터 보드
    html_content = """
    <!DOCTYPE html>
    <html lang="ko">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>HealthPort Lab</title>
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
                --active-accent: #10B981;
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
                max-width: 96%;
                width: 100%;
                box-sizing: border-box;
            }
            header {
                display: flex;
                justify-content: space-between;
                align-items: center;
                margin-bottom: 24px;
            }
            h1 {
                font-family: var(--font-display);
                font-size: 28px;
                font-weight: 800;
                color: var(--primary);
                margin: 0;
            }
            .controls-row {
                display: flex;
                gap: 12px;
                align-items: center;
            }
            .refresh-btn, .reset-filters-btn {
                background-color: var(--primary);
                color: white;
                border: none;
                padding: 10px 22px;
                border-radius: 8px;
                font-weight: 600;
                font-size: 14px;
                cursor: pointer;
                transition: background-color 0.2s, transform 0.1s;
                display: inline-flex;
                align-items: center;
                gap: 6px;
            }
            .reset-filters-btn {
                background-color: #EF4444;
            }
            .refresh-btn:hover {
                background-color: #0E1E7A;
            }
            .reset-filters-btn:hover {
                background-color: #DC2626;
            }
            .refresh-btn:active, .reset-filters-btn:active {
                transform: scale(0.98);
            }

            /* 상단 통합 필터 보드 스타일 */
            .filter-board {
                background-color: var(--card-bg);
                border-radius: 14px;
                box-shadow: 0 4px 20px rgba(148, 163, 184, 0.08);
                border: 1px solid var(--border);
                padding: 20px;
                margin-bottom: 20px;
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
                gap: 16px;
                width: 100%;
                box-sizing: border-box;
            }
            .filter-item {
                display: flex;
                flex-direction: column;
                gap: 8px;
            }
            .filter-item label {
                font-size: 11px;
                font-weight: 700;
                color: var(--primary);
                text-transform: uppercase;
                letter-spacing: 0.8px;
            }
            .filter-item input, .filter-item select {
                padding: 10px 12px;
                border: 1px solid var(--border);
                border-radius: 8px;
                font-size: 13px;
                color: var(--text);
                background-color: #F8FAFC;
                outline: none;
                transition: border-color 0.2s, box-shadow 0.2s, background-color 0.2s;
                width: 100%;
                box-sizing: border-box;
            }
            .filter-item input:focus, .filter-item select:focus {
                border-color: var(--primary);
                box-shadow: 0 0 0 3px rgba(20, 41, 160, 0.1);
                background-color: #FFFFFF;
            }
            /* 필터 활성화 상태 표시 */
            .filter-item.active label {
                color: var(--active-accent);
            }
            .filter-item.active input, .filter-item.active select {
                border-color: var(--active-accent);
                background-color: rgba(16, 185, 129, 0.03);
            }

            /* 테이블 영역 */
            .card {
                background-color: var(--card-bg);
                border-radius: 14px;
                box-shadow: 0 4px 20px rgba(148, 163, 184, 0.08);
                border: 1px solid var(--border);
                overflow-x: auto; /* 가로 스크롤을 활성화하여 14개 열이 구겨지지 않게 함 */
            }
            table {
                width: 100%;
                border-collapse: collapse;
                text-align: left;
                min-width: 100%; /* 대화면에서 전체 가로폭을 채우도록 백분율로 변경 */
            }
            th, td {
                padding: 16px 20px;
                border-bottom: 1px solid var(--border);
                font-size: 13.5px;
            }
            th {
                background-color: var(--primary-light);
                color: var(--primary);
                font-weight: 700;
                font-size: 12px;
                letter-spacing: 0.8px;
                user-select: none;
            }
            th.sortable {
                cursor: pointer;
                transition: background-color 0.2s;
            }
            th.sortable:hover {
                background-color: #DDE2F2;
            }
            .sort-indicator {
                margin-left: 4px;
                font-size: 11px;
                color: var(--text-muted);
            }
            .sort-indicator.active {
                color: var(--primary);
                font-weight: bold;
            }

            tr:last-child td {
                border-bottom: none;
            }
            tr:hover {
                background-color: #F8FAFC;
            }
            .badge {
                display: inline-block;
                padding: 4px 8px;
                border-radius: 6px;
                font-size: 11px;
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
                padding: 6px 12px;
                border-radius: 6px;
                font-weight: 600;
                font-size: 12px;
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
                font-size: 12px;
                font-weight: 600;
                margin-left: 8px;
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
            let allData = [];
            let currentFilteredData = [];
            
            // 정렬 상태
            let sortColumn = 'received_at';
            let sortOrder = 'desc';
            
            // 필터링 상태
            let activeFilters = {
                tester_name: '',
                watch: '',
                strap: '',
                exercise: '',
                wearing_position: '',
                wearing_tightness: ''
            };

            async function fetchEmails() {
                try {
                    const res = await fetch('/api/emails');
                    const json = await res.json();
                    if (json.status === 'success') {
                        allData = json.data;
                        
                        // 데이터 수집 후 드롭다운 목록 생성
                        populateSelectOptions();
                        applyFiltersAndRender();
                    }
                } catch (e) {
                    console.error("데이터 로드 중 오류 발생:", e);
                }
            }

            function copyToClipboard(text) {
                navigator.clipboard.writeText(text);
                alert("Quick Share 링크가 클립보드에 복사되었습니다!");
            }

            function exportToJSON() {
                if (currentFilteredData.length === 0) {
                    alert("추출할 데이터가 없습니다.");
                    return;
                }
                
                const exportData = currentFilteredData.map(item => ({
                    tester_name: item.tester_name || "",
                    received_at: item.received_at || "",
                    watch: item.watch || "",
                    share_link: item.share_link || ""
                }));

                const jsonString = JSON.stringify(exportData, null, 2);
                const blob = new Blob([jsonString], { type: "application/json;charset=utf-8;" });
                
                const now = new Date();
                const year = now.getFullYear();
                const month = String(now.getMonth() + 1).padStart(2, '0');
                const day = String(now.getDate()).padStart(2, '0');
                const dateStr = `${year}${month}${day}`;
                
                const link = document.createElement("a");
                const url = URL.createObjectURL(blob);
                link.setAttribute("href", url);
                link.setAttribute("download", `health_records_export_${dateStr}.json`);
                link.style.visibility = 'hidden';
                document.body.appendChild(link);
                link.click();
                document.body.removeChild(link);
            }

            // 테이블 헤더 정렬 토글
            function handleSort(column) {
                if (sortColumn === column) {
                    sortOrder = (sortOrder === 'asc') ? 'desc' : 'asc';
                } else {
                    sortColumn = column;
                    sortOrder = 'desc';
                }
                applyFiltersAndRender();
            }

            // 고유값들로 셀렉트 드롭다운 옵션 자동 갱신
            function populateSelectOptions() {
                const uniqueWatches = new Set();
                const uniqueStraps = new Set();
                const uniqueExercises = new Set();
                const uniquePositions = new Set();
                const uniqueTightnesses = new Set();

                allData.forEach(item => {
                    if (item.watch) uniqueWatches.add(item.watch.trim());
                    if (item.strap) uniqueStraps.add(item.strap.trim());
                    if (item.exercise) uniqueExercises.add(item.exercise.trim());
                    if (item.wearing_position) uniquePositions.add(item.wearing_position.trim());
                    if (item.wearing_tightness) uniqueTightnesses.add(item.wearing_tightness.trim());
                });

                updateSelectOptions('select-watch', uniqueWatches, activeFilters.watch);
                updateSelectOptions('select-strap', uniqueStraps, activeFilters.strap);
                updateSelectOptions('select-exercise', uniqueExercises, activeFilters.exercise);
                updateSelectOptions('select-position', uniquePositions, activeFilters.wearing_position);
                updateSelectOptions('select-tightness', uniqueTightnesses, activeFilters.wearing_tightness);
            }

            function updateSelectOptions(elementId, uniqueSet, currentValue) {
                const select = document.getElementById(elementId);
                if (!select) return;
                
                // 기존 '전체' 옵션 유지하고 초기화
                select.innerHTML = '<option value="">전체</option>';
                
                Array.from(uniqueSet).sort().forEach(val => {
                    const opt = document.createElement('option');
                    opt.value = val;
                    opt.textContent = val;
                    if (val === currentValue) {
                        opt.selected = true;
                    }
                    select.appendChild(opt);
                });
            }

            // 실시간 텍스트 검색 핸들러
            function handleTextFilter(value) {
                activeFilters.tester_name = value.trim();
                toggleItemActiveStyle('filter-tester-name', activeFilters.tester_name !== '');
                applyFiltersAndRender();
            }

            // 실시간 드롭다운 선택 핸들러
            function handleSelectFilter(filterKey, value, elementContainerId) {
                activeFilters[filterKey] = value;
                toggleItemActiveStyle(elementContainerId, value !== '');
                applyFiltersAndRender();
            }

            // 활성 필터 비주얼 변경
            function toggleItemActiveStyle(elementId, isActive) {
                const item = document.getElementById(elementId);
                if (item) {
                    if (isActive) {
                        item.classList.add('active');
                    } else {
                        item.classList.remove('active');
                    }
                }
            }

            // 모든 필터링 초기화
            function resetAllFilters() {
                activeFilters = {
                    tester_name: '',
                    watch: '',
                    strap: '',
                    exercise: '',
                    wearing_position: '',
                    wearing_tightness: ''
                };
                
                // UI 초기화
                document.getElementById('input-tester-name').value = '';
                document.getElementById('select-watch').value = '';
                document.getElementById('select-strap').value = '';
                document.getElementById('select-exercise').value = '';
                document.getElementById('select-position').value = '';
                document.getElementById('select-tightness').value = '';

                // 비주얼 클래스 제거
                const items = document.querySelectorAll('.filter-item');
                items.forEach(item => item.classList.remove('active'));

                applyFiltersAndRender();
            }

            // 필터 및 정렬 연산 프로세스
            function applyFiltersAndRender() {
                let data = [...allData];

                // 1. 필터링
                if (activeFilters.tester_name !== '') {
                    const searchLower = activeFilters.tester_name.toLowerCase();
                    data = data.filter(item => 
                        item.tester_name && item.tester_name.toLowerCase().includes(searchLower)
                    );
                }
                if (activeFilters.watch !== '') {
                    data = data.filter(item => item.watch && item.watch.trim() === activeFilters.watch);
                }
                if (activeFilters.strap !== '') {
                    data = data.filter(item => item.strap && item.strap.trim() === activeFilters.strap);
                }
                if (activeFilters.exercise !== '') {
                    data = data.filter(item => item.exercise && item.exercise.trim() === activeFilters.exercise);
                }
                if (activeFilters.wearing_position !== '') {
                    data = data.filter(item => item.wearing_position && item.wearing_position.trim() === activeFilters.wearing_position);
                }
                if (activeFilters.wearing_tightness !== '') {
                    data = data.filter(item => item.wearing_tightness && item.wearing_tightness.trim() === activeFilters.wearing_tightness);
                }

                // 2. 정렬
                data.sort((a, b) => {
                    let valA = a[sortColumn];
                    let valB = b[sortColumn];

                    // 수치형 특수 정렬 처리 (키, 몸무게)
                    if (sortColumn === 'height' || sortColumn === 'weight') {
                        let numA = parseFloat((valA || '0').replace(/[^0-9.]/g, '')) || 0;
                        let numB = parseFloat((valB || '0').replace(/[^0-9.]/g, '')) || 0;
                        return sortOrder === 'asc' ? numA - numB : numB - numA;
                    }

                    // 기본 알파벳 정렬
                    valA = (valA || '').toString().toLowerCase();
                    valB = (valB || '').toString().toLowerCase();
                    
                    if (valA < valB) return sortOrder === 'asc' ? -1 : 1;
                    if (valA > valB) return sortOrder === 'asc' ? 1 : -1;
                    return 0;
                });

                // 3. UI 렌더링
                currentFilteredData = data;
                renderTable(data);
                updateSortIndicators();
            }

            // 정렬 표시 갱신
            function updateSortIndicators() {
                const indicators = document.querySelectorAll('.sort-indicator');
                indicators.forEach(ind => {
                    ind.innerText = '↕';
                    ind.classList.remove('active');
                });

                const currentInd = document.getElementById(`sort-icon-${sortColumn}`);
                if (currentInd) {
                    currentInd.innerText = (sortOrder === 'asc') ? '▲' : '▼';
                    currentInd.classList.add('active');
                }
            }

            function renderTable(data) {
                const tbody = document.getElementById('table-body');
                if (data.length === 0) {
                    tbody.innerHTML = `<tr><td colspan="14" class="no-data">조건에 맞는 수집 내역이 없습니다.</td></tr>`;
                    return;
                }
                
                let html = '';
                data.forEach(item => {
                    const height = item.height || '-';
                    const weight = item.weight || '-';
                    const watch = item.watch || '알 수 없음';
                    const strap = item.strap || '알 수 없음';
                    const exercise = item.exercise || '알 수 없음';
                    const position = item.wearing_position || '-';
                    const tightness = item.wearing_tightness || '-';
                    const competitor = item.competitor_watch || '-';
                    const training = item.training_type || '-';
                    const location = item.location || '-';
                    const remarks = item.remarks || '';

                    // 단위 중복 방지 처리
                    let hStr = height;
                    if (hStr !== '-' && !hStr.toLowerCase().includes('cm')) hStr += ' cm';
                    let wStr = weight;
                    if (wStr !== '-' && !wStr.toLowerCase().includes('kg')) wStr += ' kg';

                    html += `
                        <tr>
                            <td style="color: var(--text-muted); font-size: 12.5px; white-space: nowrap;">${item.received_at}</td>
                            <td><span style="font-size: 13.5px; white-space: nowrap;">${item.tester_name}</span></td>
                            <td style="white-space: nowrap;">${hStr}</td>
                            <td style="white-space: nowrap;">${wStr}</td>
                            <td><span class="badge" style="background-color: #E8EBF5; color: #1429A0; white-space: nowrap;">${watch}</span></td>
                            <td style="white-space: nowrap;">${strap}</td>
                            <td><span style="color: #10B981; white-space: nowrap;">${exercise}</span></td>
                            <td style="white-space: nowrap;">${training}</td>
                            <td style="white-space: nowrap;">${position}</td>
                            <td style="white-space: nowrap;">${tightness}</td>
                            <td style="white-space: nowrap;">${competitor}</td>
                            <td style="white-space: nowrap;">${location}</td>
                            <td style="max-width: 180px; font-size: 12px; color: #475569; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;" title="${remarks}">
                                ${remarks ? remarks : '<span style="color: #cbd5e1; font-style: italic;">없음</span>'}
                            </td>
                            <td style="white-space: nowrap;">
                                ${item.share_link ? `
                                    <a href="${item.share_link}" target="_blank" class="link-btn">다운로드</a>
                                    <button class="copy-btn" onclick="copyToClipboard('${item.share_link}')">복사</button>
                                ` : '<span style="color: var(--text-muted);">링크 없음</span>'}
                            </td>
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
                <h1>HealthPort Lab</h1>
                <div class="controls-row">
                    <button class="reset-filters-btn" onclick="resetAllFilters()">필터 모두 초기화</button>
                    <button class="export-btn" onclick="exportToJSON()" style="background-color: #10B981; color: white; border: none; padding: 10px 16px; border-radius: 6px; cursor: pointer; font-weight: bold;">대시보드 데이터 JSON 추출 📥</button>
                    <button class="refresh-btn" onclick="fetchEmails()">데이터 새로고침</button>
                </div>
            </header>

            <!-- 상단 통합 필터 보드 카드 -->
            <div class="filter-board">
                <div class="filter-item" id="filter-tester-name">
                    <label>테스터 명 검색</label>
                    <input type="text" id="input-tester-name" placeholder="이름 입력..." oninput="handleTextFilter(this.value)">
                </div>
                <div class="filter-item" id="filter-watch">
                    <label>착용 워치</label>
                    <select id="select-watch" onchange="handleSelectFilter('watch', this.value, 'filter-watch')">
                        <option value="">전체</option>
                    </select>
                </div>
                <div class="filter-item" id="filter-strap">
                    <label>착용 스트랩</label>
                    <select id="select-strap" onchange="handleSelectFilter('strap', this.value, 'filter-strap')">
                        <option value="">전체</option>
                    </select>
                </div>
                <div class="filter-item" id="filter-exercise">
                    <label>운동 종목</label>
                    <select id="select-exercise" onchange="handleSelectFilter('exercise', this.value, 'filter-exercise')">
                        <option value="">전체</option>
                    </select>
                </div>
                <div class="filter-item" id="filter-position">
                    <label>착용 위치</label>
                    <select id="select-position" onchange="handleSelectFilter('wearing_position', this.value, 'filter-position')">
                        <option value="">전체</option>
                    </select>
                </div>
                <div class="filter-item" id="filter-tightness">
                    <label>조임 상태</label>
                    <select id="select-tightness" onchange="handleSelectFilter('wearing_tightness', this.value, 'filter-tightness')">
                        <option value="">전체</option>
                    </select>
                </div>
            </div>

            <!-- 데이터 테이블 카드 -->
            <div class="card">
                <table>
                    <thead>
                        <tr>
                            <th class="sortable" onclick="handleSort('received_at')">수신 일시 <span class="sort-indicator" id="sort-icon-received_at">▼</span></th>
                            <th class="sortable" onclick="handleSort('tester_name')">이름 <span class="sort-indicator" id="sort-icon-tester_name">↕</span></th>
                            <th class="sortable" onclick="handleSort('height')">키 <span class="sort-indicator" id="sort-icon-height">↕</span></th>
                            <th class="sortable" onclick="handleSort('weight')">몸무게 <span class="sort-indicator" id="sort-icon-weight">↕</span></th>
                            <th class="sortable" onclick="handleSort('watch')">착용 워치 <span class="sort-indicator" id="sort-icon-watch">↕</span></th>
                            <th class="sortable" onclick="handleSort('strap')">착용 스트랩 <span class="sort-indicator" id="sort-icon-strap">↕</span></th>
                            <th class="sortable" onclick="handleSort('exercise')">운동 종류 <span class="sort-indicator" id="sort-icon-exercise">↕</span></th>
                            <th class="sortable" onclick="handleSort('training_type')">훈련 종류 <span class="sort-indicator" id="sort-icon-training_type">↕</span></th>
                            <th class="sortable" onclick="handleSort('wearing_position')">착용 위치 <span class="sort-indicator" id="sort-icon-wearing_position">↕</span></th>
                            <th class="sortable" onclick="handleSort('wearing_tightness')">착용 정도 <span class="sort-indicator" id="sort-icon-wearing_tightness">↕</span></th>
                            <th class="sortable" onclick="handleSort('competitor_watch')">동시착용 모델 <span class="sort-indicator" id="sort-icon-competitor_watch">↕</span></th>
                            <th class="sortable" onclick="handleSort('location')">운동 장소 <span class="sort-indicator" id="sort-icon-location">↕</span></th>
                            <th>특이 사항</th>
                            <th>Quick Share</th>
                        </tr>
                    </thead>
                    <tbody id="table-body">
                        <tr>
                            <td colspan="14" style="text-align: center; padding: 50px; color: var(--text-muted);">데이터를 불러오는 중입니다...</td>
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
