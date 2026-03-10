# Windows용 배포 스크립트 (scp 기반, rsync 없는 환경)
# - .env.production → 서버의 .env로 복사
# - 로컬 telegram-mcp/ 파일을 서버로 업로드 후 이미지 빌드 & 컨테이너 재시작
# - 사용법: .\deploy.ps1
$ErrorActionPreference = "Stop"

$Host_ = "orangepi5plus-jhcheong"
$RemoteDir = "~/telegram-mcp"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
# 배포 대상 파일 목록
$Files = @("Dockerfile", ".dockerignore", "build.sh", "run.sh", "pyproject.toml", ".python-version", "main.py", "session_string_generator.py")

# 컨테이너 정리
Write-Host "==> Stopping current container"
ssh $Host_ "docker stop telegram-mcp 2>/dev/null; docker rm telegram-mcp 2>/dev/null; true"

# 파일 업로드
Write-Host "==> Uploading files to ${Host_}:${RemoteDir}"
ssh $Host_ "mkdir -p $RemoteDir"
foreach ($f in $Files) {
    $local = Join-Path $ScriptDir $f
    if (Test-Path $local) {
        scp $local "${Host_}:${RemoteDir}/$f"
        Write-Host "  $f"
    }
}

# .env.production → 서버의 .env로 복사
Write-Host "==> Deploying .env.production as .env"
$envProd = Join-Path $ScriptDir ".env.production"
if (Test-Path $envProd) {
    scp $envProd "${Host_}:${RemoteDir}/.env"
} else {
    Write-Error ".env.production not found. Create it from .env.example first."
    exit 1
}

# Windows에서 scp한 파일은 CRLF 줄바꿈 → LF로 변환 (scp는 git이 아니므로 .gitattributes 미적용)
Write-Host "==> Converting CRLF to LF on remote"
ssh $Host_ "cd $RemoteDir && find . -name '*.sh' -o -name '*.py' -o -name 'Dockerfile' -o -name '.dockerignore' -o -name '.env' | xargs -r sed -i 's/\r$//'"

# 배포 대상 외 잔여 파일 정리 — 보존: .env, Dockerfile, .dockerignore, *.sh, *.py, pyproject.toml, .python-version, logs
Write-Host "==> Cleaning up old files on remote"
ssh $Host_ "cd $RemoteDir && ls -A | grep -v -E '^(\.env|Dockerfile|\.dockerignore|build\.sh|run\.sh|main\.py|session_string_generator\.py|pyproject\.toml|\.python-version|logs)$' | xargs -r rm -rf"

# 이미지 빌드
Write-Host "==> Building Docker image on remote"
ssh $Host_ "cd $RemoteDir && bash build.sh"

# 컨테이너 시작
Write-Host "==> Starting telegram-mcp container"
ssh $Host_ "bash $RemoteDir/run.sh"

# 기동 확인
Write-Host "==> Waiting for startup..."
Start-Sleep -Seconds 5
ssh $Host_ "docker ps --filter name=telegram-mcp --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
Write-Host "Done."
