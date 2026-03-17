# Telegram MCP

Telegram MCP 서버. Telethon 기반으로 Telegram 계정을 MCP 도구로 노출한다. 2개의 독립 인스턴스로 서로 다른 Telegram 계정을 운용한다.

## 서버 정보

- **배포 대상**: DM300S3B-B33 (192.168.2.14)
- **이미지**: `codescent/telegram-mcp:latest` (커스텀 — python:3.11-slim + uv)
- **컨테이너**: `telegram-mcp-1` (8001), `telegram-mcp-2` (8002)
- **네트워크**: bridge (8001, 8002)
- **재시작 정책**: unless-stopped

## 파일 구조

```
telegram-mcp/
├── .dockerignore
├── .env.example
├── .gitattributes
├── .gitignore
├── .python-version
├── Dockerfile                  # 멀티 스테이지 빌드 (builder + runtime)
├── build.sh
├── deploy.ps1
├── deploy.sh
├── main.py
├── pyproject.toml
├── README.md
├── run.sh                      # 2인스턴스 실행
└── session_string_generator.py
```

## 볼륨 마운트

| 컨테이너 경로 | 호스트 경로 | 모드 | 용도 |
|---|---|---|---|
| `/app/logs` | `~/telegram-mcp/logs-{1,2}` | rw | 인스턴스별 로그 |
| `/app/screenshots` | `~/telegram-mcp/screenshots-{1,2}` | rw | 인스턴스별 스크린샷 |

## 환경 변수

`.env.example` 참조. 인스턴스별로 `.env.production.1`, `.env.production.2`를 각각 생성한다. 주요 변수:

- `TZ` — 타임존 (Asia/Seoul)
- `TELEGRAM_API_ID` / `TELEGRAM_API_HASH` — Telegram API 자격증명
- `TELEGRAM_SESSION_STRING` — 세션 문자열 (`session_string_generator.py`로 생성)
- `MCP_ALLOWED_HOSTS` — SSE 보안: 허용 호스트 (쉼표 구분)

## 배포

```bash
# macOS/Linux
./deploy.sh

# Windows
.\deploy.ps1
```

배포 흐름:
1. 파일 동기화 (rsync / scp)
2. `.env.production.{1,2}` → 서버의 `.env.{1,2}`로 복사
3. 로그/스크린샷 디렉토리 생성
4. 이미지 빌드 → 컨테이너 2개 재시작

## 운영

### 상태 확인
```bash
ssh DM300S3B-B33 "docker ps --filter name=telegram-mcp"
```

### 로그 확인
```bash
ssh DM300S3B-B33 "docker logs telegram-mcp-1"
ssh DM300S3B-B33 "docker logs telegram-mcp-2"
```
