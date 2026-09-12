<#
    Raum-Terminals - Firmware aufs Schild bringen

    Braucht keine Administratorrechte und keine Entwicklungsumgebung.
    Der serielle Zugriff geht mit normalen Benutzerrechten.

    Die Firmwaredatei merged_firmware.bin wird NICHT mitgeliefert. Sie muss
    im aktuellen Ordner liegen oder wird abgefragt. Grund: Sie unterliegt der
    GPLv3, und solange die Quelltextpflicht nicht geklaert ist, wird sie
    nicht oeffentlich verteilt.

    Beispiele:
        irm https://raw.githubusercontent.com/domall-it/raum-terminals-releases/master/flash.ps1 | iex
            Sucht merged_firmware.bin im aktuellen Ordner und fragt nach dem Port

        .\flash.ps1 -Firmware D:\firmware\merged_firmware.bin -Port COM5
            Laeuft ohne Rueckfrage

        .\flash.ps1 -Erase
            Loescht den Flash vollstaendig, bevor geschrieben wird.
            Nur noetig, wenn ein Geraet sich sonst nicht faengt.
#>
param(
    [string]$Firmware = "",
    [string]$Port = "",
    [switch]$Erase,
    [switch]$Ja
)

$ErrorActionPreference = "Stop"

# Fest verdrahtet, weil alle ausgelieferten Schilder denselben Baustein haben.
# esptool bricht ab, wenn ein anderer angeschlossen ist. Das ist beabsichtigt:
# ESP32-S3-Firmware auf einen anderen Baustein zu schreiben legt ihn lahm.
$CHIP          = "esp32s3"
$FW_NAME       = "merged_firmware.bin"
$ESPTOOL_VER   = "v5.4.0"
$ESPTOOL_URL   = "https://github.com/espressif/esptool/releases/download/$ESPTOOL_VER/esptool-$ESPTOOL_VER-windows-amd64.zip"
$BAUD          = 921600

# Das Werkzeug liegt unter LOCALAPPDATA und nicht in Program Files. Dort
# greift die Verhaltensueberwachung mancher Virenschutzprogramme besonders
# hart zu, und fuer ein Werkzeug des angemeldeten Benutzers gehoert es
# ohnehin nicht dorthin. Beim zweiten Aufruf ist es schon da.
$TOOL_DIR = Join-Path $env:LOCALAPPDATA "Raum-Terminals\flash-werkzeug\$ESPTOOL_VER"
$TOOL_EXE = Join-Path $TOOL_DIR "esptool-windows-amd64\esptool.exe"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Raum-Terminals - Firmware flashen    " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------ 1 Firmware
# Bei "irm | iex" gibt es kein Skriptverzeichnis, $PSScriptRoot ist leer.
# Massgeblich ist deshalb der Ordner, in dem die Konsole steht.
Write-Host "[1/4] Firmwaredatei wird gesucht..." -ForegroundColor Yellow

if ($Firmware -eq "") {
    $hier = Join-Path (Get-Location).Path $FW_NAME
    if (Test-Path $hier) {
        $Firmware = $hier
        Write-Host "    Gefunden: $Firmware" -ForegroundColor Green
    } else {
        Write-Host "    $FW_NAME liegt nicht im aktuellen Ordner." -ForegroundColor Gray
        Write-Host "    ($((Get-Location).Path))" -ForegroundColor Gray
        Write-Host ""
        Write-Host "    Die Datei entsteht beim Bauen der Firmware unter" -ForegroundColor Gray
        Write-Host "    .pio\build\seeed_reTerminal_E1001\$FW_NAME" -ForegroundColor Gray
        Write-Host ""
        $Firmware = (Read-Host "Pfad zur $FW_NAME").Trim().Trim('"')
    }
}

if ($Firmware -eq "" -or -not (Test-Path $Firmware)) {
    Write-Host ""
    Write-Host "Firmwaredatei nicht gefunden: $Firmware" -ForegroundColor Red
    exit 1
}
$Firmware = (Resolve-Path $Firmware).Path

