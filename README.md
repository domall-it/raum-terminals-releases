# Raum-Terminals

**E-Ink Raumbuchungssystem für Microsoft Exchange**  
Aktuelle Version: **v1.2.22**

---

## Systemvoraussetzungen

- Windows 10 / Windows Server 2016 oder neuer (64-bit)
- Microsoft Exchange 2016+ mit EWS-Zugang
- TRMNL E-Ink Displays (BYOS-Modus)
- Netzwerkzugang vom Display-Gerät zum Server

---

## Installation

**PowerShell als Administrator öffnen** und ausführen:

```powershell
# Mit mitgelieferter Lizenzdatei:
.\install.ps1 -LicenseFile "C:\Downloads\IhreFirma.lic"

# Ohne Lizenzdatei (Lizenz kann später kopiert werden):
.\install.ps1
```

Nach der Installation ist das Dashboard erreichbar unter:  
**http://localhost:2300**

Standard-Login: `admin` / `admin` — **bitte sofort ändern!**

---

## Update

```powershell
# Auf neueste Version aktualisieren:
.\update.ps1

# Auf bestimmte Version aktualisieren:
.\update.ps1 -Version "v1.2.22"
```

Das Update stoppt den Dienst, tauscht die Binary und startet neu.  
Bei Fehler wird automatisch ein Rollback auf die vorherige Version durchgeführt.

### Manuelles Update

1. Neue `raum-terminals.exe` aus dem [neuesten Release](../../releases/latest) herunterladen
2. `sc stop raum-terminals` — Dienst stoppen
3. Alte `C:\raum-terminals\raum-terminals.exe` ersetzen
4. `sc start raum-terminals` — Dienst starten

---

## Ersteinrichtung

1. Dashboard öffnen: **http://localhost:2300**
2. **Einstellungen → Kalender**: Exchange/EWS-Zugangsdaten eingeben und testen
3. **Räume**: Räume anlegen, Exchange-Mailbox zuweisen
4. **Geräte**: TRMNL-Gerät flashen (BYOS-Firmware: https://trmnl.com/flash), Server-URL eintragen
5. **Geräte**: Registriertes Gerät einem Raum zuweisen

---

## Funktionsübersicht

| Bereich | Funktion |
|---|---|
| **Kalender** | Exchange EWS — automatische Synchronisierung der Raumbelegung |
| **Räume** | Beliebig viele Räume, Standorte und Gruppen |
| **Geräte** | TRMNL BYOS-Protokoll, Akku-Anzeige, WLAN-Signal, Firmware |
| **Energiesparen** | Dynamische Abrufintervalle je nach Raumstatus, Bürozeiten, Tiefschlaf |
| **Buchungsportal** | Spontanbuchung direkt am Gerät (QR-Code), Personensuche im Adressbuch |
| **Lizenzverwaltung** | Ed25519-signierte Lizenzen, Anzeige verbleibender Laufzeit |
| **Benutzerverwaltung** | Mehrere Admin-Benutzer, Passwort-Änderung |
| **Backend-Logs** | Live-Log mit Textfilter (Filter: `INFO`, `WARN`, `DBUG`, `ERROR`) |
| **Handbuch** | Vollständige Anleitung direkt im Dashboard |

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

## Gerät flashen (TRMNL BYOS)

1. TRMNL-Gerät unter **https://trmnl.com/flash** mit der aktuellen Firmware flashen
2. Gerät mit WLAN verbinden
3. Im Gerät-Setup als Server-URL eintragen: `http://<Server-IP>:2300`
4. Das Gerät registriert sich automatisch und erscheint unter **Geräte** im Dashboard

---

## Lizenz

Eine abgelaufene oder fehlende Lizenz sperrt alle Geräte vollständig.  
Zur Lizenzverlängerung oder für neue Lizenzen:

- E-Mail: [kontakt@raum-terminal.de](mailto:kontakt@raum-terminal.de)
- Web: [www.raum-terminals.de](https://www.raum-terminals.de)
