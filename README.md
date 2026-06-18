# Raum-Terminals — Kundeninstallation

E-Ink Raumbuchungssystem für Microsoft Exchange.

## Systemvoraussetzungen

- Windows 10 / Windows Server 2016 oder neuer (64-bit)
- Microsoft Exchange 2016+ oder Microsoft 365 mit EWS-Zugang
- TRMNL E-Ink Displays (mit Custom Firmware)
- Netzwerkzugang vom Display-Gerät zum Server

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

## Update

```powershell
# Auf neueste Version aktualisieren:
.\update.ps1

# Auf bestimmte Version aktualisieren:
.\update.ps1 -Version "v1.3.0"
```

Das Update stoppt den Dienst, tauscht die Binary und startet neu.
Bei Fehler wird automatisch ein Rollback auf die vorherige Version durchgeführt.

## Manuelles Update

1. Neue `raum-terminals.exe` aus dem [neuesten Release](../../releases/latest) herunterladen
2. `sc stop raum-terminals` — Dienst stoppen
3. Alte `C:\raum-terminals\raum-terminals.exe` ersetzen
4. `sc start raum-terminals` — Dienst starten

## Ersteinrichtung

1. Dashboard öffnen: **http://localhost:2300**
2. **Einstellungen → Exchange/EWS**: Server-URL, Benutzername, Passwort eingeben
3. **Räume**: Räume anlegen, Exchange-Mailbox zuweisen
4. **Geräte**: TRMNL-Geräte registrieren sich automatisch beim ersten Start
5. **Geräte**: Jedem Gerät einen Raum zuweisen

## Dateistruktur nach Installation

```
C:\raum-terminals\
├── raum-terminals.exe   ← Server + Dashboard (alles in einer Datei)
├── license.lic          ← Ihre Lizenzdatei
└── data\
    └── raum-terminals.db  ← Datenbank (automatisch angelegt)
```

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

## Support

Bei Fragen oder Problemen wenden Sie sich an: support@eimermacher.de