# Der Aufbau wird geprueft, nicht die Groesse. Ein zusammengefuehrtes Abbild
# traegt drei Merkmale an festen Stellen:
#
#   0x0      0xE9        Bootloader
#   0x8000   0xAA 0x50   Kennzeichen der Partitionstabelle
#   0x10000  0xE9        Anwendung
#
# firmware.bin faengt ebenfalls mit 0xE9 an und ist fast gleich gross, hat
# aber weder Bootloader noch Partitionstabelle. Wird sie ab Adresse 0
# geschrieben, startet das Geraet nicht mehr. Nach der Groesse zu gehen
# reicht also nicht, der Unterschied betraegt nur rund 60 KB.
$groesse = (Get-Item $Firmware).Length

function Read-ByteAt([string]$pfad, [long]$offset, [int]$anzahl) {
    $fs = [System.IO.File]::OpenRead($pfad)
    try {
        if ($offset + $anzahl -gt $fs.Length) { return @() }
        $fs.Position = $offset
        $puffer = New-Object byte[] $anzahl
        [void]$fs.Read($puffer, 0, $anzahl)
        return $puffer
    } finally { $fs.Dispose() }
}

$bootloader = Read-ByteAt $Firmware 0x0 1
if ($bootloader.Count -lt 1 -or $bootloader[0] -ne 0xE9) {
    Write-Host ""
    Write-Host "Das ist kein ESP-Abbild." -ForegroundColor Red
    if ($bootloader.Count -ge 1) {
        Write-Host "Erstes Byte 0x$('{0:X2}' -f $bootloader[0]), erwartet 0xE9." -ForegroundColor Gray
    }
    exit 1
}

$tabelle = Read-ByteAt $Firmware 0x8000 2
$anwendung = Read-ByteAt $Firmware 0x10000 1
if ($tabelle.Count -lt 2 -or $tabelle[0] -ne 0xAA -or $tabelle[1] -ne 0x50 -or
    $anwendung.Count -lt 1 -or $anwendung[0] -ne 0xE9) {
    Write-Host ""
    Write-Host "Der Datei fehlen Partitionstabelle oder Anwendung." -ForegroundColor Red
    Write-Host ""
    Write-Host "Das ist mit grosser Wahrscheinlichkeit firmware.bin." -ForegroundColor Yellow
    Write-Host "Gebraucht wird $FW_NAME aus demselben Ordner:" -ForegroundColor Yellow
    Write-Host "  .pio\build\seeed_reTerminal_E1001\$FW_NAME" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "firmware.bin enthaelt nur die Anwendung. Ab Adresse 0 geschrieben" -ForegroundColor Gray
    Write-Host "ueberschreibt sie den Bootloader, und das Geraet startet nicht mehr." -ForegroundColor Gray
    exit 1
}
Write-Host "    $([math]::Round($groesse/1MB,2)) MB, Bootloader, Partitionstabelle und Anwendung vorhanden" -ForegroundColor Green

# ------------------------------------------------------------- 2 Werkzeug
Write-Host "[2/4] Flash-Werkzeug wird bereitgestellt..." -ForegroundColor Yellow

