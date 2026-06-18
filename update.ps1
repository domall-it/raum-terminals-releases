#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Aktualisiert den Raum-Terminals Server auf die neueste Version.

.PARAMETER InstallDir
    Installationsverzeichnis (Standard: C:\raum-terminals)

.PARAMETER Version
    Bestimmte Version installieren (z.B. "v1.2.0"). Standard: neueste Version.

.EXAMPLE
    .\update.ps1
    .\update.ps1 -Version "v1.3.0"
#>
param(
    [string]$InstallDir = "C:\raum-terminals",
    [string]$Version    = ""
)

$ErrorActionPreference = "Stop"
$GITHUB_REPO = "domall-it/raum-terminals-releases"
$SERVICE_NAME = "raum-terminals"
$EXE_NAME     = "raum-terminals.exe"
$exePath      = Join-Path $InstallDir $EXE_NAME

if (-not (Test-Path $exePath)) {
    Write-Error "Raum-Terminals ist nicht installiert ($exePath nicht gefunden). Bitte install.ps1 ausfuehren."
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Raum-Terminals Server — Update       " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# --- Aktuelle Version anzeigen ---
$currentVersion = (& "$exePath" version 2>&1) -replace '^[^0-9v]*', ''
Write-Host "  Installiert: $currentVersion" -ForegroundColor Gray

# --- Zielversion ermitteln ---
Write-Host "[1/4] Verfuegbare Versionen werden geprueft..." -ForegroundColor Yellow
$apiUrl = if ($Version -eq "") {
    "https://api.github.com/repos/$GITHUB_REPO/releases/latest"
} else {
    "https://api.github.com/repos/$GITHUB_REPO/releases/tags/$Version"
}
$release     = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
$newVersion  = $release.tag_name
$asset       = $release.assets | Where-Object { $_.name -eq $EXE_NAME } | Select-Object -First 1

if (-not $asset) {
    Write-Error "Konnte $EXE_NAME in Release $newVersion nicht finden."
    exit 1
}

Write-Host "  Verfuegbar:  $newVersion" -ForegroundColor Green

if ($currentVersion -eq $newVersion -and $Version -eq "") {
    Write-Host ""
    Write-Host "Bereits aktuell — kein Update noetig." -ForegroundColor Green
    Write-Host ""
    exit 0
}

# --- Dienst stoppen ---
Write-Host "[2/4] Dienst wird gestoppt..." -ForegroundColor Yellow
$svc = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq "Running") {
    Stop-Service -Name $SERVICE_NAME -Force
    Start-Sleep -Seconds 3
}

# --- Binary ersetzen ---
Write-Host "[3/4] Neue Version wird heruntergeladen..." -ForegroundColor Yellow
$tmpPath = "$exePath.new"
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmpPath -UseBasicParsing

# Backup der alten Binary
Copy-Item -Path $exePath -Destination "$exePath.bak" -Force
Move-Item  -Path $tmpPath -Destination $exePath -Force

Write-Host "    $newVersion installiert." -ForegroundColor Green

# --- Dienst starten ---
Write-Host "[4/4] Dienst wird gestartet..." -ForegroundColor Yellow
Start-Service -Name $SERVICE_NAME
Start-Sleep -Seconds 2

$svc = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq "Running") {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Update auf $newVersion erfolgreich!   " -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    # Backup loeschen
    Remove-Item "$exePath.bak" -Force -ErrorAction SilentlyContinue
} else {
    Write-Host ""
    Write-Host "FEHLER: Dienst konnte nicht gestartet werden!" -ForegroundColor Red
    Write-Host "Rollback auf vorherige Version..." -ForegroundColor Yellow
    Stop-Service -Name $SERVICE_NAME -Force -ErrorAction SilentlyContinue
    Move-Item -Path "$exePath.bak" -Destination $exePath -Force
    Start-Service -Name $SERVICE_NAME
    Write-Host "Rollback abgeschlossen." -ForegroundColor Yellow
    exit 1
}
