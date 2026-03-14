# telegram-mcp

Telegram MCP 서버 (2 인스턴스). Telethon 기반으로 Telegram 계정을 MCP 도구로 노출한다. 메시지 송수신, 채팅 관리, 연락처 관리, 미디어 전송 등 Telegram의 주요 기능을 MCP 클라이언트에서 사용할 수 있다.

## 서버 정보

- **배포 대상**: DM300S3B-B33-jhcheong (192.168.2.14)
- **이미지**: `codescent/telegram-mcp:latest` (커스텀)
- **네트워크**: bridge — telegram-mcp-1 (8001→8000), telegram-mcp-2 (8002→8000)
- **재시작 정책**: always

## 파일 구조

```
telegram-mcp/
├── Dockerfile               # 커스텀 이미지 빌드
├── main.py                  # MCP 서버 구현체 (upstream)
├── build.sh                 # 이미지 빌드
├── run-1.sh                 # 인스턴스 1 실행 (포트 8001)
├── run-2.sh                 # 인스턴스 2 실행 (포트 8002)
├── deploy.sh                # macOS/Linux 배포 (rsync)
├── deploy.ps1               # Windows 배포 (scp)
├── .env.example             # .env 템플릿
├── .env.production.1        # 인스턴스 1 운영 환경 변수 (gitignore 대상)
├── .env.production.2        # 인스턴스 2 운영 환경 변수 (gitignore 대상)
├── .dockerignore
├── .gitattributes
├── .gitignore
├── logs/                    # 로컬 로그 (gitignore 대상)
├── pyproject.toml
├── requirements.txt
├── session_string_generator.py
└── README.md
```

서버에는 인스턴스별 로그 디렉토리가 생성된다: `logs-1/`, `logs-2/`

## 볼륨 마운트

| 컨테이너 경로 | 호스트 경로 | 용도 |
|---|---|---|
| `/app/logs` | `~/telegram-mcp/logs-1` | 인스턴스 1 로그 |
| `/app/logs` | `~/telegram-mcp/logs-2` | 인스턴스 2 로그 |

## 인스턴스 구성

2개의 독립 컨테이너로 서로 다른 Telegram 계정을 운용한다. 각 인스턴스는 별도 env 파일과 포트를 사용한다.

| 인스턴스 | 컨테이너명 | 포트 | env 파일 | 로그 디렉토리 |
|----------|------------|------|----------|---------------|
| 1 | telegram-mcp-1 | 8001 | .env.1 | logs-1/ |
| 2 | telegram-mcp-2 | 8002 | .env.2 | logs-2/ |

### 환경 변수

| 변수 | 설명 |
|------|------|
| `TELEGRAM_API_ID` | Telegram API ID (my.telegram.org/apps) |
| `TELEGRAM_API_HASH` | Telegram API Hash |
| `TELEGRAM_SESSION_STRING` | 세션 문자열 (session_string_generator.py로 생성) |

`.env.example`을 복사하여 `.env.production.1`, `.env.production.2`를 각각 생성한다.

`docker --env-file`은 따옴표를 리터럴로 포함시키므로 값에 따옴표를 사용하지 않는다.

### 세션 문자열 생성

```bash
# 로컬에서 실행 (uv 필요)
uv run session_string_generator.py
```

프롬프트에 따라 인증 후 생성된 세션 문자열을 해당 인스턴스의 env 파일에 저장한다.

## 운영

### 상태 확인

```bash
# 컨테이너 상태
ssh DM300S3B-B33-jhcheong "docker ps --filter name=telegram-mcp"

# 실시간 로그 (인스턴스 1)
ssh DM300S3B-B33-jhcheong "docker logs -f telegram-mcp-1"

# 실시간 로그 (인스턴스 2)
ssh DM300S3B-B33-jhcheong "docker logs -f telegram-mcp-2"
```

### 컨테이너 재시작

```bash
# 인스턴스 1
ssh DM300S3B-B33-jhcheong "docker stop telegram-mcp-1 && docker rm telegram-mcp-1 && bash ~/telegram-mcp/run-1.sh"

# 인스턴스 2
ssh DM300S3B-B33-jhcheong "docker stop telegram-mcp-2 && docker rm telegram-mcp-2 && bash ~/telegram-mcp/run-2.sh"
```

## 배포

```bash
# Windows
.\deploy.ps1

# macOS/Linux
./deploy.sh
```
