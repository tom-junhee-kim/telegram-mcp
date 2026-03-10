#!/bin/bash
# macOS용 배포 스크립트 (rsync 기반)
# - .env.production → 서버의 .env로 복사
# - 로컬 telegram-mcp/ 파일을 서버로 동기화 후 이미지 빌드 & 컨테이너 재시작
# - 사용법: ./deploy.sh
set -euo pipefail

HOST="orangepi5plus-jhcheong"
REMOTE_DIR="~/telegram-mcp"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 컨테이너 정리
echo "==> Stopping current container"
ssh "$HOST" 'docker stop telegram-mcp 2>/dev/null; docker rm telegram-mcp 2>/dev/null; true'

# 파일 동기화
echo "==> Uploading files to $HOST:$REMOTE_DIR"
ssh "$HOST" "mkdir -p $REMOTE_DIR"
rsync -av --delete \
  --exclude='.env*' \
  --exclude='deploy.*' \
  --exclude='.gitignore' \
  --exclude='.gitattributes' \
  --exclude='README.md' \
  --exclude='LICENSE' \
  --exclude='docker-compose.yml' \
  --exclude='.venv/' \
  --exclude='__pycache__/' \
  --exclude='logs/' \
  --exclude='screenshots/' \
  --exclude='tests/' \
  --exclude='test_*.py' \
  --exclude='*.session' \
  --exclude='*.session-journal' \
  --exclude='*.tmp' \
  --exclude='*.log' \
  --exclude='telegram_mcp.egg-info/' \
  --exclude='poetry.lock' \
  --exclude='claude_desktop_config.json' \
  --exclude='.github/' \
  "$SCRIPT_DIR/" "$HOST:$REMOTE_DIR/"

# .env.production → 서버의 .env로 복사
echo "==> Deploying .env.production as .env"
if [ -f "$SCRIPT_DIR/.env.production" ]; then
    scp "$SCRIPT_DIR/.env.production" "$HOST:$REMOTE_DIR/.env"
else
    echo "ERROR: .env.production not found. Create it from .env.example first." >&2
    exit 1
fi

# 이미지 빌드
echo "==> Building Docker image on remote"
ssh "$HOST" "cd $REMOTE_DIR && bash build.sh"

# 컨테이너 시작
echo "==> Starting telegram-mcp container"
ssh "$HOST" "bash $REMOTE_DIR/run.sh"

# 기동 확인
echo "==> Waiting for startup..."
sleep 5
ssh "$HOST" "docker ps --filter name=telegram-mcp --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
echo "Done."
