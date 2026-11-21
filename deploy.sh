#!/bin/bash
# shellcheck disable=SC2029,SC2088
# 위 억제: REMOTE_DIR 의 `~` 와 변수는 일부러 로컬에서 펼치지 않거나 펼쳐 원격 셸에 넘긴다.
# telegram-mcp 배포 (isD-MacBookPro → DM300S3B-B33 에서 빌드 → registry → k3s shared-ai, 2 인스턴스) — iD-186 ⓑ(11-22)
# - **k3s 로 이전했다**(iD-176): 이 스크립트는 더 이상 Docker 컨테이너를 만들지 않는다(옛 컨테이너가 되살아나면 텔레그램 세션을 두 곳에서
#   동시에 써 AUTH_KEY_DUPLICATED 로 세션이 무효화된다). 흐름 = 소스 업로드 → 서버(amd64)에서 빌드 → registry 에 핀 태그 push →
#   gitops 이미지 태그 커밋(bump.sh) → Flux 가 반영(Recreate 라 옛 파드가 내려간 뒤에 새 파드가 뜬다) → rollout 확인.
# - 세션 문자열·API 키는 gitops 의 SOPS Secret(shared-ai-telegram-mcp-{1,2}-env)이 정본이다 — 서버 .env.1·.env.2 는 쓰지 않는다.
# - 사용법: ./deploy.sh [태그]   (태그는 빌드용 이름이고 push 되는 이미지 태그는 이미지 ID 앞 7자 sha-<id>)
# - 필요: ssh DM300S3B-B33, 워크스페이스 tools/gitops-image/bump.sh(GITOPS_BUMP 로 경로 지정 가능), kubectl+${KUBECONFIG:-~/.kube/cs-b450m.yaml}
set -euo pipefail

HOST="DM300S3B-B33"
REMOTE_DIR="~/telegram-mcp"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TAG="${1:-latest}"
REG="registry.codescent.biz"
BUMP="${GITOPS_BUMP:-$HOME/Developer/codescent-claude-workspace/tools/gitops-image/bump.sh}"
KCFG="${KUBECONFIG:-$HOME/.kube/cs-b450m.yaml}"
[ -x "$BUMP" ] || { echo "ERROR: bump.sh 를 찾지 못했다($BUMP) — GITOPS_BUMP 로 경로를 준다." >&2; exit 1; }

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

echo "==> Building image codescent/telegram-mcp:$TAG (실패하면 여기서 멈춘다 — 운영은 그대로)"
ssh "$HOST" "bash $REMOTE_DIR/build.sh $TAG"

ID="$(ssh "$HOST" "docker image inspect codescent/telegram-mcp:$TAG --format '{{.Id}}'" | cut -c8-14)"
[ -n "$ID" ] || { echo "ERROR: 이미지 ID 를 읽지 못했다" >&2; exit 1; }
NEW="sha-$ID"
echo "==> Pushing $REG/telegram-mcp:$NEW"
ssh "$HOST" "docker tag codescent/telegram-mcp:$TAG $REG/telegram-mcp:$NEW && docker push $REG/telegram-mcp:$NEW | tail -1"

echo "==> gitops 이미지 태그 반영(Flux 가 두 인스턴스를 차례로 갈아 끼운다 — 인스턴스당 약 1~2분 끊김)"
"$BUMP" telegram-mcp "$NEW"

if command -v kubectl >/dev/null 2>&1 && [ -f "$KCFG" ]; then
  echo "==> rollout 확인(최대 약 6분)"
  for i in 1 2; do
    for _ in $(seq 1 36); do
      cur="$(kubectl --kubeconfig "$KCFG" -n shared-ai get deploy "telegram-mcp-$i" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"
      [ "$cur" = "$REG/telegram-mcp:$NEW" ] && break
      sleep 10
    done
    kubectl --kubeconfig "$KCFG" -n shared-ai rollout status "deploy/telegram-mcp-$i" --timeout=240s
  done
else
  echo "(kubectl·kubeconfig 가 없어 rollout 확인은 건너뜀 — kubectl -n shared-ai get pods 로 보면 된다)"
fi
