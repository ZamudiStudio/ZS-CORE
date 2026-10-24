# txAdmin-Recipe (Installation per Template-URL)

Mit dem Recipe richtet txAdmin einen kompletten Server ein: lädt `oxmysql`, die Manager und `zs_core` / `zs_character`
von GitHub, legt die Datenbank an und schreibt die `server.cfg`.

## Einrichten

1. Das Repo muss **öffentlich** auf GitHub liegen (txAdmin kann keine privaten Repos laden).
2. Die Recipe-Datei zeigt auf `https://github.com/ZamudiStudio/ZSCORE`. Bei einem anderen Repo-Namen die Adressen in `recipe.yaml` anpassen.
3. In txAdmin beim Einrichten eines neuen Servers **Remote URL Template** wählen und die Raw-Adresse der Datei eintragen:
   `https://raw.githubusercontent.com/ZamudiStudio/ZSCORE/main/recipe/recipe.yaml`
4. Die Fragen von txAdmin (Servername, Lizenzkey, Datenbank) beantworten und den Recipe-Lauf starten.

## Lokaler Test ohne GitHub

```
powershell -ExecutionPolicy Bypass -File build-package.ps1
```
erzeugt `dist\zamudi-core.zip` und eine Kopie des Recipes. In einer eigenen Recipe-Kopie ersetzt du die beiden `download_github`-Schritte
für `zs_core` und `zs_character` durch einen `download_file` auf die Zip (z. B. `http://localhost:8000/zamudi-core.zip` mit
`python -m http.server 8000` im Ordner `dist`) und einen `unzip` nach `./resources/[zs]`.

## Hinweise

- Die Tabellen von `zs_core` legt die Resource beim ersten Start selbst an, das Recipe legt nur die leere Datenbank an.
- Das Recipe nutzt die in txAdmin üblichen Platzhalter (`{{serverEndpoints}}`, `{{svLicense}}`, `{{dbConnectionString}}` usw.).
- Bezahlte Module liefert ihr getrennt über Tebex aus, sie gehören nicht ins öffentliche Repo.
