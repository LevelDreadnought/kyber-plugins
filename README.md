# Kyber Chat Filter Plugin

A robust, configurable chat moderation plugin for **Kyber dedicated servers**.
Designed to catch common word-filter bypasses, track player strikes, and automatically enforce mutes, kicks, and bans — all while remaining fully controllable at runtime by admins and moderators.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Plugin Structure](#plugin-file-structure)
- [Admin & Moderator Configuration](#admin-configuration)
- [In-Game Moderation Commands](#in-game-moderation-commands-via-game-chat)
- [Admin Commands](#admin-commands-configuration-changes)
- [Configuration & Defaults](#configuration-options-in-lua)
- [Environment Variables](#environment-variable-list-for-docker)
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
* Punctuation-tolerant
* Blocks or allows messages based on configuration
* Precomputes filter patterns at startup (minimal runtime overhead)
* Chat messages filtered using **Lua pattern matching** (regex-like)
* Supports aggressive spaced-letter detection without regex cost per message

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
* `/listbans` outputs a single-line structured format


>### ⚠ Warning:
>
>The included word list file `filtered_word_list.lua` contains some **very offensive language and slurs** (necessary in order to match/filter them).  
>Please use caution when reviewing or editing the word list.



## Installation

1. Place the `ChatFilter.kbplugin` file in your Kyber plugins directory.
2. Restart the server or reload plugins.

Optional:

- Set environment variables for Docker deployments (overwrites default variables)
- Modify defaults in `__init__.lua`
- Adjust thresholds and toggle features in-game via admin commands

## Plugin File Structure
```
ChatFilter.kbplugin
├── plugin.json
├── common/
│   └── timer.lua
└── server/
    ├── __init__.lua
    ├── admins.lua
    └── filtered_word_list.lua
```

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
* Moderators have limited moderation powers


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

Duration suffixes:
```
30   -> 30 minutes
12h  -> 12 hours
7d   -> 7 days
0    -> permanent
```

### Manual Moderation

#### Mute Player

```
/mute <playerName> [duration]
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

#### Ban Player (Online)

```
/ban <playerName> [duration] <reason>
```

Examples:

```
/ban PlayerOne
/ban PlayerOne 3h Chat spam
/ban PlayerOne 5d Repeated violations
```

* Duration optional
* 0 = permanent
* Reason is stored in ban list
* Banning resets strike count
* Player is auto-kicked after ban

#### Ban Player (Offline)

```
/banoffline <playerId> [duration] <reason>
```

* Allows banning by playerID even if player is not online
* Same configuration and effect as `/ban`


#### Unban Player

```
/unban <playerId>
```

* Removes player from ban list
* Resets strike count

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


#### List Admins

```
/listadmins
```

* Shows online admins by name and ID
* Offline admins shown by ID only




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
* Server restarts (unless also set via env vars)

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


## ⚠ Common Issues

* Admins are matched by **playerId**, not name
* `/unban` requires the playerId rather than player name
* Admin changes made in chat are **not persistent** across restarts
* Bans are memory-only unless extended, and are **not persistent** across restarts



## Configuration Options in lua

The following table shows the default moderation behavior when no environment
variables or admin commands override these values.

| Setting               | Default | Description                                   |
| --------------------- | ------- | --------------------------------------------- |
| `BlockMessage`        | `true`  | Blocks chat messages that trigger the filter  |
| `EnableLogging`       | `true`  | Logs moderation events to the server console  |
| `EnableHostAlert`     | `false` | Sends alerts to the Kyber host event log      |
| `EnableStrikeTrack`   | `true`  | Enables per-player strike tracking            |
| `EnableAutoMute`      | `true`  | Automatically mutes players at strike limit   |
| `EnableAutoKick`      | `true`  | Automatically kicks players at kick threshold |
| `EnableAutoBan`       | `false` | Automatically bans players at ban threshold   |
| `EnableTimedAutoBan`  | `true`  | Enables timed auto-bans                       |       
| `MaxStrikes`          | `3`     | Strikes required before auto-mute             |
| `MuteDuration`        | `5`     | Mute duration (`0` = permanent)               |
| `AutoBanDuration`     | `60`    | Ban duration (`0` = permanent)                |
| `KickAtStrikes`       | `5`     | Strikes required before auto-kick             |
| `BanAtStrikes`        | `7`     | Strikes required before auto-ban              |


### Default Settings Appearance in `__init__.lua`

```lua
ChatFilter.BlockMessage        = true
ChatFilter.EnableLogging       = true
ChatFilter.EnableHostAlert     = false

ChatFilter.EnableStrikeTrack   = true
ChatFilter.EnableAutoMute      = true
ChatFilter.EnableAutoKick      = true
ChatFilter.EnableAutoBan       = false
ChatFilter.EnableTimedAutoBan  = true

ChatFilter.MaxStrikes          = 3
ChatFilter.MuteDuration        = 5
ChatFilter.AutoBanDuration     = 60
ChatFilter.KickAtStrikes       = 5
ChatFilter.BanAtStrikes        = 7
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
| `KYBER_CHAT_FILTER_MUTE_TIME`     | Mute duration (`0` = permanent)          |  `ChatFilter.MuteDuration`      |
| `KYBER_CHAT_FILTER_KICK_AT`       | Strikes before kick (`int`)              |  `ChatFilter.KickAtStrikes`     |
| `KYBER_CHAT_FILTER_BAN_AT`        | Strikes before ban (`int`)               |  `ChatFilter.BanAtStrikes`      |
| `KYBER_CHAT_FILTER_ADMINS`        | Additional admin playerIds (`Id1:Id2`)   |   merged with `admins.lua`      |
| `KYBER_CHAT_FILTER_MODERATORS`    | Additional mod playerIds (`Id1:Id2`)     |   merged with `admins.lua`      |

Boolean values accepted:

```
1, true, yes, on
0, false, no, off
```


## Bans and Kicks

* Bans are stored in memory and are non-persistent across server restarts
* Players are auto-kicked **on join** if banned
* Kicks and bans are evaluated immediately after a strike is added
* If a player crosses multiple thresholds at once, only the highest action is applied
* Auto-kick on join is slightly delayed to prevent server crash
* Expired bans are automatically cleaned
* Strike count resets when ban expires
* Admins are immune to automated punishments

## Performance Notes

* Banned words are compiled at startup
* Frontier pattern matching used
* No runtime regex building
* Normal chat messages incur minimal overhead
* Aggressive spaced-letter detection is only applied when needed
* Designed for high-chat-traffic HvV servers

## Safety Defaults

* Auto-ban is disabled by default
* Admins are exempt from automation
* Moderator hierarchy protection enforced
* False positives minimized via boundary matching


## Debugging

Enable debug log output with:

```bash
KYBER_DEV_MODE=1
```

or

```bash
KYBER_LOG_LEVEL=debug
```

This prints detailed matching and decision logs to the server console.

## ⚠ Notes & Limitations

* Bans are **not persistent across restarts**
* Host alerting is stubbed (ready for Discord or Kyber event log integration)
* Player lookup by name is case-insensitive but requires the player to be online
* Offline name resolution not available (ID required)

## Planned Future Features

* Optional player warning messages if chat is flagged
* Ability to push logged events to the Kyber client Event Log
* Further refactoring of `__init__.lua` for easier readability
* Real time chat redaction instead of blocking (e.g `example chat message` --> `example **** message`)



