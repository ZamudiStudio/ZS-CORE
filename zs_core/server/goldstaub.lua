-- Goldstaub: Premiumwaehrung mit eigener Speicherung, unabhaengig vom Gold des Charakters.
-- Abschaltbar ueber Config.Goldstaub.enabled; Ein-/Auszahlung braucht zs_inventory.

if not Config.Goldstaub.enabled then return end

CreateThread(function()
    ZS.WaitForDatabase()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS zs_goldstaub (
            char_id INT NOT NULL,
            balance BIGINT NOT NULL DEFAULT 0,
            PRIMARY KEY (char_id)
        )
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS zs_goldstaub_log (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            char_id INT NOT NULL,
            delta BIGINT NOT NULL,
            balance_after BIGINT NOT NULL,
            reason VARCHAR(100) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            KEY idx_char (char_id)
        )
    ]])
end)

local function getCharId(src)
    local entry = ZS.players[tonumber(src)]
    return entry and entry.char and entry.char.id or nil
end

local function isValidAmount(amount)
    return type(amount) == 'number' and amount > 0 and amount == math.floor(amount)
end

local function getBalance(charId)
    return MySQL.scalar.await('SELECT balance FROM zs_goldstaub WHERE char_id = ?', { charId }) or 0
end

local function writeLog(charId, delta, reason)
    MySQL.insert.await(
        'INSERT INTO zs_goldstaub_log (char_id, delta, balance_after, reason) VALUES (?, ?, ?, ?)',
        { charId, delta, getBalance(charId), reason }
    )
end

local function addGoldstaub(charId, amount, reason)
    if not charId or not isValidAmount(amount) then return false end
    MySQL.update.await(
        'INSERT INTO zs_goldstaub (char_id, balance) VALUES (?, ?) ON DUPLICATE KEY UPDATE balance = balance + VALUES(balance)',
        { charId, amount }
    )
    writeLog(charId, amount, reason or 'add')
    return true
end

-- Atomar: zieht nur ab, wenn genug Guthaben da ist
local function removeGoldstaub(charId, amount, reason)
    if not charId or not isValidAmount(amount) then return false end
    local affected = MySQL.update.await(
        'UPDATE zs_goldstaub SET balance = balance - ? WHERE char_id = ? AND balance >= ?',
        { amount, charId, amount }
    )
    if not affected or affected == 0 then return false end
    writeLog(charId, -amount, reason or 'remove')
    return true
end

exports('GetGoldstaub', getBalance)
exports('AddGoldstaub', addGoldstaub)
exports('RemoveGoldstaub', removeGoldstaub)

-- Guthaben -> Inventar
local function withdraw(src, amount)
    local charId = getCharId(src)
    if not charId or not isValidAmount(amount) or amount > Config.Goldstaub.maxPerTransfer then return false, 'invalid' end

    -- Direkt zs_inventory ansprechen und mit Rueckgabewerten arbeiten (keine Callbacks ueber Ressourcen-Grenzen)
    local canCarry = exports.zs_inventory:canCarryItem(src, Config.Goldstaub.item, amount)
    if not canCarry then return false, 'no_space' end

    if not removeGoldstaub(charId, amount, 'withdraw') then return false, 'no_balance' end

    local added = exports.zs_inventory:addItem(src, Config.Goldstaub.item, amount, {})
    if not added then
        addGoldstaub(charId, amount, 'withdraw_refund')
        return false, 'inventory_failed'
    end
    return true
end

-- Inventar -> Guthaben
local function deposit(src, amount)
    local charId = getCharId(src)
    if not charId or not isValidAmount(amount) or amount > Config.Goldstaub.maxPerTransfer then return false, 'invalid' end

    local count = exports.zs_inventory:getItemCount(src, nil, Config.Goldstaub.item) or 0
    if count < amount then return false, 'not_enough_items' end

    local removed = exports.zs_inventory:subItem(src, Config.Goldstaub.item, amount, {})
    if not removed then return false, 'inventory_failed' end

    addGoldstaub(charId, amount, 'deposit')
    return true
end

-- Callbacks fuer das spaetere Dashboard (NUI)
ZS.RegisterCallback('zs_core:goldstaub:get', function(src)
    local charId = getCharId(src)
    return charId and getBalance(charId) or 0
end)

ZS.RegisterCallback('zs_core:goldstaub:withdraw', function(src, amount)
    local ok, err = withdraw(src, tonumber(amount))
    return { ok = ok, error = err, balance = getBalance(getCharId(src) or 0) }
end)

ZS.RegisterCallback('zs_core:goldstaub:deposit', function(src, amount)
    local ok, err = deposit(src, tonumber(amount))
    return { ok = ok, error = err, balance = getBalance(getCharId(src) or 0) }
end)

-- Testbefehle (Dashboard folgt)
RegisterCommand('goldstaub', function(src)
    if src == 0 then return end
    local charId = getCharId(src)
    if not charId then return end
    local text = ('Goldstaub: %d'):format(getBalance(charId))
    ZS.Notify(src, text, { title = 'Goldstaub' })
end, false)

-- Nur Konsole/Admin: addgoldstaub <UID> <Menge>
-- Berechtigung per ACE: add_ace group.admin command.addgoldstaub allow
RegisterCommand('addgoldstaub', function(src, args)
    local target = exports.zs_core:GetSourceByUid(args[1])
    local amount = tonumber(args[2])
    local charId = target and getCharId(target)
    if not charId or not isValidAmount(amount) then
        print('[zs_core] Nutzung: addgoldstaub <UID> <Menge>')
        return
    end
    addGoldstaub(charId, amount, ('admin:%s'):format(src == 0 and 'console' or tostring(src)))
    print(('[zs_core] %d Goldstaub an UID %s vergeben'):format(amount, args[1]))
end, true)

-- Fuer das Dashboard: Guthaben <-> Inventar. Beide geben (ok, fehler) zurueck.
exports('GoldstaubWithdraw', function(src, amount) return withdraw(src, tonumber(amount)) end)
exports('GoldstaubDeposit', function(src, amount) return deposit(src, tonumber(amount)) end)
