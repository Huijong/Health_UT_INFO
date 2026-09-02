from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse
from motor.motor_asyncio import AsyncIOMotorClient
from typing import Optional
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
    
    # Startup migration & cleanup: link points_transactions to verification_emails
    try:
        cnt = await db["points_transactions"].count_documents({})
        if cnt == 0:
            print("[INFO] Migrating existing verification_emails to points_transactions...")
            cursor = db["verification_emails"].find({})
            async for email in cursor:
                received_at = email.get("received_at")
                if not received_at:
                    received_at = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
                month = received_at[:7]
                await db["points_transactions"].insert_one({
                    "tester_name": email.get("tester_name"),
                    "points": 1,
                    "memo": "자동 적립 (이메일 수집)",
                    "month": month,
                    "created_at": received_at,
                    "email_id": email["_id"]
                })
            print("[INFO] Points migration completed successfully.")
        else:
            # Cleanup orphans & link missing email_ids
            print("[INFO] Running points_transactions cleanup & linking...")
            cursor = db["points_transactions"].find({"memo": "자동 적립 (이메일 수집)"})
            async for trans in cursor:
                email_id = trans.get("email_id")
                if not email_id:
                    # Find matching email by tester_name and created_at
                    email_doc = await db["verification_emails"].find_one({
                        "tester_name": trans["tester_name"],
                        "received_at": trans["created_at"]
                    })
                    if email_doc:
                        await db["points_transactions"].update_one(
                            {"_id": trans["_id"]},
                            {"$set": {"email_id": email_doc["_id"]}}
                        )
                    else:
                        # Orphan points transaction! Delete it!
                        await db["points_transactions"].delete_one({"_id": trans["_id"]})
            print("[INFO] Points cleanup & linking completed.")
    except Exception as me:
        print(f"[ERROR] Points migration/cleanup failed: {me}")
    
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
    target_tester: Optional[str] = None

class DevicePing(BaseModel):
    tester_name: str
    watch: str
    strap: Optional[str] = None
    os_version: str
    device_uuid: Optional[str] = None
    email: Optional[str] = None
    last_seen_fame_month: Optional[str] = None
    app_version: Optional[str] = None

class NoticeAck(BaseModel):
    tester_name: str

class PointCreate(BaseModel):
    tester_name: Optional[str] = None
    points: Optional[float] = None
    memo: Optional[str] = None
    month: Optional[str] = None
    old_name: Optional[str] = None
    new_name: Optional[str] = None
    email: Optional[str] = None
    watch: Optional[str] = None
    custom_watch: Optional[str] = None
    strap: Optional[str] = None
    custom_strap: Optional[str] = None
    height: Optional[float] = None
    weight: Optional[float] = None

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
        if ping.strap:
            device_dict["strap"] = ping.strap
        if ping.device_uuid:
            device_dict["device_uuid"] = ping.device_uuid.strip()
        if ping.email:
            device_dict["email"] = ping.email.strip()
        if ping.last_seen_fame_month:
            device_dict["last_seen_fame_month"] = ping.last_seen_fame_month.strip()
        if ping.app_version:
            device_dict["app_version"] = ping.app_version.strip()
        
        # 만약 이메일 정보가 들어왔다면 이메일 기준으로 기기(유저) 식별 및 업데이트
        if ping.email:
            await db["devices"].update_one(
                {"email": ping.email.strip()},
                {"$set": device_dict},
                upsert=True
            )
        else:
            await db["devices"].update_one(
                {"tester_name": ping.tester_name},
                {"$set": device_dict},
                upsert=True
            )
        return JSONResponse(content={"status": "success", "message": "Ping received"})
    except Exception as e:
        return JSONResponse(content={"status": "error", "message": str(e)}, status_code=500)

@app.post("/api/devices")
async def create_point_adjustment_alt(pc: PointCreate, rename: bool = False):
    try:
        if db is None:
            return JSONResponse(content={"status": "error", "message": "Database not initialized"}, status_code=500)
        
        if rename:
            if not pc.old_name or not pc.new_name:
                return JSONResponse(content={"status": "error", "message": "old_name and new_name are required for rename"}, status_code=400)
            
            old_name = pc.old_name.strip()
            new_name = pc.new_name.strip()
            email = pc.email.strip() if pc.email else ""
            
            # 1. Update devices (이메일이 있다면 이메일 기준으로 최우선 업데이트)
            updated = False
            resolved_old_name = old_name # 기본값
            
            set_data = {"tester_name": new_name}
            if pc.watch is not None: set_data["watch"] = pc.watch
            if pc.custom_watch is not None: set_data["custom_watch"] = pc.custom_watch
            if pc.strap is not None: set_data["strap"] = pc.strap
            if pc.custom_strap is not None: set_data["custom_strap"] = pc.custom_strap
            if pc.height is not None: set_data["height"] = pc.height
            if pc.weight is not None: set_data["weight"] = pc.weight
            
            if email:
                # 닉네임 변경 전에 현재 등록되어 있는 tester_name 백업
                device = await db["devices"].find_one({"email": email})
                if device:
                    resolved_old_name = device.get("tester_name", old_name)
                
                res = await db["devices"].update_one(
                    {"email": email}, 
                    {"$set": set_data}
                )
                if res.modified_count > 0 or res.matched_count > 0:
                    updated = True
            
            # 이메일로 매칭되는 다큐먼트가 없었거나 이메일이 없는 경우, 기존 닉네임(old_name) 기준으로 업데이트 수행
            if not updated:
                await db["devices"].update_many(
                    {"tester_name": old_name}, 
                    {"$set": set_data}
                )
                # 만약 이메일 정보가 왔는데 DB에 email 필드가 없어서 매치되지 않았던 것이라면, email 필드도 같이 set해 줍니다.
                if email:
                    await db["devices"].update_many(
                        {"tester_name": new_name},
                        {"$set": {"email": email}}
                    )
            
            # 2. Update points_transactions (실제 매칭된 resolved_old_name 기준으로 랭킹 테이블 일괄 변경)
            await db["points_transactions"].update_many({"tester_name": resolved_old_name}, {"$set": {"tester_name": new_name}})
            
            # 3. Update verification_emails (실제 매칭된 resolved_old_name 기준으로 대시보드 테이블 일괄 변경)
            await db["verification_emails"].update_many({"tester_name": resolved_old_name}, {"$set": {"tester_name": new_name}})
            
            return JSONResponse(content={"status": "success", "message": "Nickname renamed successfully"})
            
        created_at = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
        
        await db["points_transactions"].insert_one({
            "tester_name": pc.tester_name,
            "points": pc.points,
            "memo": pc.memo,
            "month": pc.month,
            "created_at": created_at
        })
        return JSONResponse(content={"status": "success", "message": "Points transaction added successfully"})
    except Exception as e:
        return JSONResponse(content={"status": "error", "message": str(e)}, status_code=500)

