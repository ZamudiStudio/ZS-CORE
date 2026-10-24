Config = {}

-- Sprache der Meldungen: 'de' oder 'en'
Config.Locale = 'de'

-- Womit ein Spieler eindeutig erkannt wird: 'license', 'license2', 'steam', 'discord' oder 'fivem'.
-- 'license' ist die Rockstar-Lizenz und auf jedem RedM-Server vorhanden.
-- Achtung: Nachtraeglich aendern trennt Spieler von ihren Charakteren.
Config.Identifier = 'license'

-- Startwerte
Config.Defaults = {
    group = 'user',            -- Gruppe fuer neue Konten
    firstAccountGroup = 'admin', -- Gruppe fuer das allererste Konto auf einem frischen Server ('' = keine Sonderregel)
    maxCharacters = 5,         -- Charakter-Slots pro Konto
    job = 'unemployed',
    jobGrade = 0,
    jobLabel = 'Arbeitslos',
}

-- Waehrungen: frei definierbar, jede bekommt pro Charakter einen Kontostand (Tabelle zs_character_money).
-- Neue Waehrung = neuer Eintrag hier, keine Datenbank-Aenderung noetig. Leere Liste ({}) = zs_core verwaltet kein Geld,
-- z. B. wenn Bargeld bei dir ein Inventar-Item ist.
--   start    = Betrag, mit dem neue Charaktere beginnen
--   label    = Anzeigename
Config.Currencies = {
    cash = { label = 'Bargeld', start = 200.0 },
    gold = { label = 'Gold', start = 0.0 },
}

-- Gruppen, die als Admin gelten (IsAdmin)
Config.AdminGroups = { admin = true }

-- Automatisches Speichern aller Spieler (Sekunden)
Config.AutosaveSeconds = 300

-- Benachrichtigungen: nutzt 'zs-notify', wenn gestartet, sonst eine einfache Chat-Zeile
Config.NotifyResource = 'zs-notify'

-- UID: oeffentliche, zufaellige ID pro Charakter (nur 9000 moegliche IDs bei 1000-9999), dazu Spielzeit
Config.Uid = {
    enabled = true,
    min = 1000,
    max = 9999,
    maxTries = 100,
    -- Nur fuer Server, die von aelteren Zamudi-Resources umsteigen: alte Namen (GetWsid, State 'wsid', Spalte wsid) weiter anbieten
    legacyNames = false,
}

-- Goldstaub (Premiumwaehrung mit eigener Speicherung, optional). Braucht zs_inventory fuer Ein-/Auszahlung.
Config.Goldstaub = {
    enabled = true,
    item = 'goldstaub',
    maxPerTransfer = 100000,
}

-- Konsolen-Banner und Resource-Check beim Start
Config.Banner = true

-- Meldungen
Config.Strings = {
    de = {
        no_identifier = 'Kein Identifier gefunden (%s). Spieler kann nicht geladen werden.',
        already_online = 'Mit diesem Konto ist bereits ein Spieler im Spiel.',
    },
    en = {
        no_identifier = 'No identifier found (%s). Player cannot be loaded.',
        already_online = 'This account is already in the game.',
    },
}

function L(key, ...)
    local pack = Config.Strings[Config.Locale] or Config.Strings.en
    local text = pack[key] or key
    if select('#', ...) > 0 then return text:format(...) end
    return text
end
