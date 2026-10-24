-- Oeffentliche Server-API von zs_core.
-- Aufruf aus anderen Resources:  exports.zs_core:GetPlayer(source)
-- Alle Funktionen liefern nil/false, wenn der Spieler keinen aktiven Charakter hat.

ZS = ZS or {}

local function entryOf(src)
    return ZS.players[tonumber(src)]
end

local function charOf(src)
    local e = entryOf(src)
    return e and e.char, e
end

-- ------------------------------------------------------------
-- Spieler und Charakter
-- ------------------------------------------------------------
exports('GetPlayer', function(src) return ZS.Snapshot(entryOf(src)) end)
exports('IsLoggedIn', function(src) return charOf(src) ~= nil end)
exports('GetCharacterId', function(src) local c = charOf(src); return c and c.id or nil end)
exports('GetSourceByCharacterId', function(charId) return ZS.sourceByChar[tonumber(charId)] end)
exports('GetIdentifier', function(src) local e = entryOf(src); return e and e.identifier or nil end)
exports('GetFullName', function(src)
    local c = charOf(src)
    return c and (c.firstname .. ' ' .. c.lastname) or nil
end)

-- Liste aller Spieler mit aktivem Charakter: { { source, id, fullname, job, group }, ... }
exports('GetOnlinePlayers', function()
    local list = {}
    for src, entry in pairs(ZS.players) do
        if entry.char then
            list[#list + 1] = { source = src, id = entry.char.id, fullname = entry.char.firstname .. ' ' .. entry.char.lastname,
                job = entry.char.job, group = entry.account.group }
        end
    end
    return list
end)

-- ------------------------------------------------------------
-- Gruppe (gilt fuer das ganze Konto)
-- ------------------------------------------------------------
exports('GetGroup', function(src) local e = entryOf(src); return e and e.account.group or nil end)
exports('IsAdmin', function(src)
    local e = entryOf(src)
    return e ~= nil and Config.AdminGroups[e.account.group] == true
end)

exports('SetGroup', function(src, group)
    local e = entryOf(src)
    if not e or type(group) ~= 'string' or group == '' then return false end
    local old = e.account.group
    e.account.group = group
    MySQL.update('UPDATE zs_accounts SET `group` = ? WHERE identifier = ?', { group, e.identifier })
    ZS.RefreshState(e)
    TriggerEvent('zs_core:groupChanged', src, group, old)
    return true
end)

-- ------------------------------------------------------------
-- Job
-- ------------------------------------------------------------
exports('GetJob', function(src)
    local c = charOf(src)
    if not c then return nil end
    return c.job, c.jobGrade, c.jobLabel
end)

exports('SetJob', function(src, name, grade, label)
    local c, e = charOf(src)
    if not c or type(name) ~= 'string' or name == '' then return false end
    local old = { name = c.job, grade = c.jobGrade, label = c.jobLabel }
    c.job = name
    c.jobGrade = tonumber(grade) or 0
    c.jobLabel = (type(label) == 'string' and label ~= '') and label or name
    MySQL.update('UPDATE zs_characters SET job = ?, job_grade = ?, job_label = ? WHERE id = ?', { c.job, c.jobGrade, c.jobLabel, c.id })
    ZS.RefreshState(e)
    TriggerEvent('zs_core:jobChanged', src, { name = c.job, grade = c.jobGrade, label = c.jobLabel }, old)
    return true
end)

-- ------------------------------------------------------------
-- Geld: frei definierbare Waehrungen aus Config.Currencies (Standard: 'cash' und 'gold')
-- ------------------------------------------------------------
local function validAmount(kind, amount)
    return Config.Currencies[kind] ~= nil and type(amount) == 'number' and amount == amount and amount >= 0 and amount < 1e12
end

exports('GetMoney', function(src, kind)
    local c = charOf(src)
    if not c or not Config.Currencies[kind] then return nil end
    return c.money[kind] or 0.0
end)

-- Alle Kontostaende als Tabelle: { cash = 12.5, gold = 0.0 }
exports('GetAllMoney', function(src)
    local c = charOf(src)
    if not c then return nil end
    local copy = {}
    for k, v in pairs(c.money) do copy[k] = v end
    return copy
end)

local function changeMoney(src, kind, newAmount, delta, reason)
    local c = charOf(src)
    c.money[kind] = newAmount
    ZS.PersistMoney(c.id, kind, newAmount)
    TriggerEvent('zs_core:moneyChanged', src, kind, delta, newAmount, reason)
    return true
end

exports('AddMoney', function(src, kind, amount, reason)
    local c = charOf(src)
    if not c or not validAmount(kind, amount) then return false end
    return changeMoney(src, kind, (c.money[kind] or 0.0) + amount, amount, reason)
end)

exports('RemoveMoney', function(src, kind, amount, reason)
    local c = charOf(src)
    if not c or not validAmount(kind, amount) then return false end
    local current = c.money[kind] or 0.0
    if current < amount then return false end
    return changeMoney(src, kind, current - amount, -amount, reason)
end)

exports('SetMoney', function(src, kind, amount, reason)
    local c = charOf(src)
    if not c or not validAmount(kind, amount) then return false end
    local current = c.money[kind] or 0.0
    return changeMoney(src, kind, amount + 0.0, amount - current, reason)
end)

-- ------------------------------------------------------------
-- Eigene Daten pro Charakter (Meta): fuer andere Resources, z. B. exports.zs_core:SetMeta(src, 'fishing_level', 3)
-- Werte muessen JSON-tauglich sein.
-- ------------------------------------------------------------
exports('GetMeta', function(src, key)
    local c = charOf(src)
    if not c or type(key) ~= 'string' then return nil end
    return c.meta[key]
end)

