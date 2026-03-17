#!/bin/bash
# telegram-mcp 컨테이너 실행 (2 인스턴스)
# - 서버(DM300S3B-B33)의 ~/telegram-mcp/ 에서 실행
# - 같은 이미지를 서로 다른 env, 포트, 볼륨으로 2개 실행
# - deploy.sh 또는 deploy.ps1이 이 스크립트를 원격 호출함

# 인스턴스 1
docker run -d \
  --name telegram-mcp-1 \
  -h telegram-mcp-1 \
  --restart unless-stopped \
  --env-file ~/telegram-mcp/.env.1 \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  -v ~/telegram-mcp/logs-1:/app/logs \
  -v ~/telegram-mcp/screenshots-1:/app/screenshots \
  -p 8001:8000 \
  --health-cmd='bash -c "echo > /dev/tcp/localhost/8000" || exit 1' \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  --health-start-period=15s \
  codescent/telegram-mcp:latest

# 인스턴스 2
docker run -d \
  --name telegram-mcp-2 \
  -h telegram-mcp-2 \
  --restart unless-stopped \
  --env-file ~/telegram-mcp/.env.2 \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  -v ~/telegram-mcp/logs-2:/app/logs \
  -v ~/telegram-mcp/screenshots-2:/app/screenshots \
  -p 8002:8000 \
  --health-cmd='bash -c "echo > /dev/tcp/localhost/8000" || exit 1' \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  --health-start-period=15s \
  codescent/telegram-mcp:latest
