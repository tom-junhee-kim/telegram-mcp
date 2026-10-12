#!/bin/bash
# shellcheck disable=SC2029,SC2088
# 위 억제: REMOTE_DIR 의 `~` 와 변수는 일부러 로컬에서 펼치지 않거나 펼쳐 원격 셸에 넘긴다.
# telegram-mcp 배포 (isD-MacBookPro → DM300S3B-B33, 2 인스턴스)
# - 서버의 .env.1·.env.2 가 정본이다 — 이 스크립트는 올리지도 덮지도 않는다(없으면 아무것도 안 하고 멈춘다).
# - 소스를 올리고 서버에서 빌드한 뒤 고른 인스턴스의 컨테이너를 바꾼다. 빌드가 실패하면 운영 컨테이너는 그대로다.
# - 사용법: [MCP_TRANSPORT_1=http|sse] [MCP_TRANSPORT_2=…] ./deploy.sh [태그] [인스턴스 번호...]   (기본 latest, 1 2, 전송 http)
set -euo pipefail

HOST="DM300S3B-B33"
REMOTE_DIR="~/telegram-mcp"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TAG="${1:-latest}"
if [ $# -gt 1 ]; then
  INSTANCES="${*:2}"
else
  INSTANCES="1 2"
fi
NAMES=""
for i in $INSTANCES; do NAMES="$NAMES telegram-mcp-$i"; done
TRANSPORTS="MCP_TRANSPORT_1=${MCP_TRANSPORT_1:-http} MCP_TRANSPORT_2=${MCP_TRANSPORT_2:-http}"

echo "==> Checking server .env.1 / .env.2"
ssh "$HOST" "test -s $REMOTE_DIR/.env.1 && test -s $REMOTE_DIR/.env.2" || {
  echo "ERROR: 서버에 $REMOTE_DIR/.env.1·.env.2 가 없다 — 먼저 서버에서 만든다." >&2; exit 1; }

echo "==> Uploading source to $HOST:$REMOTE_DIR"
rsync -a --delete \
  --exclude='.env*' \
  --exclude='data-*/' \
  --exclude='logs*/' \
  --exclude='screenshots*/' \
  --exclude='.git*' \
  --exclude='.venv/' \
  --exclude='__pycache__/' \
  --exclude='tests/' \
  --exclude='skills/' \
  --exclude='*.session' \
  --exclude='*.session-journal' \
  "$SCRIPT_DIR/" "$HOST:$REMOTE_DIR/"

echo "==> Building image codescent/telegram-mcp:$TAG"
ssh "$HOST" "bash $REMOTE_DIR/build.sh $TAG"

echo "==> Ensuring data directories (appuser uid 1000)"
ssh "$HOST" "mkdir -p $REMOTE_DIR/data-1 $REMOTE_DIR/data-2 && sudo chown 1000:1000 $REMOTE_DIR/data-1 $REMOTE_DIR/data-2"

echo "==> Replacing containers:$NAMES ($TRANSPORTS)"
ssh "$HOST" "docker rm -f$NAMES 2>/dev/null || true; $TRANSPORTS bash $REMOTE_DIR/run.sh $TAG $INSTANCES"

echo "==> Waiting for health"
sleep 20
ssh "$HOST" "docker ps --filter name=telegram-mcp --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
