#!/bin/bash
# macOS/Linux용 배포 스크립트 (rsync 기반)
# - .env.production.{1,2} → 서버의 .env.{1,2}로 복사
# - 2인스턴스 구조: 같은 이미지, 서로 다른 Telegram 계정
# - 사용법: ./deploy.sh
set -euo pipefail

HOST="DM300S3B-B33"
REMOTE_DIR="~/telegram-mcp"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# .env.production.1, .env.production.2 확인
for i in 1 2; do
  if [ ! -f "$SCRIPT_DIR/.env.production.$i" ]; then
    echo "ERROR: .env.production.$i not found. Create it from .env.example first." >&2
    exit 1
  fi
done

# 컨테이너 중지 (배포 중 설정 불일치 방지)
echo "==> Stopping telegram-mcp containers"
ssh "$HOST" "docker stop telegram-mcp-1 telegram-mcp-2 2>/dev/null || true"

# 파일 동기화 (.env*, deploy 스크립트, .git*, README.md, Python/런타임 제외)
echo "==> Uploading files to $HOST:$REMOTE_DIR"
ssh "$HOST" "mkdir -p $REMOTE_DIR"
rsync -av --delete \
  --exclude='.env*' \
  --exclude='deploy.*' \
  --exclude='.git*' \
  --exclude='README.md' \
  --exclude='LICENSE' \
  --exclude='docker-compose.yml' \
  --exclude='claude_desktop_config.json' \
  --exclude='.venv/' \
  --exclude='__pycache__/' \
  --exclude='logs*/' \
  --exclude='screenshots*/' \
  --exclude='test_*.py' \
  --exclude='*.session' \
  --exclude='*.session-journal' \
  --exclude='*.tmp' \
  --exclude='*.log' \
  --exclude='telegram_mcp.egg-info/' \
  --exclude='poetry.lock' \
  "$SCRIPT_DIR/" "$HOST:$REMOTE_DIR/"

# .env.production.{1,2} → 서버의 .env.{1,2}로 복사
for i in 1 2; do
  echo "==> Deploying .env.production.$i as .env.$i"
  scp "$SCRIPT_DIR/.env.production.$i" "$HOST:$REMOTE_DIR/.env.$i"
  ssh "$HOST" "chmod 600 $REMOTE_DIR/.env.$i"
done

# 로그/스크린샷 디렉토리 생성
echo "==> Ensuring data directories"
ssh "$HOST" "mkdir -p $REMOTE_DIR/logs-1 $REMOTE_DIR/logs-2 $REMOTE_DIR/screenshots-1 $REMOTE_DIR/screenshots-2"

# 이미지 빌드
echo "==> Building telegram-mcp image"
ssh "$HOST" "bash $REMOTE_DIR/build.sh"

# 컨테이너 재시작
echo "==> Restarting telegram-mcp containers"
ssh "$HOST" "docker rm telegram-mcp-1 telegram-mcp-2 2>/dev/null || true && bash $REMOTE_DIR/run.sh"

# 기동 확인
echo "==> Waiting for startup..."
sleep 5
ssh "$HOST" "docker ps --filter name=telegram-mcp --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
echo "Done."
