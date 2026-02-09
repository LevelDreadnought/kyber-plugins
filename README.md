# Kyber Chat Filter Plugin

A robust, configurable chat moderation plugin for **Kyber dedicated servers**.
Designed to catch common word-filter bypasses, track player strikes, and automatically enforce mutes, kicks, and bans — all while remaining fully controllable at runtime by admins.

## Features

### Core Filtering

* Detects **banned words** from an editable list using:

  * Word-boundary matching (reduces false positives)
  * Obfuscation normalization (`@ → a`, `0 → o`, etc.)
  * Spaced / punctuated letter detection (`b a n`, `b-a-n`, `b_a_n`)
* Case-insensitive and punctuation-tolerant
* Blocks or allows messages based on configuration
* Chat messages filtered via Regex

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

## Installation

1. Place the `ChatFilter.kbplugin` file in your Kyber plugins directory.
2. Restart the server or reload plugins.

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
* Unban players by name
* View the full admin list
* Bypass all automated punishments

Admins **cannot**:

* Be auto-muted
* Be auto-kicked
* Be auto-banned
* Mute or ban other admins


## In-Game Moderation Commands (Via Game Chat)

**Mute a Player**

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

`/unban <playerName>`

* Removes the player from the in-memory ban list
* Player must be online to be resolved by name

**List All Admins**

`/listadmins`

Output behavior:

* Online admins → shown by name + ID
* Offline admins → shown by playerId only

## Admin Commands (Configuration Changes)

These commands modify chat filter behavior **at runtime**.

### Enable / Disable Features

```text
/enableblockmessage
/disableblockmessage

/enablelogging
/disablelogging

/enablehostalert
/disablehostalert

/enablestriketrack
/disablestriketrack

/enableautomute
/disableautomute
```

Changes apply immediately and remain active until:

* Changed again
* Server restarts (unless also set via env vars)

---

### Adjust Strike Thresholds & Timing

```text
/setmaxstrikes <number>
/setkickat <number>
/setbanat <number>
/setmuteduration <seconds>
```

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
| Admin chat commands   | Runtime      | Highest  |

* Chat commands **override everything** until restart
* Environment variables override Lua defaults but **not** runtime commands



## ⚠ Common Issues

* Admins are matched by **playerId**, not name
* `/unban` requires the player to be resolvable by name
* Admin changes made in chat are **not persistent**
* Bans are memory-only unless extended, and are **not persistent**



## Configuration Options

### Default Settings (Editable in Lua `__init__.lua`)

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


## Environment Variable List

These override Lua defaults **at startup**.

| Variable                          | Description                              |
| --------------------------------- | ---------------------------------------- |
| `KYBER_CHAT_FILTER_BLOCK_MESSAGE` | Block flagged messages (`true/false`)    |
| `KYBER_CHAT_FILTER_LOGGING`       | Enable server logging (`true/false`)     |
| `KYBER_CHAT_FILTER_HOST_ALERT`    | Enable host alerts  (`true/false`)       |
| `KYBER_CHAT_FILTER_STRIKE_TRACK`  | Enable strike tracking (`true/false`)    |
| `KYBER_CHAT_FILTER_AUTO_MUTE`     | Enable auto-mute (`true/false`)          |
| `KYBER_CHAT_FILTER_AUTO_KICK`     | Enable auto-kick (`true/false`)          |
| `KYBER_CHAT_FILTER_AUTO_BAN`      | Enable auto-ban (`true/false`)           |
| `KYBER_CHAT_FILTER_MAX_STRIKES`   | Strikes before mute (`int`)              |
| `KYBER_CHAT_FILTER_MUTE_TIME`     | Mute duration (seconds, `0` = permanent) |
| `KYBER_CHAT_FILTER_KICK_AT`       | Strikes before kick (`int`)              |
| `KYBER_CHAT_FILTER_BAN_AT`        | Strikes before ban (`int`)               |

Boolean values accept:

```
1, true, yes, on
0, false, no, off
```

---

## In-Game Admin Commands

All commands:

* Must be issued by an admin
* Start with `/`
* Are **not shown in chat**

---

### Feature Toggles

```text
/enableblockmessage
/disableblockmessage

/enablelogging
/disablelogging

/enablehostalert
/disablehostalert

/enablestriketrack
/disablestriketrack

/enableautomute
/disableautomute
```

---

### Threshold & Timing Controls

```text
/setmaxstrikes <number>
/setkickat <number>
/setbanat <number>
/setmuteduration <seconds>
```

Examples:

```text
/setmaxstrikes 3
/setkickat 5
/setbanat 7
/setmuteduration 0   (permanent mute)
```

---

## 🛠 Moderation Commands (Non-Toggle)

These commands directly affect players.

### Mute a Player

```text
/mute <playerName> [seconds]
```

* Seconds optional
* `0` or omitted = permanent
* Admins cannot mute other admins

### Unmute a Player

```text
/unmute <playerName>
```

### Unban a Player

```text
/unban <playerName>
```

### List Admins

```text
/listadmins
```

* Shows online admins by name
* Shows offline admins by playerId

---

## Bans

* Banned players are kicked **on join**
* Stored in memory (non-persistent by default)
* Admins are immune to auto-ban logic

---

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

---

## ⚠ Notes & Limitations

* Bans are **not persistent across restarts** unless extended
* Host alerting is stubbed (ready for Discord or event viewer integration)
* Player lookup by name is case-insensitive but requires the player to be online

---



