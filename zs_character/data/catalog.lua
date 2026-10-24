-- Aussehens-Katalog: bestimmt, was der Spieler in der Charaktererstellung auswaehlen kann.
--
-- Jede Kategorie erscheint als Auswahl in der Oberflaeche. Die Hashes sind Shop-Item-Hashes aus dem Spiel
-- (Meta-Ped-Komponenten). Sie sind NICHT Teil dieses Pakets, weil sie spiel- und versionsabhaengig sind:
-- trag hier deine eigenen, getesteten Hashes ein (z. B. aus einer oeffentlichen RDR3-Kleidungsliste).
-- Wichtig: Mit leerem Katalog funktioniert alles, der Spieler waehlt dann nur Geschlecht und Koerpergroesse.
--
-- Aufbau:
--   {
--     id = 'hair',                       -- eindeutiger Name (nur Buchstaben/Zahlen/_)
--     label = { de = 'Haare', en = 'Hair' },
--     male   = { 0x00000000, ... },      -- Liste der Hashes fuer maennliche Figuren
--     female = { 0x00000000, ... },      -- Liste der Hashes fuer weibliche Figuren
--     tag = 0x00000000,                  -- optional: Kategorie-Hash, der vor dem Anlegen entfernt wird
--     optional = true,                   -- optional: erste Auswahl "keine"
--   }
--
-- Beispiel (auskommentiert, Hashes sind Platzhalter):
-- Catalog.categories[#Catalog.categories + 1] = {
--     id = 'hat',
--     label = { de = 'Hut', en = 'Hat' },
--     optional = true,
--     male = { 0x11111111, 0x22222222 },
--     female = { 0x33333333 },
-- }

Catalog = {
    categories = {},

    -- Koerpergroesse (Skalierung des Peds). 1.0 = normal
    height = { min = 0.92, max = 1.08, step = 0.01, default = 1.0 },
}
