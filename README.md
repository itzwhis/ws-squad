🚀 [New Release](#)



<p align="center">
  <b>ws-squadsystem </b><br>
<i>Elite PvP RedM scripts — dominate the frontier together.</i>
</p>

<p align="center">
  <a href="#"><img src="https://img.shields.io/badge/Discord-Join%20WS%20Scripts-5865F2?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
  <a href="#"><img src="https://img.shields.io/badge/framework-rsg--core-blue?style=flat-square" alt="Framework"></a>
  <a href="#"><img src="https://img.shields.io/badge/version-1.0.6-brightgreen?style=flat-square" alt="Version"></a>
  <a href="#"><img src="https://img.shields.io/badge/Lua-5.4-black?style=flat-square" alt="Lua"></a>
</p>

Wild West squad system for **RSG Framework** (RedM) — created by WS Scripts.

Players create password-protected squads, invite friends, see each other's health on a HUD, get red map blips and overhead name tags, and (optionally) can't hurt each other.

> Wild West squad system for **RSG Framework** (RedM) — created by **WS Scripts**.

---

## Features

- Create / join / leave squads with a secret pass code
- Leader tools: invite players by ID, kick members, change the pass code
- Leader leaving disbands the squad
- Live squad HUD with health bars
- Red member blips and overhead name tags
- Friendly-fire protection between squad members
- **Discord webhook logs** (create, join, invite, leave, disband, kick, code change)
- **Multi-language: English, Português, Русский** (selected in config)

---

## Requirements

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [ox_lib](https://github.com/overextended/ox_lib)

---

## Installation

1. Drop the `ws-squad` folder into your `resources` directory.
​2. Add to `server.cfg` (after `rsg-core` and `ox_lib`):
   ```cfg
   ensure ws-squad
