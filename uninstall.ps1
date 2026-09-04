#Requires -RunAsAdministrator
<#
    Raum-Terminals Server - Deinstallation

    Entfernt Dienst, Programmdateien, Firewall-Regel und den Eintrag in der
    Programmliste. Die Daten (Datenbank, Lizenz) bleiben absichtlich
    erhalten und werden nur mit -RemoveData geloescht.

    Beispiele:
        .\uninstall.ps1
            Entfernt das Programm, behaelt Datenbank und Lizenz

        .\uninstall.ps1 -RemoveData
            Entfernt zusaetzlich alle Daten (nicht umkehrbar)
#>
param(
    [string]$InstallDir = "",
    [switch]$RemoveData
)

$SERVICE_NAME = "RaumTerminals"
$EXE_NAME     = "raum-terminals.exe"
$HTTP_PORT    = 2300
$REG_UNINST   = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\RaumTerminals"
$DATA_DIR     = Join-Path $env:ProgramData "Raum-Terminals"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Raum-Terminals Server - Deinstallation  " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------- Installation finden
# Der Dienst kennt den Pfad seiner Programmdatei, das ist die zuverlaessigste
# Quelle. Faellt sie weg, dient der Ordner dieses Skripts als Rueckfall.
if ($InstallDir -eq "") {
    $svcInfo = Get-CimInstance Win32_Service -Filter "Name='$SERVICE_NAME'" -ErrorAction SilentlyContinue
    if ($svcInfo -and $svcInfo.PathName) {
        $exeFromSvc = ($svcInfo.PathName -replace '\s+run\s*$', '').Trim('"')
        if ($exeFromSvc) { $InstallDir = Split-Path -Parent $exeFromSvc }
    }
    if ($InstallDir -eq "") {
        $InstallDir = $PSScriptRoot
        Write-Host "Kein Dienst gefunden, es wird der Ordner dieses Skripts verwendet." -ForegroundColor Gray
    }
}
Write-Host "Installationsverzeichnis: $InstallDir" -ForegroundColor Gray

$exePath = Join-Path $InstallDir $EXE_NAME

# Wo liegen die Daten? Neben der Programmdatei (aeltere Installationen) oder
# in ProgramData. Wichtig fuer die Meldung am Ende, damit niemand danach sucht.
$dataBase = $DATA_DIR
if (Test-Path (Join-Path $InstallDir (Join-Path "data" "raum-terminals.db"))) {
    $dataBase = $InstallDir
}

# -------------------------------------------------------------- 1. Dienst
$svc = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
if ($svc) {
    if ($svc.Status -eq "Running") {
        Write-Host "[1/5] Dienst wird gestoppt..." -ForegroundColor Yellow
        Stop-Service -Name $SERVICE_NAME -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    } else {
        Write-Host "[1/5] Dienst ist bereits gestoppt." -ForegroundColor Gray
    }
} else {
    Write-Host "[1/5] Kein Dienst gefunden." -ForegroundColor Gray
}

Write-Host "[2/5] Prozess wird beendet, falls noch aktiv..." -ForegroundColor Yellow
Get-Process -Name ($EXE_NAME -replace '\.exe$','') -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

$svc = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
if ($svc) {
    Write-Host "[3/5] Dienst wird aus dem System entfernt..." -ForegroundColor Yellow
    if (Test-Path $exePath) {
        & "$exePath" uninstall 2>&1 | Out-Null
    }
    if (Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue) {
        sc.exe delete $SERVICE_NAME | Out-Null
    }
    Write-Host "    Entfernt." -ForegroundColor Green
} else {
    Write-Host "[3/5] Kein Dienst zum Entfernen." -ForegroundColor Gray
}

# ------------------------------------------- 4. Firewall und Programmliste
Write-Host "[4/5] Firewall-Regel und Programmliste werden aufgeraeumt..." -ForegroundColor Yellow
Get-NetFirewallRule -DisplayName "Raum-Terminals*" -ErrorAction SilentlyContinue |
    Remove-NetFirewallRule -ErrorAction SilentlyContinue
if (Test-Path $REG_UNINST) {
    Remove-Item -Path $REG_UNINST -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "    Erledigt." -ForegroundColor Green

# ---------------------------------------------------------- 5. Dateien
Write-Host "[5/5] Programmdateien werden entfernt..." -ForegroundColor Yellow
foreach ($file in @($EXE_NAME, "update.ps1", "raum-terminals.exe.bak")) {
    $path = Join-Path $InstallDir $file
    if (Test-Path $path) { Remove-Item -Path $path -Force -ErrorAction SilentlyContinue }
}
Write-Host "    Erledigt." -ForegroundColor Green

if ($RemoveData) {
    # Ausdruecklich verlangt: Datenbank und Lizenz werden geloescht.
    Write-Host ""
    Write-Host "    -RemoveData ist gesetzt: Datenbank und Lizenz werden geloescht." -ForegroundColor Yellow
    Write-Host "    Betroffen sind: $dataBase\data und $dataBase\license.lic" -ForegroundColor Gray
    $confirm = Read-Host "    Wirklich loeschen? Das ist nicht umkehrbar. (j = loeschen, ENTER = behalten)"
    if ($confirm -eq "j" -or $confirm -eq "J") {
        foreach ($item in @((Join-Path $dataBase "data"), (Join-Path $dataBase "license.lic"))) {
            if (Test-Path $item) { Remove-Item -Path $item -Recurse -Force -ErrorAction SilentlyContinue }
        }
        Write-Host "    Daten geloescht." -ForegroundColor Yellow
    } else {
        Write-Host "    Abgebrochen, die Daten bleiben erhalten." -ForegroundColor Gray
    }
}

# Leeres Programmverzeichnis mitnehmen, aber nur wenn nichts drin geblieben ist.
if ((Test-Path $InstallDir) -and (Get-ChildItem -Path $InstallDir -Force | Measure-Object).Count -eq 0) {
    Remove-Item -Path $InstallDir -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Deinstallation abgeschlossen.           " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
if (-not $RemoveData) {
    Write-Host "  Ihre Daten sind erhalten geblieben:" -ForegroundColor Cyan
    Write-Host "    Datenbank: $dataBase\data\raum-terminals.db" -ForegroundColor Gray
    Write-Host "    Lizenz:    $dataBase\license.lic" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Bei einer Neuinstallation an dieselbe Stelle werden sie" -ForegroundColor Gray
    Write-Host "  automatisch weiterverwendet. Zum vollstaendigen Entfernen:" -ForegroundColor Gray
    Write-Host "    .\uninstall.ps1 -RemoveData" -ForegroundColor Gray
    Write-Host ""
}
