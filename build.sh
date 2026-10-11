#!/bin/bash
set -euo pipefail
# telegram-mcp 이미지 빌드 (서버 DM300S3B-B33 에서 실행 — deploy.sh 가 원격 호출)
# - 상류 Dockerfile 의 production 단계만 굽는다(development 단계는 테스트 도구용).
# - 사용법: build.sh [태그]   (기본 latest)
TAG="${1:-latest}"
cd "$(dirname "$0")" && docker build --target production -t "codescent/telegram-mcp:${TAG}" .
