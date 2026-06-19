#Requires -RunAsAdministrator
param(
    [string]$InstallDir = "C:\raum-terminals",
    [string]$LicenseFile = ""
)

$ErrorActionPreference = "Stop"
$GITHUB_REPO = "domall-it/raum-terminals-releases"
$SERVICE_NAME = "RaumTerminals"
$EXE_NAME = "raum-terminals.exe"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Raum-Terminals Server - Installation  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/5] Aktuelle Version wird ermittelt..." -ForegroundColor Yellow
$releaseApi = "https://api.github.com/repos/$GITHUB_REPO/releases/latest"
$release = Invoke-RestMethod -Uri $releaseApi -UseBasicParsing
$version = $release.tag_name
$asset = $release.assets | Where-Object { $_.name -eq $EXE_NAME } | Select-Object -First 1

if (-not $asset) {
    Write-Error "Konnte $EXE_NAME in Release $version nicht finden."
    exit 1
}

Write-Host "    Version: $version" -ForegroundColor Green

$svc = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq "Running") {
    Write-Host "[2/5] Bestehender Dienst wird gestoppt..." -ForegroundColor Yellow
    Stop-Service -Name $SERVICE_NAME -Force
    Start-Sleep -Seconds 2
} else {
    Write-Host "[2/5] Kein laufender Dienst gefunden." -ForegroundColor Gray
}

Write-Host "[3/5] Installationsverzeichnis: $InstallDir" -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path "$InstallDir\data" | Out-Null

$exePath = Join-Path $InstallDir $EXE_NAME
Write-Host "[4/5] $EXE_NAME wird heruntergeladen..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $exePath -UseBasicParsing
Write-Host "    Gespeichert: $exePath" -ForegroundColor Green

if ($LicenseFile -ne "" -and (Test-Path $LicenseFile)) {
    Copy-Item -Path $LicenseFile -Destination "$InstallDir\license.lic" -Force
    Write-Host "    Lizenz kopiert: $InstallDir\license.lic" -ForegroundColor Green
} elseif (-not (Test-Path "$InstallDir\license.lic")) {
    Write-Host ""
    Write-Host "HINWEIS: Bitte license.lic nach $InstallDir kopieren." -ForegroundColor Yellow
}

Write-Host "[5/5] Windows-Dienst wird registriert..." -ForegroundColor Yellow
$svcExists = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
if ($svcExists) {
    if ($svcExists.Status -eq "Running") {
        Stop-Service -Name $SERVICE_NAME -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
    }
    Get-Process -Name ($EXE_NAME -replace '\.exe$','') -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    & "$exePath" uninstall 2>&1 | Out-Null
    Start-Sleep -Seconds 1
}
& "$exePath" install
Start-Sleep -Seconds 1
& "$exePath" start

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Installation abgeschlossen!           " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Dashboard: http://localhost:2300" -ForegroundColor Cyan
Write-Host "  Dienst:    $SERVICE_NAME" -ForegroundColor Cyan
Write-Host ""
Write-Host "Naechste Schritte:" -ForegroundColor White
Write-Host "  1. http://localhost:2300 im Browser oeffnen" -ForegroundColor Gray
Write-Host "  2. EWS-Verbindung in den Einstellungen konfigurieren" -ForegroundColor Gray
Write-Host "  3. Raeume anlegen und Geraete zuweisen" -ForegroundColor Gray
Write-Host ""
