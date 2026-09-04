# Raum-Terminals

**E-Ink Raumbuchungssystem für Microsoft 365 und Exchange**  
Aktuelle Version: **v1.4.0**

---

## Systemvoraussetzungen

- Windows 10 / Windows Server 2016 oder neuer (64-bit)
- Kalender-Anbindung, eines der folgenden:
  - **Exchange Online / Microsoft 365** über die Microsoft Graph API (App-Registrierung in Microsoft Entra, keine Zusatzlizenz erforderlich)
  - **Exchange on-premises** 2016 oder neuer mit EWS-Zugang
- Raumpostfächer (Room Mailboxes) für die anzuzeigenden Räume
- TRMNL e1001 E-Ink Display (BYOS-Modus)
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

Datenbank und Lizenzdatei bleiben unberührt. Nach einem Update kann eine erneute Anmeldung im Dashboard nötig sein.

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
4. **Geräte**: TRMNL e1001 flashen (BYOS-Firmware: https://trmnl.com/flash), Server-URL eintragen
5. **Geräte**: Registriertes Gerät einem Raum zuweisen

Die vollständige Anleitung zur Einrichtung in Microsoft Entra (App-Registrierung, Anwendungsberechtigungen, Administratorzustimmung) steht im Handbuch direkt im Dashboard.

---

## Funktionsübersicht

| Bereich | Funktion |
|---|---|
| **Kalender** | Exchange Online über Graph API und Exchange on-premises über EWS, automatische Synchronisierung der Raumbelegung |
| **Räume** | Beliebig viele Räume, Standorte und Gruppen, gemischter Betrieb mehrerer Anbieter |
| **Geräte** | TRMNL e1001 (BYOS-Protokoll), Akku-Anzeige, WLAN-Signal, Firmware |
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

## Gerät flashen (TRMNL e1001)

1. TRMNL e1001 unter **https://trmnl.com/flash** mit der aktuellen BYOS-Firmware flashen
2. Gerät mit WLAN verbinden
3. Im Gerät-Setup als Server-URL eintragen: `http://<Server-IP>:2300`
4. Das Gerät registriert sich automatisch und erscheint unter **Geräte** im Dashboard

Die passende Adresse steht im Dashboard unter *Server* im Abschnitt „Erreichbar unter" und lässt sich dort mit einem Klick kopieren.

---

## Testversion

Raum-Terminals kann **30 Tage kostenlos** mit vollem Funktionsumfang getestet werden. Die Testlizenz wird beim ersten Start automatisch erzeugt, eine Anforderung ist nicht nötig.

| | Testversion | Vollversion |
|---|---|---|
| Laufzeit | 30 Tage | Unbefristet (Kauflizenz) |
| Geräte | 1 TRMNL e1001 | Je nach Anzahl der Gerätelizenzen |
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
