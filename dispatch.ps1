<#
.SYNOPSIS
    Dispatch production launcher.

.DESCRIPTION
    Docker-only commands for running Dispatch without npm.
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet("setup", "start", "stop", "restart", "logs", "status", "down", "pull", "help", "version", "")]
    [string]$Command = ""
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptRoot = $PSScriptRoot
$EnvFilePath = Join-Path $ScriptRoot ".env.local"
$RequiredKeys = @(
    "AUTH_SECRET",
    "NEXTAUTH_URL",
    "AUTH_TRUST_HOST",
    "AUTH_GITHUB_ID",
    "AUTH_GITHUB_SECRET",
    "DISPATCH_PORT"
)

$PackageJson = Get-Content -Raw -Path (Join-Path $ScriptRoot "package.json") | ConvertFrom-Json
$Version = $PackageJson.version

function Write-CyanLn   { param([string]$Text) Write-Host $Text -ForegroundColor Cyan }
function Write-DimLn    { param([string]$Text) Write-Host $Text -ForegroundColor DarkGray }
function Write-GreenLn  { param([string]$Text) Write-Host $Text -ForegroundColor Green }
function Write-YellowLn { param([string]$Text) Write-Host $Text -ForegroundColor Yellow }
function Write-RedLn    { param([string]$Text) Write-Host $Text -ForegroundColor Red }

function Show-Logo {
    $logo = @(
        "  ____  ___ ____  ____   _  _____ ____ _   _ "
        " |  _ \\|_ _/ ___||  _ \\ / \\|_   _/ ___| | | |"
        " | | | || |\\___ \\| |_) / _ \\ | || |   | |_| |"
        " | |_| || | ___) |  __/ ___ \\| || |___|  _  |"
        " |____/|___|____/|_| /_/   \\_\\_| \\____|_| |_|"
    )
    Write-Host ""
    foreach ($line in $logo) {
        Write-Host $line -ForegroundColor Cyan
    }
    Write-Host ""
    Write-DimLn "  v$Version - Docker production launcher"
    Write-Host ""
}

function Show-Help {
    Show-Logo

    Write-Host "  USAGE" -ForegroundColor White
    Write-Host "    .\\dispatch.ps1 <command>"
    Write-Host ""
    Write-Host "  COMMANDS" -ForegroundColor White
    Write-Host "    setup      Create or update .env.local for Docker"
    Write-Host "    start      Start Dispatch with Docker Compose"
    Write-Host "    stop       Stop running Dispatch containers"
    Write-Host "    restart    Restart Dispatch containers"
    Write-Host "    logs       Follow Dispatch logs"
    Write-Host "    status     Show container status"
    Write-Host "    pull       Pull latest image and restart"
    Write-Host "    down       Stop and remove containers/network"
    Write-Host "    version    Show version number"
    Write-Host "    help       Show this help message"
    Write-Host ""
    Write-DimLn "  Developer workflow (npm build/test/dev) moved to .\\dispatch-dev.ps1"
    Write-Host ""
}

function Assert-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-RedLn "Docker is not installed or not on PATH."
        exit 1
    }
}

function New-AuthSecret {
    $bytes = New-Object byte[] 32
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    return ([Convert]::ToBase64String($bytes)).TrimEnd("=") -replace "\+", "-" -replace "/", "_"
}

function Get-EnvMap {
    param([string]$Path)

    $map = [ordered]@{}
    if (-not (Test-Path $Path)) {
        return $map
    }

    foreach ($line in Get-Content -Path $Path) {
        $trimmed = $line.Trim()
        if ($trimmed.Length -eq 0 -or $trimmed.StartsWith("#")) {
            continue
        }

        $parts = $trimmed -split "=", 2
        if ($parts.Length -ne 2) {
            continue
        }

        $key = $parts[0].Trim()
        $value = $parts[1]

        if ($key -match "^[A-Za-z_][A-Za-z0-9_]*$") {
            $map[$key] = $value
        }
    }

    return $map
}

function Write-EnvFile {
    param(
        [string]$Path,
        [hashtable]$Map,
        [string[]]$ExtraLines
    )

    $lines = @(
        "# NextAuth",
        "AUTH_SECRET=$($Map.AUTH_SECRET)",
        "NEXTAUTH_URL=$($Map.NEXTAUTH_URL)",
        "AUTH_TRUST_HOST=$($Map.AUTH_TRUST_HOST)",
        "AUTH_GITHUB_ID=$($Map.AUTH_GITHUB_ID)",
        "AUTH_GITHUB_SECRET=$($Map.AUTH_GITHUB_SECRET)",
        "",
        "# Docker",
        "DISPATCH_PORT=$($Map.DISPATCH_PORT)"
    )

    if ($ExtraLines.Count -gt 0) {
        $lines += ""
        $lines += "# Additional"
        $lines += $ExtraLines
    }

    $lines += ""
    Set-Content -Path $Path -Value $lines -Encoding UTF8
}

