-- Aussehen anwenden: Modell, Koerpergroesse und die Teile aus dem Katalog.

Appearance = {}

local MODELS = { male = `mp_male`, female = `mp_female` }

-- Baut die Kategorien fuer ein Geschlecht (nur Anzahl und Beschriftung fuer die Oberflaeche)
function Appearance.CategoriesFor(gender)
    local list = {}
    for _, cat in ipairs(Catalog.categories) do
        local options = cat[gender == 'female' and 'female' or 'male'] or {}
        if #options > 0 then
            local label = cat.label and (cat.label[Config.Locale] or cat.label.en or cat.label.de) or cat.id
            list[#list + 1] = { id = cat.id, label = label, count = #options, optional = cat.optional == true }
        end
    end
    return list
end

local function loadModel(hash)
    if not IsModelValid(hash) then return false end
    RequestModel(hash, false)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return false end
        Wait(0)
    end
    return true
end

-- Setzt das Spielermodell und liefert den neuen Ped
function Appearance.SetGender(gender)
    local hash = MODELS[gender == 'female' and 'female' or 'male']
    if GetEntityModel(PlayerPedId()) ~= hash then
        if not loadModel(hash) then return PlayerPedId() end
        SetPlayerModel(PlayerId(), hash, false)
        SetModelAsNoLongerNeeded(hash)
    end
    local ped = PlayerPedId()
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)   -- Grundausstattung setzen (sonst bleibt die Figur unsichtbar)
    return ped
end

local function categoryById(id)
    for _, cat in ipairs(Catalog.categories) do
        if cat.id == id then return cat end
    end
end

-- appearance = { scale = 1.0, parts = { [kategorieId] = optionIndex } }; index 0 = "keine" bei optionalen Kategorien
function Appearance.Apply(ped, gender, appearance)
    if not appearance then return end

    local scale = tonumber(appearance.scale)
    if scale then SetPedScale(ped, scale) end

    local touched = false
    for id, index in pairs(appearance.parts or {}) do
        local cat = categoryById(id)
        if cat then
            local options = cat[gender == 'female' and 'female' or 'male'] or {}
            if cat.tag then Citizen.InvokeNative(0xD710A5007C2AC539, ped, cat.tag, 0) end   -- Kategorie leeren
            local hash = options[index]
            if hash then
                Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, hash, true, true, false)      -- Teil anlegen
            end
            touched = true
        end
    end
    if touched then
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)       -- Ped aktualisieren
    end
end

-- Hoehe in der Oberflaeche -> Scale
function Appearance.ClampScale(value)
    local h = Catalog.height
    return math.max(h.min, math.min(h.max, tonumber(value) or h.default))
end
