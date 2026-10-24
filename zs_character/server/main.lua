-- zs_character Server: Auswahl, Erstellung, Loeschen und Spawn. Daten liegen in zs_core.

local core = exports.zs_core

local busy = {}          -- [src] = true, solange eine Aktion laeuft (verhindert Doppelklicks)
local lastAction = {}    -- [src] = GetGameTimer() der letzten Aktion (einfache Drosselung)

local function throttled(src)
    local now = GetGameTimer()
    if lastAction[src] and now - lastAction[src] < 400 then return true end
    lastAction[src] = now
    return false
end

-- Aussehen vom Client pruefen: nur flache Tabelle mit erlaubten Typen, begrenzte Groesse
local function sanitizeAppearance(data)
    if type(data) ~= 'table' then return nil end
    local out = { scale = 1.0, parts = {} }
    local h = Catalog.height
    local scale = tonumber(data.scale) or h.default
    out.scale = math.max(h.min, math.min(h.max, scale))
    if type(data.parts) == 'table' then
        for _, cat in ipairs(Catalog.categories) do
            local v = tonumber(data.parts[cat.id])
            if v then out.parts[cat.id] = math.floor(v) end
        end
    end
    return out
end

local function toRandomSpawn()
    local list = Config.NewCharacterSpawns
    return list[math.random(1, #list)]
end

local function enterStudio(src)
    SetPlayerRoutingBucket(src, 1000 + src)   -- eigene Instanz: andere Spieler sehen die Erstellung nicht
end

local function leaveStudio(src)
    SetPlayerRoutingBucket(src, 0)
end

local function sendOpen(src)
    local account = core:GetAccount(src)
    if not account then return end
    enterStudio(src)
    TriggerClientEvent('zs_character:client:open', src, {
        characters = core:ListCharacters(src),
        maxCharacters = account.maxCharacters,
        allowDelete = Config.AllowDelete,
    })
end

-- Spieler ist bereit: Auswahl oeffnen (ausser er hat schon einen Charakter, z. B. nach Resource-Neustart)
AddEventHandler('zs_core:playerReady', function(src)
    if core:IsLoggedIn(src) then return end
    sendOpen(src)
end)

-- Charakter ins Spiel setzen
local function spawnCharacter(src, spawnOverride)
    local player = core:GetPlayer(src)
    if not player then return false end
    local appearance, clothing = core:GetAppearance(src)

    local coords = spawnOverride or player.coords
    local dead = player.isDead
    if dead and Config.RespawnIfDead then
        coords = Config.DeadRespawn
        dead = false
        core:SetDead(src, false)
    end
    if not coords then coords = toRandomSpawn() end

    leaveStudio(src)
    TriggerClientEvent('zs_character:client:spawn', src, {
        coords = { x = coords.x, y = coords.y, z = coords.z, w = coords.w or coords.heading or 0.0 },
        gender = player.gender,
        appearance = appearance,
        clothing = clothing,
        isDead = dead,
        firstname = player.firstname,
        lastname = player.lastname,
    })
    return true
end

RegisterNetEvent('zs_character:server:select', function(charId)
    local src = source
    if busy[src] or throttled(src) then return end
    busy[src] = true
    local ok = core:SelectCharacter(src, tonumber(charId))
    if ok then
        spawnCharacter(src)
    else
        TriggerClientEvent('zs_character:client:error', src, 'errGeneric')
    end
    busy[src] = nil
end)

RegisterNetEvent('zs_character:server:create', function(data)
    local src = source
    if busy[src] or throttled(src) then return end
    if type(data) ~= 'table' then return end
    busy[src] = true

    local appearance = sanitizeAppearance(data.appearance)
    local id, err = core:CreateCharacter(src, {
        firstname = data.firstname,
        lastname = data.lastname,
        age = data.age,
        gender = data.gender,
        description = data.description,
        appearance = appearance,
    })

    if not id then
        local key = (err == 'invalid_name' and 'errName') or (err == 'invalid_age' and 'errAge')
            or (err == 'no_slot' and 'errNoSlot') or 'errGeneric'
        TriggerClientEvent('zs_character:client:error', src, key)
        busy[src] = nil
        return
    end

    if core:SelectCharacter(src, id) then
        spawnCharacter(src, toRandomSpawn())
    else
        TriggerClientEvent('zs_character:client:error', src, 'errGeneric')
    end
    busy[src] = nil
end)

RegisterNetEvent('zs_character:server:delete', function(charId)
    local src = source
    if not Config.AllowDelete or busy[src] or throttled(src) then return end
    busy[src] = true
    core:DeleteCharacter(src, tonumber(charId))
    TriggerClientEvent('zs_character:client:characters', src, core:ListCharacters(src))
    busy[src] = nil
end)

-- Vorschau in der Auswahl: Aussehen eines eigenen Charakters liefern
RegisterNetEvent('zs_character:server:requestCharacters', function()
    local src = source
    if core:IsLoggedIn(src) then return end
    TriggerClientEvent('zs_character:client:characters', src, core:ListCharacters(src))
end)

-- Zurueck zur Auswahl
local function logout(src)
    if not core:IsLoggedIn(src) then return end
    core:LogoutCharacter(src)
    sendOpen(src)
end

RegisterNetEvent('zs_character:server:logout', function()
    logout(source)
end)

if Config.LogoutCommand and Config.LogoutCommand ~= '' then
    RegisterCommand(Config.LogoutCommand, function(src)
        if src > 0 then logout(src) end
    end, false)
end

AddEventHandler('playerDropped', function()
    local src = source
    busy[src] = nil
    lastAction[src] = nil
end)
