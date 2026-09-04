#Requires -RunAsAdministrator
<#
    Raum-Terminals Server - Update

    Ermittelt das Installationsverzeichnis selbst aus dem Windows-Dienst.
    Datenbank und Lizenz werden nicht angefasst.

    Beispiele:
        .\update.ps1
            Aktualisiert auf die neueste Version

        .\update.ps1 -Version v1.3.1
            Wechselt auf eine bestimmte Version, auch abwaerts

        .\update.ps1 -Force
            Installiert auch dann, wenn die Version bereits aktuell ist
#>
param(
    [string]$InstallDir = "",
    [string]$Version = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$GITHUB_REPO  = "domall-it/raum-terminals-releases"
$SERVICE_NAME = "RaumTerminals"
$EXE_NAME     = "raum-terminals.exe"
$REG_UNINST   = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\RaumTerminals"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Raum-Terminals Server - Update       " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------- Installation finden
# Der Dienst kennt den Pfad seiner Programmdatei. Damit funktioniert das
# Update unabhaengig davon, wohin installiert wurde.
if ($InstallDir -eq "") {
    $svcInfo = Get-CimInstance Win32_Service -Filter "Name='$SERVICE_NAME'" -ErrorAction SilentlyContinue
    if ($svcInfo -and $svcInfo.PathName) {
        $exeFromSvc = ($svcInfo.PathName -replace '\s+run\s*$', '').Trim('"')
        if ($exeFromSvc) { $InstallDir = Split-Path -Parent $exeFromSvc }
    }
    if ($InstallDir -eq "") { $InstallDir = $PSScriptRoot }
}

$exePath = Join-Path $InstallDir $EXE_NAME
if (-not (Test-Path $exePath)) {
    Write-Error "$exePath nicht gefunden. Bitte zuerst install.ps1 ausfuehren."
    exit 1
}
Write-Host "Installationsverzeichnis: $InstallDir" -ForegroundColor Gray

# Installierte Version aus der Programmliste, falls dort registriert.
$currentVersion = ""
if (Test-Path $REG_UNINST) {
    $currentVersion = (Get-ItemProperty -Path $REG_UNINST -Name DisplayVersion -ErrorAction SilentlyContinue).DisplayVersion
}
if ($currentVersion) { Write-Host "Installierte Version:     v$currentVersion" -ForegroundColor Gray }

Write-Host ""
Write-Host "[1/4] Verfuegbare Version wird geprueft..." -ForegroundColor Yellow
if ($Version -eq "") {
    $apiUrl = "https://api.github.com/repos/$GITHUB_REPO/releases/latest"
} else {
    $apiUrl = "https://api.github.com/repos/$GITHUB_REPO/releases/tags/$Version"
}
$release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
$newVersion = $release.tag_name
$asset = $release.assets | Where-Object { $_.name -eq $EXE_NAME } | Select-Object -First 1

if (-not $asset) {
    Write-Error "Konnte $EXE_NAME in Release $newVersion nicht finden."
    exit 1
}
Write-Host "    Verfuegbar: $newVersion" -ForegroundColor Green

if ($currentVersion -and ($newVersion -replace '^v','') -eq $currentVersion -and -not $Force) {
    Write-Host ""
    Write-Host "  Die installierte Version ist bereits aktuell." -ForegroundColor Green
    Write-Host "  Zum erneuten Installieren: .\update.ps1 -Force" -ForegroundColor Gray
    Write-Host ""
    exit 0
}

Write-Host "[2/4] Dienst wird gestoppt..." -ForegroundColor Yellow
$svc = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq "Running") {
    Stop-Service -Name $SERVICE_NAME -Force
    Start-Sleep -Seconds 3
}
# Prozess erzwungen beenden, sonst bleibt die Programmdatei gesperrt.
Get-Process -Name ($EXE_NAME -replace '\.exe$','') -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Write-Host "[3/4] Neue Version wird heruntergeladen..." -ForegroundColor Yellow
$tmpPath = "$exePath.new"
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmpPath -UseBasicParsing
Copy-Item -Path $exePath -Destination "$exePath.bak" -Force
Remove-Item -Path $exePath -Force
Move-Item -Path $tmpPath -Destination $exePath
Write-Host "    $newVersion eingerichtet." -ForegroundColor Green

Write-Host "[4/4] Dienst wird gestartet..." -ForegroundColor Yellow
Start-Service -Name $SERVICE_NAME
Start-Sleep -Seconds 3

$svc = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq "Running") {
    # Version in der Programmliste nachziehen, sonst zeigt Windows dauerhaft
    # die Version der Erstinstallation an.
    if (Test-Path $REG_UNINST) {
        New-ItemProperty -Path $REG_UNINST -Name "DisplayVersion" `
            -Value ($newVersion -replace '^v','') -PropertyType String -Force | Out-Null
    }
    Remove-Item "$exePath.bak" -Force -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "  Update auf $newVersion erfolgreich." -ForegroundColor Green
    Write-Host ""
    Write-Host "  Hinweis: Nach einem Update kann eine erneute Anmeldung im" -ForegroundColor Gray
    Write-Host "  Dashboard noetig sein. Datenbank und Lizenz bleiben erhalten." -ForegroundColor Gray
    Write-Host ""
} else {
    # Startet der Dienst nicht, wird die vorherige Programmdatei
    # zurueckgeholt: Ein defektes Update darf den Betrieb nicht anhalten.
    Write-Host "FEHLER: Dienst konnte nicht gestartet werden, es wird zurueckgesetzt..." -ForegroundColor Red
    Stop-Service -Name $SERVICE_NAME -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (Test-Path "$exePath.bak") {
        Move-Item -Path "$exePath.bak" -Destination $exePath -Force
        Start-Service -Name $SERVICE_NAME
        Write-Host "Vorherige Version wiederhergestellt und gestartet." -ForegroundColor Yellow
    } else {
        Write-Host "Keine Sicherung gefunden, bitte install.ps1 erneut ausfuehren." -ForegroundColor Red
    }
    Write-Host "Ursache pruefen: Ereignisanzeige oder $InstallDir starten mit '$EXE_NAME' im Vordergrund." -ForegroundColor Gray
    exit 1
}
