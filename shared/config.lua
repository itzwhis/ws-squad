-- Language: 'en' (English) | 'pt' (Português) | 'ru' (Русский)
Locales = 'en'

Config = {}

Config.MenuCommand    = 'squad'
Config.MaxMembersLimit   = 10     -- hard cap a leader can choose
Config.DefaultMaxMembers = 6      -- pre-filled value in the create form
Config.MinNameLength  = 3
Config.MaxNameLength  = 20
Config.MinCodeLength  = 3
Config.MaxCodeLength  = 12
Config.InviteTimeout  = 60        -- seconds an invite stays valid

Config.FriendlyFire   = false     -- false = squad members cannot damage each other
Config.MemberBlips    = true
Config.NameTags       = true
Config.NameTagDistance = 150.0    -- metres
Config.SyncInterval   = 1000      -- ms between health/position reports

-- Red blip modifier (RedM blip colour modifiers are hashes)
Config.BlipSprite     = `blip_ambient_companion`
Config.BlipStyle      = 1664425300            -- BLIP_STYLE_ENEMY-like small marker
Config.BlipColor      = `BLIP_MODIFIER_MP_COLOR_8` -- RED
Config.TagColor       = { r = 220, g = 30, b = 30, a = 255 } -- RED overhead tags

-- ===== Discord webhook logs =====
-- WARNING: this file is shared, so clients can download it. Anyone who reads
-- the URL below could spam your webhook. Keep the resource private / consider
-- a webhook proxy if that matters to you.
WebhookConfig = {
    Enabled = true,
    URL     = '',                              -- paste your Discord webhook URL here
    BotName = 'WS Squad Logs',
    Avatar  = '',                              -- optional image URL
    Footer  = 'ws-squad | WS Scripts',

    -- turn individual log types on/off
    Events = {
        create     = true,   -- squad created
        join       = true,   -- player joined (code or invite)
        invite     = true,   -- leader invited a player
        leave      = true,   -- member left
        disband    = true,   -- leader left / squad deleted
        kick       = true,   -- member kicked
        changecode = true,   -- pass code changed (code itself is NOT logged)
        wrongcode  = false,  -- failed join attempt (can be spammy)
    },

    Colors = {                                 -- embed colours (decimal)
        create = 3066993, join = 3447003, invite = 10181046, leave = 15105570,
        disband = 15158332, kick = 15158332, changecode = 16776960, wrongcode = 9807270,
    },
}
