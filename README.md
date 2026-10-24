# Zamudi Studio – Free Resources

Kostenlose Resources für RedM-Server von Zamudi Studio. Sie bauen aufeinander auf und laufen auf `zs_core`.

| Resource | Aufgabe |
| --- | --- |
| [`zs_core`](zs_core) | Konten, Charaktere, Geld, Job, Gruppe, Callbacks, UID |
| [`zs_character`](zs_character) | Auswahl, Erstellung, Aussehen, Spawn |

## Installation

**Per txAdmin-Recipe:** Beim Einrichten eines neuen Servers „Remote URL Template“ wählen und eintragen:
`https://raw.githubusercontent.com/ZamudiStudio/zs-free/main/recipe/recipe.yaml` txAdmin lädt alles, legt die Datenbank an und schreibt die `server.cfg`.

**Von Hand:** Die Ordner `zs_core` und `zs_character` in `resources` legen und eintragen:

```
ensure oxmysql
ensure zs_core
ensure zs_character
```

Mehr dazu in den READMEs der beiden Resources. Lizenz: [LICENSE.txt](LICENSE.txt) (kostenlos, kein Weiterverkauf).

## Neue kostenlose Resource hinzufügen

1. Ordner neben `zs_core` legen (z. B. `zs_jobs`) und nur über die API von `zs_core` arbeiten (`exports.zs_core:...`).
2. Keine Bezüge zu einem bestimmten Server, keine Zugangsdaten, keine fremden Frameworks.
3. `README.md`, `CHANGELOG.md` und `LICENSE.txt` (Kopie aus `LICENSE.txt` im Hauptordner) in den Ordner.
4. In `recipe/recipe.yaml` einen weiteren `download_github`-Schritt mit `subpath: <ordnername>` und ein `ensure` in der `server.cfg` ergänzen.
5. Committen und mit `git push` hochladen.
