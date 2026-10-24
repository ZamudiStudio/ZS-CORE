-- zs_character Client: Auswahl- und Erstellungsoberflaeche, Kamera, Spawn.

local uiOpen = false
local cam = nil
local characters = {}

local function t(key)
    local pack = Config.Strings[Config.Locale] or Config.Strings.en
    return pack[key] or key
end

-- ------------------------------------------------------------
-- Kamera und Figur im Studio
-- ------------------------------------------------------------
local function placeInStudio()
    local ped = PlayerPedId()
    local s = Config.Studio.coords
    RequestCollisionAtCoord(s.x, s.y, s.z)
    SetEntityCoordsNoOffset(ped, s.x, s.y, s.z, false, false, false)
    SetEntityHeading(ped, s.w)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetEntityVisible(ped, true)
end

local function startCamera()
    local s = Config.Studio.coords
    local rad = math.rad(s.w)
    -- Kamera steht vor der Figur und schaut zu ihr
    local fx, fy = -math.sin(rad), math.cos(rad)
    local o = Config.Studio.camOffset
    local cx, cy, cz = s.x + fx * o.y, s.y + fy * o.y, s.z + o.z
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', cx, cy, cz, 0.0, 0.0, 0.0, 40.0, false, 0)
    PointCamAtCoord(cam, s.x, s.y, s.z + Config.Studio.camLookHeight)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 800, true, false, 0)
end

local function stopCamera()
    if cam then
        RenderScriptCams(false, true, 800, true, false, 0)
        DestroyCam(cam, false)
        cam = nil
    end
end

local function showUi(payload)
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage(payload)
end

local function hideUi()
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- ------------------------------------------------------------
-- Oeffnen (vom Server)
-- ------------------------------------------------------------
RegisterNetEvent('zs_character:client:open', function(data)
    characters = data.characters or {}

    pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
    if not IsScreenFadedOut() then DoScreenFadeOut(300) Wait(400) end
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    DisplayRadar(false)

    placeInStudio()
    Appearance.SetGender('male')
    startCamera()
    DoScreenFadeIn(800)

    local strings = Config.Strings[Config.Locale] or Config.Strings.en
    showUi({
        action = 'open',
        strings = strings,
        characters = characters,
        maxCharacters = data.maxCharacters,
        allowDelete = data.allowDelete,
        minAge = Config.MinAge,
        maxAge = Config.MaxAge,
        height = Catalog.height,
    })
end)

RegisterNetEvent('zs_character:client:characters', function(list)
    characters = list or {}
    SendNUIMessage({ action = 'characters', characters = characters })
end)

RegisterNetEvent('zs_character:client:error', function(key)
    SendNUIMessage({ action = 'error', message = t(key) })
end)

-- ------------------------------------------------------------
-- Vorschau in der Auswahl und im Creator
-- ------------------------------------------------------------
local function previewCharacter(c)
    local ped = Appearance.SetGender(c.gender)
    placeInStudio()
    ped = PlayerPedId()
    Appearance.Apply(ped, c.gender, c.appearance)
end

RegisterNUICallback('previewCharacter', function(data, cb)
    for _, c in ipairs(characters) do
        if c.id == data.id then previewCharacter(c) break end
    end
    cb({})
end)

-- Creator: Geschlecht gewaehlt oder gewechselt -> Figur neu setzen, Kategorien liefern
RegisterNUICallback('previewGender', function(data, cb)
    local gender = data.gender == 'female' and 'female' or 'male'
    Appearance.SetGender(gender)
    placeInStudio()
    SetPedScale(PlayerPedId(), Appearance.ClampScale(data.scale))
    cb({ categories = Appearance.CategoriesFor(gender) })
end)

RegisterNUICallback('previewAppearance', function(data, cb)
    local gender = data.gender == 'female' and 'female' or 'male'
    Appearance.Apply(PlayerPedId(), gender, { scale = Appearance.ClampScale(data.scale), parts = data.parts })
    cb({})
end)

-- ------------------------------------------------------------
-- Aktionen aus der Oberflaeche
-- ------------------------------------------------------------
RegisterNUICallback('select', function(data, cb)
    TriggerServerEvent('zs_character:server:select', data.id)
    cb({})
end)

RegisterNUICallback('create', function(data, cb)
    TriggerServerEvent('zs_character:server:create', {
        firstname = data.firstname, lastname = data.lastname, age = data.age, gender = data.gender,
        description = data.description,
        appearance = { scale = Appearance.ClampScale(data.scale), parts = data.parts },
    })
    cb({})
end)

RegisterNUICallback('delete', function(data, cb)
    TriggerServerEvent('zs_character:server:delete', data.id)
    cb({})
end)

-- ------------------------------------------------------------
-- Spawn (vom Server)
-- ------------------------------------------------------------
RegisterNetEvent('zs_character:client:spawn', function(data)
    hideUi()
    DoScreenFadeOut(500)
    Wait(600)

    local ped = Appearance.SetGender(data.gender)
    Appearance.Apply(ped, data.gender, data.appearance)
    ped = PlayerPedId()

    local c = data.coords
    RequestCollisionAtCoord(c.x, c.y, c.z)
    SetEntityCoordsNoOffset(ped, c.x, c.y, c.z, false, false, false)
    SetEntityHeading(ped, c.w or 0.0)

    local timeout = GetGameTimer() + 6000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do Wait(50) end

    stopCamera()
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetEntityVisible(ped, true)
    DisplayRadar(true)
    if data.isDead then SetEntityHealth(ped, 0, 0) end

    DoScreenFadeIn(1200)
    TriggerEvent('zs_character:spawned', data)
end)

-- ------------------------------------------------------------
-- Gesundheit regelmaessig melden (fuer das Speichern)
-- ------------------------------------------------------------
CreateThread(function()
    if Config.VitalsIntervalSeconds <= 0 then return end
    while true do
        Wait(Config.VitalsIntervalSeconds * 1000)
        if LocalPlayer.state['zs:char'] and not uiOpen then
            local ped = PlayerPedId()
            TriggerServerEvent('zs_core:server:reportVitals', {
                health = GetEntityHealth(ped),
                healthCore = Citizen.InvokeNative(0x36731AC041289BB1, ped, 0, Citizen.ResultAsInteger()),
                staminaCore = Citizen.InvokeNative(0x36731AC041289BB1, ped, 1, Citizen.ResultAsInteger()),
            })
        end
    end
end)

-- Tod melden (fuer "tot gespeichert")
CreateThread(function()
    local wasDead = false
    while true do
        Wait(1000)
        if LocalPlayer.state['zs:char'] and not uiOpen then
            local dead = IsEntityDead(PlayerPedId())
            if dead ~= wasDead then
                wasDead = dead
                TriggerServerEvent('zs_core:server:reportDead', dead)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if uiOpen then SetNuiFocus(false, false) end
    stopCamera()
end)