@app.get("/api/devices")
async def get_devices(summary: bool = False, latest_apk: bool = False, rankings: bool = False, points_history: bool = False, check_nickname: Optional[str] = None, check_uuid: Optional[str] = None, check_email: Optional[str] = None, email: Optional[str] = None, month: Optional[str] = None, tester_name: Optional[str] = None):
    try:
        if db is None:
            return JSONResponse(content={"status": "error", "message": "Database not initialized"}, status_code=500)
            
        if check_email:
            device = await db["devices"].find_one({"email": check_email.strip()})
            if device:
                return JSONResponse(content={
                    "status": "success", 
                    "exists": True, 
                    "tester_name": device.get("tester_name", ""),
                    "watch": device.get("watch", ""),
                    "strap": device.get("strap", ""),
                    "last_seen_fame_month": device.get("last_seen_fame_month", "")
                })
            else:
                return JSONResponse(content={"status": "success", "exists": False})

        if check_uuid:
            device = await db["devices"].find_one({"device_uuid": check_uuid.strip()})
            if device:
                return JSONResponse(content={"status": "success", "exists": True, "tester_name": device.get("tester_name", "")})
            else:
                return JSONResponse(content={"status": "success", "exists": False})

        if check_nickname:
            # 닉네임 중복 검사 시, 동일 기기(이메일)가 소유한 닉네임인 경우에는 중복(exists=true)이 아니라고 판단해 줘야 합니다.
            query = {"tester_name": check_nickname.strip()}
            device = await db["devices"].find_one(query)
            if device:
                # 찾은 기기의 이메일이 현재 요청 보낸 이메일과 같다면 자신의 닉네임이므로 중복 아님 처리
                if email and device.get("email") == email.strip():
                    return JSONResponse(content={"status": "success", "exists": False})
                return JSONResponse(content={
                    "status": "success", 
                    "exists": True,
                    "watch": device.get("watch", ""),
                    "strap": device.get("strap", "")
                })
            return JSONResponse(content={"status": "success", "exists": False})

        if points_history:
            if not tester_name:
                return JSONResponse(content={"status": "error", "message": "tester_name is required for points history"}, status_code=400)
            
            query = {"tester_name": tester_name}
            if month:
                query["month"] = month
                
            cursor = db["points_transactions"].find(query).sort("created_at", -1)
            history = await cursor.to_list(length=1000)
            for h in history:
                h["_id"] = str(h["_id"])
                if isinstance(h.get("created_at"), datetime):
                    h["created_at"] = h["created_at"].isoformat()
                if "email_id" in h:
                    h["email_id"] = str(h["email_id"])
            return JSONResponse(content={"status": "success", "data": history})

        if rankings:
            if not month:
                month = datetime.utcnow().strftime("%Y-%m")
            
            try:
                curr_yr, curr_mon = map(int, month.split("-"))
                if curr_mon == 1:
                    prev_month = f"{curr_yr - 1}-12"
                else:
                    prev_month = f"{curr_yr}-{str(curr_mon - 1).zfill(2)}"
            except Exception:
                return JSONResponse(content={"status": "error", "message": "Invalid month format. Use YYYY-MM"}, status_code=400)

            async def get_monthly_counts(target_month):
                pipeline = [
                    {"$match": {"month": target_month}},
                    {
                        "$group": {
                            "_id": "$tester_name",
                            "points": {"$sum": "$points"},
                            "submissions": {
                                "$sum": {
                                    "$cond": [
                                        {"$eq": [{"$indexOfCP": ["$memo", "자동 적립"]}, 0]},
                                        1,
                                        0
                                    ]
                                }
                            }
                        }
                    },
                    {"$match": {"submissions": {"$gt": 0}}},
                    {"$sort": {"points": -1}}
                ]
                cursor = db["points_transactions"].aggregate(pipeline)
                return await cursor.to_list(length=1000)

            curr_data = await get_monthly_counts(month)
            prev_data = await get_monthly_counts(prev_month)

            def assign_ranks(data_list):
                ranks = {}
                for i, item in enumerate(data_list):
                    name = item["_id"]
                    cnt = item["points"]
                    if i > 0 and cnt == data_list[i-1]["points"]:
                        ranks[name] = ranks[data_list[i-1]["_id"]]
                    else:
                        ranks[name] = i + 1
                return ranks

            curr_ranks = assign_ranks(curr_data)
            prev_ranks = assign_ranks(prev_data)

            rankings_list = []
            for item in curr_data:
                name = item["_id"]
                points = item["points"]
                submissions = item["submissions"]
                rank = curr_ranks[name]
                
                if name in prev_ranks:
                    diff = prev_ranks[name] - rank
                    if diff > 0:
                        change = f"+{diff}"
                    elif diff < 0:
                        change = str(diff)
                    else:
                        change = "0"
                else:
                    change = "new"

                rankings_list.append({
                    "tester_name": name,
                    "points": points,
                    "submissions": submissions,
                    "rank": rank,
                    "change": change
                })

            total_testers = len(rankings_list)
            total_points = sum(item["points"] for item in curr_data)
            avg_points = round(total_points / total_testers, 1) if total_testers > 0 else 0.0

            my_rank = None
            my_points = 0
            my_submissions = 0
            next_rank_info = None

            if tester_name:
                for idx, r in enumerate(rankings_list):
                    if r["tester_name"] == tester_name:
                        my_rank = r["rank"]
                        my_points = r["points"]
                        my_submissions = r["submissions"]
                        
                        target_idx = idx - 1
                        while target_idx >= 0:
                            above = rankings_list[target_idx]
                            if above["points"] > my_points:
                                next_rank_info = {
                                    "tester_name": above["tester_name"],
                                    "rank": above["rank"],
                                    "points": above["points"],
                                    "diff": above["points"] - my_points
                                }
                                break
                            target_idx -= 1
                        break

            return JSONResponse(content={
                "status": "success",
                "data": {
                    "rankings": rankings_list,
                    "meta": {
                        "total_testers": total_testers,
                        "avg_submissions": avg_points,
                        "my_rank": my_rank,
                        "my_count": my_points,
                        "my_submissions": my_submissions,
                        "next_rank": next_rank_info
                    }
                }
            })

        if latest_apk:
            import os
            import glob
            apk_dir = os.path.join(os.path.dirname(__file__), "static", "apks")
            if not os.path.exists(apk_dir):
                return JSONResponse(content={"status": "error", "message": "APK directory not found"}, status_code=404)
            
            search_pattern = os.path.join(apk_dir, "HealthPort*.apk")
            apk_files = glob.glob(search_pattern)
            if not apk_files:
                return JSONResponse(content={"status": "error", "message": "No HealthPort APK found"}, status_code=404)
            
            apk_files.sort()
            latest_apk_path = apk_files[-1]
            latest_filename = os.path.basename(latest_apk_path)
            
            return JSONResponse(content={
                "status": "success", 
                "filename": latest_filename, 
                "url": f"/static/apks/{latest_filename}"
            })
            
        if summary:
            pipeline = [
                {
                    "$sort": { "received_at": -1 }
                },
                {
                    "$group": {
                        "_id": "$tester_name",
                        "total_count": { "$sum": 1 },
                        "last_received_at": { "$first": "$received_at" },
                        "app_version": { "$first": "$app_version" }
                    }
                },
                {
                    "$project": {
                        "tester_name": "$_id",
                        "total_count": 1,
                        "last_received_at": 1,
                        "app_version": 1,
                        "_id": 0
                    }
                },
                {
                    "$sort": { "last_received_at": -1 }
                }
            ]
            cursor = db["verification_emails"].aggregate(pipeline)
            result = await cursor.to_list(length=200)
            return JSONResponse(content={"status": "success", "data": result})

        cursor = db["devices"].find({}).sort("last_active_at", -1)
        raw_devices = await cursor.to_list(length=200)
        
        devices = []
        seen_names = set()
        
        for d in raw_devices:
            t_name = d.get("tester_name")
            # 닉네임이 같으면 최신 기록(먼저 나온 것)만 남기고 건너뜀
            if t_name and t_name in seen_names:
                continue
            if t_name:
                seen_names.add(t_name)
                
            d["_id"] = str(d["_id"])
            if isinstance(d.get("last_active_at"), datetime):
                d["last_active_at"] = d["last_active_at"].isoformat() + "Z"
            devices.append(d)
            
        return JSONResponse(content={"status": "success", "data": devices})
    except Exception as e:
        return JSONResponse(content={"status": "error", "message": str(e)}, status_code=500)

