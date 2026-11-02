local mySquad    = nil    -- { id, name, leader, members = { {src,name,leader} }, max }
local squadList  = {}
local pendingInvite = nil
local memberStats = {}    -- [src] = { health, maxHealth, dead, x, y, z }
local blips      = {}     -- [src] = blip
local menuOpen   = false
local relGroup   = nil
local myServerId = GetPlayerServerId(PlayerId())

-- ===== Helpers =====
local function inSquad() return mySquad ~= nil end

local function sendNui(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function refreshMenu()
    sendNui('menu', {
        list = squadList, squad = mySquad, invite = pendingInvite,
        me = myServerId, open = menuOpen,
        maxLimit = Config.MaxMembersLimit, defaultMax = Config.DefaultMaxMembers,
        locale = GetNuiLocale(),
    })
end

local function removeBlip(src)
    if blips[src] and DoesBlipExist(blips[src]) then RemoveBlip(blips[src]) end
    blips[src] = nil
end

local function clearBlips()
    for src in pairs(blips) do removeBlip(src) end
end

local function createRedBlip(src, name, coords)
    local blip = Citizen.InvokeNative(0x554D9D53F696D002, Config.BlipStyle, coords.x, coords.y, coords.z) -- BlipAddForCoords
    SetBlipSprite(blip, Config.BlipSprite, true)
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, name)                         -- SetBlipName
    Citizen.InvokeNative(0x662D364ABF16DE2F, blip, Config.BlipColor)             -- BlipAddModifier (RED)
    SetBlipScale(blip, 0.8)
    blips[src] = blip
    return blip
end

-- ===== Friendly fire (relationship group) =====
local function applyRelationship()
    if Config.FriendlyFire or not mySquad then return end
    if not relGroup then
        local _, hash = AddRelationshipGroup(('ws_squad_%s'):format(mySquad.id))
        relGroup = hash
        SetRelationshipBetweenGroups(0, relGroup, relGroup) -- companion
    end
    local ped = PlayerPedId()
    if GetPedRelationshipGroupHash(ped) ~= relGroup then
        SetPedRelationshipGroupHash(ped, relGroup)
    end
    SetEntityCanBeDamagedByRelationshipGroup(ped, false, relGroup)
end

local function clearRelationship()
    if not relGroup then return end
    local ped = PlayerPedId()
    SetEntityCanBeDamagedByRelationshipGroup(ped, true, relGroup)
    SetPedRelationshipGroupHash(ped, `PLAYER`)
    RemoveRelationshipGroup(relGroup)
    relGroup = nil
end

-- ===== NUI focus =====
local function openMenu()
    menuOpen = true
    SetNuiFocus(true, true)
    TriggerServerEvent('ws-squad:server:requestData')
    refreshMenu()
end

local function closeMenu()
    menuOpen = false
    SetNuiFocus(false, false)
    sendNui('close')
end

RegisterCommand(Config.MenuCommand, function()
    if menuOpen then closeMenu() else openMenu() end
end, false)

-- ===== Server -> Client =====
RegisterNetEvent('ws-squad:client:squadList', function(list)
    squadList = list or {}
    if menuOpen then refreshMenu() end
end)

RegisterNetEvent('ws-squad:client:invite', function(inv)
    pendingInvite = inv
    if menuOpen then refreshMenu() end
end)

RegisterNetEvent('ws-squad:client:setSquad', function(sq)
    local hadSquad = mySquad ~= nil
    local oldId = mySquad and mySquad.id
    mySquad = sq
    if not sq then
        clearBlips()
        clearRelationship()
        memberStats = {}
        sendNui('hud', { show = false })
    else
        if oldId and oldId ~= sq.id then clearRelationship() end
        -- drop blips of players no longer in squad
        local valid = {}
        for _, m in ipairs(sq.members) do valid[m.src] = true end
        for src in pairs(blips) do if not valid[src] then removeBlip(src) end end
        for src in pairs(memberStats) do if not valid[src] then memberStats[src] = nil end end
        applyRelationship()
        sendNui('locale', GetNuiLocale())   -- HUD strings (e.g. DEAD) before the menu is ever opened
    end
    if menuOpen then refreshMenu() end
end)

RegisterNetEvent('ws-squad:client:stats', function(data)
    if not mySquad then return end
    for k, v in pairs(data or {}) do memberStats[tonumber(k)] = v end
end)

