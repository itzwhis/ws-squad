local RSGCore = exports['rsg-core']:GetCoreObject()

local Squads   = {}   -- [id] = { id, name, code, leader, members = { [src] = {src,name,citizenid} } }
local PlayerSquad = {} -- [src] = squadId
local Invites  = {}   -- [targetSrc] = { squadId, from, expires }
local Stats    = {}   -- [src] = { health, maxHealth, dead, x, y, z }
local nextId   = 1

local function notify(src, msg, typ)
    TriggerClientEvent('ox_lib:notify', src, { title = _L('notify_title'), description = msg, type = typ or 'inform', duration = 5000 })
end

local function charName(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player and Player.PlayerData and Player.PlayerData.charinfo then
        local c = Player.PlayerData.charinfo
        return (c.firstname or '') .. ' ' .. (c.lastname or ''), Player.PlayerData.citizenid
    end
    return GetPlayerName(src) or ('#' .. src), nil
end

local function countMembers(sq)
    local n = 0
    for _ in pairs(sq.members) do n = n + 1 end
    return n
end

local function publicList()
    local list = {}
    for id, sq in pairs(Squads) do
        local leader = sq.members[sq.leader]
        list[#list + 1] = {
            id = id, name = sq.name,
            leader = leader and leader.name or '?',
            count = countMembers(sq), max = sq.max,
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

local function squadPayload(sq)
    local members = {}
    for src, m in pairs(sq.members) do
        members[#members + 1] = { src = src, name = m.name, leader = (src == sq.leader) }
    end
    table.sort(members, function(a, b)
        if a.leader ~= b.leader then return a.leader end
        return a.src < b.src
    end)
    return { id = sq.id, name = sq.name, leader = sq.leader, members = members, max = sq.max }
end

local function broadcastList()
    TriggerClientEvent('ws-squad:client:squadList', -1, publicList())
end

local function syncSquad(id)
    local sq = Squads[id]
    if not sq then return end
    local payload = squadPayload(sq)
    for src in pairs(sq.members) do
        TriggerClientEvent('ws-squad:client:setSquad', src, payload)
    end
end

local function validStr(s, min, max)
    if type(s) ~= 'string' then return false end
    s = s:gsub('^%s+', ''):gsub('%s+$', '')
    local len = utf8.len(s) or #s
    return len >= min and len <= max, s
end

local function who(src)
    local name, cid = charName(src)
    return WebhookWho(src, cid, name)
end

local function addMember(src, id)
    local sq = Squads[id]
    local name, cid = charName(src)
    sq.members[src] = { src = src, name = name, citizenid = cid }
    PlayerSquad[src] = id
    Invites[src] = nil
    for other in pairs(sq.members) do
        if other ~= src then notify(other, _L('member_joined', name), 'success') end
    end
    syncSquad(id)
    broadcastList()
end

local function removeMember(src, reason)
    local id = PlayerSquad[src]
    if not id then return end
    local sq = Squads[id]
    PlayerSquad[src] = nil
    Stats[src] = nil
    if not sq then return end
    local name = sq.members[src] and sq.members[src].name or ('#' .. src)
    sq.members[src] = nil
    if GetPlayerName(src) then TriggerClientEvent('ws-squad:client:setSquad', src, nil) end

    if countMembers(sq) == 0 then
        Squads[id] = nil
    else
        if sq.leader == src then
            local newLeader
            for s in pairs(sq.members) do if not newLeader or s < newLeader then newLeader = s end end
            sq.leader = newLeader
        end
        for other in pairs(sq.members) do notify(other, _L('member_left', name), 'warning') end
        syncSquad(id)
    end
    broadcastList()
end

local function disband(id, byWho)
    local sq = Squads[id]
    if not sq then return end
    SendLog('disband', 'Squad disbanded', {
        { 'Squad', sq.name }, { 'Members', countMembers(sq) }, { 'Leader', byWho or '?', false },
    })
    for src in pairs(sq.members) do
        PlayerSquad[src] = nil
        Stats[src] = nil
        TriggerClientEvent('ws-squad:client:setSquad', src, nil)
        if src ~= sq.leader then notify(src, _L('squad_disbanded'), 'error') end
    end
    for t, inv in pairs(Invites) do if inv.squadId == id then Invites[t] = nil end end
    Squads[id] = nil
    broadcastList()
end

-- ===== Events =====
RegisterNetEvent('ws-squad:server:requestData', function()
    local src = source
    TriggerClientEvent('ws-squad:client:squadList', src, publicList())
    local id = PlayerSquad[src]
    TriggerClientEvent('ws-squad:client:setSquad', src, id and Squads[id] and squadPayload(Squads[id]) or nil)
    local inv = Invites[src]
    if inv and inv.expires > os.time() and Squads[inv.squadId] then
        TriggerClientEvent('ws-squad:client:invite', src, { squadId = inv.squadId, name = Squads[inv.squadId].name, from = inv.fromName })
    else
        TriggerClientEvent('ws-squad:client:invite', src, nil)
    end
end)

RegisterNetEvent('ws-squad:server:create', function(data)
    local src = source
    if PlayerSquad[src] then return notify(src, _L('already_in'), 'error') end
    if type(data) ~= 'table' then return end
    local okN, name = validStr(data.name, Config.MinNameLength, Config.MaxNameLength)
    if not okN then return notify(src, _L('invalid_name'), 'error') end
    local okC, code = validStr(data.code, Config.MinCodeLength, Config.MaxCodeLength)
    if not okC then return notify(src, _L('invalid_code'), 'error') end
    local maxMembers = math.floor(tonumber(data.max) or Config.DefaultMaxMembers)
    if maxMembers < 1 or maxMembers > Config.MaxMembersLimit then
        return notify(src, _L('invalid_max', Config.MaxMembersLimit), 'error')
    end
    for _, sq in pairs(Squads) do
        if sq.name:lower() == name:lower() then return notify(src, _L('name_taken'), 'error') end
    end
    local id = nextId; nextId = nextId + 1
    Squads[id] = { id = id, name = name, code = code, max = maxMembers, leader = src, members = {} }
    addMember(src, id)
    notify(src, _L('squad_created'), 'success')
    SendLog('create', 'Squad created', { { 'Squad', name }, { 'Max members', maxMembers }, { 'Leader', who(src), false } })
end)

RegisterNetEvent('ws-squad:server:join', function(data)
    local src = source
    if PlayerSquad[src] then return notify(src, _L('already_in'), 'error') end
    if type(data) ~= 'table' then return end
    local id = tonumber(data.id)
    local sq = id and Squads[id]
    if not sq then return end
    if tostring(data.code or '') ~= sq.code then
        SendLog('wrongcode', 'Wrong pass code', { { 'Squad', sq.name }, { 'Player', who(src), false } })
        return notify(src, _L('wrong_code'), 'error')
    end
    if countMembers(sq) >= sq.max then return notify(src, _L('squad_full'), 'error') end
    addMember(src, id)
    notify(src, _L('squad_joined'), 'success')
    SendLog('join', 'Player joined squad', { { 'Squad', sq.name }, { 'Via', 'Pass code' }, { 'Player', who(src), false } })
end)

RegisterNetEvent('ws-squad:server:invite', function(target)
    local src = source
    target = tonumber(target)
    local id = PlayerSquad[src]
    if not id then return notify(src, _L('not_in_squad'), 'error') end
    local sq = Squads[id]
    if sq.leader ~= src then return notify(src, _L('not_leader'), 'error') end
    if not target or not GetPlayerName(target) then return notify(src, _L('player_offline'), 'error') end
    if target == src then return notify(src, _L('cannot_self'), 'error') end
    if PlayerSquad[target] then return notify(src, _L('target_in_squad'), 'error') end
    if countMembers(sq) >= sq.max then return notify(src, _L('squad_full'), 'error') end
    local fromName = charName(src)
    Invites[target] = { squadId = id, from = src, fromName = fromName, expires = os.time() + Config.InviteTimeout }
    notify(src, _L('invite_sent'), 'success')
    notify(target, _L('invite_received', sq.name), 'inform')
    SendLog('invite', 'Player invited', { { 'Squad', sq.name }, { 'Leader', who(src), false }, { 'Invited', who(target), false } })
    TriggerClientEvent('ws-squad:client:invite', target, { squadId = id, name = sq.name, from = fromName })
end)

RegisterNetEvent('ws-squad:server:acceptInvite', function()
    local src = source
    local inv = Invites[src]
    if not inv or inv.expires < os.time() or not Squads[inv.squadId] then
        Invites[src] = nil
        TriggerClientEvent('ws-squad:client:invite', src, nil)
        return notify(src, _L('no_invite'), 'error')
    end
    if PlayerSquad[src] then return notify(src, _L('already_in'), 'error') end
    if countMembers(Squads[inv.squadId]) >= Squads[inv.squadId].max then return notify(src, _L('squad_full'), 'error') end
    addMember(src, inv.squadId)
    SendLog('join', 'Player joined squad', { { 'Squad', Squads[inv.squadId].name }, { 'Via', 'Invite' }, { 'Player', who(src), false } })
    TriggerClientEvent('ws-squad:client:invite', src, nil)
    notify(src, _L('squad_joined'), 'success')
end)

RegisterNetEvent('ws-squad:server:declineInvite', function()
    local src = source
    Invites[src] = nil
    TriggerClientEvent('ws-squad:client:invite', src, nil)
end)

RegisterNetEvent('ws-squad:server:leave', function()
    local src = source
    local id = PlayerSquad[src]
    if not id or not Squads[id] then return notify(src, _L('not_in_squad'), 'error') end
    if Squads[id].leader == src then
        disband(id, who(src))  -- leader leaving = squad is deleted
    else
        SendLog('leave', 'Player left squad', { { 'Squad', Squads[id].name }, { 'Player', who(src), false } })
        removeMember(src)
    end
    notify(src, _L('squad_left'), 'inform')
end)

RegisterNetEvent('ws-squad:server:kick', function(target)
    local src = source
    target = tonumber(target)
    local id = PlayerSquad[src]
    if not id or Squads[id].leader ~= src then return notify(src, _L('not_leader'), 'error') end
    if not target or target == src or PlayerSquad[target] ~= id then return end
    SendLog('kick', 'Player kicked', { { 'Squad', Squads[id].name }, { 'Leader', who(src), false }, { 'Kicked', who(target), false } })
    removeMember(target)
    notify(target, _L('kicked'), 'error')
end)

RegisterNetEvent('ws-squad:server:changeCode', function(newCode)
    local src = source
    local id = PlayerSquad[src]
    if not id or not Squads[id] or Squads[id].leader ~= src then return notify(src, _L('not_leader'), 'error') end
    local ok, code = validStr(newCode, Config.MinCodeLength, Config.MaxCodeLength)
    if not ok then return notify(src, _L('invalid_code'), 'error') end
    Squads[id].code = code
    notify(src, _L('code_changed'), 'success')
    SendLog('changecode', 'Pass code changed', { { 'Squad', Squads[id].name }, { 'Leader', who(src), false } })
end)

-- Client reports own vitals/position; server relays to squadmates
RegisterNetEvent('ws-squad:server:report', function(d)
    local src = source
    if not PlayerSquad[src] or type(d) ~= 'table' then return end
    Stats[src] = {
        health = tonumber(d.health) or 0, maxHealth = tonumber(d.maxHealth) or 100,
        dead = d.dead == true, x = tonumber(d.x) or 0.0, y = tonumber(d.y) or 0.0, z = tonumber(d.z) or 0.0,
    }
end)

CreateThread(function()
    while true do
        Wait(Config.SyncInterval)
        for id, sq in pairs(Squads) do
            local data = {}
            for src in pairs(sq.members) do
                local s = Stats[src]
                if s then data[tostring(src)] = s end
            end
            for src in pairs(sq.members) do
                TriggerClientEvent('ws-squad:client:stats', src, data)
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    Invites[src] = nil
    if PlayerSquad[src] then removeMember(src) end
end)

RegisterNetEvent('RSGCore:Server:OnPlayerUnload', function(src)
    src = src or source
    if PlayerSquad[src] then removeMember(src) end
end)