@app.delete("/api/devices/{device_id}")
async def delete_device(device_id: str):
    try:
        if db is None:
            return JSONResponse(content={"status": "error", "message": "Database not initialized"}, status_code=500)
        from bson import ObjectId
        try:
            obj_id = ObjectId(device_id)
        except Exception:
            return JSONResponse(content={"status": "error", "message": "Invalid device ID format"}, status_code=400)
            
        result = await db["devices"].delete_one({"_id": obj_id})
        if result.deleted_count == 1:
            return JSONResponse(content={"status": "success", "message": "Device deleted"})
        else:
            return JSONResponse(content={"status": "error", "message": "Device not found"}, status_code=404)
    except Exception as e:
        return JSONResponse(content={"status": "error", "message": str(e)}, status_code=500)

@app.delete("/api/emails/{email_id}")
async def delete_email_record(email_id: str):
    try:
        if db is None:
            return JSONResponse(content={"status": "error", "message": "Database not initialized"}, status_code=500)
        from bson import ObjectId
        try:
            obj_id = ObjectId(email_id)
        except Exception:
            return JSONResponse(content={"status": "error", "message": "Invalid ID format"}, status_code=400)
        
        result = await db["verification_emails"].delete_one({"_id": obj_id})
        if result.deleted_count == 1:
            # Also delete points transaction associated with this email_id
            await db["points_transactions"].delete_one({"email_id": obj_id})
            return JSONResponse(content={"status": "success", "message": "Record deleted successfully"})
        else:
            return JSONResponse(content={"status": "error", "message": "Record not found"}, status_code=404)
    except Exception as e:
        return JSONResponse(content={"status": "error", "message": str(e)}, status_code=500)

@app.post("/api/points")
async def create_point_adjustment(pc: PointCreate):
    try:
        if db is None:
            return JSONResponse(content={"status": "error", "message": "Database not initialized"}, status_code=500)
        
        created_at = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
        
        await db["points_transactions"].insert_one({
            "tester_name": pc.tester_name,
            "points": pc.points,
            "memo": pc.memo,
            "month": pc.month,
            "created_at": created_at
        })
        return JSONResponse(content={"status": "success", "message": "Points transaction added successfully"})
    except Exception as e:
        return JSONResponse(content={"status": "error", "message": str(e)}, status_code=500)

