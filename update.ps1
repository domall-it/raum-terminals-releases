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
$DEFAULT_DIR  = "C:\Program Files\Raum-Terminals"

# Wird das Skript mit "irm <url> | iex" gestartet, laeuft es nicht aus einer
# Datei. $PSScriptRoot ist dann leer, und jedes Join-Path damit bricht mit
# einer Bindungsfehlermeldung ab, die niemandem sagt, was los ist.
# $ScriptDir ist entweder ein brauchbares Verzeichnis oder leer, und jede
# Verwendung prueft das.
$ScriptDir = $PSScriptRoot

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
    if ($InstallDir -eq "" -and $ScriptDir) { $InstallDir = $ScriptDir }
    if ($InstallDir -eq "") {
        # Kein Dienst, kein Skriptordner: ueber "irm | iex" gestartet, ohne
        # dass jemals installiert wurde. Statt mit einer Bindungsfehlermeldung
        # abzubrechen, wird die Vorgabe geprueft und sonst klar gesagt, was zu
        # tun ist.
        $InstallDir = $DEFAULT_DIR
        Write-Host "Kein Dienst gefunden, es wird die Vorgabe geprueft: $DEFAULT_DIR" -ForegroundColor Gray
    }
}

$exePath = Join-Path $InstallDir $EXE_NAME
if (-not (Test-Path $exePath)) {
    Write-Host ""
    Write-Host "$exePath nicht gefunden." -ForegroundColor Red
    Write-Host "Es ist keine Installation vorhanden, die sich aktualisieren liesse." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Erstinstallation:" -ForegroundColor White
    Write-Host "  irm https://raw.githubusercontent.com/$GITHUB_REPO/master/install.ps1 | iex" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Liegt die Installation woanders, den Pfad angeben:" -ForegroundColor White
    Write-Host "  .\update.ps1 -InstallDir 'D:\Raum-Terminals'" -ForegroundColor Cyan
    Write-Host ""
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
