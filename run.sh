#!/bin/bash
# telegram-mcp 컨테이너 실행 (2 인스턴스 — 같은 이미지, 서로 다른 Telegram 계정)
# - 서버(DM300S3B-B33)의 ~/telegram-mcp/ 에서 deploy.sh 가 원격 호출한다.
# - 전송은 streamable HTTP(MCP_TRANSPORT=http, 엔드포인트 /mcp). 클라이언트는 type http 로 등록한다.
# - 이미지는 비루트 appuser(uid 1000)로 돌아 data-N 폴더는 1000 소유여야 한다(deploy.sh 가 맞춘다).
# - alpine 이미지라 bash 가 없어 헬스체크는 python 으로 포트를 연다.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
TAG="${1:-latest}"

for i in 1 2; do
  docker run -d \
    --name "telegram-mcp-$i" \
    --restart unless-stopped \
    --env-file "$DIR/.env.$i" \
    -e MCP_TRANSPORT=http \
    -e MCP_HOST=0.0.0.0 \
    -e MCP_PORT=8000 \
    --log-opt max-size=10m \
    --log-opt max-file=3 \
    -v "$DIR/data-$i:/app/data" \
    -p "800$i:8000" \
    --health-cmd='python -c "import socket; socket.create_connection((\"127.0.0.1\", 8000), 3)"' \
    --health-interval=30s \
    --health-timeout=10s \
    --health-retries=3 \
    --health-start-period=15s \
    "codescent/telegram-mcp:${TAG}"
done
