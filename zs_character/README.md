# zs_character

Charakterauswahl, Charaktererstellung und Spawn für `zs_core`. Eigenständig, ohne VORP. *(English summary at the bottom.)*

## Was es kann

- Auswahl mit Vorschau der Figur, mehrere Charakter-Slots (aus `zs_core`)
- Erstellung in drei Schritten: Identität, Aussehen, Bestätigen
- Aussehen über einen **Katalog** (`data/catalog.lua`): Kategorien mit Auswahllisten, dazu Körpergröße
- Spawn an der gespeicherten Position, neue Charaktere an konfigurierbaren Startpunkten
- Eigene Instanz (Routing-Bucket) während der Auswahl, andere Spieler sehen die Erstellung nicht
- Befehl zum Wechseln des Charakters (`/charwechsel`), Löschen in der Auswahl (abschaltbar)
- Meldet Gesundheit und Tod regelmäßig an `zs_core` (Speichern)

## Voraussetzungen

- `zs_core`, `oxmysql`

## Installation

1. Ordner `zs_character` in `resources` legen.
2. In der `server.cfg` nach `zs_core`:
   ```
   ensure zs_core
   ensure zs_character
   ```
3. In `config.lua` den **Studio-Ort** (`Config.Studio.coords`) und die **Startpunkte** (`Config.NewCharacterSpawns`) auf deinen Server anpassen.
4. In `data/catalog.lua` das Aussehen eintragen (siehe unten).

## Aussehens-Katalog

Die Hashes der Kleidung und Frisuren sind spiel- und versionsabhängig und **nicht** Teil dieses Pakets. Mit dem leeren
Katalog funktioniert alles; der Spieler wählt dann Geschlecht und Körpergröße. Eigene Kategorien trägst du in
`data/catalog.lua` ein, die Oberfläche baut sich daraus automatisch auf:

```lua
Catalog.categories[#Catalog.categories + 1] = {
    id = 'hat',
    label = { de = 'Hut', en = 'Hat' },
    optional = true,                       -- erste Auswahl "keine"
    male   = { 0x11111111, 0x22222222 },   -- Shop-Item-Hashes
    female = { 0x33333333 },
}
```

Das gewählte Aussehen liegt pro Charakter als `{ scale = 1.0, parts = { hat = 2 } }` in `zs_characters.appearance`.

## Konfiguration (`config.lua`)

| Option | Bedeutung |
| --- | --- |
| `Config.Studio` | Ort und Kamera für Auswahl und Erstellung |
| `Config.NewCharacterSpawns` | Startpunkte für neue Charaktere (zufällig einer) |
| `Config.RespawnIfDead`, `Config.DeadRespawn` | Charakter, der als tot gespeichert ist, kommt hier mit voller Gesundheit zurück |
| `Config.AllowDelete` | Löschen in der Auswahl erlauben |
| `Config.LogoutCommand` | Befehl zum Wechseln (`''` = aus) |
| `Config.VitalsIntervalSeconds` | Intervall für das Melden der Gesundheit (0 = aus) |
| `Config.Locale`, `Config.Strings` | Sprache (`de`/`en`) und Texte |

## Ereignisse für andere Resources

- Client: `zs_character:spawned` (Daten des Spawns)
- Server: `zs_core:characterLoaded`, `zs_core:characterUnloaded` (von `zs_core`)

## Hinweise

- Das Sterben und Wiederbeleben übernimmt dein Todes-Script. `zs_character` speichert nur, ob der Charakter tot ist.
- Die Oberfläche braucht keine weitere Menü-Resource.

## Lizenz

Siehe `LICENSE.txt`.

---

## English summary

Character selection, creation and spawn for `zs_core` (standalone, no VORP). Install after `zs_core`, set the studio location
and spawn points in `config.lua`, and fill `data/catalog.lua` with your own appearance hashes (not included). Without a
catalog, players choose gender and height. Texts: `Config.Locale = 'en'`.
