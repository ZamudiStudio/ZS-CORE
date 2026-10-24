-- Start-Banner in der txAdmin-Konsole (abschaltbar ueber Config.Banner)
if not Config.Banner then return end

local letters = {
    Z = {
        [[ /########]],
        [[|____  ## ]],
        [[     /##/ ]],
        [[    /##/  ]],
        [[   /##/   ]],
        [[  /##/    ]],
        [[ /########]],
        [[|________/]],
    },
    A = {
        [[  /###### ]],
        [[ /##__  ##]],
        [[| ##  | ##]],
        [[| ########]],
        [[| ##__  ##]],
        [[| ##  | ##]],
        [[| ##  | ##]],
        [[|__/  |__/]],
    },
    M = {
        [[ /##      /##]],
        [[| ###    /###]],
        [[| ####  /####]],
        [[| ## ##/## ##]],
        [[| ##  ###| ##]],
        [[| ##\  #| ##]],
        [[| ##     | ##]],
        [[|__/     |__/]],
    },
    U = {
        [[ /##   /##]],
        [[| ##  | ##]],
        [[| ##  | ##]],
        [[| ##  | ##]],
        [[| ##  | ##]],
        [[| ##  | ##]],
        [[|  ######/]],
        [[ \______/ ]],
    },
    D = {
        [[ /####### ]],
        [[| ##__  ##]],
        [[| ##  \ ##]],
        [[| ##  | ##]],
        [[| ##  | ##]],
        [[| ##  | ##]],
        [[| #######/]],
        [[|_______/ ]],
    },
    I = {
        [[ /######]],
        [[|_  ##_/]],
        [[  | ##  ]],
        [[  | ##  ]],
        [[  | ##  ]],
        [[  | ##  ]],
        [[ /######]],
        [[|______/]],
    },
}

local function render(word)
    local rows = {}
    for r = 1, 8 do
        local line = ''
        for c in word:gmatch('.') do
            local part = letters[c][r]
            line = line .. part .. string.rep(' ', #letters[c][1] - #part) .. ' '
        end
        rows[r] = line
    end
    return rows
end

-- Checker: laeuft verzoegert, damit die anderen Ressourcen schon gestartet sind
local function runChecks()
    local line = string.rep('#', 79)
    print('^3' .. line)
    print('^7ZAMUDI Resource Check')

    local ok, bad, total = 0, 0, 0
    local names = {}
    for i = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(i)
        if name and (name:sub(1, 3) == 'zs_' or name:sub(1, 3) == 'zs-') then
            names[#names + 1] = name
        end
    end
    table.sort(names)

    for _, name in ipairs(names) do
        total = total + 1
        local state = GetResourceState(name)
        local ver = GetResourceMetadata(name, 'version', 0) or '?'
        if state == 'started' then
            ok = ok + 1
            print(('^2Resource Check (%s) ✅ gestartet - Version %s^7'):format(name, ver))
        else
            bad = bad + 1
            print(('^1Resource Check (%s) ❌ Status: %s - Version %s^7'):format(name, state, ver))
        end
    end

    for _, dep in ipairs({ 'oxmysql' }) do
        if GetResourceState(dep) == 'started' then
            print(('^2Abhaengigkeit (%s) ✅ laeuft^7'):format(dep))
        else
            bad = bad + 1
            print(('^1Abhaengigkeit (%s) ❌ Status: %s^7'):format(dep, GetResourceState(dep)))
        end
    end

    local dbOk = pcall(function() return MySQL.scalar.await('SELECT 1') end)
    if dbOk then
        print('^2Datenbank ✅ Verbindung ok^7')
    else
        bad = bad + 1
        print('^1Datenbank ❌ keine Verbindung^7')
    end

    print(('^7%d/%d zs-Ressourcen gestartet, %d Problem(e)'):format(ok, total, bad))
    print('^3' .. line .. '^7')
end

CreateThread(function()
    Wait(10000)
    runChecks()
end)

CreateThread(function()
    Wait(500)
    local version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '?'
    local title = (' #RedM '):rep(1) .. '-- ZAMUDI STUDIO CORE v' .. version .. ' '
    print('^3----- ' .. title .. string.rep('-', 40))
    for _, line in ipairs(render('ZAMUDI')) do
        print('^3' .. line)
    end
    print('^3' .. string.rep('-', 70) .. '^7')
end)
