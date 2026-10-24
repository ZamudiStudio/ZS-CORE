-- Spieler, Konten und Charaktere im Speicher.
-- Jeder verbundene Spieler hat einen Eintrag in ZS.players[src]; der aktive Charakter steckt in entry.char.

ZS = ZS or {}
ZS.players = {}        -- [src] = { src, identifier, name, account = { group, maxCharacters }, char = rec|nil }
ZS.sourceByChar = {}   -- [charId] = src

local function jsonOr(value, fallback)
    if value == nil or value == '' then return fallback end
    local ok, decoded = pcall(json.decode, value)
    if ok and decoded ~= nil then return decoded end
    return fallback
end

local function identifierOf(src)
    return GetPlayerIdentifierByType(tostring(src), Config.Identifier)
end
ZS.IdentifierOf = identifierOf

-- ------------------------------------------------------------
-- Konto
-- ------------------------------------------------------------
function ZS.EnsureAccount(src)
    src = tonumber(src)
    if not src then return nil end
    local existing = ZS.players[src]
    if existing then return existing end

    ZS.WaitForDatabase()

    local identifier = identifierOf(src)
    if not identifier then
        print(('^1[zs_core] %s^0'):format(L('no_identifier', Config.Identifier)))
        return nil
    end

    -- Zweiter Login mit demselben Konto: den alten Zugang rauswerfen
    for otherSrc, entry in pairs(ZS.players) do
        if entry.identifier == identifier and otherSrc ~= src then
            DropPlayer(src, L('already_online'))
            return nil
        end
    end

    local name = GetPlayerName(src) or ''
    local row = MySQL.single.await('SELECT `group`, max_characters FROM zs_accounts WHERE identifier = ?', { identifier })
    if not row then
        local count = MySQL.scalar.await('SELECT COUNT(*) FROM zs_accounts') or 0
        local group = Config.Defaults.group
        if count == 0 and Config.Defaults.firstAccountGroup ~= '' then group = Config.Defaults.firstAccountGroup end
        MySQL.insert.await('INSERT INTO zs_accounts (identifier, display_name, `group`, max_characters) VALUES (?, ?, ?, ?)',
            { identifier, name, group, Config.Defaults.maxCharacters })
        row = { group = group, max_characters = Config.Defaults.maxCharacters }
    else
        MySQL.update('UPDATE zs_accounts SET display_name = ?, last_seen = NOW() WHERE identifier = ?', { name, identifier })
    end

    local entry = {
        src = src,
        identifier = identifier,
        name = name,
        account = { group = row.group, maxCharacters = row.max_characters },
        char = nil,
    }
    ZS.players[src] = entry
    return entry
end

-- ------------------------------------------------------------
-- Charakter laden / entladen
-- ------------------------------------------------------------
local function buildRecord(row)
    return {
        id = row.id,
        identifier = row.identifier,
        firstname = row.firstname,
        lastname = row.lastname,
        nickname = row.nickname or '',
        age = row.age,
        gender = row.gender,
        description = row.description or '',
        job = row.job,
        jobGrade = row.job_grade,
        jobLabel = row.job_label,
        money = {},
        coords = jsonOr(row.coords, nil),
        vitals = jsonOr(row.vitals, nil),
        isDead = row.is_dead == 1 or row.is_dead == true,
        appearance = jsonOr(row.appearance, nil),
        clothing = jsonOr(row.clothing, nil),
        meta = jsonOr(row.meta, {}),
    }
end

-- Kurzform, die Spielern ueber den State Bag zur Verfuegung steht (Client darf mitlesen)
local function publicState(entry)
    local c = entry.char
    return {
        id = c.id,
        firstname = c.firstname,
        lastname = c.lastname,
        gender = c.gender,
        job = c.job,
        jobGrade = c.jobGrade,
        jobLabel = c.jobLabel,
        group = entry.account.group,
    }
end

function ZS.RefreshState(entry)
    if entry.char then
        Player(entry.src).state:set('zs:char', publicState(entry), true)
    else
        Player(entry.src).state:set('zs:char', nil, true)
    end
end

