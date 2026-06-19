#Requires -RunAsAdministrator
param(
    [string]$InstallDir = "C:\raum-terminals",
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"
$GITHUB_REPO = "domall-it/raum-terminals-releases"
$SERVICE_NAME = "RaumTerminals"
$EXE_NAME = "raum-terminals.exe"
$exePath = Join-Path $InstallDir $EXE_NAME

if (-not (Test-Path $exePath)) {
    Write-Error "$exePath nicht gefunden. Bitte zuerst install.ps1 ausfuehren."
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Raum-Terminals Server - Update       " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/4] Verfuegbare Versionen werden geprueft..." -ForegroundColor Yellow
$apiUrl = if ($Version -eq "") {
    "https://api.github.com/repos/$GITHUB_REPO/releases/latest"
} else {
    "https://api.github.com/repos/$GITHUB_REPO/releases/tags/$Version"
}
$release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
$newVersion = $release.tag_name
$asset = $release.assets | Where-Object { $_.name -eq $EXE_NAME } | Select-Object -First 1

if (-not $asset) {
    Write-Error "Konnte $EXE_NAME in Release $newVersion nicht finden."
    exit 1
}

Write-Host "  Verfuegbar: $newVersion" -ForegroundColor Green

Write-Host "[2/4] Dienst wird gestoppt..." -ForegroundColor Yellow
$svc = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq "Running") {
    Stop-Service -Name $SERVICE_NAME -Force
    Start-Sleep -Seconds 3
}
# Prozess erzwungen beenden falls noch laufend (Datei-Lock vermeiden)
$null = & taskkill /F /IM $EXE_NAME /T 2>&1
Start-Sleep -Seconds 2

Write-Host "[3/4] Neue Version wird heruntergeladen..." -ForegroundColor Yellow
$tmpPath = "$exePath.new"
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmpPath -UseBasicParsing
Copy-Item -Path $exePath -Destination "$exePath.bak" -Force
Remove-Item -Path $exePath -Force
Move-Item -Path $tmpPath -Destination $exePath
Write-Host "    $newVersion installiert." -ForegroundColor Green

Write-Host "[4/4] Dienst wird gestartet..." -ForegroundColor Yellow
Start-Service -Name $SERVICE_NAME
Start-Sleep -Seconds 2

$svc = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq "Running") {
    Write-Host ""
    Write-Host "  Update auf $newVersion erfolgreich!" -ForegroundColor Green
    Write-Host ""
    Remove-Item "$exePath.bak" -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "FEHLER: Dienst konnte nicht gestartet werden - Rollback..." -ForegroundColor Red
    Stop-Service -Name $SERVICE_NAME -Force -ErrorAction SilentlyContinue
    Move-Item -Path "$exePath.bak" -Destination $exePath -Force
    Start-Service -Name $SERVICE_NAME
    Write-Host "Rollback abgeschlossen." -ForegroundColor Yellow
    exit 1
}