if (Test-Path $TOOL_EXE) {
    Write-Host "    esptool $ESPTOOL_VER liegt schon bereit" -ForegroundColor Green
} else {
    # Das Archiv landet im Zielordner und nicht in TEMP: eine Abhaengigkeit
    # weniger, und TEMP ist nicht auf jedem Rechner brauchbar gesetzt.
    New-Item -ItemType Directory -Path $TOOL_DIR -Force | Out-Null
    $zip = Join-Path $TOOL_DIR "esptool-$ESPTOOL_VER.zip"
    try {
        Write-Host "    esptool $ESPTOOL_VER wird geladen (rund 63 MB, einmalig)..." -ForegroundColor Gray
        # Der Fortschrittsbalken von Invoke-WebRequest bremst grosse Downloads
        # in Windows PowerShell erheblich aus.
        $alt = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"
        Invoke-WebRequest -Uri $ESPTOOL_URL -OutFile $zip -UseBasicParsing
        $ProgressPreference = $alt
    } catch {
        Write-Host ""
        Write-Host "Der Download ist fehlgeschlagen:" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Adresse:  $ESPTOOL_URL" -ForegroundColor Gray
        Write-Host "Laesst der Zugang zum Netz das nicht zu, das Archiv von Hand laden," -ForegroundColor Yellow
        Write-Host "hierhin entpacken und erneut starten:" -ForegroundColor Yellow
        Write-Host "  $TOOL_DIR" -ForegroundColor Cyan
        exit 1
    }

    try {
        Expand-Archive -Path $zip -DestinationPath $TOOL_DIR -Force
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host ""
        Write-Host "Das Entpacken ist fehlgeschlagen:" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }

    if (-not (Test-Path $TOOL_EXE)) {
        # Entpacken lief durch, die Datei ist trotzdem nicht da. Dafuer gibt
        # es praktisch nur eine Erklaerung.
        Write-Host ""
        Write-Host "esptool.exe fehlt, obwohl das Entpacken durchlief." -ForegroundColor Red
        Write-Host "Das macht in aller Regel ein Virenschutz, der die Datei" -ForegroundColor Yellow
        Write-Host "gleich wieder entfernt hat. Diesen Ordner ausnehmen:" -ForegroundColor Yellow
        Write-Host "  $TOOL_DIR" -ForegroundColor Cyan
        exit 1
    }
    Write-Host "    Bereit: $TOOL_EXE" -ForegroundColor Green
}

# ----------------------------------------------------------------- 3 Port
Write-Host "[3/4] Serieller Anschluss wird gesucht..." -ForegroundColor Yellow

if ($Port -eq "") {
    # Get-PnpDevice liefert den Klartextnamen mit. Der hilft beim Auswaehlen,
    # wenn mehrere Geraete stecken.
    # Die aeusseren Klammern sind nicht schmueckend: Liefert die Pipeline genau
    # ein Ergebnis, ist es ein einzelnes PSCustomObject, und dessen .Count ist
    # leer statt 1. Ohne @() faellt der haeufigste Fall, naemlich genau ein
    # angestecktes Geraet, durch beide Abfragen hindurch.
    $ports = @()
    try {
        $ports = @(Get-PnpDevice -Class Ports -PresentOnly -ErrorAction SilentlyContinue |
                 Where-Object { $_.FriendlyName -match '\(COM\d+\)' } |
                 ForEach-Object {
                     [pscustomobject]@{
                         Name = $_.FriendlyName
                         Com  = ([regex]::Match($_.FriendlyName, '\(COM(\d+)\)').Groups[1].Value)
                     }
                 })
    } catch { }

    if ($ports.Count -eq 0) {
        # Rueckfall ohne PnP, etwa bei eingeschraenkten Rechten.
        $ports = @([System.IO.Ports.SerialPort]::GetPortNames() |
                 ForEach-Object { [pscustomobject]@{ Name = $_; Com = ($_ -replace '\D','') } })
    }

    if ($ports.Count -eq 0) {
        Write-Host ""
        Write-Host "Kein serieller Anschluss gefunden." -ForegroundColor Red
        Write-Host ""
        Write-Host "  1. Schild per USB-C anstecken, moeglichst direkt am Rechner," -ForegroundColor Yellow
        Write-Host "     nicht ueber einen Hub ohne eigene Stromversorgung." -ForegroundColor Yellow
        Write-Host "  2. Ein reines Ladekabel uebertraegt keine Daten. Anderes Kabel probieren." -ForegroundColor Yellow
        Write-Host "  3. Meldet sich das Geraet gar nicht, in den Download-Modus bringen:" -ForegroundColor Yellow
        Write-Host "     BOOT gedrueckt halten, RESET kurz druecken, BOOT loslassen." -ForegroundColor Yellow
        exit 1
    }

    if ($ports.Count -eq 1) {
        $Port = "COM" + $ports[0].Com
        Write-Host "    Genau ein Anschluss: $Port ($($ports[0].Name))" -ForegroundColor Green
    } else {
        Write-Host ""
        for ($i = 0; $i -lt $ports.Count; $i++) {
            Write-Host ("  [{0}] COM{1}  {2}" -f ($i + 1), $ports[$i].Com, $ports[$i].Name) -ForegroundColor Cyan
        }
        Write-Host ""
        $wahl = Read-Host "Nummer waehlen (1 bis $($ports.Count))"
        $idx = 0
        if (-not [int]::TryParse($wahl, [ref]$idx) -or $idx -lt 1 -or $idx -gt $ports.Count) {
            Write-Host "Keine gueltige Auswahl." -ForegroundColor Red
            exit 1
        }
        $Port = "COM" + $ports[$idx - 1].Com
        Write-Host "    Gewaehlt: $Port" -ForegroundColor Green
    }
}

