# zs_core

Basis-Framework für RedM-Server von Zamudi Studio: Konten, Charaktere, Geld, Jobs, Gruppen, Callbacks, Benachrichtigungen.
Eigenständig, ohne VORP oder andere Frameworks. *(English summary at the bottom.)*

## Was es kann

- Konten und Charaktere in eigenen Tabellen (`zs_accounts`, `zs_characters`), mehrere Charakter-Slots pro Konto
- Geld in frei definierbaren Währungen (Standard `cash`, `gold`), Job mit Rang und Bezeichnung, Konto-Gruppen (z. B. `admin`)
- Eigene Daten pro Charakter (`GetMeta` / `SetMeta`) für andere Resources
- Server-Callbacks mit Antwort vom Client (`RegisterCallback` / `TriggerCallback`)
- Benachrichtigungen (nutzt `zs-notify`, sonst eine einfache Chat-Zeile)
- Autosave, Speichern beim Verlassen und beim Resource-Stopp
- Optional: UID (öffentliche, zufällige ID pro Charakter), Spielzeit mit Tageskalender, Goldstaub-Premiumwährung

## Voraussetzungen

- RedM-Server mit [oxmysql](https://github.com/overextended/oxmysql)
- Für die Charakterauswahl: `zs_character` (liegt bei)

## Installation

1. Ordner `zs_core` in deinen `resources`-Ordner legen.
2. In der `server.cfg` nach `oxmysql` eintragen:
   ```
   ensure oxmysql
   ensure zs_core
   ensure zs_character
   ```
3. Konfiguration in `config.lua` prüfen (siehe unten). Die Tabellen legt die Resource beim ersten Start selbst an.
4. Starten. Der erste Spieler, der sich auf einem frischen Server verbindet, bekommt die Gruppe `admin`
   (`Config.Defaults.firstAccountGroup`).

## Konfiguration (`config.lua`)

| Option | Bedeutung |
| --- | --- |
| `Config.Identifier` | Womit Spieler erkannt werden: `license` (Standard), `license2`, `steam`, `discord`, `fivem`. Nachträglich ändern trennt Spieler von ihren Charakteren. |
| `Config.Defaults` | Startwerte: Gruppe, Charakter-Slots, Job, Startgeld |
| `Config.Currencies` | Währungen mit Anzeigename und Startbetrag. Neue Währung = neuer Eintrag, keine Datenbank-Änderung. `{}` = zs_core verwaltet kein Geld (z. B. wenn Bargeld bei dir ein Inventar-Item ist). |
| `Config.AdminGroups` | Gruppen, die `IsAdmin` als Admin zählt |
| `Config.AutosaveSeconds` | Autosave-Intervall |
| `Config.Uid`, `Config.Goldstaub` | Optionale Module, mit `enabled = false` abschaltbar |
| `Config.Uid.legacyNames` | Nur für Umsteiger von älteren Zamudi-Resources: bietet zusätzlich die alten Namen an (`GetWsid`, Spalte `wsid`). Sonst `false` lassen. |
| `Config.Banner` | Konsolen-Banner und Resource-Check beim Start |

## API (Server)

Aufruf aus anderen Resources: `exports.zs_core:Funktion(...)`. Gibt `nil`/`false` zurück, wenn der Spieler keinen aktiven Charakter hat.

```lua
local p = exports.zs_core:GetPlayer(source)       -- { id, firstname, lastname, fullname, job, jobGrade, jobLabel, group, money = { cash, gold }, coords, meta, ... }
local uid = exports.zs_core:GetUid(source)         -- öffentliche UID (wenn das UID-Modul aktiv ist)
local src = exports.zs_core:GetSourceByUid(1234)
exports.zs_core:IsLoggedIn(source)
exports.zs_core:GetCharacterId(source)
exports.zs_core:GetSourceByCharacterId(charId)
exports.zs_core:GetOnlinePlayers()

exports.zs_core:GetMoney(source, 'cash')
exports.zs_core:GetAllMoney(source)                              -- { cash = 12.5, gold = 0.0 }
exports.zs_core:AddMoney(source, 'cash', 50, 'Verkauf')          -- true/false
exports.zs_core:RemoveMoney(source, 'cash', 20, 'Kauf')          -- false, wenn nicht genug da ist
exports.zs_core:SetMoney(source, 'gold', 5)

local job, grade, label = exports.zs_core:GetJob(source)
exports.zs_core:SetJob(source, 'sheriff', 2, 'Deputy')

exports.zs_core:GetGroup(source) ; exports.zs_core:SetGroup(source, 'admin') ; exports.zs_core:IsAdmin(source)

exports.zs_core:GetMeta(source, 'schluessel') ; exports.zs_core:SetMeta(source, 'schluessel', wert)   -- Wert muss JSON-tauglich sein

exports.zs_core:Notify(source, 'Text', { type = 'success', title = 'Titel', duration = 5000 })
```

Server-Callback registrieren und vom Client aufrufen:

```lua
-- Server
exports.zs_core:RegisterCallback('meinscript:kontostand', function(source, bank)
    return exports.zs_core:GetMoney(source, 'cash')
exports.zs_core:GetAllMoney(source)                              -- { cash = 12.5, gold = 0.0 }
end)

-- Client
local ok, kontostand = exports.zs_core:TriggerCallback('meinscript:kontostand', 'hauptbank')
```

Client: `exports.zs_core:GetLocalCharacter()` liefert `{ id, firstname, lastname, gender, job, jobGrade, jobLabel, group }`.

### Ereignisse (Server, lokal)

| Ereignis | Parameter |
| --- | --- |
| `zs_core:characterLoaded` | `source, player` (wie `GetPlayer`) |
| `zs_core:characterUnloaded` | `source, charId` |
| `zs_core:jobChanged` | `source, neu, alt` (je `{ name, grade, label }`) |
| `zs_core:groupChanged` | `source, neu, alt` |
| `zs_core:moneyChanged` | `source, art, änderung, neuerStand, grund` |
| `zs_core:characterCreated` / `characterDeleted` | `source, charId` |

## Befehle

- `setnative <UID> <0|1>` (Konsole): setzt das Native-Merkmal (nur mit aktivem UID-Modul)
- `goldstaub` (Spieler): zeigt den eigenen Goldstaub-Stand
- `addgoldstaub <UID> <Menge>` (Konsole)

## Datenbank

Beim Start entstehen: `zs_accounts`, `zs_characters`, `zs_character_money` (ein Kontostand pro Charakter und Währung), und je nach Modul `zs_players` (enthält die `uid`), `zs_playtime_daily`, `zs_goldstaub`, `zs_goldstaub_log`.
Ältere Tabellen mit der Spalte `wsid` werden beim Start automatisch auf `uid` umbenannt. Vor Updates bitte die Datenbank sichern.

## Support und Lizenz

Siehe `LICENSE.txt`. Bei Fragen: Tebex-Store von Zamudi Studio.

---

## English summary

Standalone RedM base framework: accounts, characters, money (`cash`, `gold`), jobs, groups, callbacks and notifications.
Requires `oxmysql`. Install: copy `zs_core` (and `zs_character`) to `resources`, add `ensure oxmysql`, `ensure zs_core`,
`ensure zs_character` to `server.cfg`. Configure `config.lua`; tables are created automatically. The API is listed above
(function names are the same). Texts are German by default; set `Config.Locale = 'en'` for English messages.
