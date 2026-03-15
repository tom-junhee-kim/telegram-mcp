# telegram-mcp

Telegram MCP 서버. Telethon 기반으로 Telegram 계정을 MCP 도구로 노출한다. 2개의 독립 인스턴스로 서로 다른 Telegram 계정을 운용한다.

## 서버 정보

- **배포 대상**: DM300S3B-B33-jhcheong (192.168.2.14)
- **이미지**: `codescent/telegram-mcp:latest` (커스텀)
- **컨테이너**: `telegram-mcp-1`, `telegram-mcp-2`
- **네트워크**: bridge (8001:8000, 8002:8000)
- **재시작 정책**: always

## 파일 구조

```
telegram-mcp/
├── .dockerignore
├── .env.example
├── .env.production.1
├── .env.production.2
├── .gitattributes
├── .gitignore
├── .python-version
├── Dockerfile
├── LICENSE
├── README.md
├── __init__.py
├── build.sh
├── claude_desktop_config.json
├── deploy.ps1
├── deploy.sh
├── docker-compose.yml
├── main.py
├── poetry.lock
├── pyproject.toml
├── requirements.txt
├── run.sh
├── session_string_generator.py
├── test_file_path_security.py
├── test_validation.py
├── uv.lock
├── logs/
└── screenshots/
```

## 볼륨 마운트

| 컨테이너 경로 | 호스트 경로 | 모드 | 용도 |
|---|---|---|---|
| `/app/logs` | `~/telegram-mcp/logs-1` | rw | 인스턴스 1 로그 |
| `/app/screenshots` | `~/telegram-mcp/screenshots-1` | rw | 인스턴스 1 스크린샷 |
| `/app/logs` | `~/telegram-mcp/logs-2` | rw | 인스턴스 2 로그 |
| `/app/screenshots` | `~/telegram-mcp/screenshots-2` | rw | 인스턴스 2 스크린샷 |

## 환경 변수

`.env.example` 참조. 주요 변수:

- `TZ` — 타임존 (기본: `Asia/Seoul`)
- `TELEGRAM_API_ID` — Telegram API ID (my.telegram.org/apps에서 발급)
- `TELEGRAM_API_HASH` — Telegram API Hash
- `TELEGRAM_SESSION_STRING` — 세션 문자열 (`session_string_generator.py`로 생성)
- `MCP_ALLOWED_HOSTS` — SSE 보안: 허용 호스트 (쉼표 구분)
- `MCP_ALLOWED_ORIGINS` — SSE 보안: 허용 오리진 (쉼표 구분)

인스턴스별로 `.env.production.1`, `.env.production.2`를 각각 생성한다.

## 배포

```bash
# macOS
./deploy.sh

# Windows
.\deploy.ps1
```

## 운영

### 상태 확인
```bash
ssh DM300S3B-B33-jhcheong "docker ps --filter name=telegram-mcp"
```

### 로그 확인
```bash
ssh DM300S3B-B33-jhcheong "docker logs telegram-mcp-1"
ssh DM300S3B-B33-jhcheong "docker logs telegram-mcp-2"
```
