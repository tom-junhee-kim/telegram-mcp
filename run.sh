#!/bin/bash
# telegram-mcp 컨테이너 실행 (2 인스턴스 — 같은 이미지, 서로 다른 Telegram 계정)
# - 서버(DM300S3B-B33)의 ~/telegram-mcp/ 에서 deploy.sh 가 원격 호출한다.
# - 사용법: run.sh [태그] [인스턴스 번호...]   (기본 latest, 1 2)
# - 전송은 인스턴스마다 MCP_TRANSPORT_<번호>(http|sse, 기본 http)로 고른다.
#   한 프로세스는 전송 하나만 연다 — http 는 /mcp(클라이언트 type http), sse 는 /sse(type sse).
#   클라이언트 등록을 바꾸는 시각이 인스턴스마다 달라서 따로 고를 수 있게 둔다.
# - 이미지는 비루트 appuser(uid 1000)로 돌아 data-N 폴더는 1000 소유여야 한다(deploy.sh 가 맞춘다).
# - alpine 이미지라 bash 가 없어 헬스체크는 python 으로 포트를 연다.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
TAG="${1:-latest}"
if [ $# -gt 1 ]; then
  INSTANCES=("${@:2}")
else
  INSTANCES=(1 2)
fi

for i in "${INSTANCES[@]}"; do
  transport_var="MCP_TRANSPORT_$i"
  transport="${!transport_var:-http}"
  case "$transport" in
    http|sse) ;;
    *) echo "ERROR: $transport_var 는 http 또는 sse 여야 한다: $transport" >&2; exit 1 ;;
  esac
  docker run -d \
    --name "telegram-mcp-$i" \
    --restart unless-stopped \
    --env-file "$DIR/.env.$i" \
    -e MCP_TRANSPORT="$transport" \
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