-- ===== NUI callbacks =====
RegisterNUICallback('close', function(_, cb) closeMenu(); cb('ok') end)
RegisterNUICallback('create', function(d, cb) TriggerServerEvent('ws-squad:server:create', d); cb('ok') end)
RegisterNUICallback('join', function(d, cb) TriggerServerEvent('ws-squad:server:join', d); cb('ok') end)
RegisterNUICallback('invite', function(d, cb) TriggerServerEvent('ws-squad:server:invite', d and d.id); cb('ok') end)
RegisterNUICallback('acceptInvite', function(_, cb) TriggerServerEvent('ws-squad:server:acceptInvite'); cb('ok') end)
RegisterNUICallback('declineInvite', function(_, cb) TriggerServerEvent('ws-squad:server:declineInvite'); cb('ok') end)
RegisterNUICallback('leave', function(_, cb) TriggerServerEvent('ws-squad:server:leave'); cb('ok') end)
RegisterNUICallback('kick', function(d, cb) TriggerServerEvent('ws-squad:server:kick', d and d.id); cb('ok') end)
RegisterNUICallback('changeCode', function(d, cb) TriggerServerEvent('ws-squad:server:changeCode', d and d.code); cb('ok') end)

-- ===== Self report loop =====
CreateThread(function()
    while true do
        if mySquad then
            local ped = PlayerPedId()
            local c = GetEntityCoords(ped)
            TriggerServerEvent('ws-squad:server:report', {
                health = GetEntityHealth(ped),
                maxHealth = GetEntityMaxHealth(ped),
                dead = IsEntityDead(ped) or IsPedDeadOrDying(ped, true),
                x = c.x, y = c.y, z = c.z,
            })
            Wait(Config.SyncInterval)
        else
            Wait(1500)
        end
    end
end)

-- ===== HUD + blips loop (uses live local ped data when in scope) =====
CreateThread(function()
    while true do
        if mySquad then
            local hud = {}
            for _, m in ipairs(mySquad.members) do
                local s = memberStats[m.src] or {}
                local health, maxHealth, dead = s.health or 0, s.maxHealth or 100, s.dead or false
                local coords = s.x and vector3(s.x, s.y, s.z) or nil

                local player = GetPlayerFromServerId(m.src)
                if player ~= -1 then
                    local ped = GetPlayerPed(player)
                    if DoesEntityExist(ped) then
                        health = GetEntityHealth(ped)
                        maxHealth = GetEntityMaxHealth(ped)
                        dead = IsEntityDead(ped) or IsPedDeadOrDying(ped, true)
                        coords = GetEntityCoords(ped)
                    end
                end

                local pct = 0
                if maxHealth and maxHealth > 0 then pct = math.floor(math.max(0, math.min(1, health / maxHealth)) * 100) end
                if dead then pct = 0 end
                hud[#hud + 1] = { src = m.src, name = m.name, leader = m.leader, health = pct, dead = dead, me = (m.src == myServerId) }

                -- blips for others only
                if Config.MemberBlips and m.src ~= myServerId and coords then
                    local blip = blips[m.src]
                    if not blip or not DoesBlipExist(blip) then
                        createRedBlip(m.src, m.name, coords)
                    else
                        SetBlipCoords(blip, coords.x, coords.y, coords.z)
                    end
                end
            end
            sendNui('hud', { show = true, name = mySquad.name, members = hud })
            applyRelationship()
            Wait(250)
        else
            Wait(1000)
        end
    end
end)

-- ===== Overhead RED name tags =====
local function drawText3D(x, y, z, text, dist)
    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(x, y, z)
    if not onScreen then return end
    local scale = math.max(0.22, 0.42 - (dist / Config.NameTagDistance) * 0.2)
    SetTextScale(scale, scale)
    SetTextColor(Config.TagColor.r, Config.TagColor.g, Config.TagColor.b, Config.TagColor.a)
    SetTextCentre(true)
    SetTextDropshadow(2, 0, 0, 0, 255)
    Citizen.InvokeNative(0xADA9255D, 1) -- SetTextFontForCurrentCommand
    DisplayText(CreateVarString(10, 'LITERAL_STRING', text), sx, sy)
end

CreateThread(function()
    while true do
        local sleep = 1000
        if mySquad and Config.NameTags then
            local myPed = PlayerPedId()
            local myCoords = GetEntityCoords(myPed)
            for _, m in ipairs(mySquad.members) do
                if m.src ~= myServerId then
                    local player = GetPlayerFromServerId(m.src)
                    if player ~= -1 then
                        local ped = GetPlayerPed(player)
                        if DoesEntityExist(ped) then
                            local c = GetEntityCoords(ped)
                            local dist = #(myCoords - c)
                            if dist <= Config.NameTagDistance and IsEntityOnScreen(ped) then
                                sleep = 0
                                local label = m.name
                                if IsEntityDead(ped) then label = '✝ ' .. label end
                                drawText3D(c.x, c.y, c.z + 1.15, label, dist)
                            end
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- ===== Lifecycle =====
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    myServerId = GetPlayerServerId(PlayerId())
    TriggerServerEvent('ws-squad:server:requestData')
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    mySquad = nil
    clearBlips()
    clearRelationship()
    sendNui('hud', { show = false })
end)

CreateThread(function()
    Wait(2000)
    myServerId = GetPlayerServerId(PlayerId())
    TriggerServerEvent('ws-squad:server:requestData')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearBlips()
    clearRelationship()
    SetNuiFocus(false, false)
end)