exports('SetMeta', function(src, key, value)
    local c = charOf(src)
    if not c or type(key) ~= 'string' then return false end
    c.meta[key] = value
    return true
end)

-- ------------------------------------------------------------
-- Zustand, den der Client meldet (Leben, Tod)
-- ------------------------------------------------------------
exports('SetDead', function(src, dead)
    local c = charOf(src)
    if not c then return false end
    c.isDead = dead and true or false
    ZS.PersistColumn(c.id, 'is_dead', c.isDead and 1 or 0)
    return true
end)

exports('SetVitals', function(src, vitals)
    local c = charOf(src)
    if not c or type(vitals) ~= 'table' then return false end
    c.vitals = vitals
    return true
end)

exports('SetPositionSaving', function(src, enabled)
    if not entryOf(src) then return false end
    Player(src).state:set('zs:noPositionSave', (not enabled) or nil, false)
    return true
end)

-- ------------------------------------------------------------
-- Aussehen (fuer zs_character und Kleidungsgeschaefte)
-- ------------------------------------------------------------
exports('GetAppearance', function(src)
    local c = charOf(src)
    if not c then return nil end
    return c.appearance, c.clothing
end)

exports('SaveAppearance', function(src, appearance, clothing)
    local c = charOf(src)
    if not c then return false end
    if appearance ~= nil then
        c.appearance = appearance
        ZS.PersistColumn(c.id, 'appearance', json.encode(appearance))
    end
    if clothing ~= nil then
        c.clothing = clothing
        ZS.PersistColumn(c.id, 'clothing', json.encode(clothing))
    end
    return true
end)

-- ------------------------------------------------------------
-- Charakterverwaltung (genutzt von zs_character)
-- ------------------------------------------------------------
exports('GetAccount', function(src)
    local e = ZS.EnsureAccount(src)
    return e and { group = e.account.group, maxCharacters = e.account.maxCharacters, identifier = e.identifier } or nil
end)
exports('ListCharacters', function(src) return ZS.ListCharacters(src) end)
exports('CreateCharacter', function(src, data) return ZS.CreateCharacter(src, data) end)
exports('DeleteCharacter', function(src, charId) return ZS.DeleteCharacter(src, tonumber(charId)) end)
exports('SelectCharacter', function(src, charId) return ZS.LoadCharacter(src, tonumber(charId)) end)
exports('LogoutCharacter', function(src)
    local e = entryOf(src)
    if not e or not e.char then return false end
    ZS.UnloadCharacter(e)
    return true
end)
exports('Save', function(src)
    local e = entryOf(src)
    if not e then return false end
    ZS.SaveCharacter(e)
    return true
end)

-- ------------------------------------------------------------
-- Benachrichtigung
-- opts: { type = 'info'|'success'|'error'|'warning', title = '...', duration = ms }
-- ------------------------------------------------------------
function ZS.Notify(src, text, opts)
    opts = opts or {}
    if GetResourceState(Config.NotifyResource) == 'started' then
        local ok = pcall(function()
            exports[Config.NotifyResource]:Notify(src, opts.type or 'info', text, { title = opts.title, duration = opts.duration })
        end)
        if ok then return true end
    end
    TriggerClientEvent('zs_core:client:notify', src, text, opts)
    return true
end
exports('Notify', function(src, text, opts) return ZS.Notify(src, text, opts) end)

-- ------------------------------------------------------------
-- Server-Callbacks: exports.zs_core:RegisterCallback('meine:rpc', function(source, ...) return wert end)
-- Aufruf vom Client: exports.zs_core:TriggerCallback('meine:rpc', ...)  (wartet auf die Antwort)
-- ------------------------------------------------------------
local callbacks = {}   -- [name] = { resource, fn }

function ZS.RegisterCallback(name, fn, resource)
    if type(name) ~= 'string' or not fn then return false end
    callbacks[name] = { resource = resource or GetCurrentResourceName(), fn = fn }
    return true
end

exports('RegisterCallback', function(name, fn)
    return ZS.RegisterCallback(name, fn, GetInvokingResource())
end)

AddEventHandler('onResourceStop', function(res)
    for name, cb in pairs(callbacks) do
        if cb.resource == res then callbacks[name] = nil end
    end
end)

RegisterNetEvent('zs_core:server:callback', function(name, requestId, ...)
    local src = source
    local cb = callbacks[name]
    if not cb then
        return TriggerClientEvent('zs_core:client:callbackResult', src, requestId, false, 'callback_not_found')
    end
    local results = table.pack(pcall(cb.fn, src, ...))
    if not results[1] then
        print(('^1[zs_core] Callback %s: %s^0'):format(name, tostring(results[2])))
        return TriggerClientEvent('zs_core:client:callbackResult', src, requestId, false, 'callback_error')
    end
    TriggerClientEvent('zs_core:client:callbackResult', src, requestId, true, table.unpack(results, 2, results.n))
end)

-- Client meldet Zustand
RegisterNetEvent('zs_core:server:reportVitals', function(vitals)
    local src = source
    local c = charOf(src)
    if c and type(vitals) == 'table' then c.vitals = vitals end
end)

RegisterNetEvent('zs_core:server:reportDead', function(dead)
    local src = source
    local c = charOf(src)
    if c then
        c.isDead = dead and true or false
        ZS.PersistColumn(c.id, 'is_dead', c.isDead and 1 or 0)
    end
end)
