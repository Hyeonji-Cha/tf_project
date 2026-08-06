# 1. 모듈 가져오기
import os
import socket
from contextlib import closing
import pymysql
from fastapi import FastAPI, HTTPException

# 2. FastAPI 객체 생성
app = FastAPI(title="DE-AI-18 EKS Auto Mode WAS", version="1.0.0-auto")

# 3. 일반 사용자 정의 함수
def required_env(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value

def db_connection():
    return pymysql.connect(
        host=required_env("DB_HOST"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=required_env("DB_USER"),
        password=required_env("DB_PASSWORD"),
        database=required_env("DB_NAME"),
        connect_timeout=5,
        read_timeout=5,
        write_timeout=5,
        autocommit=True,
        cursorclass=pymysql.cursors.DictCursor,
    )

# 4. 라우팅 함수
# WAS Pod의 생존 여부와 정상 가동 여부를 확인하는 Endpoint로, 정상일 때 HTTP 200을 응답합니다.
@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}

# Web → WAS 정상 연동과 Service의 로드 밸런싱 동작을 확인합니다(여러 번 요청하여 확인).
@app.get("/api/info")
def info() -> dict[str, str]:
    return {
        "message": "WEB Pod에서 WAS Service로 정상 연결되었습니다.",
        # WAS Service를 통해 가용 영역 a 또는 c의 특정 Pod가 응답하므로 Hostname은 유동적입니다.
        "was_pod": socket.gethostname(), 
        "version": "v1-eks-auto",
    }

# Web → WAS → RDS 연결을 확인합니다.
@app.get("/api/db")
def db_test() -> dict:
    # I/O 작업에서 발생할 수 있는 예외를 처리합니다.
    try:
        # I/O 연결은 사용 후 반드시 close()해야 하므로 with 문으로 자동 처리합니다.
        with closing(db_connection()) as connection:
            # DB Cursor를 엽니다.
            with connection.cursor() as cursor:
                # 요청 기록을 저장하는 테이블 생성
                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS request_counter (
                        id BIGINT AUTO_INCREMENT PRIMARY KEY,
                        pod_name VARCHAR(255) NOT NULL,
                        requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                    """
                )
                # 요청에 대한 로그 기록
                cursor.execute(
                    "INSERT INTO request_counter (pod_name) VALUES (%s)",
                    (socket.gethostname(),),
                )
                # 현재 DB 시간을 기준으로 총 요청 수와 DB 시간을 조회합니다.
                cursor.execute(
                    "SELECT COUNT(*) AS total_requests, NOW() AS database_time FROM request_counter"
                )
                # 조회 결과 한 건만 가져옵니다.
                result = cursor.fetchone()

        return {
            "message": "WAS Pod에서 RDS MySQL로 정상 연결되었습니다.",
            "was_pod": socket.gethostname(),
            **result,
        }
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"RDS connection failed: {exc}") from exc
