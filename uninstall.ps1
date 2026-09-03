#Requires -RunAsAdministrator
param(
    [string]$InstallDir = "C:\raum-terminals",
    [switch]$KeepData
)

$SERVICE_NAME = "RaumTerminals"
$EXE_NAME     = "raum-terminals.exe"
$exePath      = Join-Path $InstallDir $EXE_NAME

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Raum-Terminals Server - Deinstallation  " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Dienst stoppen
$svc = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
if ($svc) {
    if ($svc.Status -eq "Running") {
        Write-Host "[1/4] Dienst wird gestoppt..." -ForegroundColor Yellow
        Stop-Service -Name $SERVICE_NAME -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    } else {
        Write-Host "[1/4] Dienst ist bereits gestoppt." -ForegroundColor Gray
    }
} else {
    Write-Host "[1/4] Kein Dienst gefunden." -ForegroundColor Gray
}

# 2. Prozess hart beenden (falls noch laufend)
Write-Host "[2/4] Prozess wird beendet..." -ForegroundColor Yellow
Get-Process -Name ($EXE_NAME -replace '\.exe$','') -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# 3. Dienst aus SCM entfernen
$svc = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
if ($svc) {
    Write-Host "[3/4] Dienst wird aus dem System entfernt..." -ForegroundColor Yellow
    if (Test-Path $exePath) {
        & "$exePath" uninstall 2>&1 | Out-Null
    }
    if (Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue) {
        sc.exe delete $SERVICE_NAME | Out-Null
    }
    Write-Host "    Dienst entfernt." -ForegroundColor Green
} else {
    Write-Host "[3/4] Kein Dienst zum Entfernen." -ForegroundColor Gray
}

# 4. Installationsverzeichnis loeschen
if (Test-Path $InstallDir) {
    if ($KeepData) {
        Write-Host "[4/4] Programmdateien werden entfernt (Daten bleiben erhalten)..." -ForegroundColor Yellow
        Remove-Item -Path $exePath -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host ""
        $confirm = Read-Host "    Installationsverzeichnis '$InstallDir' komplett loeschen? (Datenbank geht verloren!) [j/N]"
        if ($confirm -eq "j" -or $confirm -eq "J") {
            Write-Host "[4/4] Verzeichnis wird geloescht..." -ForegroundColor Yellow
            Remove-Item -Path $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "    Geloescht: $InstallDir" -ForegroundColor Green
        } else {
            Write-Host "[4/4] Verzeichnis bleibt erhalten: $InstallDir" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "[4/4] Installationsverzeichnis nicht gefunden." -ForegroundColor Gray
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Deinstallation abgeschlossen.           " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
