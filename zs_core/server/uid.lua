-- UID: oeffentliche Spieler-ID pro Charakter, dazu Spielzeit, Aktivitaets-Kalender und das Native-Merkmal.
-- Abschaltbar ueber Config.Uid.enabled.

if not Config.Uid.enabled then return end

local legacy = Config.Uid.legacyNames

local uidBySource = {}
local sourceByUid = {}

CreateThread(function()
    ZS.WaitForDatabase()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS zs_players (
            char_id INT NOT NULL,
            uid INT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (char_id),
            UNIQUE KEY uq_uid (uid)
        )
    ]])

    -- Umstieg von aelteren Staenden: die Spalte hiess frueher wsid
    local function hasColumn(tbl, col)
        return (MySQL.scalar.await('SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?', { tbl, col }) or 0) > 0
    end
    for _, tbl in ipairs({ 'zs_players', 'zs_playtime_daily' }) do
        if hasColumn(tbl, 'wsid') and not hasColumn(tbl, 'uid') then
            MySQL.query.await(('ALTER TABLE %s CHANGE wsid uid INT NOT NULL'):format(tbl))
        end
    end
    -- Spielzeit in Sekunden (aeltere Tabellen bekommen die Spalte nachtraeglich)
    MySQL.query.await('ALTER TABLE zs_players ADD COLUMN IF NOT EXISTS playtime INT NOT NULL DEFAULT 0')
    -- Native-Merkmal des Charakters, fuer Craftings, Items und Quests
    MySQL.query.await('ALTER TABLE zs_players ADD COLUMN IF NOT EXISTS native TINYINT(1) NOT NULL DEFAULT 0')
    -- Spielzeit pro Tag (fuer Aktivitaets-Kalender)
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS zs_playtime_daily (
            uid INT NOT NULL,
            day DATE NOT NULL,
            seconds INT NOT NULL DEFAULT 0,
            PRIMARY KEY (uid, day)
        )
    ]])

    -- Nur mit legacyNames: die alte Spalte wsid als berechnete Spalte weiter anbieten (fuer alte Abfragen)
    if legacy then
        for _, tbl in ipairs({ 'zs_players', 'zs_playtime_daily' }) do
            if not hasColumn(tbl, 'wsid') then
                MySQL.query.await(('ALTER TABLE %s ADD COLUMN wsid INT AS (uid) VIRTUAL'):format(tbl))
            end
        end
    end
end)

-- Spielzeit: gutgeschrieben werden die tatsaechlich gespielten Sekunden, alle 30 s und beim Verlassen
local lastCredit = {}    -- [uid] = Zeitpunkt (os.time) der letzten Gutschrift

local function creditPlaytime(uid)
    local now = os.time()
    local secs = math.min(now - (lastCredit[uid] or now), 120)     -- hoechstens 120 s auf einmal (Schutz gegen Zeitspruenge)
    lastCredit[uid] = now
    if secs <= 0 then return end
    MySQL.update('UPDATE zs_players SET playtime = playtime + ? WHERE uid = ?', { secs, uid })
    MySQL.update(
        'INSERT INTO zs_playtime_daily (uid, day, seconds) VALUES (?, CURDATE(), ?) ON DUPLICATE KEY UPDATE seconds = seconds + VALUES(seconds)',
        { uid, secs }
    )
end

CreateThread(function()
    while true do
        Wait(30000)
        for _, uid in pairs(uidBySource) do creditPlaytime(uid) end
    end
end)

local function loadOrCreateUid(charId)
    local existing = MySQL.scalar.await('SELECT uid FROM zs_players WHERE char_id = ?', { charId })
    if existing then return existing end

    local w = Config.Uid
    for _ = 1, w.maxTries do
        local uid = math.random(w.min, w.max)
        -- INSERT IGNORE: schlaegt bei doppelter UID still fehl (affectedRows = 0)
        local affected = MySQL.update.await('INSERT IGNORE INTO zs_players (char_id, uid) VALUES (?, ?)', { charId, uid })
        if affected and affected > 0 then return uid end
    end

    print('^1[zs_core] Keine freie UID mehr gefunden (Bereich voll?)^0')
    return nil
end

AddEventHandler('zs_core:characterLoaded', function(src, char)
    local uid = loadOrCreateUid(char.id)
    if not uid then return end
    uidBySource[src] = uid
    sourceByUid[uid] = src
    lastCredit[uid] = lastCredit[uid] or os.time()
    Player(src).state:set('uid', uid, true)
    if legacy then Player(src).state:set('wsid', uid, true) end
end)

AddEventHandler('zs_core:characterUnloaded', function(src)
    local uid = uidBySource[src]
    if uid then
        creditPlaytime(uid)
        lastCredit[uid] = nil
        sourceByUid[uid] = nil
    end
    uidBySource[src] = nil
    Player(src).state:set('uid', nil, true)
    if legacy then Player(src).state:set('wsid', nil, true) end
end)

exports('GetUid', function(src) return uidBySource[src] end)
exports('GetSourceByUid', function(uid) return sourceByUid[tonumber(uid)] end)

if legacy then
    -- Alte Namen fuer aeltere Resources
    exports('GetWsid', function(src) return uidBySource[src] end)
    exports('GetSourceByWsid', function(uid) return sourceByUid[tonumber(uid)] end)
end

-- Spielzeit pro Tag der letzten Tage: { ["2026-10-09"] = Sekunden, ... }
exports('GetActivity', function(src, days)
    local uid = uidBySource[src]
    if not uid then return {} end
    local rows = MySQL.query.await(
        'SELECT DATE_FORMAT(day, "%Y-%m-%d") AS d, seconds FROM zs_playtime_daily WHERE uid = ? AND day >= DATE_SUB(CURDATE(), INTERVAL ? DAY)',
        { uid, tonumber(days) or 365 }
    )
    local out = {}
    for _, r in ipairs(rows or {}) do out[r.d] = r.seconds end
    return out
end)

-- Spielzeit des aktiven Charakters in Sekunden
exports('GetPlaytime', function(src)
    local uid = uidBySource[src]
    if not uid then return 0 end
    local stored = MySQL.scalar.await('SELECT playtime FROM zs_players WHERE uid = ?', { uid }) or 0
    -- Dazu die Sekunden seit der letzten Gutschrift, damit die Anzeige nicht auf volle Intervalle springt
    local pending = lastCredit[uid] and math.min(os.time() - lastCredit[uid], 120) or 0
    return stored + math.max(0, pending)
end)

-- Native-Merkmal: exports.zs_core:IsNative(src) / SetNative(src, true|false)
exports('IsNative', function(src)
    local uid = uidBySource[src]
    if not uid then return false end
    return MySQL.scalar.await('SELECT native FROM zs_players WHERE uid = ?', { uid }) == 1
end)

exports('SetNative', function(src, value)
    local uid = uidBySource[src]
    if not uid then return false end
    MySQL.update.await('UPDATE zs_players SET native = ? WHERE uid = ?', { value and 1 or 0, uid })
    return true
end)

-- Nur Konsole/Admin: setnative <UID> <0|1>
RegisterCommand('setnative', function(src, args)
    local target = sourceByUid[tonumber(args[1])]
    if not target then print('[zs_core] Nutzung: setnative <UID> <0|1> (Spieler muss online sein)') return end
    exports.zs_core:SetNative(target, args[2] == '1')
    print(('[zs_core] UID %s: Native = %s'):format(args[1], args[2] == '1' and 'ja' or 'nein'))
end, true)
