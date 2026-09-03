# Raum-Terminals

**E-Ink Raumbuchungssystem für Microsoft 365 und Exchange**  
Aktuelle Version: **v1.3.1**

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
# Mit mitgelieferter Lizenzdatei:
powershell.exe -ExecutionPolicy Bypass -File .\install.ps1 -LicenseFile "C:\Downloads\IhreFirma.lic"

# Ohne Lizenzdatei (30-Tage-Testlizenz wird automatisch erzeugt):
powershell.exe -ExecutionPolicy Bypass -File .\install.ps1
```

> **Hinweis:** Der Parameter `-ExecutionPolicy Bypass` ist notwendig, da Windows standardmäßig die Ausführung von PowerShell-Skripten blockiert. Der Bypass gilt nur für diesen einen Aufruf und ändert keine systemweiten Einstellungen.

Nach der Installation ist das Dashboard erreichbar unter:  
**http://localhost:2300**

Standard-Login: `admin` / `admin`, **bitte sofort ändern!**

---

## Update

```powershell
# Auf neueste Version aktualisieren:
powershell.exe -ExecutionPolicy Bypass -File .\update.ps1

# Auf bestimmte Version aktualisieren:
powershell.exe -ExecutionPolicy Bypass -File .\update.ps1 -Version "v1.3.1"
```

Das Update stoppt den Dienst, tauscht die Binary und startet neu.  
Bei Fehler wird automatisch ein Rollback auf die vorherige Version durchgeführt.

> **Hinweis:** Nach einem Update kann eine erneute Anmeldung im Dashboard nötig sein. Datenbank und Lizenzdatei bleiben erhalten.

### Manuelles Update

1. Neue `raum-terminals.exe` aus dem [neuesten Release](../../releases/latest) herunterladen
2. `sc stop raum-terminals` (Dienst stoppen)
3. Alte `C:\raum-terminals\raum-terminals.exe` ersetzen
4. `sc start raum-terminals` (Dienst starten)

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
| **Lizenzverwaltung** | Ed25519-signierte Lizenzen, Anzeige verbleibender Laufzeit |
| **Benutzerverwaltung** | Mehrere Admin-Benutzer, Passwort-Änderung |
| **Backend-Logs** | Live-Log mit Textfilter (Filter: `INFO`, `WARN`, `DBUG`, `ERROR`) |
| **Handbuch** | Vollständige Anleitung direkt im Dashboard, deutsch und englisch |

---

## Dateistruktur nach Installation

```
C:\raum-terminals\
├── raum-terminals.exe    ← Server + Dashboard (alles in einer Datei)
├── license.lic           ← Ihre Lizenzdatei
└── data\
    └── raum-terminals.db ← Datenbank (automatisch angelegt)
```

---

## Windows-Dienst

```powershell
sc start raum-terminals    # Starten
sc stop raum-terminals     # Stoppen
sc query raum-terminals    # Status

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
