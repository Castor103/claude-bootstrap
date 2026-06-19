#Requires -Version 5.1
<#
.SYNOPSIS
    Claude Code를 npm 방식으로 설치/업데이트한다.

.DESCRIPTION
    install-claude-npm.sh 의 Windows PowerShell 포팅.
    Node.js 없으면 winget 또는 직접 다운로드로 설치한 뒤,
    npm install -g @anthropic-ai/claude-code@latest 를 실행한다.
    기존 standalone 설치가 있으면 정리하고 npm으로 통일.

    설치 항목
      1) Node.js / npm 확보 (winget → fnm → 직접 다운로드)
      2) Claude Code 설치   (npm install -g)
      3) standalone 정리    (있으면 제거)
      4) PATH 확인
      5) 검증

    멱등성: 여러 번 실행해도 안전.
    설정 디렉터리(~/.claude)는 절대 건드리지 않는다.

.EXAMPLE
    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
    .\install-claude-npm.ps1
#>

$ErrorActionPreference = "Stop"

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " Claude Code: npm 설치 (최신 버전)"
Write-Host " 지원 OS: Windows 10+ (PowerShell 5.1+)"
Write-Host " standalone 설치가 있으면 자동으로 정리하고 npm으로 통일"
Write-Host "================================================="
Write-Host ""

# ---------------------------------------------------------------
# 1. Windows 버전 확인
# ---------------------------------------------------------------
Write-Host "[1/5] Windows 버전 확인..." -ForegroundColor Yellow

$osVersion = [System.Environment]::OSVersion.Version
if ($osVersion.Major -lt 10) {
    Write-Host "  X Windows 10 이상에서만 동작합니다." -ForegroundColor Red
    exit 1
}
Write-Host "  OK Windows $($osVersion.Major).$($osVersion.Minor) (Build $($osVersion.Build))" -ForegroundColor Green
Write-Host ""

# ---------------------------------------------------------------
# 2. Node.js / npm 확인 및 설치
# ---------------------------------------------------------------
Write-Host "[2/5] Node.js / npm 확인..." -ForegroundColor Yellow

$nodeExists = Get-Command node -ErrorAction SilentlyContinue
$npmExists  = Get-Command npm  -ErrorAction SilentlyContinue

