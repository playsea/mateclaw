# MateClaw Windows dev environment stop script
# Usage:
#   .\dev-stop.ps1
#   .\dev-stop.ps1 -BackendOnly
#   .\dev-stop.ps1 -FrontendOnly

param(
    [switch]$BackendOnly,
    [switch]$FrontendOnly
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "dev-lib.ps1")

Write-Host "=== Stop MateClaw dev services ===" -ForegroundColor Cyan
if ($BackendOnly -and $FrontendOnly) {
    throw "Use only one of -BackendOnly or -FrontendOnly."
}
$stopBackend = -not $FrontendOnly
$stopFrontend = -not $BackendOnly
Stop-MateClawDevServices -Backend:$stopBackend -Frontend:$stopFrontend
Write-Host "Done."