function Ensure-EnvFile {
    $existingMap = Get-EnvMap -Path $EnvFilePath

    $extras = @()
    if (Test-Path $EnvFilePath) {
        foreach ($line in Get-Content -Path $EnvFilePath) {
            $trimmed = $line.Trim()
            if ($trimmed.Length -eq 0 -or $trimmed.StartsWith("#")) {
                continue
            }

            $parts = $trimmed -split "=", 2
            if ($parts.Length -ne 2) {
                continue
            }

            $key = $parts[0].Trim()
            if ($RequiredKeys -notcontains $key) {
                $extras += $trimmed
            }
        }
    }

    $dispatchPort = if ($existingMap.Contains("DISPATCH_PORT") -and $existingMap.DISPATCH_PORT) { $existingMap.DISPATCH_PORT } else { "3000" }
    $nextAuthUrl = if ($existingMap.Contains("NEXTAUTH_URL") -and $existingMap.NEXTAUTH_URL) { $existingMap.NEXTAUTH_URL } else { "http://localhost:$dispatchPort" }

    $finalMap = [ordered]@{
        AUTH_SECRET        = if ($existingMap.Contains("AUTH_SECRET") -and $existingMap.AUTH_SECRET) { $existingMap.AUTH_SECRET } else { New-AuthSecret }
        NEXTAUTH_URL       = $nextAuthUrl
        AUTH_TRUST_HOST    = if ($existingMap.Contains("AUTH_TRUST_HOST") -and $existingMap.AUTH_TRUST_HOST) { $existingMap.AUTH_TRUST_HOST } else { "true" }
        AUTH_GITHUB_ID     = if ($existingMap.Contains("AUTH_GITHUB_ID")) { $existingMap.AUTH_GITHUB_ID } else { "" }
        AUTH_GITHUB_SECRET = if ($existingMap.Contains("AUTH_GITHUB_SECRET")) { $existingMap.AUTH_GITHUB_SECRET } else { "" }
        DISPATCH_PORT      = $dispatchPort
    }

    Write-EnvFile -Path $EnvFilePath -Map $finalMap -ExtraLines $extras

    if ($existingMap.Count -eq 0) {
        Write-GreenLn "Created .env.local for Docker deployment."
    } else {
        Write-GreenLn "Updated .env.local for Docker deployment."
    }
    Write-DimLn "Using DISPATCH_PORT=$dispatchPort"
}

function Invoke-Compose {
    param([string[]]$ComposeArgs)

    Set-Location $ScriptRoot
    docker compose --env-file .env.local @ComposeArgs
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

function Invoke-Setup {
    Show-Logo
    Assert-Docker
    Ensure-EnvFile
}

function Invoke-Start {
    Show-Logo
    Assert-Docker
    Ensure-EnvFile
    Invoke-Compose -ComposeArgs @("up", "-d")
    Write-GreenLn "Dispatch is running."
}

function Invoke-Stop {
    Show-Logo
    Assert-Docker
    Ensure-EnvFile
    Invoke-Compose -ComposeArgs @("stop")
}

function Invoke-Restart {
    Show-Logo
    Assert-Docker
    Ensure-EnvFile
    Invoke-Compose -ComposeArgs @("restart")
}

function Invoke-Logs {
    Show-Logo
    Assert-Docker
    Ensure-EnvFile
    Invoke-Compose -ComposeArgs @("logs", "-f", "dispatch")
}

function Invoke-Status {
    Show-Logo
    Assert-Docker
    Ensure-EnvFile
    Invoke-Compose -ComposeArgs @("ps")
}

function Invoke-Down {
    Show-Logo
    Assert-Docker
    Ensure-EnvFile
    Invoke-Compose -ComposeArgs @("down")
}

function Invoke-Pull {
    Show-Logo
    Assert-Docker
    Ensure-EnvFile
    Invoke-Compose -ComposeArgs @("pull")
    Invoke-Compose -ComposeArgs @("up", "-d")
}

switch ($Command) {
    "setup"   { Invoke-Setup }
    "start"   { Invoke-Start }
    "stop"    { Invoke-Stop }
    "restart" { Invoke-Restart }
    "logs"    { Invoke-Logs }
    "status"  { Invoke-Status }
    "down"    { Invoke-Down }
    "pull"    { Invoke-Pull }
    "version" { Write-Host "Dispatch v$Version" }
    "help"    { Show-Help }
    default    { Show-Help }
}