if ($nodeExists -and $npmExists) {
    $nodeVer = & node --version 2>$null
    $npmVer  = & npm --version 2>$null
    Write-Host "  OK Node.js $nodeVer / npm $npmVer 감지" -ForegroundColor Green
}
else {
    Write-Host "  Node.js 또는 npm이 없습니다. 설치를 진행합니다..." -ForegroundColor Yellow

    $installed = $false

    # 방법 1: winget
    $wingetExists = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetExists -and -not $installed) {
        Write-Host "  winget으로 Node.js LTS 설치 중..."
        winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            $installed = $true
            Write-Host "  OK winget으로 Node.js 설치 완료" -ForegroundColor Green
        }
        else {
            Write-Host "  ! winget 설치 실패 (exit: $LASTEXITCODE), 다른 방법 시도..." -ForegroundColor Yellow
        }
    }

    # 방법 2: fnm (Fast Node Manager)
    $fnmExists = Get-Command fnm -ErrorAction SilentlyContinue
    if ($fnmExists -and -not $installed) {
        Write-Host "  fnm으로 Node.js v20 설치 중..."
        fnm install 20
        if ($LASTEXITCODE -eq 0) {
            fnm use 20
            fnm default 20
            $installed = $true
            Write-Host "  OK fnm으로 Node.js 설치 완료" -ForegroundColor Green
        }
        else {
            Write-Host "  ! fnm 설치 실패 (exit: $LASTEXITCODE), 다른 방법 시도..." -ForegroundColor Yellow
        }
    }

    # 방법 3: 직접 다운로드
    if (-not $installed) {
        Write-Host "  Node.js v20 LTS를 직접 다운로드합니다..."
        $arch = if ([System.Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
        $msiUrl = "https://nodejs.org/dist/v20.18.1/node-v20.18.1-$arch.msi"
        $msiPath = Join-Path $env:TEMP "node-lts-install.msi"

        Write-Host "  다운로드: $msiUrl"
        Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath -UseBasicParsing

        Write-Host "  MSI 설치 중 (관리자 권한 필요할 수 있음)..."
        $proc = Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /qn" -Wait -NoNewWindow -PassThru
        Remove-Item $msiPath -ErrorAction SilentlyContinue

        if ($proc.ExitCode -ne 0) {
            Write-Host "  ! MSI 설치 실패 (exit: $($proc.ExitCode)). 관리자 권한으로 다시 시도하세요." -ForegroundColor Red
            exit 1
        }

        # PATH 갱신 (MSI가 시스템 PATH에 추가하므로 현재 세션에 반영)
        $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        $userPath    = [System.Environment]::GetEnvironmentVariable("Path", "User")
        $env:Path    = "$machinePath;$userPath"

        $installed = $true
        Write-Host "  OK Node.js 직접 설치 완료" -ForegroundColor Green
    }

    # 설치 확인
    $nodeExists = Get-Command node -ErrorAction SilentlyContinue
    $npmExists  = Get-Command npm  -ErrorAction SilentlyContinue
    if (-not $nodeExists -or -not $npmExists) {
        Write-Host "  X Node.js 설치 후에도 node/npm을 찾을 수 없습니다." -ForegroundColor Red
        Write-Host "    새 PowerShell 창을 열고 다시 실행하세요."
        exit 1
    }
    $nodeVer = & node --version 2>$null
    $npmVer  = & npm --version 2>$null
    Write-Host "  OK Node.js $nodeVer / npm $npmVer 설치 완료" -ForegroundColor Green
}
Write-Host ""

# ---------------------------------------------------------------
# 3. npm으로 Claude Code 최신 버전 설치
# ---------------------------------------------------------------
Write-Host "[3/5] npm으로 Claude Code 최신 버전 설치..." -ForegroundColor Yellow

$claudeExists = Get-Command claude -ErrorAction SilentlyContinue
if ($claudeExists) {
    $claudeVer = & claude --version 2>$null
    Write-Host "  이미 claude가 설치돼 있습니다 ($claudeVer). 최신으로 업데이트..."
}
& npm install -g @anthropic-ai/claude-code@latest
if ($LASTEXITCODE -ne 0) {
    Write-Host "  X npm install 실패" -ForegroundColor Red
    exit 1
}
Write-Host "  OK 설치 완료" -ForegroundColor Green
Write-Host ""

# ---------------------------------------------------------------
# 4. 기존 standalone 설치 정리 (있으면 제거)
# ---------------------------------------------------------------
Write-Host "[4/5] 기존 standalone 설치 정리..." -ForegroundColor Yellow

$standalonePaths = @(
    (Join-Path $env:LOCALAPPDATA "claude"),
    (Join-Path $env:USERPROFILE ".local\bin\claude.exe"),
    (Join-Path $env:USERPROFILE ".local\share\claude")
)

$cleaned = $false
foreach ($p in $standalonePaths) {
    if (Test-Path $p) {
        if ((Get-Item $p).PSIsContainer) {
            $versionsDir = Join-Path $p "versions"
            if (Test-Path $versionsDir) {
                Remove-Item $versionsDir -Recurse -Force
                Write-Host "  OK standalone versions 제거: $versionsDir" -ForegroundColor Green
                $cleaned = $true
            }
        }
        else {
            Remove-Item $p -Force
            Write-Host "  OK standalone 파일 제거: $p" -ForegroundColor Green
            $cleaned = $true
        }
    }
}
if (-not $cleaned) {
    Write-Host "  - standalone 설치 없음 (스킵)"
}
Write-Host ""

# ---------------------------------------------------------------
# 5. 검증
# ---------------------------------------------------------------
Write-Host "[5/5] 설치 검증..." -ForegroundColor Yellow

# PATH 갱신
$machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath    = [System.Environment]::GetEnvironmentVariable("Path", "User")
$env:Path    = "$machinePath;$userPath"

$claudePath = (Get-Command claude -ErrorAction SilentlyContinue).Source
if (-not $claudePath) {
    Write-Host "  X claude 명령어를 찾을 수 없습니다!" -ForegroundColor Red
    Write-Host "    새 PowerShell 창을 열고 다시 확인하세요."
    exit 1
}

$claudeVer = & claude --version 2>$null
Write-Host "  OK claude 경로: $claudePath" -ForegroundColor Green
Write-Host "  OK claude 버전: $claudeVer" -ForegroundColor Green
Write-Host ""

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " 설치 완료!"
Write-Host ""
Write-Host " 다음 단계:"
Write-Host "  1) claude login  (OAuth 인증)"
Write-Host "  2) .\bootstrap-claude-instance.ps1  (스킬/가이드/설정 설치)"
Write-Host "================================================="
