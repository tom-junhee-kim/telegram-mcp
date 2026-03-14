#!/bin/bash
# telegram-mcp 컨테이너 실행 (2 인스턴스)
# - 같은 이미지를 서로 다른 env, 포트, 볼륨으로 2개 실행
# - deploy.sh/deploy.ps1이 이 스크립트를 원격 호출함

DIR=~/telegram-mcp

mkdir -p "$DIR/logs-1" "$DIR/logs-2" "$DIR/screenshots-1" "$DIR/screenshots-2"

# 인스턴스 1
docker run -d \
  --name telegram-mcp-1 \
  -h telegram-mcp-1 \
  --restart always \
  --env-file "$DIR/.env.1" \
  -v "$DIR/logs-1:/app/logs" \
  -v "$DIR/screenshots-1:/app/screenshots" \
  -p 8001:8000 \
  codescent/telegram-mcp:latest

# 인스턴스 2
docker run -d \
  --name telegram-mcp-2 \
  -h telegram-mcp-2 \
  --restart always \
  --env-file "$DIR/.env.2" \
  -v "$DIR/logs-2:/app/logs" \
  -v "$DIR/screenshots-2:/app/screenshots" \
  -p 8002:8000 \
  codescent/telegram-mcp:latest
