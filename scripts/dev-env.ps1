# MateClaw Windows dev environment variables
#
# Manual use (run in current terminal):
#   . E:\project\mateclaw\scripts\dev-env.ps1
#
# Then:
#   mvn spring-boot:run '-Dmaven.test.skip=true'   # in mateclaw-server/
#   mvn clean compile -pl mateclaw-server -am -DskipTests   # in project root

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$local = Join-Path $ScriptDir "dev.local.ps1"

# Always use project JDK 21 by default (do NOT inherit system JAVA_HOME which may be 17)
$env:JAVA_HOME = "E:\runtime\jdk-21_windows-x64_bin\jdk-21.0.11"
$env:NODE_HOME = "E:\runtime\node-v20.19.0-win-x64"
$env:MAVEN_HOME = "E:\runtime\apache-maven-3.9.8\apache-maven-3.9.8"

if (Test-Path $local) {
    . $local
}

$javaExe = Join-Path $env:JAVA_HOME "bin\java.exe"
$mvnCmd = Join-Path $env:MAVEN_HOME "bin\mvn.cmd"

if (-not (Test-Path $javaExe)) {
    throw @"
Java not found: $javaExe

JDK 21 path must include the inner folder, e.g.:
  E:\runtime\jdk-21_windows-x64_bin\jdk-21.0.11
NOT the outer extract folder:
  E:\runtime\jdk-21_windows-x64_bin

Copy scripts/dev.local.ps1.example to dev.local.ps1 and fix JAVA_HOME.
"@
}
if (-not (Test-Path $mvnCmd)) {
    throw "Maven not found: $mvnCmd. Set MAVEN_HOME in dev.local.ps1."
}

# Prepend JDK/Maven/Node so mvn/java never pick system Java 17 from PATH
$env:Path = "$(Join-Path $env:JAVA_HOME 'bin');$(Join-Path $env:MAVEN_HOME 'bin');$env:NODE_HOME;$env:Path"

function Get-CommandOutputLines([string]$Exe, [string[]]$CmdArgs) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $savedToolOpts = $env:JAVA_TOOL_OPTIONS
        $env:JAVA_TOOL_OPTIONS = ''
        $lines = & $Exe @CmdArgs 2>&1 | ForEach-Object { $_.ToString() }
        $env:JAVA_TOOL_OPTIONS = $savedToolOpts
        return $lines
    } finally {
        $ErrorActionPreference = $prev
    }
}

function Get-JavaVersionLine([string]$Exe) {
    $line = Get-CommandOutputLines $Exe @('-version') |
        Where-Object { $_ -match 'version "' } |
        Select-Object -First 1
    if (-not $line) {
        throw "Cannot detect Java version from: $Exe"
    }
    return $line
}

$javaVersionLine = Get-JavaVersionLine $javaExe
if ($javaVersionLine -notmatch '"21\.') {
    throw @"
JAVA_HOME must point to JDK 21, but got: $javaVersionLine
Current JAVA_HOME=$env:JAVA_HOME

Fix dev.local.ps1, example:
  `$env:JAVA_HOME = "E:\runtime\jdk-21_windows-x64_bin\jdk-21.0.11"
"@
}

$mvnOutput = Get-CommandOutputLines $mvnCmd @('-version')
$mavenVersionLine = $mvnOutput | Where-Object { $_ -match '^Apache Maven ' } | Select-Object -First 1
$mvnJavaLine = $mvnOutput | Where-Object { $_ -match '^Java version: ' } | Select-Object -First 1
if (-not $mavenVersionLine) {
    throw "Cannot detect Maven version from: $mvnCmd"
}
if ($mvnJavaLine -notmatch 'Java version: 21\.') {
    throw "Maven is not using JDK 21. Maven reports: $mvnJavaLine"
}

# UTF-8 console for Java/Spring Boot logs (set AFTER version checks)
if ($Host.Name -eq 'ConsoleHost') {
    try { chcp 65001 > $null } catch {}
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
}
$env:JAVA_TOOL_OPTIONS = '-Dfile.encoding=UTF-8 -Dstdout.encoding=UTF-8 -Dstderr.encoding=UTF-8'

Write-Host "JAVA_HOME = $env:JAVA_HOME"
Write-Host "Java      = $javaVersionLine"
Write-Host "Maven     = $mavenVersionLine"
