# Zamudi Studio – zs_core & zs_character

Kostenloses Grundgerüst für RedM-Server: Konten, Charaktere, Geld, Jobs, Gruppen, Callbacks, dazu Charakterauswahl und -erstellung.

| Resource | Aufgabe |
| --- | --- |
| [`zs_core`](zs_core) | Konten, Charaktere, Geld, Job, Gruppe, Callbacks, UID |
| [`zs_character`](zs_character) | Auswahl, Erstellung, Aussehen, Spawn |

## Installation

**Per txAdmin-Recipe:** Beim Einrichten eines neuen Servers „Remote URL Template“ wählen und eintragen:
`https://raw.githubusercontent.com/ZamudiStudio/zs-core/main/recipe/recipe.yaml`
(den Pfad auf dein Repo anpassen). txAdmin lädt alles, legt die Datenbank an und schreibt die `server.cfg`.

**Von Hand:** Die Ordner `zs_core` und `zs_character` in `resources` legen und eintragen:

```
ensure oxmysql
ensure zs_core
ensure zs_character
```

Mehr dazu in den READMEs der beiden Resources. Lizenz: [LICENSE.txt](LICENSE.txt) (kostenlos, kein Weiterverkauf).
