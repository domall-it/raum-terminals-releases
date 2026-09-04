#Requires -RunAsAdministrator
<#
    Raum-Terminals Server - Installation

    Beispiele:
        .\install.ps1
            Fragt nach dem Installationsverzeichnis
            (Vorgabe: C:\Program Files\Raum-Terminals)

        .\install.ps1 -InstallDir "D:\Programme\Raum-Terminals" -LicenseFile C:\Downloads\firma.lic
            Laeuft ohne Rueckfrage, geeignet fuer automatisierte Installation

        .\install.ps1 -SkipFirewall
            Legt keine Firewall-Regel an
#>
param(
    [string]$InstallDir = "",
    [string]$LicenseFile = "",
    [switch]$SkipFirewall
)

$ErrorActionPreference = "Stop"

$GITHUB_REPO  = "domall-it/raum-terminals-releases"
$SERVICE_NAME = "RaumTerminals"
$EXE_NAME     = "raum-terminals.exe"
$HTTP_PORT    = 2300
$REG_UNINST   = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\RaumTerminals"

# Programm und Daten liegen getrennt: In Program Files darf ein Dienst nicht
# schreiben, deshalb gehoeren Datenbank und Lizenz nach ProgramData. Bestehende
# Installationen behalten ihren bisherigen Ort, das erkennt der Server selbst
# an der vorhandenen Datenbank.
$DEFAULT_DIR = Join-Path $env:ProgramFiles "Raum-Terminals"
$DATA_DIR    = Join-Path $env:ProgramData  "Raum-Terminals"

# Diese Dateien gehoeren mit ins Installationsverzeichnis, damit Update und
# Deinstallation spaeter ohne erneuten Download funktionieren.
$HELPER_SCRIPTS = @("uninstall.ps1", "update.ps1")

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Raum-Terminals Server - Installation  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------- Zielpfad
# Eine bestehende Installation wird am Dienst erkannt: Der SCM kennt den
# Pfad der Programmdatei, damit braucht es keine eigene Ablage dafuer.
$existingDir = ""
$svcInfo = Get-CimInstance Win32_Service -Filter "Name='$SERVICE_NAME'" -ErrorAction SilentlyContinue
if ($svcInfo -and $svcInfo.PathName) {
    $exeFromSvc = ($svcInfo.PathName -replace '\s+run\s*$', '').Trim('"')
    if ($exeFromSvc) { $existingDir = Split-Path -Parent $exeFromSvc }
}

if ($InstallDir -eq "") {
    $suggestion = $DEFAULT_DIR
    if ($existingDir -ne "") {
        $suggestion = $existingDir
        Write-Host "Bestehende Installation gefunden: $existingDir" -ForegroundColor Gray
        Write-Host ""
    }
    Write-Host "Wohin soll das Programm installiert werden?" -ForegroundColor White
    Write-Host "  Vorgabe: $suggestion" -ForegroundColor Cyan
    Write-Host "  Zum Uebernehmen einfach ENTER druecken," -ForegroundColor Gray
    Write-Host "  oder einen anderen Pfad eingeben." -ForegroundColor Gray
    Write-Host ""
    $answer = Read-Host "Pfad (ENTER = Vorgabe)"
    if ($answer.Trim() -eq "") { $InstallDir = $suggestion } else { $InstallDir = $answer.Trim() }
    Write-Host "  Gewaehlt: $InstallDir" -ForegroundColor Green
}

# Zeigt der Dienst woanders hin, muss das geklaert werden: sonst laeuft die
# Installation ins Leere oder es entstehen zwei getrennte Datenbestaende.
if ($existingDir -ne "" -and $existingDir -ne $InstallDir) {
    Write-Host ""
    Write-Host "ACHTUNG: Der Dienst zeigt derzeit auf $existingDir" -ForegroundColor Yellow
    Write-Host "Bei Installation nach $InstallDir wird der Dienst dorthin umgestellt." -ForegroundColor Yellow
    Write-Host "Liegt Ihre bisherige Datenbank in $existingDir\data, bleibt sie dort" -ForegroundColor Yellow
    Write-Host "liegen und wird nicht mehr verwendet." -ForegroundColor Yellow
    $go = Read-Host "Trotzdem fortfahren? (j = ja, ENTER = abbrechen)"
    if ($go -ne "j" -and $go -ne "J") {
        Write-Host "Abgebrochen, es wurde nichts geaendert." -ForegroundColor Gray
        exit 0
    }
}