@app.get("/api/points/{tester_name}/history")
async def get_tester_points_history(tester_name: str, month: Optional[str] = None):
    try:
        if db is None:
            return JSONResponse(content={"status": "error", "message": "Database not initialized"}, status_code=500)
            
        query = {"tester_name": tester_name}
        if month:
            query["month"] = month
            
        cursor = db["points_transactions"].find(query).sort("created_at", -1)
        history = await cursor.to_list(length=1000)
        for h in history:
            h["_id"] = str(h["_id"])
            if isinstance(h.get("created_at"), datetime):
                h["created_at"] = h["created_at"].isoformat()
            if "email_id" in h:
                h["email_id"] = str(h["email_id"])
        return JSONResponse(content={"status": "success", "data": history})
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
async def get_all_notices(tester_name: Optional[str] = None):
    try:
        if db is None:
            return JSONResponse(content={"status": "error", "message": "Database not initialized"}, status_code=500)
            
        query = {
            "$or": [
                {"target_tester": None},
                {"target_tester": {"$exists": False}}
            ]
        }
        if tester_name:
            query["$or"].append({"target_tester": tester_name})

        cursor = db["notices"].find(query).sort("created_at", -1)
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
        if notice.target_tester:
            notice_dict["target_tester"] = notice.target_tester
        
        result = await db["notices"].insert_one(notice_dict)
        notice_id = str(result.inserted_id)
        
        # 실시간 FCM 토픽 푸시 알림 발송
        try:
            if notice.target_tester:
                topic = f"tester_{notice.target_tester.encode('utf-8').hex()}"
            else:
                topic = "notices"

            message = messaging.Message(
                notification=messaging.Notification(
                    title=notice.title,
                    body=notice.content[:100] + ("..." if len(notice.content) > 100 else ""),
                ),
                android=messaging.AndroidConfig(
                    priority="high",
                    notification=messaging.AndroidNotification(
                        channel_id="high_importance_channel"
                    )
                ),
                topic=topic,
                data={
                    "notice_id": notice_id,
                    "title": notice.title,
                    "body": notice.content[:100] + ("..." if len(notice.content) > 100 else "")
                }
            )
            response = messaging.send(message)
            print(f"[INFO] FCM 푸시 메시지 전송 성공 (Topic: {topic}): {response}")
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
                min-width: 1400px; /* 열이 많을 때 구겨지지 않고 가로 스크롤바가 화면 단위에서 생성되도록 강제 설정 */
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
            .delete-record-btn {
                background: none;
                border: none;
                color: #EF4444;
                cursor: pointer;
                font-size: 12px;
                font-weight: 600;
                margin-left: 10px;
                text-decoration: underline;
            }
            .no-data {
                text-align: center;
                padding: 50px;
                color: var(--text-muted);
                font-style: italic;
                font-size: 15px;
            }
            /* 첨부파일 미니 배지 스타일 */
            .attach-badge {
                display: inline-block;
                padding: 2px 6px;
                border-radius: 4px;
                font-size: 10px;
                font-weight: 700;
                margin-right: 4px;
                text-align: center;
                letter-spacing: 0.3px;
                user-select: none;
            }
            .attach-badge.present {
                background-color: rgba(16, 185, 129, 0.1);
                color: #10B981;
                border: 1px solid rgba(16, 185, 129, 0.25);
            }
            .attach-badge.absent {
                background-color: rgba(241, 245, 249, 0.05);
                color: #94A3B8;
                border: 1px solid rgba(226, 232, 240, 0.15);
                font-weight: 500;
                opacity: 0.5;
            }
            
            /* 센서/데이터 검증 이슈 배지 스타일 */
            .sensor-badge {
                display: inline-block;
                padding: 2px 6px;
                border-radius: 4px;
                font-size: 10.5px;
                font-weight: 700;
                margin-right: 4px;
                text-align: center;
                cursor: default;
                position: relative;
                user-select: none;
            }
            .sensor-badge.normal {
                background-color: rgba(241, 245, 249, 0.05);
                color: #94A3B8;
                border: 1px solid rgba(226, 232, 240, 0.15);
                font-weight: 500;
                opacity: 0.5;
            }
            .sensor-badge.issue {
                background-color: rgba(239, 68, 68, 0.1);
                color: #EF4444;
                border: 1px solid rgba(239, 68, 68, 0.25);
            }
            .sensor-badge.na {
                background-color: rgba(148, 163, 184, 0.05);
                color: #94A3B8;
                border: 1px solid rgba(226, 232, 240, 0.15);
                font-weight: 500;
                opacity: 0.5;
            }
            
            /* CSS 툴팁 처리 */
            .sensor-badge[data-tooltip]::after {
                content: attr(data-tooltip);
                position: absolute;
                bottom: 125%;
                left: 50%;
                transform: translateX(-50%);
                background-color: #1E293B;
                color: #F8FAFC;
                padding: 6px 10px;
                border-radius: 6px;
                font-size: 11px;
                font-weight: 500;
                white-space: pre-wrap;
                width: 180px;
                box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
                border: 1px solid rgba(255, 255, 255, 0.08);
                display: none;
                z-index: 100;
                text-align: left;
                line-height: 1.4;
            }
            .sensor-badge[data-tooltip]:hover::after {
                display: block;
            }
            
            /* 컬럼 선택 보드 스타일 */
            .column-selector-board {
                background-color: var(--card-bg);
                border-radius: 14px;
                box-shadow: 0 4px 20px rgba(148, 163, 184, 0.08);
                border: 1px solid var(--border);
                padding: 16px 20px;
                margin-bottom: 20px;
                display: flex;
                flex-wrap: wrap;
                align-items: center;
                gap: 16px;
                width: 100%;
                box-sizing: border-box;
            }
            .column-selector-title {
                font-size: 12px;
                font-weight: 700;
                color: var(--primary);
                text-transform: uppercase;
                letter-spacing: 0.8px;
                margin-right: 8px;
            }
            .column-checkbox-item {
                display: flex;
                align-items: center;
                gap: 6px;
                font-size: 13px;
                color: var(--text);
                cursor: pointer;
                user-select: none;
            }
            .column-checkbox-item input {
                cursor: pointer;
                accent-color: var(--primary);
                width: 16px;
                height: 16px;
            }
            /* 드로어 및 모달 스타일 */
            .drawer-overlay {
                position: fixed;
                z-index: 1999;
                left: 0;
                top: 0;
                width: 100%;
                height: 100%;
                background-color: rgba(15, 23, 42, 0.4);
                backdrop-filter: blur(2px);
                display: none;
            }
            .drawer {
                position: fixed;
                z-index: 2000;
                right: -450px;
                top: 0;
                width: 420px;
                height: 100%;
                background-color: var(--card-bg);
                box-shadow: -5px 0 25px rgba(15, 23, 42, 0.15);
                border-left: 1px solid var(--border);
                transition: right 0.3s cubic-bezier(0.4, 0, 0.2, 1);
                display: flex;
                flex-direction: column;
                box-sizing: border-box;
            }
            .drawer.open {
                right: 0;
            }
            .drawer-header {
                padding: 20px 24px;
                border-bottom: 1px solid var(--border);
                display: flex;
                justify-content: space-between;
                align-items: center;
                background-color: #FAFAFA;
            }
            .drawer-header h2 {
                font-family: var(--font-display);
                font-size: 17px;
                font-weight: 700;
                margin: 0;
                color: var(--text);
            }
            .close-drawer {
                font-size: 24px;
                font-weight: bold;
                color: var(--text-muted);
                cursor: pointer;
                transition: color 0.2s;
            }
            .close-drawer:hover {
                color: #EF4444;
            }
            .drawer-body {
                padding: 24px;
                flex: 1;
                overflow-y: auto;
                display: flex;
                flex-direction: column;
                gap: 20px;
            }
            .tester-badge-container {
                display: flex;
                justify-content: space-between;
                align-items: center;
                background-color: var(--primary-light);
                padding: 16px;
                border-radius: 12px;
                border: 1px solid rgba(20, 41, 160, 0.1);
            }
            .tester-badge-title {
                font-size: 13px;
                font-weight: 600;
                color: var(--primary);
            }
            .tester-accumulated-points {
                font-size: 20px;
                font-weight: 800;
                color: var(--primary);
            }
            .history-section {
                display: flex;
                flex-direction: column;
                gap: 12px;
            }
            .history-section h3 {
                font-size: 14px;
                font-weight: 700;
                margin: 0 0 4px 0;
                color: var(--text);
            }
            .history-list {
                display: flex;
                flex-direction: column;
                gap: 8px;
                max-height: 280px;
                overflow-y: auto;
                padding-right: 4px;
            }
            .history-item {
                display: flex;
                justify-content: space-between;
                align-items: center;
                padding: 10px 12px;
                background-color: #F8FAFC;
                border: 1px solid var(--border);
                border-radius: 8px;
                font-size: 12.5px;
            }
            .history-item-left {
                display: flex;
                flex-direction: column;
                gap: 2px;
            }
            .history-item-memo {
                font-weight: 600;
                color: var(--text);
            }
            .history-item-date {
                font-size: 11px;
                color: var(--text-muted);
            }
            .history-item-points {
                font-weight: 700;
            }
            .history-item-points.plus {
                color: var(--success);
            }
            .history-item-points.minus {
                color: #EF4444;
            }
            .modal-adjust-btn {
                background-color: #F1F5F9;
                border: 1px solid var(--border);
                border-radius: 8px;
                width: 40px;
                height: 40px;
                font-size: 16px;
                font-weight: bold;
                cursor: pointer;
                display: flex;
                align-items: center;
                justify-content: center;
                transition: background-color 0.2s;
            }
            .modal-adjust-btn.plus {
                color: var(--success);
            }
            .modal-adjust-btn.minus {
                color: #EF4444;
            }
            .modal-adjust-btn:hover {
                background-color: #E2E8F0;
            }
            .preset-btn {
                background-color: #F8FAFC;
                border: 1px solid var(--border);
                border-radius: 6px;
                padding: 8px;
                font-size: 11px;
                font-weight: 600;
                cursor: pointer;
                transition: all 0.2s;
            }
            .preset-btn.plus {
                color: var(--success);
            }
            .preset-btn.plus:hover {
                background-color: rgba(16, 185, 129, 0.08);
                border-color: rgba(16, 185, 129, 0.3);
            }
            .preset-btn.minus {
                color: #EF4444;
            }
            .preset-btn.minus:hover {
                background-color: rgba(239, 68, 68, 0.08);
                border-color: rgba(239, 68, 68, 0.3);
            }
            .modal-confirm-btn {
                background-color: var(--primary);
                color: white;
                border: none;
                border-radius: 8px;
                font-weight: 600;
                cursor: pointer;
                transition: background-color 0.2s;
            }
            .modal-confirm-btn:hover {
                background-color: #0E1E7A;
            }
            .adjust-points-btn {
                background: none;
                border: none;
                color: #10B981;
                cursor: pointer;
                font-size: 12px;
                font-weight: 600;
                margin-left: 8px;
                text-decoration: underline;
                padding: 0;
            }
            .adjust-points-btn:hover {
                color: #059669;
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
                wearing_tightness: '',
                location: '',
                training_type: ''
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
                
                const exportData = currentFilteredData.map(item => {
                    const cleanItem = { ...item };
                    delete cleanItem._id;
                    return cleanItem;
                });

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
                const uniqueLocations = new Set();
                const uniqueTrainingTypes = new Set();

                allData.forEach(item => {
                    if (item.watch) uniqueWatches.add(item.watch.trim());
                    if (item.strap) uniqueStraps.add(item.strap.trim());
                    if (item.exercise) uniqueExercises.add(item.exercise.trim());
                    if (item.wearing_position) uniquePositions.add(item.wearing_position.trim());
                    if (item.wearing_tightness) uniqueTightnesses.add(item.wearing_tightness.trim());
                    if (item.location) uniqueLocations.add(item.location.trim());
                    if (item.training_type) uniqueTrainingTypes.add(item.training_type.trim());
                });

                updateSelectOptions('select-watch', uniqueWatches, activeFilters.watch);
                updateSelectOptions('select-strap', uniqueStraps, activeFilters.strap);
                updateSelectOptions('select-exercise', uniqueExercises, activeFilters.exercise);
                updateSelectOptions('select-position', uniquePositions, activeFilters.wearing_position);
                updateSelectOptions('select-tightness', uniqueTightnesses, activeFilters.wearing_tightness);
                updateSelectOptions('select-location', uniqueLocations, activeFilters.location);
                updateSelectOptions('select-training-type', uniqueTrainingTypes, activeFilters.training_type);
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
                    wearing_tightness: '',
                    location: '',
                    training_type: ''
                };
                
                // UI 초기화
                document.getElementById('input-tester-name').value = '';
                document.getElementById('select-watch').value = '';
                document.getElementById('select-strap').value = '';
                document.getElementById('select-exercise').value = '';
                document.getElementById('select-position').value = '';
                document.getElementById('select-tightness').value = '';
                document.getElementById('select-location').value = '';
                document.getElementById('select-training-type').value = '';

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
                if (activeFilters.location !== '') {
                    data = data.filter(item => item.location && item.location.trim() === activeFilters.location);
                }
                if (activeFilters.training_type !== '') {
                    data = data.filter(item => item.training_type && item.training_type.trim() === activeFilters.training_type);
                }

                // 2. 정렬
                data.sort((a, b) => {
                    let valA = a[sortColumn];
                    let valB = b[sortColumn];

                    // 수치형 특수 정렬 처리 (키, 몸무게, 거리)
                    if (sortColumn === 'height' || sortColumn === 'weight' || sortColumn === 'distance') {
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

            function linkify(text) {
                if (!text) return '<span style="color: #cbd5e1; font-style: italic;">없음</span>';
                const urlRegex = /(https?:\/\/[^\s]+)/g;
                return text.replace(urlRegex, function(url) {
                    return `<a href="${url}" target="_blank" style="color: var(--primary); text-decoration: underline; word-break: break-all;">${url}</a>`;
                });
            }

            function renderTable(data) {
                const tbody = document.getElementById('table-body');
                if (data.length === 0) {
                    tbody.innerHTML = `<tr><td colspan="16" class="no-data">조건에 맞는 수집 내역이 없습니다.</td></tr>`;
                    return;
                }
                
                let html = '';
                data.forEach(item => {
                    const watch = item.watch || '알 수 없음';
                    const strap = item.strap || '알 수 없음';
                    const exercise = item.exercise || '알 수 없음';
                    const position = item.wearing_position || '-';
                    const tightness = item.wearing_tightness || '-';
                    const competitor = item.competitor_watch || '-';
                    const training = item.training_type || '-';
                    const distance = item.distance || '-';
                    const location = item.location || '-';
                    const remarks = item.remarks || '';
                    const remarksHtml = linkify(remarks);
                    
                    const consentGiven = item.consent_given || 'N';
                    const consentDate = item.consent_date || '';
                    const consentHtml = consentGiven === 'Y' 
                        ? `<span class="badge" style="background-color: rgba(16, 185, 129, 0.1); color: #10B981; font-weight: bold; white-space: nowrap;" title="동의 일시: ${consentDate}">동의 (Y)</span>` 
                        : `<span class="badge" style="background-color: rgba(239, 68, 68, 0.1); color: #EF4444; font-weight: bold; white-space: nowrap;">미동의 (N)</span>`;
 
                    const appVersion = item.app_version || '-';
                    const shealthVersion = item.shealth_version || '-';
 
                    // 첨부파일 미니 배지 구성
                    const fitBadge = item.has_fit === 'Y' 
                        ? '<span class="attach-badge present" title="FIT 파일 첨부됨">FIT</span>' 
                        : '<span class="attach-badge absent" title="FIT 파일 없음">FIT</span>';
                    const garminBadge = item.has_garmin === 'Y' 
                        ? '<span class="attach-badge present" title="Garmin FIT 파일 첨부됨">GAR</span>' 
                        : '<span class="attach-badge absent" title="Garmin FIT 파일 없음">GAR</span>';
                    const colaBadge = item.has_cola === 'Y' 
                        ? '<span class="attach-badge present" title="COLA 파일 첨부됨">COLA</span>' 
                        : '<span class="attach-badge absent" title="COLA 파일 없음">COLA</span>';
                    const logBadge = item.has_log === 'Y' 
                        ? '<span class="attach-badge present" title="로그 파일 첨부됨">LOG</span>' 
                        : '<span class="attach-badge absent" title="로그 파일 없음">LOG</span>';
                    const imgCount = item.capture_count || 0;
                    const imgBadge = imgCount > 0 
                        ? `<span class="attach-badge present" title="운동 캡처 ${imgCount}장 첨부됨">IMG (${imgCount})</span>` 
                        : '<span class="attach-badge absent" title="운동 캡처 없음">IMG</span>';

                    const attachmentsHtml = `<div style="display: flex; align-items: center; justify-content: center; white-space: nowrap;">${fitBadge}${garminBadge}${colaBadge}${logBadge}${imgBadge}</div>`;

                    // 센서/데이터 이슈 검증 배지 세트 구성
                    const gpsStat = item.gps_status || '정상';
                    const gpsMem = item.gps_memo || '';
                    const gpsClass = gpsStat === 'N/A' ? 'na' : (gpsStat === '확인 필요' ? 'issue' : 'normal');
                    const gpsTooltip = gpsMem ? `data-tooltip="GPS 메모: ${gpsMem}"` : '';

                    const hrStat = item.hr_status || '정상';
                    const hrMem = item.hr_memo || '';
                    const hrClass = hrStat === 'N/A' ? 'na' : (hrStat === '확인 필요' ? 'issue' : 'normal');
                    const hrTooltip = hrMem ? `data-tooltip="심박수 메모: ${hrMem}"` : '';

                    const paceStat = item.pace_status || '정상';
                    const paceMem = item.pace_memo || '';
                    const paceClass = paceStat === 'N/A' ? 'na' : (paceStat === '확인 필요' ? 'issue' : 'normal');
                    const paceTooltip = paceMem ? `data-tooltip="페이스 메모: ${paceMem}"` : '';

                    const altStat = item.altitude_status || '정상';
                    const altMem = item.altitude_memo || '';
                    const altClass = altStat === 'N/A' ? 'na' : (altStat === '확인 필요' ? 'issue' : 'normal');
                    const altTooltip = altMem ? `data-tooltip="고도 메모: ${altMem}"` : '';

                    const verificationBadgesHtml = `
                        <div style="display: flex; gap: 4px; justify-content: center; align-items: center; white-space: nowrap;">
                            <span class="sensor-badge ${gpsClass}" ${gpsTooltip}>GPS</span>
                            <span class="sensor-badge ${hrClass}" ${hrTooltip}>HR</span>
                            <span class="sensor-badge ${paceClass}" ${paceTooltip}>페이스</span>
                            <span class="sensor-badge ${altClass}" ${altTooltip}>고도</span>
                        </div>
                    `;

                    // 컬럼 가시성 체크박스 상태 읽기
                    const showConsent = document.getElementById('col-show-consent')?.checked ? '' : 'display: none;';
                    const showStrap = document.getElementById('col-show-strap')?.checked ? '' : 'display: none;';
                    const showPosition = document.getElementById('col-show-position')?.checked ? '' : 'display: none;';
                    const showTightness = document.getElementById('col-show-tightness')?.checked ? '' : 'display: none;';
                    const showVersion = document.getElementById('col-show-version')?.checked ? '' : 'display: none;';

                    html += `
                        <tr>
                            <td style="color: var(--text-muted); font-size: 12.5px; white-space: nowrap;">${item.received_at}</td>
                            <td><span style="font-size: 13.5px; white-space: nowrap;">${item.tester_name}</span></td>
                            <td class="col-consent" style="${showConsent}">${consentHtml}</td>
                            <td><span class="badge" style="background-color: #E8EBF5; color: #1429A0; white-space: nowrap;">${watch}</span></td>
                            <td class="col-strap" style="${showStrap} white-space: nowrap;">${strap}</td>
                            <td><span style="color: #10B981; white-space: nowrap;">${exercise}</span></td>
                            <td style="white-space: nowrap;">${training}</td>
                            <td style="white-space: nowrap;">${distance}</td>
                            <td class="col-position" style="${showPosition} white-space: nowrap;">${position}</td>
                            <td class="col-tightness" style="${showTightness} white-space: nowrap;">${tightness}</td>
                            <td style="white-space: nowrap;">${competitor}</td>
                            <td style="white-space: nowrap;">${location}</td>
                            <td style="text-align: center;">${verificationBadgesHtml}</td>
                            <td style="min-width: 200px; max-width: 350px; font-size: 12.5px; color: #475569; word-break: break-all;">
                                ${remarksHtml}
                            </td>
                            <td style="text-align: center;">${attachmentsHtml}</td>
                            <td class="col-version" style="${showVersion}"><span style="font-size: 13px; color: #475569; white-space: nowrap;">${appVersion} / ${shealthVersion}</span></td>
                            <td style="white-space: nowrap;">
                                ${item.share_link ? `
                                    <a href="${item.share_link}" target="_blank" class="link-btn">다운로드</a>
                                    <button class="copy-btn" onclick="copyToClipboard('${item.share_link}')">복사</button>
                                ` : '<span style="color: var(--text-muted);">링크 없음</span>'}
                                <button class="adjust-points-btn" onclick="openPointsDrawer('${item.tester_name.replace(/'/g, "\\'")}')">P 가감</button>
                                <button class="delete-record-btn" onclick="deleteRecord('${item._id}')">삭제</button>
                            </td>
                        </tr>
                    `;
                });
                tbody.innerHTML = html;
            }

            async function deleteRecord(id) {
                if (!confirm(`정말로 이 수집 내역을 삭제하시겠습니까?\n데이터베이스에서도 영구 삭제되며 복구할 수 없습니다.`)) {
                    return;
                }
                try {
                    const response = await fetch(`/api/emails/${id}`, {
                        method: 'DELETE'
                    });
                    const result = await response.json();
                    if (result.status === 'success') {
                        alert("내역이 정상적으로 삭제되었습니다.");
                        fetchEmails(); // 데이터 새로고침
                    } else {
                        alert("삭제 실패: " + result.message);
                    }
                } catch (e) {
                    alert("에러 발생: " + e);
                }
            }

            function toggleColumn(colClass, checkboxId) {
                const isChecked = document.getElementById(checkboxId).checked;
                const headers = document.querySelectorAll('th.' + colClass);
                headers.forEach(h => {
                    h.style.display = isChecked ? '' : 'none';
                });
                applyFiltersAndRender();
            }

            window.onload = () => {
                fetchEmails();
                setInterval(fetchEmails, 10000); // 10초마다 자동 새로고침
                
                // 버전 체크박스는 기본 꺼짐(checked = false) 상태로 설정
                document.getElementById('col-show-version').checked = false;

                // 초기 헤더 가시성 설정
                toggleColumn('col-consent', 'col-show-consent');
                toggleColumn('col-strap', 'col-show-strap');
                toggleColumn('col-position', 'col-show-position');
                toggleColumn('col-tightness', 'col-show-tightness');
                toggleColumn('col-version', 'col-show-version');
            }

            let currentTargetTester = '';

            async function openPointsDrawer(testerName) {
                currentTargetTester = testerName;
                document.getElementById('drawer-title').innerText = `${testerName}님 포인트 관리`;
                document.getElementById('modal-points-input').value = "1.00";
                document.getElementById('modal-memo-input').value = "관리자 가산";
                updatePointsPreview();

                // Open drawer UI
                document.getElementById('drawer-overlay').style.display = 'block';
                document.getElementById('points-drawer').classList.add('open');

                // Load History & Cumulative points
                await fetchTesterHistoryAndPoints(testerName);
            }

            function closePointsDrawer() {
                document.getElementById('drawer-overlay').style.display = 'none';
                document.getElementById('points-drawer').classList.remove('open');
            }

            async function fetchTesterHistoryAndPoints(testerName) {
                const historyListDiv = document.getElementById('drawer-history-list');
                const accumPointsSpan = document.getElementById('drawer-accumulated-points');

                historyListDiv.innerHTML = '<div style="text-align: center; padding: 20px; color: var(--text-muted); font-size: 12.5px;">이력을 불러오는 중...</div>';
                accumPointsSpan.innerText = '0.00 P';

                try {
                    const response = await fetch(`/api/points/${encodeURIComponent(testerName)}/history`);
                    const result = await response.json();
                    if (result.status === 'success') {
                        const history = result.data || [];
                        let total = 0.0;
                        let html = '';

                        if (history.length === 0) {
                            html = '<div style="text-align: center; padding: 20px; color: var(--text-muted); font-size: 12.5px;">이력이 없습니다.</div>';
                        } else {
                            history.forEach(item => {
                                const pts = parseFloat(item.points) || 0.00;
                                total += pts;
                                const isPositive = pts > 0;
                                const ptsStr = isPositive ? `+${pts.toFixed(2)}` : pts.toFixed(2);
                                const ptsClass = isPositive ? 'plus' : 'minus';
                                const dateStr = item.created_at ? item.created_at.substring(0, 10) : '';

                                html += `
                                    <div class="history-item">
                                        <div class="history-item-left">
                                            <span class="history-item-memo">${item.memo || ''}</span>
                                            <span class="history-item-date">${dateStr}</span>
                                        </div>
                                        <span class="history-item-points ${ptsClass}">${ptsStr} P</span>
                                    </div>
                                `;
                            });
                        }
                        historyListDiv.innerHTML = html;
                        accumPointsSpan.innerText = `${total.toFixed(2)} P`;
                    } else {
                        historyListDiv.innerHTML = '<div style="text-align: center; padding: 20px; color: #EF4444; font-size: 12.5px;">이력을 가져오지 못했습니다.</div>';
                    }
                } catch (e) {
                    historyListDiv.innerHTML = '<div style="text-align: center; padding: 20px; color: #EF4444; font-size: 12.5px;">네트워크 에러가 발생했습니다.</div>';
                }
            }

            function updatePointsPreview() {
                const input = document.getElementById('modal-points-input');
                let val = parseFloat(input.value) || 0.00;
                const sign = document.getElementById('points-sign');
                if (val >= 0) {
                    sign.innerText = '+';
                    sign.style.color = 'var(--success)';
                    input.style.color = 'var(--success)';
                } else {
                    sign.innerText = '';
                    sign.style.color = '#EF4444';
                    input.style.color = '#EF4444';
                }
            }

            function stepPoints(step) {
                const input = document.getElementById('modal-points-input');
                let val = parseFloat(input.value) || 0.00;
                val += step;
                input.value = val.toFixed(2);
                updatePointsPreview();
            }

            function adjustPointsPreset(preset) {
                const input = document.getElementById('modal-points-input');
                let val = parseFloat(input.value) || 0.00;
                val += preset;
                input.value = val.toFixed(2);
                updatePointsPreview();
            }

            async function submitPointsAdjustment() {
                const input = document.getElementById('modal-points-input');
                const pointsVal = parseFloat(input.value) || 0.00;
                const memoVal = document.getElementById('modal-memo-input').value.trim();
                const now = new Date();
                const year = now.getFullYear();
                const month = String(now.getMonth() + 1).padStart(2, '0');
                const monthStr = `${year}-${month}`;

                if (!currentTargetTester) return;

                try {
                    const response = await fetch('/api/points', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({
                            tester_name: currentTargetTester,
                            points: pointsVal,
                            memo: memoVal,
                            month: monthStr
                        })
                    });
                    const result = await response.json();
                    if (result.status === 'success') {
                        alert("포인트가 정상적으로 반영되었습니다.");
                        await fetchTesterHistoryAndPoints(currentTargetTester); // Refresh history and points total
                        fetchEmails(); // 데이터 새로고침
                    } else {
                        alert("반영 실패: " + result.message);
                    }
                } catch (e) {
                    alert("에러 발생: " + e);
                }
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

            <div class="column-selector-board">
                <span class="column-selector-title">표시할 컬럼 선택:</span>
                <label class="column-checkbox-item">
                    <input type="checkbox" id="col-show-consent" onchange="toggleColumn('col-consent', 'col-show-consent')">
                    동의 여부
                </label>
                <label class="column-checkbox-item">
                    <input type="checkbox" id="col-show-strap" onchange="toggleColumn('col-strap', 'col-show-strap')">
                    착용 스트랩
                </label>
                <label class="column-checkbox-item">
                    <input type="checkbox" id="col-show-position" onchange="toggleColumn('col-position', 'col-show-position')">
                    착용 위치
                </label>
                <label class="column-checkbox-item">
                    <input type="checkbox" id="col-show-tightness" onchange="toggleColumn('col-tightness', 'col-show-tightness')">
                    착용 정도
                </label>
                <label class="column-checkbox-item">
                    <input type="checkbox" id="col-show-version" onchange="toggleColumn('col-version', 'col-show-version')">
                    버전
                </label>
            </div>

            <div class="filter-board">
                <div class="filter-item" id="filter-tester-name">
                    <label>테스터 닉네임 검색</label>
                    <input type="text" id="input-tester-name" placeholder="닉네임 입력..." oninput="handleTextFilter(this.value)">
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
                <div class="filter-item" id="filter-location">
                    <label>운동 장소</label>
                    <select id="select-location" onchange="handleSelectFilter('location', this.value, 'filter-location')">
                        <option value="">전체</option>
                    </select>
                </div>
                <div class="filter-item" id="filter-training-type">
                    <label>세부 운동 종류</label>
                    <select id="select-training-type" onchange="handleSelectFilter('training_type', this.value, 'filter-training-type')">
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
                            <th class="sortable" onclick="handleSort('tester_name')">닉네임 <span class="sort-indicator" id="sort-icon-tester_name">↕</span></th>
                            <th class="sortable col-consent" onclick="handleSort('consent_given')">동의 여부 <span class="sort-indicator" id="sort-icon-consent_given">↕</span></th>
                            <th class="sortable" onclick="handleSort('watch')">착용 워치 <span class="sort-indicator" id="sort-icon-watch">↕</span></th>
                            <th class="sortable col-strap" onclick="handleSort('strap')">착용 스트랩 <span class="sort-indicator" id="sort-icon-strap">↕</span></th>
                            <th class="sortable" onclick="handleSort('exercise')">운동 종류 <span class="sort-indicator" id="sort-icon-exercise">↕</span></th>
                            <th class="sortable" onclick="handleSort('training_type')">세부 운동 종류 <span class="sort-indicator" id="sort-icon-training_type">↕</span></th>
                            <th class="sortable" onclick="handleSort('distance')">거리 (km) <span class="sort-indicator" id="sort-icon-distance">↕</span></th>
                            <th class="sortable col-position" onclick="handleSort('wearing_position')">착용 위치 <span class="sort-indicator" id="sort-icon-wearing_position">↕</span></th>
                            <th class="sortable col-tightness" onclick="handleSort('wearing_tightness')">착용 정도 <span class="sort-indicator" id="sort-icon-wearing_tightness">↕</span></th>
                            <th class="sortable" onclick="handleSort('competitor_watch')">동시착용 모델 <span class="sort-indicator" id="sort-icon-competitor_watch">↕</span></th>
                            <th class="sortable" onclick="handleSort('location')">운동 장소 <span class="sort-indicator" id="sort-icon-location">↕</span></th>
                            <th style="text-align: center;">센서/데이터 이슈 메모</th>
                            <th>특이 사항</th>
                            <th style="text-align: center;">첨부파일</th>
                            <th class="sortable col-version" onclick="handleSort('app_version')">버전 <span class="sort-indicator" id="sort-icon-app_version">↕</span></th>
                            <th>관리</th>
                        </tr>
                    </thead>
                    <tbody id="table-body">
                        <tr>
                            <td colspan="16" style="text-align: center; padding: 50px; color: var(--text-muted);">데이터를 불러오는 중입니다...</td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>

        <!-- 드로어 오버레이 -->
        <div id="drawer-overlay" class="drawer-overlay" onclick="closePointsDrawer()"></div>

        <!-- 포인트 가감 드로어 -->
        <div id="points-drawer" class="drawer">
            <div class="drawer-header">
                <h2 id="drawer-title">포인트 관리</h2>
                <span class="close-drawer" onclick="closePointsDrawer()">&times;</span>
            </div>
            <div class="drawer-body">
                <!-- 누적 포인트 카드 -->
                <div class="tester-badge-container">
                    <span class="tester-badge-title">누적 포인트</span>
                    <span id="drawer-accumulated-points" class="tester-accumulated-points">0.00 P</span>
                </div>

                <!-- 포인트 가감 영역 -->
                <div style="display: flex; flex-direction: column; gap: 12px; border: 1px solid var(--border); padding: 16px; border-radius: 12px;">
                    <span style="font-size: 13px; font-weight: 700; color: var(--text-muted);">포인트 조정</span>
                    
                    <div style="display: flex; align-items: center; justify-content: center; gap: 12px; margin: 8px 0;">
                        <button class="modal-adjust-btn minus" onclick="stepPoints(-0.1)">-0.1</button>
                        <div style="display: flex; align-items: center; border: 1px solid var(--border); border-radius: 8px; padding: 6px 12px; background: #F8FAFC;">
                            <span id="points-sign" style="font-size: 20px; font-weight: bold; color: var(--success);">+</span>
                            <input type="number" id="modal-points-input" step="0.01" value="1.00" oninput="updatePointsPreview()" style="border: none; background: transparent; font-size: 20px; font-weight: bold; width: 80px; text-align: center; outline: none; margin-left: 4px;">
                        </div>
                        <button class="modal-adjust-btn plus" onclick="stepPoints(0.1)">+0.1</button>
                    </div>

                    <!-- 단축 버튼 -->
                    <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 6px;">
                        <button class="preset-btn plus" onclick="adjustPointsPreset(1.00)">+1.00</button>
                        <button class="preset-btn plus" onclick="adjustPointsPreset(0.50)">+0.50</button>
                        <button class="preset-btn plus" onclick="adjustPointsPreset(0.10)">+0.10</button>
                        <button class="preset-btn plus" onclick="adjustPointsPreset(0.01)">+0.01</button>
                    </div>
                    <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 6px; margin-bottom: 8px;">
                        <button class="preset-btn minus" onclick="adjustPointsPreset(-1.00)">-1.00</button>
                        <button class="preset-btn minus" onclick="adjustPointsPreset(-0.50)">-0.50</button>
                        <button class="preset-btn minus" onclick="adjustPointsPreset(-0.10)">-0.10</button>
                        <button class="preset-btn minus" onclick="adjustPointsPreset(-0.01)">-0.01</button>
                    </div>

                    <div style="display: flex; flex-direction: column; gap: 6px;">
                        <label style="font-size: 11px; font-weight: 700; color: var(--primary); text-transform: uppercase;">가감 사유 (메모)</label>
                        <input type="text" id="modal-memo-input" value="관리자 가산" placeholder="사유를 입력해 주세요" style="padding: 10px 12px; border: 1px solid var(--border); border-radius: 8px; font-size: 13px; outline: none; box-sizing: border-box; width: 100%;">
                    </div>

                    <button class="modal-confirm-btn" onclick="submitPointsAdjustment()" style="width: 100%; padding: 12px; font-size: 14px; margin-top: 8px;">포인트 반영하기</button>
                </div>

                <!-- 이력 리스트 영역 -->
                <div class="history-section">
                    <h3>포인트 지급 이력</h3>
                    <div id="drawer-history-list" class="history-list">
                        <div style="text-align: center; padding: 20px; color: var(--text-muted); font-size: 12.5px;">이력을 불러오는 중...</div>
                    </div>
                </div>
            </div>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
