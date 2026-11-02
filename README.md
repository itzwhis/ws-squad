# ws-squad

Wild West squad system for **RSG Framework** (RedM) — created by WS Scripts.

Players create password-protected squads, invite friends, see each other's health on a HUD, get red map blips and overhead name tags, and (optionally) can't hurt each other.

## Features

- Create / join / leave squads with a secret pass code
- Leader tools: invite players by ID, kick members, change the pass code
- Leader leaving disbands the squad
- Live squad HUD with health bars
- Red member blips and overhead name tags
- Friendly-fire protection between squad members
- **Discord webhook logs** (create, join, invite, leave, disband, kick, code change)
- **Multi-language: English, Português, Русский** (selected in config)

## Requirements

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [ox_lib](https://github.com/overextended/ox_lib)

## Installation

1. Drop the `ws-squad` folder into your `resources` directory.
2. Add to `server.cfg` (after `rsg-core` and `ox_lib`):
   ```cfg
   ensure ws-squad
   ```
3. Restart the server.

## Language

Open `shared/config.lua` — it's the first line:

```lua
Locales = 'en'   -- 'en' | 'pt' | 'ru'
```

| Code | Language   |
|------|------------|
| `en` | English    |
| `pt` | Português  |
| `ru` | Русский    |

This translates everything: notifications, the menu, and the HUD. If a key is missing from a language, it falls back to English. Restart the resource (`restart ws-squad`) after changing it.

### Adding another language

1. Copy `locales/en.lua` to `locales/<code>.lua` (e.g. `locales/es.lua`).
2. Change `Lang['en']` to `Lang['<code>']` and translate the values (keep `%s` / `%d` placeholders).
3. Add `'locales/<code>.lua'` to `shared_scripts` in `fxmanifest.lua`.
4. Set `Locales = '<code>'`.

> Note: the UI font *Rye* has no Cyrillic glyphs, so Russian headings automatically fall back to *Lora*.

## Configuration

All options are in `shared/config.lua`:

| Option | Default | Description |
|---|---|---|
| `Locales` | `'en'` | UI/notification language |
| `Config.MenuCommand` | `'squad'` | Chat command that opens the menu |
| `Config.MaxMembersLimit` | `10` | Hard cap a leader can choose |
| `Config.DefaultMaxMembers` | `6` | Pre-filled value in the create form |
| `Config.MinNameLength` / `MaxNameLength` | `3` / `20` | Squad name length |
| `Config.MinCodeLength` / `MaxCodeLength` | `3` / `12` | Pass code length |
| `Config.InviteTimeout` | `60` | Seconds an invite stays valid |
| `Config.FriendlyFire` | `false` | `false` = squadmates can't damage each other |
| `Config.MemberBlips` | `true` | Show squadmate blips |
| `Config.NameTags` | `true` | Show overhead name tags |
| `Config.NameTagDistance` | `150.0` | Name tag range (metres) |
| `Config.SyncInterval` | `1000` | ms between health/position reports |
| `Config.BlipSprite/Style/Color`, `Config.TagColor` | red | Blip and tag appearance |

## Webhook logs

Edit `WebhookConfig` at the bottom of `shared/config.lua` (the sender code is in `server/webhook.lua`).

> **Note:** `shared/config.lua` is downloaded by clients, so a determined player could read the webhook URL. Don't leak the resource, and rotate the webhook if it is ever abused.

```lua
WebhookConfig = {
    Enabled = true,
    URL     = 'https://discord.com/api/webhooks/...',
    Events  = { create = true, join = true, invite = true, leave = true,
                disband = true, kick = true, changecode = true, wrongcode = false },
}
```

Each log shows the squad plus player name, server ID, CitizenID, license and Discord. Pass codes are never logged. Set `Events.<name> = false` to silence a log type.

## Usage

- `/squad` — open/close the menu (also closes with `ESC`)
- Click a squad to join it (enter its pass code), or **+ Create Squad**
- Leaders: **Invite Player**, **Change Pass Code**, click a member to kick
- Invited players see an Accept / Decline banner in the menu

## File structure

```
ws-squad/
├── fxmanifest.lua
├── shared/config.lua      # settings + language (`Locales = 'en'`)
├── shared/locale.lua      # translation engine
├── locales/               # en.lua, pt.lua, ru.lua
├── client/main.lua
├── server/main.lua
├── server/webhook.lua     # webhook sender (settings are in shared/config.lua)
└── nui/                   # index.html, style.css, script.js, logo.png
```

## Credits

Created by WS Scripts.