Write-Host ""
Write-Host "[1/7] Aktuelle Version wird ermittelt..." -ForegroundColor Yellow
$releaseApi = "https://api.github.com/repos/$GITHUB_REPO/releases/latest"
$release = Invoke-RestMethod -Uri $releaseApi -UseBasicParsing
$version = $release.tag_name
$asset = $release.assets | Where-Object { $_.name -eq $EXE_NAME } | Select-Object -First 1

if (-not $asset) {
    Write-Error "Konnte $EXE_NAME in Release $version nicht finden."
    exit 1
}
Write-Host "    Version: $version" -ForegroundColor Green

# ------------------------------------------------------------ Dienst stoppen
$svc = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq "Running") {
    Write-Host "[2/7] Bestehender Dienst wird gestoppt..." -ForegroundColor Yellow
    Stop-Service -Name $SERVICE_NAME -Force
    Start-Sleep -Seconds 2
} else {
    Write-Host "[2/7] Kein laufender Dienst gefunden." -ForegroundColor Gray
}

# --------------------------------------------------------------- Verzeichnis
Write-Host "[3/7] Verzeichnisse werden vorbereitet..." -ForegroundColor Yellow
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    Write-Host "    Programm: $InstallDir (angelegt)" -ForegroundColor Green
} else {
    Write-Host "    Programm: $InstallDir" -ForegroundColor Green
}

# Liegt neben der Programmdatei bereits eine Datenbank, bleibt sie in Gebrauch.
$legacyDb = Join-Path $InstallDir (Join-Path "data" "raum-terminals.db")
if (Test-Path $legacyDb) {
    $dataBase = $InstallDir
    Write-Host "    Daten:    $InstallDir\data (bestehende Datenbank bleibt in Gebrauch)" -ForegroundColor Green
} else {
    $dataBase = $DATA_DIR
    New-Item -ItemType Directory -Force -Path (Join-Path $DATA_DIR "data") | Out-Null
    Write-Host "    Daten:    $DATA_DIR\data" -ForegroundColor Green
}

# ------------------------------------------------------------------ Programm
$exePath = Join-Path $InstallDir $EXE_NAME
Write-Host "[4/7] $EXE_NAME wird heruntergeladen..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $exePath -UseBasicParsing
Write-Host "    Gespeichert: $exePath" -ForegroundColor Green

# Verwaltungsskripte daneben legen. Liegen sie schon im aktuellen Ordner
# (Download als Paket), werden sie kopiert, sonst aus dem Repo geholt.
Write-Host "[5/7] Verwaltungsskripte werden bereitgestellt..." -ForegroundColor Yellow
foreach ($helper in $HELPER_SCRIPTS) {
    $target = Join-Path $InstallDir $helper
    $local  = Join-Path $PSScriptRoot $helper
    $copied = $false
    if (Test-Path $local) {
        if ((Resolve-Path $local).Path -ne $target) {
            Copy-Item -Path $local -Destination $target -Force
            $copied = $true
        } else {
            $copied = $true
        }
    }
    if (-not $copied) {
        try {
            $url = "https://raw.githubusercontent.com/$GITHUB_REPO/master/$helper"
            Invoke-WebRequest -Uri $url -OutFile $target -UseBasicParsing
            $copied = $true
        } catch {
            Write-Host "    WARNUNG: $helper konnte nicht bereitgestellt werden." -ForegroundColor Yellow
        }
    }
    if ($copied) { Write-Host "    $helper" -ForegroundColor Green }
}

# ------------------------------------------------------------------- Lizenz
$licPath = Join-Path $dataBase "license.lic"
if ($LicenseFile -ne "" -and (Test-Path $LicenseFile)) {
    Copy-Item -Path $LicenseFile -Destination $licPath -Force
    Write-Host "    Lizenz eingespielt: $licPath" -ForegroundColor Green
} elseif (-not (Test-Path $licPath)) {
    Write-Host "    Keine Lizenzdatei angegeben, es wird eine 30-Tage-Testlizenz erzeugt." -ForegroundColor Gray
}