-- Aussen sichtbare Kopie des Charakters (aenderungen daran wirken nicht zurueck)
function ZS.Snapshot(entry)
    local c = entry and entry.char
    if not c then return nil end
    return {
        id = c.id,
        source = entry.src,
        identifier = entry.identifier,
        firstname = c.firstname,
        lastname = c.lastname,
        fullname = c.firstname .. ' ' .. c.lastname,
        nickname = c.nickname,
        age = c.age,
        gender = c.gender,
        description = c.description,
        job = c.job,
        jobGrade = c.jobGrade,
        jobLabel = c.jobLabel,
        group = entry.account.group,
        money = (function()
            local copy = {}
            for k, v in pairs(c.money) do copy[k] = v end
            return copy
        end)(),
        coords = c.coords,
        isDead = c.isDead,
        meta = c.meta,
    }
end

-- Kontostand sofort schreiben (Geld darf bei einem Absturz nicht verloren gehen)
function ZS.PersistMoney(charId, currency, amount)
    MySQL.update('INSERT INTO zs_character_money (char_id, currency, amount) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE amount = VALUES(amount)',
        { charId, currency, amount })
end

function ZS.LoadCharacter(src, charId)
    local entry = ZS.EnsureAccount(src)
    if not entry then return false, 'no_account' end
    if entry.char then return false, 'already_loaded' end

    local row = MySQL.single.await('SELECT * FROM zs_characters WHERE id = ? AND identifier = ?', { charId, entry.identifier })
    if not row then return false, 'not_found' end
    if ZS.sourceByChar[row.id] then return false, 'in_use' end

    entry.char = buildRecord(row)
    for currency in pairs(Config.Currencies) do entry.char.money[currency] = 0.0 end
    local moneyRows = MySQL.query.await('SELECT currency, amount FROM zs_character_money WHERE char_id = ?', { row.id }) or {}
    for _, m in ipairs(moneyRows) do
        if Config.Currencies[m.currency] then entry.char.money[m.currency] = m.amount + 0.0 end
    end
    ZS.sourceByChar[row.id] = src
    MySQL.update('UPDATE zs_characters SET last_played = NOW() WHERE id = ?', { row.id })

    ZS.RefreshState(entry)
    local snap = ZS.Snapshot(entry)
    TriggerClientEvent('zs_core:client:characterLoaded', src, snap)
    TriggerEvent('zs_core:characterLoaded', src, snap)
    return true
end

-- Schreibt den aktiven Charakter in die Datenbank
function ZS.SaveCharacter(entry)
    local c = entry and entry.char
    if not c then return end

    local ped = GetPlayerPed(entry.src)
    if ped and ped ~= 0 and not Player(entry.src).state['zs:noPositionSave'] then
        local p = GetEntityCoords(ped)
        c.coords = { x = p.x, y = p.y, z = p.z, heading = GetEntityHeading(ped) }
    end

    MySQL.update([[UPDATE zs_characters SET firstname = ?, lastname = ?, nickname = ?, age = ?, gender = ?, description = ?,
        job = ?, job_grade = ?, job_label = ?, coords = ?, vitals = ?, is_dead = ?, meta = ? WHERE id = ?]],
        { c.firstname, c.lastname, c.nickname, c.age, c.gender, c.description, c.job, c.jobGrade, c.jobLabel,
          c.coords and json.encode(c.coords) or nil, c.vitals and json.encode(c.vitals) or nil, c.isDead and 1 or 0,
          json.encode(c.meta or {}), c.id })
end

function ZS.UnloadCharacter(entry)
    local c = entry and entry.char
    if not c then return end
    ZS.SaveCharacter(entry)
    ZS.sourceByChar[c.id] = nil
    entry.char = nil
    ZS.RefreshState(entry)
    TriggerEvent('zs_core:characterUnloaded', entry.src, c.id)
end

-- Einzelnes Feld sofort schreiben (Geld, Job): geht nicht erst beim naechsten Autosave verloren
function ZS.PersistColumn(charId, column, value)
    MySQL.update(('UPDATE zs_characters SET `%s` = ? WHERE id = ?'):format(column), { value, charId })
end

-- ------------------------------------------------------------
-- Charaktere anlegen / loeschen / auflisten
-- ------------------------------------------------------------
function ZS.ListCharacters(src)
    local entry = ZS.EnsureAccount(src)
    if not entry then return {} end
    local rows = MySQL.query.await([[SELECT id, firstname, lastname, nickname, age, gender, job, job_label,
        is_dead, appearance, clothing, coords, UNIX_TIMESTAMP(last_played) AS last_played
        FROM zs_characters WHERE identifier = ? ORDER BY id]], { entry.identifier }) or {}
    local list = {}
    for _, r in ipairs(rows) do
        list[#list + 1] = {
            id = r.id, firstname = r.firstname, lastname = r.lastname, nickname = r.nickname, age = r.age,
            gender = r.gender, job = r.job, jobLabel = r.job_label,
            isDead = r.is_dead == 1, appearance = jsonOr(r.appearance, nil), clothing = jsonOr(r.clothing, nil),
            coords = jsonOr(r.coords, nil), lastPlayed = r.last_played,
        }
    end
    return list
