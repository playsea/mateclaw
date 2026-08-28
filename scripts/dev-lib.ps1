# Shared helpers for MateClaw Windows dev scripts

$script:MateClawBackendPort = 18088
$script:MateClawFrontendPort = 5173

function Test-MateClawPortListening([int]$Port) {
    return [bool](Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
}

function Stop-MateClawProcessTree([int]$RootPid) {
    if ($RootPid -le 0) { return }

    $children = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ParentProcessId -eq $RootPid }

    foreach ($child in $children) {
        Stop-MateClawProcessTree $child.ProcessId
    }

    Stop-Process -Id $RootPid -Force -ErrorAction SilentlyContinue
}

function Get-MateClawDevShellRootProcessId([int]$LeafPid) {
    $current = Get-CimInstance Win32_Process -Filter "ProcessId=$LeafPid" -ErrorAction SilentlyContinue
    $lastShell = $null

    while ($current) {
        if ($current.Name -ieq 'powershell.exe' -or $current.Name -ieq 'pwsh.exe') {
            $lastShell = [int]$current.ProcessId
        }
        if ($current.ParentProcessId -eq 0) { break }
        $current = Get-CimInstance Win32_Process -Filter "ProcessId=$($current.ParentProcessId)" -ErrorAction SilentlyContinue
    }

    if ($lastShell) { return $lastShell }
    return $LeafPid
}

function Stop-MateClawDevShellsByCommandLine {
    param(
        [switch]$Backend,
        [switch]$Frontend
    )

    $shells = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ieq 'powershell.exe' -or $_.Name -ieq 'pwsh.exe' }

    foreach ($shell in $shells) {
        $cmd = [string]$shell.CommandLine
        if (-not $cmd) { continue }

        $isBackendShell = $cmd -like '*-NoExit*' -and $cmd -like '*mateclaw-server*' -and $cmd -like '*spring-boot:run*'
        $isFrontendShell = $cmd -like '*-NoExit*' -and $cmd -like '*mateclaw-ui*' -and ($cmd -like '*npm run dev*' -or $cmd -like '*vite*')

        if (($Backend -and $isBackendShell) -or ($Frontend -and $isFrontendShell)) {
            Write-Host "Stopping dev shell (PID $($shell.ProcessId))..."
            Stop-MateClawProcessTree ([int]$shell.ProcessId)
        }
    }
}

function Stop-MateClawPort([int]$Port, [string]$Label) {
    $conns = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if (-not $conns) {
        return $false
    }

    $rootIds = $conns |
        Select-Object -ExpandProperty OwningProcess -Unique |
        ForEach-Object { Get-MateClawDevShellRootProcessId $_ } |
        Select-Object -Unique

    foreach ($rootId in $rootIds) {
        try {
            $proc = Get-Process -Id $rootId -ErrorAction Stop
            Write-Host "Stopping $Label dev window (root PID $rootId, $($proc.ProcessName))..."
            Stop-MateClawProcessTree $rootId
        } catch {
            Write-Host "Cannot stop root PID $rootId : $_" -ForegroundColor Yellow
        }
    }

    return $true
}

function Wait-MateClawPortReleased([int]$Port, [int]$TimeoutSec = 15) {
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if (-not (Test-MateClawPortListening $Port)) {
            return $true
        }
        Start-Sleep -Milliseconds 500
    }
    return -not (Test-MateClawPortListening $Port)
}

function Stop-MateClawDevServices {
    param(
        [switch]$Backend,
        [switch]$Frontend,
        [switch]$All
    )

    if ($All -or (-not $Backend -and -not $Frontend)) {
        $Backend = $true
        $Frontend = $true
    }

    if ($Backend) {
        Stop-MateClawDevShellsByCommandLine -Backend
        if (Stop-MateClawPort $script:MateClawBackendPort "Backend") {
            if (-not (Wait-MateClawPortReleased $script:MateClawBackendPort)) {
                throw "Backend port $($script:MateClawBackendPort) is still in use after stop."
            }
        } else {
            Write-Host "Backend (port $($script:MateClawBackendPort)): not running"
        }
    }

    if ($Frontend) {
        Stop-MateClawDevShellsByCommandLine -Frontend
        if (Stop-MateClawPort $script:MateClawFrontendPort "Frontend") {
            if (-not (Wait-MateClawPortReleased $script:MateClawFrontendPort)) {
                throw "Frontend port $($script:MateClawFrontendPort) is still in use after stop."
            }
        } else {
            Write-Host "Frontend (port $($script:MateClawFrontendPort)): not running"
        }
    }
}

function Ensure-MateClawDevServiceStopped {
    param(
        [int]$Port,
        [string]$Label,
        [switch]$Backend,
        [switch]$Frontend
    )

    $wasRunning = Test-MateClawPortListening $Port
    if ($wasRunning) {
        Write-Host ">>> $Label already running on port $Port, stopping old process..." -ForegroundColor Yellow
    } else {
        Write-Host ">>> Checking for stale $Label dev windows..." -ForegroundColor DarkGray
    }

    if ($Backend) {
        Stop-MateClawDevServices -Backend | Out-Null
    } else {
        Stop-MateClawDevServices -Frontend | Out-Null
    }

    Start-Sleep -Milliseconds 800
}
