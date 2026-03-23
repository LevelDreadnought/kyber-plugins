# Kyber Chat Filter Plugin

A robust, configurable chat moderation plugin for **Kyber dedicated servers**.
Designed to catch common word-filter bypasses, track player strikes, and automatically enforce mutes, kicks, and bans — all while remaining fully controllable at runtime by admins and moderators via in-game chat commands or optional remote HTTP control.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Discord Integration](#optional-discord-webhook-relay-docker-image)
- [Plugin Structure](#plugin-file-structure)
- [Admin & Moderator Configuration](#admin--moderator-configuration)
- [In-Game Moderation Commands](#in-game-moderation-commands-via-game-chat)
- [Admin Commands](#admin-commands-configuration-changes)
- [Configuration & Defaults](#configuration-options-in-lua)
- [Environment Variables](#environment-variable-list-for-docker)
- [HTTP API & Remote Control](#http-api--remote-control)
- [Chat Moderation Flow](#chat-moderation-flow-diagram)
- [Bans, Performance & Safety](#bans-and-kicks)
- [Planned Future Features](#planned-future-features)


## Features

### Core Filtering

Detects **banned words** from an editable list using:

* Word-boundary matching (reduces false positives)
* Obfuscation normalization (`@ → a`, `0 → o`, etc.)
* Spaced / punctuated letter detection (`b a n`, `b-a-n`, `b_a_n`)
* Precompiled Lua pattern matching for performance

Additional features:

* Case-insensitive
* Handles punctuation
* Blocks or allows messages based on configuration
* Precomputes filter patterns at startup for minimal runtime overhead
* Chat messages filtered using regex-like **Lua pattern matching**
* Supports spaced-letter detection

### Moderation & Enforcement

* Permanent or timed mutes
* Permanent or timed bans
* **Strike tracking per player**
* Automatic enforcement thresholds:

  * Auto-mute
  * Auto-kick
  * Auto-ban
* Automatic strike reset when bans expire
* Enforcement of bans on player join (banned players are auto-kicked when joining a server)
* Highest-threshold action supersedes others (prevents double punishments)


### Role-Based Permission System

Two permission levels:

### Admin:

* Full control
* Can change configuration at runtime
* Can manually mute, unmute, ban, and unban players
* Can change strike thresholds
* **Exempt** from automated enforcement actions
* Can list bans, admins, and moderators
* Cannot mute or ban other admins

### Moderator:

* Can manually mute, unmute, ban, and unban players
* Can list bans and moderators
* Cannot change system configuration
* Cannot mute or ban admins
* Cannot mute or ban other moderators

Admins and moderators are matched strictly by **playerId**, not by name.


### Logging

* Optional server-side console logging (enabled by default)
* Debug logging enabled via environment variable
* All `logEvent()` output is written directly to the server log file
* Log prefixes (`Detection:`, `Action:`, `Error:`) used by the optional Discord relay to distinguish event types
* `/listbans` outputs a single-line structured format

### HTTP API & Remote Control

* Built-in HTTP server (default port `8081`) for remote administration and state persistence across server restarts
    * Endpoints:
    * `/state` — GET; returns current ban and mute state formatted as JSON
    * `/sync` — POST; replaces plugin ban and mute state from a Docker relay (used for persistence across restarts)
    * `/command` — POST; executes moderation commands remotely with auth token
* Auth token required for all write endpoints
* Both remote command support and state persistence are toggleable


>### ⚠ Warning:
>
>The included word list file `filtered_word_list.lua` contains some **very offensive language and slurs** (necessary in order to match/filter them).  
>Please use caution when reviewing or editing the word list.



## Installation

1. Place the `ChatFilter.kbplugin` file in your Kyber plugins directory.
2. Restart the server.
>Note: the server must be restarted, reloading plugins only will lead to instability or ChatFilter not functioning at all

Optional:

* Set environment variables for Docker deployments (overwrites default variables)
* Modify defaults in `__init__.lua`
* Adjust thresholds and toggle features in-game or remotely via admin commands

## Optional: Discord Webhook Relay (Docker Image)

This plugin can optionally integrate with Discord using a companion
Go-based Docker image (sidecar) that monitors the Kyber server log file and
forwards moderation events to Discord via webhook. The relay also optionally
saves ban and mute lists (state) over HTTP (via the `/state` and `/sync` requests),
providing persistence across server restarts since the plugin itself cannot
write to disk.

The relay:

* Watches the Kyber log directory in real time
* Parses structured `logEvent()` output along with it's prefixes
* Sends moderation events to Discord via webhook
* Optionally polls `/state` and syncs via `/sync` for ban/mute persistence
* Runs independently of the Kyber server container
* Requires no modification to the ChatFilter plugin

Repository:
https://github.com/LevelDreadnought/kyber-chatfilter-discord

This integration is completely optional and not required for core
ChatFilter functionality.

## Plugin File Structure
```
ChatFilter.kbplugin
├── plugin.json
├── common/
│   ├── dkjson.lua
│   ├── timer.lua
│   └── utils.lua
└── server/
    ├── __init__.lua
    ├── admins.lua
    ├── chatfilter_commands.lua
    ├── moderation.lua
    ├── filtered_word_list.lua
    ├── http_router.lua
    └── http_server.lua
```

| File                      | Description                                                                             |
| ------------------------- | --------------------------------------------------------------------------------------- |
| `__init__.lua`            | Main plugin file. Initializes all modules and runs the chat filter logic                |
| `admins.lua`              | Defines admin and moderator playerID lists                                              |
| `chatfilter_commands.lua` | Command registry and dispatcher. In-game and remote commands are defined here           |
| `moderation.lua`          | Moderation lists (strikes, mutes, bans) and enforcement logic (mute, kick, ban, prune)  |
| `filtered_word_list.lua`  | The banned word list                                                                    |
| `http_server.lua`         | Minimal HTTP server                                                                     |
| `http_router.lua`         | Routeing and request handling for the HTTP server                                       |
| `common/utils.lua`        | Utility functions                                                                       |
| `common/timer.lua`        | Timer and `SetTimeout` utilities                                                        |
| `common/dkjson.lua`       | Third party JSON encode/decode library used for HTTP bodies                             |

## Admin & Moderator Configuration

### Defining Admins (Required)

`admins.lua`

```lua
...
    Admins = {
        1234567890987,
    },
...
```

### Defining Moderators (Optional)

`admins.lua`

```lua
...
    Moderators = {
        1122334455667,
        9988776655443,
    }
...
```

Important configuration notes:

* Entries must be numeric playerIds, not player names
* Admins and moderators are always loaded at server start
* List is active even if player is offline
* Moderators have limited moderation permissions


### Adding Admins & Moderators via Environment Variables (Optional)

You can add extra admins and moderators without editing Lua files when using Docker setups.

```bash
KYBER_CHAT_FILTER_ADMINS="12345:67890"
KYBER_CHAT_FILTER_MODERATORS="98765:43210"
```
### How this works

* IDs are colon-separated
* IDs are merged to `admins.lua` at server startup
* Duplicate IDs are ignored automatically


## In-Game Moderation Commands (Via Game Chat)

All moderation and admin commands:

* Must begin with `/`
* Are **not shown in chat**
* Permissions are checked automatically

For commands with a `[duration]` argument:

* Minutes, hours, and days are valid entries with appropriate suffixes
* Permanent durations are supported via `0`

Duration suffix examples:
```
30   -> 30 minutes
12h  -> 12 hours
7d   -> 7 days
0    -> permanent
```

### Manual Moderation

#### Mute Player

```
/mute <playerName> <duration>
```

Examples:

```
/mute PlayerOne 30
/mute PlayerOne 2h
/mute PlayerOne 7d
/mute PlayerOne 0
```

* Supports duration parsing
* 0 = permanent mute
* Case-insensitive player name lookup
* Admins and cannot mute other admins
* Moderators cannot mute other moderators

---

#### Unmute Player

```
/unmute <playerName>
```
Example:

```
/unmute PlayerOne
```

* Removes active mute
* Player must be in-game for this command to work

---

#### Ban Player (Online)

```
/ban <playerName> <duration> [reason]
```

Examples:

```
/ban PlayerOne
/ban PlayerOne 3h Chat spam
/ban PlayerOne 5d Repeated violations
```

* Supports duration parsing
* 0 = permanent
* Reason is stored in ban list
* Banning resets strike count
* Player is auto-kicked after ban

---

#### Ban Player (Offline)

```
/banoffline <playerId> <duration> [reason]
```

Examples:

```
/banoffline 123456789 7d Evading previous ban
/banoffline 123456789 0 Permanent ban
```

* Allows banning by playerID even if player is not online
* Name is stored as `OfflinePlayer` and is updated to the actual name on that player's next join
* Same configuration and effect as `/ban`

---

#### Unban Player

```
/unban <playerId>
```

Example:

```
/unban 123456789
```

* Removes player from ban list by playerID
* Resets strike count

---

#### List All Bans

```
/listbans
```

Outputs all bans in a single-line structured format:

* Player Name
* Player ID
* Remaining Time
* Original Ban Length
* Ban Type (Manual / Auto)
* Reason
* Automatically cleans expired bans before displaying

Example output format:

```
DarthVader (10001234) | Remaining: 14m 22s | Original: 30m | Type: Manual | Reason: Toxic language || Palpatine (10009999) | Remaining: Permanent | Original: Permanent | Type: Auto | Reason: Repeated violations
```

---

#### List Admins

```
/listadmins
```

* Admin only
* Shows online admins by name and ID
* Offline admins shown by ID only

---

#### List Moderators

```
/listmods
```

* Shows online moderators by name and ID
* Offline moderators shown by ID only

---

### Moderation Utility Commands

#### Set Team

```
/setteam <number>
```

Valid team numbers:

```
0 -> Spectator
1 -> Light side
2 -> Dark side
```

* Admin or moderator only
* Sets the moderator or admin player to the specified team
* Team 0 has no character spawn list

---

#### Spectate Mode

```
/spectate <true|false>
```

* Admin or moderator only
* `true` — makes the player invisible, disables all weapon, ability, and melee (including saber) inputs for that player, and moves them to the spectator team
* `false` — restores visibility, re-enables inputs, and moves player to team 1
* Intended for moderator observation (e.g. on 1v1 servers)


## Admin Commands (Configuration Changes)

These commands modify chat filter behavior while **in game** and are admin only.

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

/enableautokick             (enables auto kicking players)
/disableautokick            (disables auto kicking players)

/enableautoban              (enables auto banning players)
/disableautoban             (disables auto banning players)
```

Changes apply immediately and remain active until:

* Changed again
* Server restarts (unless also set via environment variables)

### Adjust Strike Thresholds & Timing

```text
/setmaxstrikes <number>          (sets number of strikes before auto-mute)
/setkickat <number>              (sets number of strikes to auto-kick at)
/setbanat <number>               (sets number of strikes to auto-ban at)
/setmuteduration <seconds>       (sets duration to auto-mute a player for)
/setautobanduration <duration>   (sets duration to auto-mute a player for)
```
Note: Supports duration parsing, see this [section](#in-game-moderation-commands-via-game-chat) for duration examples

Examples:

```text
/setmaxstrikes 3
/setkickat 5
/setbanat 7
/setmuteduration 30      (30 minutes)
/setmuteduration 0       (permanent mute)
/setautobanduration 2d   (2 days)
/setautobanduration 0    (permanent ban)
```


## How Admin Settings Interact

| Source                | When Applied | Priority |
| --------------------- | ------------ | -------- |
| Lua defaults          | On load      | Lowest   |
| Environment variables | On startup   | Medium   |
| Admin chat commands   | In-game      | Highest  |

* In-game chat commands **override everything** until restart
* Environment variables override Lua defaults but **not** runtime commands
* In-game changes are not persistent across server restarts


## Example Strike Flow:

- Strike 1–2: no action (can add player warning if desired)
- Strike 3: Player is auto-muted
- Strike 5: Player is auto-kicked
- Strike 7: Player is auto-banned

### Chat Moderation Flow Diagram

```
Chat Message
   ↓
Check if command
   ├─ Yes → permissions check → execute command
   └─ No  ↓
Normalization & Pattern Matching
   ↓
Strike Added (if enabled)
   ↓
Message Blocked (if enabled)
   ↓
Threshold Check (if enabled)
   ├─ Ban  (skips kick/mute)
   ├─ Kick (skips mute)
   └─ Mute
```


## ⚠ Common Issues

* Admins are matched by **playerId**, not name
* `/unban` and `/banoffline` require playerId rather than player name
* Admin changes made in chat are **not persistent** across restarts
* Bans and mutes are memory-only unless the optional Docker relay is used, and are otherwise **not persistent** across restarts



## Configuration Options in lua

The following table shows the default moderation behavior when no environment
variables or admin commands override these values.

| Setting               | Default  | Description                                   |
| --------------------- | -------- | --------------------------------------------- |
| `BlockMessage`        | `true`   | Blocks chat messages that trigger the filter  |
| `EnableLogging`       | `true`   | Logs moderation events to the server console  |
| `EnableHostAlert`     | `false`  | Sends alerts to the Kyber host event log      |
| `EnableStrikeTrack`   | `true`   | Enables per-player strike tracking            |
| `EnableAutoMute`      | `true`   | Automatically mutes players at strike limit   |
| `EnableAutoKick`      | `true`   | Automatically kicks players at kick threshold |
| `EnableAutoBan`       | `false`  | Automatically bans players at ban threshold   |
| `EnableTimedAutoBan`  | `true`   | Enables timed auto-bans                       |
| `EnableRemoteCommands`| `false`  | Allows remote commands to be sent via HTTP    |
| `EnablePersistence`   | `false`  | Enables the HTTP server for state persistence |
| `AuthToken`           | `CHANGE` | Shared secret required for HTTP auth          |       
| `MaxStrikes`          | `3`      | Strikes required before auto-mute             |
| `MuteDuration`        | `5`      | Mute duration (`0` = permanent)               |
| `AutoBanDuration`     | `60`     | Ban duration (`0` = permanent)                |
| `KickAtStrikes`       | `5`      | Strikes required before auto-kick             |
| `BanAtStrikes`        | `7`      | Strikes required before auto-ban              |


### Default Settings Appearance in `__init__.lua`

```lua
ChatFilter.BlockMessage         = true
ChatFilter.EnableLogging        = true
ChatFilter.EnableHostAlert      = false

ChatFilter.EnableStrikeTrack    = true
ChatFilter.EnableAutoMute       = true
ChatFilter.EnableAutoKick       = true
ChatFilter.EnableAutoBan        = false
ChatFilter.EnableTimedAutoBan   = true

ChatFilter.EnableRemoteCommands = false
ChatFilter.EnablePersistence    = false
ChatFilter.AuthToken            = "CHANGE_ME_SECRET"

ChatFilter.MaxStrikes           = 3
ChatFilter.MuteDuration         = 5
ChatFilter.AutoBanDuration      = 60
ChatFilter.KickAtStrikes        = 5
ChatFilter.BanAtStrikes         = 7
```


## Environment Variable List (For Docker)

These override Lua defaults **at startup**.

| Env Variable                          | Description                                | Lua Variable Modified             |
| ------------------------------------- | ------------------------------------------ | --------------------------------- |
| `KYBER_CHAT_FILTER_BLOCK_MESSAGE`     | Block flagged messages (`true/false`)      | `ChatFilter.BlockMessage`         |
| `KYBER_CHAT_FILTER_LOGGING`           | Enable server logging (`true/false`)       | `ChatFilter.EnableLogging`        |
| `KYBER_CHAT_FILTER_HOST_ALERT`        | Enable host alerts  (`true/false`)         | `ChatFilter.EnableHostAlert`      |
| `KYBER_CHAT_FILTER_STRIKE_TRACK`      | Enable strike tracking (`true/false`)      | `ChatFilter.EnableStrikeTrack`    |
| `KYBER_CHAT_FILTER_AUTO_MUTE`         | Enable auto-mute (`true/false`)            | `ChatFilter.EnableAutoMute`       |
| `KYBER_CHAT_FILTER_AUTO_KICK`         | Enable auto-kick (`true/false`)            | `ChatFilter.EnableAutoKick`       |
| `KYBER_CHAT_FILTER_AUTO_BAN`          | Enable auto-ban (`true/false`)             | `ChatFilter.EnableAutoBan`        |
| `KYBER_CHAT_FILTER_REMOTE_COMMANDS`   | Enable remote HTTP commands (`true/false`) | `ChatFilter.EnableRemoteCommands` |
| `KYBER_CHAT_FILTER_PERSISTENCE`       | Enable HTTP persistence (`true/false`)     | `ChatFilter.EnablePersistence`    |
| `KYBER_CHAT_FILTER_AUTH`              | HTTP auth token (string)                   | `ChatFilter.AuthToken`            |
| `KYBER_CHAT_FILTER_MAX_STRIKES`       | Strikes before mute (`int`)                | `ChatFilter.MaxStrikes`           |
| `KYBER_CHAT_FILTER_MUTE_TIME`         | Mute duration (`0` = permanent)            | `ChatFilter.MuteDuration`         |
| `KYBER_CHAT_FILTER_AUTO_BAN_DURATION` | Auto-ban duration (`0` = permanent)        | `ChatFilter.AutoBanDuration`       |
| `KYBER_CHAT_FILTER_KICK_AT`           | Strikes before kick (`int`)                | `ChatFilter.KickAtStrikes`        |
| `KYBER_CHAT_FILTER_BAN_AT`            | Strikes before ban (`int`)                 | `ChatFilter.BanAtStrikes`         |
| `KYBER_CHAT_FILTER_ADMINS`            | Additional admin playerIds (`Id1:Id2`)     |  merged with `admins.lua`         |
| `KYBER_CHAT_FILTER_MODERATORS`        | Additional mod playerIds (`Id1:Id2`)       |  merged with `admins.lua`         |

Boolean values accepted:

```
1, true, yes, on
0, false, no, off
```

## HTTP API & Remote Control

When `EnableRemoteCommands` or `EnablePersistence` is set to `true`, the plugin starts an HTTP server on port `8081`.
This port can be changed in `__init__.lua`. A matching auth token must also be passed for some HTTP requests.

### `GET /state`

Returns the current ban and mute lists as JSON. No auth required.

```
GET http://<server>:8081/state
```

Response:

```json
{
  "bans":  { "<playerId>": { "name": "...", "expires": 1234567890, "reason": "...", "manual": true } },
  "mutes": { "<playerId>": { "expires": 1234567890 } }
}
```

### `POST /sync`

Replaces the in-memory ban and mute lists entirely. Used by the Docker relay to restore state after a server restart. Auth token is required.

```json
{
  "token": "your_auth_token",
  "bans":  { ... },
  "mutes": { ... }
}
```

Closes connection and logs "State synced" on success.

### `POST /command`

Executes a moderation command remotely. Only commands with `allowRemote = true` are permitted to be executed remotely. Auth token is required.

```json
{
  "token":   "your_auth_token",
  "command": "ban",
  "args":    ["PlayerOne", "2h", "Chat spam"]
}
```

Response:

```json
{
  "success":   true,
  "message":   "PlayerOne banned for 2h",
  "timestamp": 1234567890
}
```

Remote commands can be toggled on or off via environment variables or by modifying the default setting `ChatFilter.EnableRemoteCommands`


## Bans and Kicks

* Bans are stored in memory and are non-persistent across server restarts unless the optional Docker relay is used
* Players are auto-kicked **on join** if banned
* Kicks and bans are evaluated immediately after a strike is added
* If a player crosses multiple thresholds at once, only the highest action is applied
* Auto-kick on join is slightly delayed to ensure the player is fully initialized before being kicked
* Expired bans are automatically cleaned
* Strike count resets when ban expires
* Admins are immune to auto-bans and auto-kicks

## Performance Notes

* Banned words are compiled into patterns at startup
* Frontier pattern matching (`%f[]`) used for word-boundary detection
* No runtime regex building
* Normal chat messages incur minimal overhead
* Spaced-letter detection is only applied when needed
* Designed for high-chat-traffic HvV and 1v1 servers

## Safety Defaults

* Auto-ban is disabled by default
* Admins are exempt from all automated enforcement
* Moderator hierarchy protection enforced
* False positives minimized via boundary matching
* Persistence and remote commands are switched off by default, thus the HTTP server only starts if one of those is enabled


## Debugging

Enable debug log output with:

```bash
KYBER_DEV_MODE=1
```

or

```bash
KYBER_LOG_LEVEL=debug
```

This prints detailed matching, decision logs, and HTTP requests to the server console.

## ⚠ Notes & Limitations

* Bans are **not persistent across restarts** unless the Docker relay
* Player lookup by name is case-insensitive but requires the player to be online (Offline name resolution is not available)
* Host alerting is stubbed (ready for Discord or Kyber event log integration)
* In-game admin setting changes are **not persistent** across restarts

## Planned Future Features

* Optional player warning messages if chat is flagged
* Ability to push logged events to the Kyber client Event Log
* Real time chat redaction instead of blocking (e.g `example chat message` --> `example **** message`)