end

local function cleanName(value, maxLen)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('^%s+', ''):gsub('%s+$', '')
    if #value < 2 or #value > maxLen then return nil end
    if value:find('[%c<>{}\\]') then return nil end
    return value
end

-- data: firstname, lastname, age, gender ('male'|'female'), nickname?, description?, appearance?, clothing?
function ZS.CreateCharacter(src, data)
    local entry = ZS.EnsureAccount(src)
    if not entry then return nil, 'no_account' end
    if type(data) ~= 'table' then return nil, 'invalid' end

    local firstname = cleanName(data.firstname, 30)
    local lastname = cleanName(data.lastname, 30)
    if not firstname or not lastname then return nil, 'invalid_name' end

    local gender = data.gender == 'female' and 'female' or 'male'
    local age = math.floor(tonumber(data.age) or 25)
    if age < 18 or age > 90 then return nil, 'invalid_age' end

    local owned = MySQL.scalar.await('SELECT COUNT(*) FROM zs_characters WHERE identifier = ?', { entry.identifier }) or 0
    if owned >= entry.account.maxCharacters then return nil, 'no_slot' end

    local d = Config.Defaults
    local id = MySQL.insert.await([[INSERT INTO zs_characters (identifier, firstname, lastname, nickname, age, gender, description,
        job, job_grade, job_label, appearance, clothing, meta) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)]],
        { entry.identifier, firstname, lastname, cleanName(data.nickname, 30) or '', age, gender,
          type(data.description) == 'string' and data.description:sub(1, 500) or '',
          d.job, d.jobGrade, d.jobLabel,
          data.appearance and json.encode(data.appearance) or nil,
          data.clothing and json.encode(data.clothing) or nil, '{}' })
    if not id then return nil, 'db_error' end
    for currency, def in pairs(Config.Currencies) do
        ZS.PersistMoney(id, currency, tonumber(def.start) or 0.0)
    end
    TriggerEvent('zs_core:characterCreated', src, id)
    return id
end

function ZS.DeleteCharacter(src, charId)
    local entry = ZS.EnsureAccount(src)
    if not entry then return false end
    if entry.char and entry.char.id == charId then return false end   -- aktiven Charakter nicht loeschen
    local affected = MySQL.update.await('DELETE FROM zs_characters WHERE id = ? AND identifier = ?', { charId, entry.identifier })
    if affected and affected > 0 then
        MySQL.update('DELETE FROM zs_character_money WHERE char_id = ?', { charId })
        TriggerEvent('zs_core:characterDeleted', src, charId)
        return true
    end
    return false
end

-- ------------------------------------------------------------
-- Lebenszyklus
-- ------------------------------------------------------------
-- Der Client meldet sich, sobald er im Spiel ist
RegisterNetEvent('zs_core:server:clientReady', function()
    local src = source
    local entry = ZS.EnsureAccount(src)
    if not entry then return end
    TriggerEvent('zs_core:playerReady', src, { group = entry.account.group, maxCharacters = entry.account.maxCharacters })
end)

AddEventHandler('playerDropped', function()
    local src = source
    local entry = ZS.players[src]
    if not entry then return end
    ZS.UnloadCharacter(entry)
    ZS.players[src] = nil
end)

CreateThread(function()
    while true do
        Wait(Config.AutosaveSeconds * 1000)
        for _, entry in pairs(ZS.players) do ZS.SaveCharacter(entry) end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, entry in pairs(ZS.players) do ZS.SaveCharacter(entry) end
end)

-- Resource-Neustart im laufenden Betrieb: Spieler samt Charakter wieder anbinden
AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    CreateThread(function()
        ZS.WaitForDatabase()
        for _, sid in ipairs(GetPlayers()) do
            local src = tonumber(sid)
            local entry = ZS.EnsureAccount(src)
            local st = entry and Player(src).state['zs:char']
            if st and st.id then ZS.LoadCharacter(src, st.id) end
        end
    end)
end)
