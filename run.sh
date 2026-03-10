#!/bin/bash
# telegram-mcp 컨테이너 실행 (단일 인스턴스)
# - orangepi5plus의 ~/telegram-mcp/ 에서 실행
# - .env를 --env-file로 주입
# - deploy.sh 또는 deploy.ps1이 이 스크립트를 원격 호출함
#
# 포트: 8000

DIR=~/telegram-mcp

# logs 디렉토리 생성 (없으면)
mkdir -p "$DIR/logs"

docker run -d \
  --name telegram-mcp \
  -h telegram-mcp \
  --restart always \
  --env-file "$DIR/.env" \
  -v "$DIR/logs:/app/logs" \
  -p 8000:8000 \
  codescent/telegram-mcp:latest
