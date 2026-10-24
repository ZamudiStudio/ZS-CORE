-- zs_core Client: meldet sich beim Server, stellt Callbacks und den Charakter-Zustand bereit.

local requests = {}
local nextRequestId = 0

-- Wartet auf die Antwort eines Server-Callbacks: local ok, result = exports.zs_core:TriggerCallback('name', ...)
local function triggerCallback(name, ...)
    nextRequestId = nextRequestId + 1
    local id = nextRequestId
    local p = promise.new()
    requests[id] = p
    TriggerServerEvent('zs_core:server:callback', name, id, ...)

    SetTimeout(15000, function()
        if requests[id] then
            requests[id] = nil
            p:resolve({ false, 'timeout' })
        end
    end)

    local reply = Citizen.Await(p)
    return table.unpack(reply, 1, reply.n or #reply)
end

RegisterNetEvent('zs_core:client:callbackResult', function(id, ...)
    local p = requests[id]
    if not p then return end
    requests[id] = nil
    p:resolve(table.pack(...))
end)

exports('TriggerCallback', triggerCallback)

-- Aktueller Charakter (nur die oeffentlichen Felder aus dem State Bag)
exports('GetLocalCharacter', function()
    return LocalPlayer.state['zs:char']
end)
exports('IsLoggedIn', function()
    return LocalPlayer.state['zs:char'] ~= nil
end)

RegisterNetEvent('zs_core:client:characterLoaded', function(snapshot)
    TriggerEvent('zs_core:characterLoaded', snapshot)
end)

-- Einfache Rueckfall-Meldung, wenn zs-notify nicht laeuft
RegisterNetEvent('zs_core:client:notify', function(text)
    TriggerEvent('chat:addMessage', { args = { text } })
end)

-- Sobald der Spieler wirklich im Spiel ist, dem Server Bescheid geben
CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    Wait(1000)
    TriggerServerEvent('zs_core:server:clientReady')
end)
