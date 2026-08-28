# MateClaw Windows dev environment one-click launcher
#
# Usage:
#   .\dev-start.ps1              Start backend + frontend (each in a new terminal)
#   .\dev-start.ps1 -Build       Build/install deps first, then start
#   .\dev-start.ps1 -BackendOnly Start backend only
#   .\dev-start.ps1 -FrontendOnly Start frontend only
#   .\dev-start.ps1 -Status      Check ports and health

param(
    [switch]$Build,
    [switch]$BackendOnly,
    [switch]$FrontendOnly,
    [switch]$Status
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$startMutex = New-Object System.Threading.Mutex($false, 'Global\MateClawDevStart')
if (-not $startMutex.WaitOne(0, $false)) {
    Write-Host "dev-start is already running. Please wait for it to finish." -ForegroundColor Yellow
    exit 0
}

try {
$ProjectRoot = Split-Path -Parent $ScriptDir
$ServerDir = Join-Path $ProjectRoot "mateclaw-server"
$UiDir = Join-Path $ProjectRoot "mateclaw-ui"
$BackendPort = 18088
$FrontendPort = 5173

. (Join-Path $ScriptDir "dev-lib.ps1")

function Import-LocalConfig {
    . (Join-Path $ScriptDir "dev-env.ps1")
}

function Assert-Runtime {
    Import-LocalConfig
    $nodeExe = Join-Path $env:NODE_HOME "node.exe"
    if (-not (Test-Path $nodeExe)) {
        throw "Node.js not found: $nodeExe`nSet NODE_HOME in dev.local.ps1."
    }
}

function Test-PortListening([int]$Port) {
    return Test-MateClawPortListening $Port
}

function Show-Status {
    Write-Host ""
    Write-Host "=== MateClaw dev status ===" -ForegroundColor Cyan
    Write-Host ""

    $backendUp = Test-PortListening $BackendPort
    $frontendUp = Test-PortListening $FrontendPort

    $backendLabel = if ($backendUp) { "running" } else { "stopped" }
    $frontendLabel = if ($frontendUp) { "running" } else { "stopped" }

    Write-Host ("Backend  :{0}  {1}" -f $BackendPort, $backendLabel)
    Write-Host ("Frontend :{0}  {1}" -f $FrontendPort, $frontendLabel)

    if ($backendUp) {
        try {
            $health = Invoke-RestMethod -Uri "http://localhost:$BackendPort/actuator/health" -TimeoutSec 3
            Write-Host ("Health   : {0}" -f $health.status)
        } catch {
            Write-Host "Health   : port open but API not responding" -ForegroundColor Yellow
        }
    }

    Write-Host ""
    if ($frontendUp) {
        Write-Host "Open: http://localhost:$FrontendPort" -ForegroundColor Green
        Write-Host "Login: admin / Playsea45"
    }
    Write-Host ""
}

function Invoke-Build {
    Write-Host ">>> mvn install (backend modules)..." -ForegroundColor Cyan
    Push-Location $ProjectRoot
    try {
        $mvnArgs = @("install", "-pl", "mateclaw-server", "-am", "-DskipTests")
        if ($env:MAVEN_FLAGS) { $mvnArgs += $env:MAVEN_FLAGS.Split(" ", [StringSplitOptions]::RemoveEmptyEntries) }
        & mvn @mvnArgs
        if ($LASTEXITCODE -ne 0) { throw "Maven install failed (exit $LASTEXITCODE)" }
    } finally {
        Pop-Location
    }

    Write-Host ">>> npm install (frontend)..." -ForegroundColor Cyan
    Push-Location $UiDir
    try {
        if (-not (Test-Path "node_modules")) {
            & npm install
            if ($LASTEXITCODE -ne 0) { throw "npm install failed (exit $LASTEXITCODE)" }
        } else {
            Write-Host "node_modules exists, skip npm install (delete it to reinstall)"
        }
    } finally {
        Pop-Location
    }

    Write-Host ">>> Build done" -ForegroundColor Green
}

function Ensure-DevServiceStopped([int]$Port, [string]$Label, [switch]$Backend, [switch]$Frontend) {
    Ensure-MateClawDevServiceStopped -Port $Port -Label $Label -Backend:$Backend -Frontend:$Frontend
}

function Start-BackendWindow {
    Ensure-DevServiceStopped -Port $BackendPort -Label "Backend" -Backend

    $javaBin = Join-Path $env:JAVA_HOME "bin"
    $mavenBin = Join-Path $env:MAVEN_HOME "bin"
    $cmd = @"
chcp 65001 > `$null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
`$env:JAVA_HOME='$env:JAVA_HOME'
`$env:Path='$javaBin;$mavenBin;' + `$env:Path
Set-Location '$ServerDir'
Write-Host '>>> MateClaw backend starting (port $BackendPort)...' -ForegroundColor Cyan
mvn spring-boot:run '-Dmaven.test.skip=true' '-Dspring-boot.run.jvmArguments=-Dfile.encoding=UTF-8 -Dstdout.encoding=UTF-8 -Dstderr.encoding=UTF-8'
"@
    Start-Process powershell -ArgumentList "-NoExit", "-Command", $cmd -WindowStyle Normal
    Write-Host "Backend started in new window (port $BackendPort)"
}

function Start-FrontendWindow {
    Ensure-DevServiceStopped -Port $FrontendPort -Label "Frontend" -Frontend

    if (-not (Test-Path (Join-Path $UiDir "node_modules"))) {
        throw "Frontend deps missing. Run: .\dev-start.ps1 -Build"
    }

    $cmd = @"
`$env:Path='$env:NODE_HOME;' + `$env:Path
Set-Location '$UiDir'
Write-Host '>>> MateClaw frontend starting (port $FrontendPort)...' -ForegroundColor Cyan
npm run dev
"@
    Start-Process powershell -ArgumentList "-NoExit", "-Command", $cmd
    Write-Host "Frontend started in new window (port $FrontendPort)"
}

Assert-Runtime

if ($Status) {
    Show-Status
    return
}

if ($Build) {
    Invoke-Build
}

$startBackend = -not $FrontendOnly
$startFrontend = -not $BackendOnly

if ($startBackend) { Start-BackendWindow }
if ($startFrontend) { Start-FrontendWindow }

Write-Host ""
Write-Host "Open: http://localhost:$FrontendPort" -ForegroundColor Green
Write-Host "Login: admin / Playsea45"
Write-Host "Stop:  .\dev-stop.ps1"
Write-Host ""

} finally {
    if ($startMutex) {
        try { $startMutex.ReleaseMutex() | Out-Null } catch {}
        $startMutex.Dispose()
    }
}
