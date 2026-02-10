# Kyber Chat Filter Plugin

A robust, configurable chat moderation plugin for **Kyber dedicated servers**.
Designed to catch common word-filter bypasses, track player strikes, and automatically enforce mutes, kicks, and bans — all while remaining fully controllable at runtime by admins.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Plugin Structure](#plugin-file-structure)
- [Admin Configuration](#admin-configuration)
- [In-Game Moderation Commands](#in-game-moderation-commands-via-game-chat)
- [Admin Commands](#admin-commands-configuration-changes)
- [Configuration & Defaults](#configuration-options-in-lua)
- [Environment Variables](#environment-variable-list-for-docker)
- [Chat Moderation Flow](#chat-moderation-flow-diagram)
- [Bans, Performance & Safety](#bans-and-kicks)
- [Planned Future Features](#planned-future-features)


## Features

### Core Filtering

* Detects **banned words** from an editable list using:

  * Word-boundary matching (reduces false positives)
  * Obfuscation normalization (`@ → a`, `0 → o`, etc.)
  * Spaced / punctuated letter detection (`b a n`, `b-a-n`, `b_a_n`)
* Case-insensitive and punctuation-tolerant
* Blocks or allows messages based on configuration
* Chat messages filtered using **Lua pattern matching** (regex-like)

### Moderation & Enforcement

* Permanent or timed mutes supported
* **Strike tracking per player**
* Automatic actions when strike thresholds are reached:

  * Mute
  * Kick
  * Ban
* Admins are **exempt** from automated punishments


### Admin Control

* Includes in-game **admin chat commands** (no server restart required)
* Settings can be changed by environment variables passed into a Docker container
* Manual mute, unmute, and unban commands

### Logging

* Optional server-side logging (enabled by default)
* Optional host alerting via the Kyber client event log (work in progress)
* Debug logging enabled via environment variables

>### ⚠ Warning:
>
>The included word list file `filtered_word_list.lua` contains some **very offensive language and slurs** (necessary in order to match/filter them).  
>Please use caution when reviewing or editing the word list.



## Installation

1. Place the `ChatFilter.kbplugin` file in your Kyber plugins directory.
2. Restart the server or reload plugins.

Optional:

- Set environment variables for Docker deployments
- Modify default variables in `__init__.lua`
- Adjust thresholds in-game via admin commands

## Plugin File Structure
```
- ChatFilter.kbplugin/
    - plugin.json
    - common/
        - timer.lua
    - server/
        - __init__.lua
        - admins.lua
        - filtered_word_list.lua
```

## Admin Configuration

Admins have elevated permissions in the chat filter. They can:

* Use all admin chat commands
* Bypass automated mute / kick / ban enforcement
* Manually mute, unmute, and unban players

Admins are identified only by `playerId`, not by player name.

## Defining Admins (Required)

### `admins.lua` (Primary Admin List)

This is the main and recommended way to define admins.

```lua
Admins = {
    1234567890987,
    1122334455667,
}

return Admins
```

Important notes:

* Each entry must be a numeric playerId
* Player names are not supported here
* Admins listed here are always loaded when the server starts
* If a player is in this list, they are considered an admin even if they are offline.


### Adding Admins via Environment Variable (Optional)

You can add extra admins without editing Lua files when using Docker setups.

```bash
KYBER_CHAT_FILTER_ADMINS="12345:67890"
```
### How this works

* IDs are colon-separated
* Values are parsed at server startup
* IDs are merged into the existing admins.lua list
* Duplicate IDs are ignored automatically

## Admin Permissions Summary

Admins **can**:

* Use all chat commands listed below
* Change moderation settings at runtime
* Mute / unmute players by name
* Unban players by ID
* View the full admin list
* Bypass all automated punishments

Admins **cannot**:

* Be auto-muted
* Be auto-kicked
* Be auto-banned
* Mute or ban other admins


## In-Game Moderation Commands (Via Game Chat)

All moderation and admin commands:

* Must be issued by an admin
* Start with `/`
* Are **not shown in chat**

**Mute a Player Manually**

`/mute <playerName> [seconds]`

Examples:

```
/mute PlayerOne
/mute PlayerOne 60
/mute PlayerOne 0
```

* Duration is optional
* 0 or omitted = permanent mute
* Player name lookup is case-insensitive
* Admins cannot mute other admins

**Unmute a Player**

`/unmute <playerName>`

Removes any active mute from the player.

**Unban a Player**

`/unban <playerId>`

* Removes the player from the in-memory ban list
* Resets player's strike count

**List All Admins**

`/listadmins`

Output behavior:

* Online admins → shown by name + ID
* Offline admins → shown by playerId only

## Admin Commands (Configuration Changes)

These commands modify chat filter behavior while **in game**.

### Enable / Disable Features

```text
/enableblockmessage         (enables chat message blocking)
/disableblockmessage        (disables chat message blocking)

/enablelogging              (enables event logging)
/disablelogging             (disables event logging)

/enablehostalert            (enables event log alerts)
/disablehostalert           (disables event log alerts)

/enablestriketrack          (enables strike tracking)
/disablestriketrack         (disables strike tracking)

/enableautomute             (enables auto muting players)
/disableautomute            (disables auto muting players)
```

Changes apply immediately and remain active until:

* Changed again
* Server restarts (unless also set via env vars)

### Adjust Strike Thresholds & Timing

```text
/setmaxstrikes <number>        (sets number of strikes before auto-mute)
/setkickat <number>            (sets number of strikes to auto-kick at)
/setbanat <number>             (sets number of strikes to auto-ban at)
/setmuteduration <seconds>     (sets how long in seconds to mute a player)
```
Note: setting `/setmuteduration` to `0` enables a permanent mute of the selected player

Examples:

```text
/setmaxstrikes 3
/setkickat 5
/setbanat 7
/setmuteduration 300
/setmuteduration 0   (permanent mute)
```


## How Admin Settings Interact

| Source                | When Applied | Priority |
| --------------------- | ------------ | -------- |
| Lua defaults          | On load      | Lowest   |
| Environment variables | On startup   | Medium   |
| Admin chat commands   | In-game      | Highest  |

* Chat commands **override everything** until restart
* Environment variables override Lua defaults but **not** runtime commands



## ⚠ Common Issues

* Admins are matched by **playerId**, not name
* `/unban` requires the playerId rather than player name
* Admin changes made in chat are **not persistent** across restarts
* Bans are memory-only unless extended, and are **not persistent** across restarts



## Configuration Options in lua

The following table shows the default moderation behavior when no environment
variables or admin commands override these values.

| Setting             | Default | Description                                   |
| ------------------- | ------- | --------------------------------------------- |
| `BlockMessage`      | `true`  | Blocks chat messages that trigger the filter  |
| `EnableLogging`     | `true`  | Logs moderation events to the server console  |
| `EnableHostAlert`   | `false` | Sends alerts to the Kyber host event log      |
| `EnableStrikeTrack` | `true`  | Enables per-player strike tracking            |
| `EnableAutoMute`    | `true`  | Automatically mutes players at strike limit   |
| `EnableAutoKick`    | `true`  | Automatically kicks players at kick threshold |
| `EnableAutoBan`     | `false` | Automatically bans players at ban threshold   |
| `MaxStrikes`        | `3`     | Strikes required before auto-mute             |
| `MuteDuration`      | `300`   | Mute duration in seconds (`0` = permanent)    |
| `KickAtStrikes`     | `5`     | Strikes required before auto-kick             |
| `BanAtStrikes`      | `7`     | Strikes required before auto-ban              |


### Default Settings Appearance in `__init__.lua`

```lua
ChatFilter.BlockMessage      = true
ChatFilter.EnableLogging     = true
ChatFilter.EnableHostAlert   = false

ChatFilter.EnableStrikeTrack = true
ChatFilter.EnableAutoMute    = true
ChatFilter.EnableAutoKick    = true
ChatFilter.EnableAutoBan     = false

ChatFilter.MaxStrikes        = 3
ChatFilter.MuteDuration      = 300
ChatFilter.KickAtStrikes     = 5
ChatFilter.BanAtStrikes      = 7
```


## Environment Variable List (For Docker)

These override Lua defaults **at startup**.

| Env Variable                      | Description                              | Lua Variable Modified           |
| --------------------------------- | ---------------------------------------- | ------------------------------- |
| `KYBER_CHAT_FILTER_BLOCK_MESSAGE` | Block flagged messages (`true/false`)    |  `ChatFilter.BlockMessage`      |
| `KYBER_CHAT_FILTER_LOGGING`       | Enable server logging (`true/false`)     |  `ChatFilter.EnableLogging`     |
| `KYBER_CHAT_FILTER_HOST_ALERT`    | Enable host alerts  (`true/false`)       |  `ChatFilter.EnableHostAlert`   |
| `KYBER_CHAT_FILTER_STRIKE_TRACK`  | Enable strike tracking (`true/false`)    |  `ChatFilter.EnableStrikeTrack` |
| `KYBER_CHAT_FILTER_AUTO_MUTE`     | Enable auto-mute (`true/false`)          |  `ChatFilter.EnableAutoMute`    |
| `KYBER_CHAT_FILTER_AUTO_KICK`     | Enable auto-kick (`true/false`)          |  `ChatFilter.EnableAutoKick`    |
| `KYBER_CHAT_FILTER_AUTO_BAN`      | Enable auto-ban (`true/false`)           |  `ChatFilter.EnableAutoBan`     |
| `KYBER_CHAT_FILTER_MAX_STRIKES`   | Strikes before mute (`int`)              |  `ChatFilter.MaxStrikes`        |
| `KYBER_CHAT_FILTER_MUTE_TIME`     | Mute duration (seconds, `0` = permanent) |  `ChatFilter.MuteDuration`      |
| `KYBER_CHAT_FILTER_KICK_AT`       | Strikes before kick (`int`)              |  `ChatFilter.KickAtStrikes`     |
| `KYBER_CHAT_FILTER_BAN_AT`        | Strikes before ban (`int`)               |  `ChatFilter.BanAtStrikes`      |
| `KYBER_CHAT_FILTER_ADMINS`        | Additional admin playerIds (`Id1:Id2`)   |   merged with `admins.lua`      |

Boolean values accepted:

```
1, true, yes, on
0, false, no, off
```

### Example Strike Flow:

- Strike 1–2: no action (can add player warning if desired)
- Strike 3: Player is muted
- Strike 5: Player is kicked
- Strike 7: Player is banned

### Chat Moderation Flow Diagram

```
Chat Message
   ↓
Normalization & Matching
   ↓
Strike Added (if enabled)
   ↓
Message Blocked (if enabled)
   ↓
Threshold Check (if enabled)
   ├─ Mute
   ├─ Kick
   └─ Ban
```

## Bans and Kicks

* Kicks and bans are evaluated immediately after a strike is added.
* If a player crosses multiple thresholds at once, only the highest action is applied.

### Bans

* Banned players are kicked **on join**
* Bans are stored in memory (non-persistent across server restarts)
  * Functions by auto-kicking players on the ban list at server join
* Admins are immune to auto-ban logic
* `/unban` command requires playerId instead of PlayerName due to how the Kyber api works with offline player lookup

## Performance Notes

- Banned words are compiled into lookup tables on startup
- Normal chat messages incur minimal overhead
- Aggressive spaced-letter detection is only applied when needed


## Safety Defaults

- Auto-ban is disabled by default
- Admins are always exempt from automation
- False-positive reduction is prioritized over aggressive matching


## Debugging

Enable debug output with:

```bash
KYBER_DEV_MODE=1
```

or

```bash
KYBER_LOG_LEVEL=debug
```

This prints detailed matching and decision logs to the server console.

## ⚠ Notes & Limitations

* Bans are **not persistent across restarts** unless extended
* Host alerting is stubbed (ready for Discord or Kyber event log integration)
* Player lookup by name is case-insensitive but requires the player to be online

## Planned Future Features

* Optional JSON-backed persistence for strikes, mutes, and bans
* Optional player warning messages if chat is flagged
* Discord integration option for logging
* Ability to push logged events to the Kyber client Event Log
* General cleanup of `__init__.lua` for easier readability
* Real time chat filtering without blocking message (e.g `example chat message` --> `example **** message`)



