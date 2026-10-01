# Raum-Terminals

**E-Ink Raumbuchungssystem für Microsoft 365 und Exchange**

[![Aktuelle Version](https://img.shields.io/github/v/release/domall-it/raum-terminals-releases?label=Aktuelle%20Version&color=1586d8)](../../releases/latest)

---

## Systemvoraussetzungen

- Windows 10 / Windows Server 2016 oder neuer (64-bit)
- Kalender-Anbindung, eines der folgenden:
  - **Exchange Online / Microsoft 365** über die Microsoft Graph API (App-Registrierung in Microsoft Entra, keine Zusatzlizenz erforderlich)
  - **Exchange on-premises** 2016 oder neuer mit EWS-Zugang
- Raumpostfächer (Room Mailboxes) für die anzuzeigenden Räume
- E-Ink-Display reTerminal E1001 (Seeed Studio) mit der Firmware von Raum-Terminals
- Netzwerkzugang vom Display-Gerät zum Server

---

## Installation

**PowerShell als Administrator öffnen** und ausführen:

```powershell
# Fragt nach dem Installationsverzeichnis (Vorgabe: C:\Program Files\Raum-Terminals)
powershell.exe -ExecutionPolicy Bypass -File .\install.ps1

# Mit Lizenzdatei und festem Verzeichnis, ohne Rueckfrage:
powershell.exe -ExecutionPolicy Bypass -File .\install.ps1 -InstallDir "D:\Programme\Raum-Terminals" -LicenseFile "C:\Downloads\IhreFirma.lic"

# Ohne automatische Firewall-Regel:
powershell.exe -ExecutionPolicy Bypass -File .\install.ps1 -SkipFirewall
```

> **Hinweis:** Der Parameter `-ExecutionPolicy Bypass` ist notwendig, da Windows standardmäßig die Ausführung von PowerShell-Skripten blockiert. Der Bypass gilt nur für diesen einen Aufruf und ändert keine systemweiten Einstellungen.

Das Skript erledigt dabei:

- Verzeichnisse anlegen und die aktuelle Programmversion herunterladen
- `update.ps1` und `uninstall.ps1` ins Installationsverzeichnis kopieren
- Windows-Dienst einrichten und starten
- Port 2300 eingehend in der Firewall freigeben (Domäne und privates Netz)
- Installation in **Apps & Features** registrieren, mit Version und Deinstallations-Eintrag

Nach der Installation ist das Dashboard erreichbar unter:  
**http://localhost:2300**

Standard-Login: `admin` / `admin`, **bitte sofort ändern!**

---

## Verzeichnisse

Programm und Daten liegen getrennt, weil ein Dienst in `Program Files` nicht schreiben darf:

```
C:\Program Files\Raum-Terminals\     ← Programm
├── raum-terminals.exe               ← Server + Dashboard (eine Datei)
├── update.ps1
└── uninstall.ps1

C:\ProgramData\Raum-Terminals\       ← Daten
├── license.lic                      ← Ihre Lizenzdatei
└── data\
    └── raum-terminals.db            ← Datenbank (automatisch angelegt)
```

Das Installationsverzeichnis ist frei wählbar, das Skript fragt danach.

**Bestehende Installationen behalten ihren Ort:** Liegt bereits eine Datenbank neben der Programmdatei, etwa unter `C:\raum-terminals\data`, wird sie weiterverwendet. Ein Update ändert daran nichts. Ein abweichender Datenort lässt sich über die Umgebungsvariable `RAUMTERMINALS_DATA` festlegen.

---

## Update

```powershell
cd "C:\Program Files\Raum-Terminals"

# Auf neueste Version aktualisieren:
powershell.exe -ExecutionPolicy Bypass -File .\update.ps1

# Auf bestimmte Version wechseln, auch abwaerts:
powershell.exe -ExecutionPolicy Bypass -File .\update.ps1 -Version "v1.4.0"
```

Das Skript ermittelt das Installationsverzeichnis selbst aus dem Windows-Dienst, ein Pfad muss also nicht angegeben werden. Es stoppt den Dienst, tauscht die Programmdatei und startet neu. Lässt sich der Dienst mit der neuen Version nicht starten, wird automatisch die vorherige wiederhergestellt.

Vor dem Austausch sichert das Skript die Datenbank, bei gestopptem Dienst und samt WAL-Dateien, in den Ordner `backup` neben dem Ordner `data` (zum Beispiel `C:\ProgramData\Raum-Terminals\backup\raum-terminals-v1.8.0-20260926-215058.db`). Die letzten fünf Sicherungen bleiben erhalten. Gelingt die Sicherung nicht, bricht das Update ab und die bisherige Version läuft weiter.

Lizenzdatei und Einstellungen bleiben unberührt. Nach einem Update kann eine erneute Anmeldung im Dashboard nötig sein.

**Datenbank zurückholen:** Dienst stoppen (`sc stop RaumTerminals`), die gewünschte Sicherung als `data\raum-terminals.db` zurückkopieren (die zugehörige `-wal`-Datei, falls vorhanden, als `raum-terminals.db-wal`), Dienst starten. Passt die Datenbank zu einer älteren Version, vorher mit `-Version` auf diese wechseln.

### Manuelles Update

1. Neue `raum-terminals.exe` aus dem [neuesten Release](../../releases/latest) herunterladen
2. `sc stop RaumTerminals` (Dienst stoppen)
3. Alte `raum-terminals.exe` im Installationsverzeichnis ersetzen
4. `sc start RaumTerminals` (Dienst starten)

---

## Deinstallation

```powershell
cd "C:\Program Files\Raum-Terminals"

# Programm entfernen, Datenbank und Lizenz behalten:
powershell.exe -ExecutionPolicy Bypass -File .\uninstall.ps1

# Zusaetzlich alle Daten loeschen (nicht umkehrbar):
powershell.exe -ExecutionPolicy Bypass -File .\uninstall.ps1 -RemoveData
```

Entfernt werden Dienst, Programmdateien, Firewall-Regel und der Eintrag in der Programmliste. **Datenbank und Lizenz bleiben standardmäßig erhalten** und werden nur mit `-RemoveData` gelöscht, nach zusätzlicher Rückfrage. Bei einer Neuinstallation an dieselbe Stelle werden sie automatisch weiterverwendet.

Die Deinstallation lässt sich auch über *Apps & Features* in den Windows-Einstellungen starten.

---

## Ersteinrichtung

1. Dashboard öffnen: **http://localhost:2300**
2. **Einstellungen → Kalender**: Anbieter hinzufügen und Verbindung testen
   - *Exchange Online / Microsoft 365*: Tenant-ID, Client-ID und Client-Secret der App-Registrierung
   - *Exchange on-premises*: EWS-URL, Dienstkonto und Passwort
3. **Räume**: Räume über die Erkennung importieren oder manuell mit Postfachadresse anlegen
4. **Geräte**: Display mit der Firmware von Raum-Terminals flashen (siehe unten, bei uns bezogene sind fertig aufgespielt), Server-URL eintragen
5. **Geräte**: Registriertes Gerät einem Raum zuweisen

Die vollständige Anleitung zur Einrichtung in Microsoft Entra (App-Registrierung, Anwendungsberechtigungen, Administratorzustimmung) steht im Handbuch direkt im Dashboard.

---

## Funktionsübersicht

| Bereich | Funktion |
|---|---|
| **Kalender** | Exchange Online über Graph API und Exchange on-premises über EWS, automatische Synchronisierung der Raumbelegung |
| **Räume** | Beliebig viele Räume, Standorte und Gruppen, gemischter Betrieb mehrerer Anbieter |
| **Geräte** | reTerminal E1001, Akku-Anzeige, WLAN-Signal, Firmware |
| **Energiesparen** | Dynamische Abrufintervalle je nach Raumstatus, Bürozeiten, Tiefschlaf |
| **Buchungsportal** | Spontanbuchung direkt am Gerät (QR-Code), Personensuche im Adressbuch |
| **HTTPS** | Eigenes Zertifikat als PEM oder PFX, Dashboard und Buchungsportal verschlüsselt |
| **Lizenzverwaltung** | Ed25519-signierte Lizenzen, Anzeige verbleibender Laufzeit |
| **Benutzerverwaltung** | Mehrere Admin-Benutzer, Passwort-Änderung |
| **Backend-Logs** | Live-Log mit Textfilter (Filter: `INFO`, `WARN`, `DBUG`, `ERROR`) |
| **Handbuch** | Vollständige Anleitung direkt im Dashboard, deutsch und englisch |

---

## Windows-Dienst

```powershell
sc start RaumTerminals    # Starten
sc stop RaumTerminals     # Stoppen
sc query RaumTerminals    # Status

# Oder über raum-terminals.exe direkt:
raum-terminals.exe install    # Dienst registrieren
raum-terminals.exe uninstall  # Dienst entfernen
raum-terminals.exe run        # Im Vordergrund starten (Debugging)
```

---

## Gerät flashen (reTerminal E1001)

Bei uns bezogene Displays sind fertig aufgespielt. Für alle anderen wird weder eine
Entwicklungsumgebung noch ein Administratorkonto gebraucht, der serielle
Zugriff geht mit normalen Benutzerrechten.

1. `merged_firmware.bin` in einen Ordner legen, etwa vom USB-Stick oder aus
   dem Netzlaufwerk
2. Eine PowerShell in diesem Ordner öffnen
3. Schild per USB-C anstecken
4. Diesen Befehl ausführen:

```powershell
irm https://raw.githubusercontent.com/domall-it/raum-terminals-releases/master/flash.ps1 | iex
```

Das Skript sucht die Firmwaredatei im aktuellen Ordner, holt beim ersten Mal
das Flash-Werkzeug (rund 63 MB, danach liegt es bereit), findet den Anschluss
und fragt vor dem Schreiben nach.

Ohne Rückfrage, etwa für mehrere Geräte hintereinander:

```powershell
.\flash.ps1 -Firmware D:\firmware\merged_firmware.bin -Port COM5 -Ja
```

Fängt sich ein Gerät nicht mehr, hilft meist `-Erase`. Damit wird der
Speicher vorher vollständig gelöscht.

Die Firmware von Raum-Terminals ist eine Weiterentwicklung der quelloffenen
TRMNL-Firmware und steht wie diese unter der GNU GPL 3.0.

**Die Firmwaredatei liegt bewusst nicht in diesem Repository.** Sie wird über
den internen Weg verteilt, solange die Quelltextfrage der Firmware nicht
abschließend geklärt ist.

### Nach dem Flashen

Das Schild startet neu und zeigt den Einrichtungsbildschirm mit Serveradresse
und MAC. Die passende Adresse steht im Dashboard unter *Server* im Abschnitt
„Erreichbar unter" und lässt sich dort mit einem Klick kopieren.

### Wenn es klemmt

| Sie sehen | Das hilft |
|---|---|
| Kein serieller Anschluss gefunden | Ein reines Ladekabel überträgt keine Daten. Anderes USB-C-Kabel nehmen und möglichst direkt am Rechner anstecken, nicht über einen Hub ohne eigene Stromversorgung. |
| Der Anschluss ist belegt | Ein offener serieller Monitor hält ihn. Fenster schließen. |
| Das Gerät meldet sich gar nicht | In den Download-Modus bringen: BOOT gedrückt halten, RESET kurz drücken, BOOT loslassen. |
| `esptool.exe` fehlt nach dem Entpacken | Das macht in aller Regel ein Virenschutz. Den genannten Ordner unter `%LOCALAPPDATA%\Raum-Terminals` ausnehmen. |

---

## Testversion

Raum-Terminals kann **30 Tage kostenlos** mit vollem Funktionsumfang getestet werden. Die Testlizenz wird beim ersten Start automatisch erzeugt, eine Anforderung ist nicht nötig.

| | Testversion | Vollversion |
|---|---|---|
| Laufzeit | 30 Tage | Unbefristet (Kauflizenz) |
| Geräte | 1 Display | Je nach Anzahl der Gerätelizenzen |
| Räume | Unbegrenzt | Unbegrenzt |
| Funktionen | Vollständig | Vollständig |
| Updates | Enthalten | Über optionale Software-Wartung |

Im Dashboard erscheint ein Hinweis mit der verbleibenden Testlaufzeit.  
**Nach Ablauf der Testphase werden alle Geräte gesperrt.** Das Dashboard bleibt erreichbar, sodass eine Lizenz jederzeit eingespielt werden kann.

---

## Lizenz

Die Gerätelizenzen sind Kauflizenzen und unbefristet gültig, ein Abonnement ist nicht erforderlich. Programmaktualisierungen können über eine optionale Software-Wartung bezogen werden.

Eine fehlende oder abgelaufene Lizenz (etwa nach Ende der Testphase) sperrt die Geräte, bis eine gültige Lizenz eingespielt wird.

Für Lizenzen und Wartung:

- E-Mail: [kontakt@raum-terminal.de](mailto:kontakt@raum-terminal.de)
- Web: [www.raum-terminals.de](https://www.raum-terminals.de)
