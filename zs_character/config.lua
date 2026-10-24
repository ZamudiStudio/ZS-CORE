Config = {}

-- Studio: hier steht der Charakter waehrend Auswahl und Erstellung (abseits der Spieler, gern ein ruhiger Ort)
Config.Studio = {
    coords = vector4(-290.0, 780.0, 118.4, 280.0),   -- x, y, z, Blickrichtung (heading). ANPASSEN auf einen Ort deiner Wahl.
    camOffset = vector3(0.0, 2.6, 0.35),             -- Kamera relativ zur Figur (vorn, Hoehe)
    camLookHeight = 0.0,                             -- zusaetzliche Hoehe des Blickpunkts
}

-- Wo ein neuer Charakter nach der Erstellung ins Spiel kommt (Liste: zufaellig einer davon)
Config.NewCharacterSpawns = {
    vector4(-174.0, 631.0, 114.1, 330.0),
}

-- Lebt ein Charakter beim Einloggen als "tot" gespeichert: dort wird er stattdessen mit voller Gesundheit hierhin gesetzt.
-- (Das eigentliche Sterben/Wiederbeleben uebernimmt dein Todes-Script.)
Config.RespawnIfDead = true
Config.DeadRespawn = vector4(-174.0, 631.0, 114.1, 330.0)

-- Erlaubt dem Spieler, Charaktere in der Auswahl zu loeschen
Config.AllowDelete = true

-- Befehl, um zur Charakterauswahl zurueckzukehren ('' = abgeschaltet)
Config.LogoutCommand = 'charwechsel'

-- Gesundheit/Ausdauer alle X Sekunden an den Server melden (0 = nicht speichern)
Config.VitalsIntervalSeconds = 60

-- Alter-Grenzen in der Erstellung (der Server prueft 18-90)
Config.MinAge = 18
Config.MaxAge = 90

-- Texte der Oberflaeche
Config.Locale = 'de'
Config.Strings = {
    de = {
        title = 'Charakter wählen', create = 'Neuer Charakter', play = 'Spielen', delete = 'Löschen',
        confirmDelete = 'Wirklich löschen? Das kann nicht rückgängig gemacht werden.',
        firstname = 'Vorname', lastname = 'Nachname', age = 'Alter', gender = 'Geschlecht', male = 'Männlich', female = 'Weiblich',
        description = 'Beschreibung (optional)', next = 'Weiter', back = 'Zurück', finish = 'Charakter erstellen',
        stepIdentity = 'Identität', stepLook = 'Aussehen', stepConfirm = 'Bestätigen', height = 'Körpergröße',
        slotsFree = 'Freie Plätze', empty = 'Noch kein Charakter', lastPlayed = 'Zuletzt gespielt', never = 'Noch nie',
        errName = 'Bitte gültige Namen eingeben (2-30 Zeichen).', errAge = 'Das Alter muss zwischen %d und %d liegen.',
        errNoSlot = 'Alle Charakterplätze sind belegt.', errGeneric = 'Das hat nicht geklappt. Bitte erneut versuchen.',
        noOptions = 'Für diesen Server sind noch keine Aussehens-Optionen hinterlegt.',
    },
    en = {
        title = 'Choose character', create = 'New character', play = 'Play', delete = 'Delete',
        confirmDelete = 'Really delete? This cannot be undone.',
        firstname = 'First name', lastname = 'Last name', age = 'Age', gender = 'Gender', male = 'Male', female = 'Female',
        description = 'Description (optional)', next = 'Next', back = 'Back', finish = 'Create character',
        stepIdentity = 'Identity', stepLook = 'Appearance', stepConfirm = 'Confirm', height = 'Height',
        slotsFree = 'Free slots', empty = 'No character yet', lastPlayed = 'Last played', never = 'Never',
        errName = 'Please enter valid names (2-30 characters).', errAge = 'Age must be between %d and %d.',
        errNoSlot = 'All character slots are used.', errGeneric = 'That did not work. Please try again.',
        noOptions = 'No appearance options have been configured for this server yet.',
    },
}
