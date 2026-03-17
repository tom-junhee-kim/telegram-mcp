# telegram-mcp 배포 (Windows → Linux)
# - deploy.sh와 동일한 결과 보장 (rsync --delete 대체)
# - 사용법: .\deploy.ps1
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$Host_ = "DM300S3B-B33"
$RemoteDir = "~/telegram-mcp"

# .env.production.1, .env.production.2 확인
if (-not (Test-Path ".env.production.1")) {
    Write-Error ".env.production.1 파일이 없습니다. .env.example을 참고하여 생성하세요."
    exit 1
}
if (-not (Test-Path ".env.production.2")) {
    Write-Error ".env.production.2 파일이 없습니다. .env.example을 참고하여 생성하세요."
    exit 1
}

# 컨테이너 정리
Write-Host "==> Stopping current containers"
ssh $Host_ "docker stop telegram-mcp-1 telegram-mcp-2 2>/dev/null; docker rm telegram-mcp-1 telegram-mcp-2 2>/dev/null; true"

# --- 파일 동기화 (deploy.sh rsync --delete 대체) ---
# 제외 대상 (deploy.sh --exclude와 동일)
$ExcludeNames = @('deploy.sh', 'deploy.ps1', 'README.md', 'LICENSE', 'docker-compose.yml', 'poetry.lock', 'uv.lock', '__init__.py', 'claude_desktop_config.json', 'requirements.txt', 'mcp_errors.log')
$ExcludePatterns = @('.env*', '.git*', '*.session', '*.session-journal', '*.log', '*.tmp', 'test_*.py')
$ExcludeDirs = @('.git', '.github', '.venv', '__pycache__', 'logs', 'logs-1', 'logs-2', 'screenshots', 'screenshots-1', 'screenshots-2', 'telegram_mcp.egg-info', 'tests')

# 임시 디렉토리에 배포 대상만 복사
$TempDir = Join-Path $env:TEMP "deploy-telegram-mcp"
if (Test-Path $TempDir) { Remove-Item -Recurse -Force $TempDir }
New-Item -ItemType Directory -Path $TempDir | Out-Null

Get-ChildItem -Path $ScriptDir -Force | Where-Object {
    $n = $_.Name
    if ($ExcludeNames -contains $n) { return $false }
    if ($_.PSIsContainer -and ($ExcludeDirs -contains $n)) { return $false }
    foreach ($p in $ExcludePatterns) { if ($n -like $p) { return $false } }
    return $true
} | ForEach-Object {
    if ($_.PSIsContainer) {
        Copy-Item $_.FullName (Join-Path $TempDir $_.Name) -Recurse
    } else {
        Copy-Item $_.FullName $TempDir
    }
}

# 업로드
Write-Host "==> Uploading files to ${Host_}:${RemoteDir}"
ssh $Host_ "mkdir -p $RemoteDir"

foreach ($item in @(Get-ChildItem $TempDir -Force)) {
    if ($item.PSIsContainer) {
        ssh $Host_ "rm -rf $RemoteDir/$($item.Name)"
        scp -r $item.FullName "${Host_}:${RemoteDir}/"
    } else {
        scp $item.FullName "${Host_}:${RemoteDir}/"
    }
    Write-Host "  $($item.Name)"
}

# 원격 정리 (업로드되지 않은 파일/디렉토리 제거)
Write-Host "==> Cleaning up old files on remote"
$UploadedNames = @(Get-ChildItem $TempDir -Force | ForEach-Object { [regex]::Escape($_.Name) })
$PreserveRegex = '^(' + ($UploadedNames -join '|') + '|\.env.*|logs-1|logs-2|screenshots-1|screenshots-2)$'
ssh $Host_ "cd $RemoteDir && ls -A | grep -v -E '$PreserveRegex' | xargs -r rm -rf"

Remove-Item -Recurse -Force $TempDir

# CRLF→LF 변환
Write-Host "==> Converting CRLF to LF on remote"
ssh $Host_ "cd $RemoteDir && find . -type f \( -name '*.sh' -o -name '*.py' -o -name '*.conf' -o -name '*.cnf' -o -name '*.cf' -o -name '*.yaml' -o -name '*.yml' -o -name '*.toml' -o -name '*.json' -o -name '*.ini' -o -name '*.sql' -o -name '*.pem' -o -name 'Dockerfile' -o -name '.dockerignore' \) -exec sed -i 's/\r$//' {} +"

# 스크립트 실행 권한 복원 (scp는 권한 미보존)
ssh $Host_ "cd $RemoteDir && find . -name '*.sh' -exec chmod +x {} +"

# .env.production.1 → .env.1
Write-Host "==> Deploying .env.production.1 as .env.1"
scp ".env.production.1" "${Host_}:${RemoteDir}/.env.1"
ssh $Host_ "cd $RemoteDir && sed -i 's/\r$//' .env.1 && chmod 600 .env.1"

# .env.production.2 → .env.2
Write-Host "==> Deploying .env.production.2 as .env.2"
scp ".env.production.2" "${Host_}:${RemoteDir}/.env.2"
ssh $Host_ "cd $RemoteDir && sed -i 's/\r$//' .env.2 && chmod 600 .env.2"

# 데이터 디렉토리 생성
Write-Host "==> Ensuring data directories"
ssh $Host_ "mkdir -p $RemoteDir/logs-1 $RemoteDir/logs-2 $RemoteDir/screenshots-1 $RemoteDir/screenshots-2 && chmod 755 $RemoteDir/logs-1 $RemoteDir/logs-2 $RemoteDir/screenshots-1 $RemoteDir/screenshots-2"

# 이미지 빌드
Write-Host "==> Building telegram-mcp image"
ssh $Host_ "cd $RemoteDir && bash build.sh"

# 컨테이너 시작
Write-Host "==> Starting telegram-mcp containers"
ssh $Host_ "bash $RemoteDir/run.sh"

# 기동 확인
Write-Host "==> Waiting for startup..."
Start-Sleep -Seconds 5
ssh $Host_ "docker ps --filter name=telegram-mcp --format 'table {{.Names}}`t{{.Status}}`t{{.Ports}}'"
Write-Host "Done."
