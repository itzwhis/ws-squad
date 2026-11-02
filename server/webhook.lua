-- ws-squad webhook sender. Settings live in shared/config.lua (WebhookConfig).
-- Pass codes are never logged.

local function identifier(src, kind)
    local id = GetPlayerIdentifierByType and GetPlayerIdentifierByType(src, kind)
    if not id then return 'n/a' end
    return id:gsub('^%w+:', '')
end

-- Build a "who" string for a player
function WebhookWho(src, citizenid, name)
    local discord = identifier(src, 'discord')
    return ('**%s**\nID: `%s`\nCitizenID: `%s`\nLicense: `%s`%s'):format(
        name or GetPlayerName(src) or 'unknown', tostring(src), citizenid or 'n/a', identifier(src, 'license'),
        discord ~= 'n/a' and ('\nDiscord: <@%s>'):format(discord) or '')
end

-- SendLog('kick', 'Member kicked', { { 'Squad', 'Alpha' }, { 'Leader', whoString, false } })
function SendLog(event, title, fields)
    local cfg = WebhookConfig
    if not cfg.Enabled or not cfg.URL or cfg.URL == '' then return end
    if cfg.Events[event] == false or cfg.Events[event] == nil then return end

    local embedFields = {}
    for _, f in ipairs(fields or {}) do
        embedFields[#embedFields + 1] = { name = f[1], value = tostring(f[2]), inline = f[3] ~= false }
    end
    local payload = {
        username   = cfg.BotName,
        avatar_url = (cfg.Avatar ~= '' and cfg.Avatar) or nil,
        embeds = {{
            title = title, color = cfg.Colors[event] or 3447003, fields = embedFields,
            footer = { text = cfg.Footer }, timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        }},
    }
    PerformHttpRequest(cfg.URL, function() end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end