# --------------------------------------------------------------- 4 Flashen
Write-Host "[4/4] Firmware wird geschrieben..." -ForegroundColor Yellow
Write-Host ""
Write-Host "    Datei:    $Firmware" -ForegroundColor Gray
Write-Host "    Anschluss: $Port" -ForegroundColor Gray
Write-Host "    Baustein:  $CHIP" -ForegroundColor Gray
if ($Erase) { Write-Host "    Flash wird vorher vollstaendig geloescht" -ForegroundColor Gray }
Write-Host ""

if (-not $Ja) {
    Write-Host "Der bisherige Inhalt des Geraets wird ueberschrieben." -ForegroundColor Yellow
    $antwort = Read-Host "Weiter? (j/N)"
    if ($antwort.Trim().ToLower() -ne "j") {
        Write-Host "Abgebrochen, es wurde nichts veraendert." -ForegroundColor Gray
        exit 0
    }
    Write-Host ""
}

if ($Erase) {
    & $TOOL_EXE --chip $CHIP --port $Port --baud $BAUD erase-flash
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Das Loeschen ist fehlgeschlagen." -ForegroundColor Red
        exit 1
    }
    Write-Host ""
}

# --flash-mode/-freq/-size auf keep: Die Werte stehen schon im Kopf des
# Abbilds, den merge_bin beim Bauen geschrieben hat. Wuerde esptool sie
# ueberschreiben, passte der Kopf nicht mehr zum Board.
& $TOOL_EXE --chip $CHIP --port $Port --baud $BAUD write-flash `
    --flash-mode keep --flash-freq keep --flash-size keep `
    0x0 $Firmware

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Das Schreiben ist fehlgeschlagen." -ForegroundColor Red
    Write-Host ""
    Write-Host "Was meistens hilft:" -ForegroundColor Yellow
    Write-Host "  1. Download-Modus: BOOT gedrueckt halten, RESET kurz druecken," -ForegroundColor Yellow
    Write-Host "     BOOT loslassen, dann erneut starten." -ForegroundColor Yellow
    Write-Host "  2. Anderes USB-C-Kabel. Ladekabel ohne Datenleitungen sind haeufig." -ForegroundColor Yellow
    Write-Host "  3. Ist ein serieller Monitor offen, belegt er den Anschluss." -ForegroundColor Yellow
    Write-Host "  4. Faengt sich das Geraet gar nicht, mit -Erase erneut versuchen." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "   Fertig                               " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Das Schild startet neu und zeigt den Einrichtungsbildschirm." -ForegroundColor White
Write-Host "Dort stehen Serveradresse und MAC, die im Dashboard gebraucht werden." -ForegroundColor Gray
Write-Host ""