# ----------------------------------------------------------------- Firewall
# Ohne diese Regel erreichen die Displays den Server nicht. Genau daran
# scheitern Erstinstallationen am haeufigsten.
if ($SkipFirewall) {
    Write-Host "[6/7] Firewall wird uebersprungen (-SkipFirewall)." -ForegroundColor Gray
    Write-Host "    Bitte Port $HTTP_PORT eingehend selbst freigeben." -ForegroundColor Yellow
} else {
    Write-Host "[6/7] Firewall-Regel wird geprueft..." -ForegroundColor Yellow
    $ruleName = "Raum-Terminals (HTTP $HTTP_PORT)"
    $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    if ($existingRule) {
        Write-Host "    Regel besteht bereits." -ForegroundColor Gray
    } else {
        try {
            New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow `
                -Protocol TCP -LocalPort $HTTP_PORT -Profile Domain,Private | Out-Null
            Write-Host "    Angelegt: TCP $HTTP_PORT eingehend (Domaene und privates Netz)." -ForegroundColor Green
        } catch {
            Write-Host "    WARNUNG: Regel nicht angelegt: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "    Bitte Port $HTTP_PORT eingehend selbst freigeben." -ForegroundColor Yellow
        }
    }
    Write-Host "    Hinweis: Bei aktiviertem HTTPS zusaetzlich den HTTPS-Port freigeben." -ForegroundColor Gray
}

# -------------------------------------------------------------------- Dienst
Write-Host "[7/7] Windows-Dienst wird registriert..." -ForegroundColor Yellow
$svcExists = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
if ($svcExists) {
    if ($svcExists.Status -eq "Running") {
        Stop-Service -Name $SERVICE_NAME -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
    }
    Get-Process -Name ($EXE_NAME -replace '\.exe$','') -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    # Die alte Registrierung muss ueber die alte Programmdatei entfernt
    # werden, sonst bleibt ein Dienst mit falschem Pfad zurueck.
    $oldExe = Join-Path $existingDir $EXE_NAME
    if ($existingDir -ne "" -and (Test-Path $oldExe)) {
        & "$oldExe" uninstall 2>&1 | Out-Null
    } else {
        & "$exePath" uninstall 2>&1 | Out-Null
    }
    Start-Sleep -Seconds 1
}
& "$exePath" install
Start-Sleep -Seconds 1
& "$exePath" start

# Eintrag in "Apps & Features", damit die Installation dort sichtbar und
# regulaer deinstallierbar ist.
try {
    New-Item -Path $REG_UNINST -Force | Out-Null
    $props = @{
        DisplayName     = "Raum-Terminals Server"
        DisplayVersion  = ($version -replace '^v', '')
        Publisher       = "Raum-Terminals"
        InstallLocation = $InstallDir
        URLInfoAbout    = "https://www.raum-terminals.de"
        UninstallString = "powershell.exe -ExecutionPolicy Bypass -File `"$InstallDir\uninstall.ps1`""
    }
    foreach ($key in $props.Keys) {
        New-ItemProperty -Path $REG_UNINST -Name $key -Value $props[$key] -PropertyType String -Force | Out-Null
    }
    New-ItemProperty -Path $REG_UNINST -Name "NoModify" -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $REG_UNINST -Name "NoRepair" -Value 1 -PropertyType DWord -Force | Out-Null
    Write-Host "    In der Programmliste registriert." -ForegroundColor Green
} catch {
    Write-Host "    WARNUNG: Eintrag in der Programmliste nicht moeglich: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Installation abgeschlossen!           " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Programm:  $InstallDir" -ForegroundColor Cyan
Write-Host "  Daten:     $dataBase\data" -ForegroundColor Cyan
Write-Host "  Dashboard: http://localhost:$HTTP_PORT" -ForegroundColor Cyan
Write-Host "  Dienst:    $SERVICE_NAME" -ForegroundColor Cyan
Write-Host ""
Write-Host "Naechste Schritte:" -ForegroundColor White
Write-Host "  1. http://localhost:$HTTP_PORT im Browser oeffnen (admin / admin)" -ForegroundColor Gray
Write-Host "  2. Kennwort unter Benutzer aendern" -ForegroundColor Gray
Write-Host "  3. Unter Einstellungen den Kalender-Anbieter einrichten" -ForegroundColor Gray
Write-Host "  4. Raeume importieren und Geraete zuweisen" -ForegroundColor Gray
Write-Host ""
Write-Host "Verwaltung:" -ForegroundColor White
Write-Host "  Aktualisieren:  $InstallDir\update.ps1" -ForegroundColor Gray
Write-Host "  Deinstallieren: $InstallDir\uninstall.ps1" -ForegroundColor Gray
Write-Host ""
