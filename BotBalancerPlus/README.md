# BotBalancerPlus

**BotBalancerPlus** is an enhanced bot balancing plugin for Kyber dedicated servers. It dynamically adjusts AI bot counts based on server player population, allowing games to stay populated without overcrowding servers with bots.

This plugin supports **Battlefront Plus**, **Battlefront Expanded**, **IOI game modes**, and **vanilla Battlefront II**, with extensive configuration options in lua and via environment variables.



## Features

* **Dynamic Bot Balancing**

  * Automatically adjusts bot counts based on number of connected players
  * Maintains a configurable *game density* which sets the bot-to-player ratio (default: 80%)

* **Team Auto-Balancing**

  * On join, players are automatically placed on the team with fewer players and bot counts are adjusted accordingly

* **Team Auto-Shuffling**

  * Teams are automatically randomly shuffled at the start of each new game

* **Multi-Mode Support**

  * Works with:

    * Vanilla game modes
    * BF+
    * BF Expanded
    * IOI custom modes

* **Per-Mode Configuration**

  * Enable/disable bots for specific game modes
  * Override max player counts for each mode

* **Environment Variable Overrides**

  * Plugin is fully configurable without editing Lua files

* **Server Safety Checks**

  * Enforces maximum server player+bot limits
  * Prevents excessive bot population


## How It Works

When a level loads, the plugin:

1. Detects the current game mode
2. Checks if bots are enabled for that mode
3. Applies any configured player count overrides
4. Calculates bot count using the `desiredGameDensity` setting and current player population
5. Fills remaining non-player slots with bots, making sure teams are balanced

Bot counts are updated when:

* A player joins the server
* A player leaves the server
* A new level loads



## Configuration

### Game Mode Toggle

Bot balancing for each game mode can be toggled on or off in `game_modes.lua`. The entry for each mode will look like this example:

```lua
gameModes["Mode1"] = {
    name = "SUPREMACY",
    maxPlayers = 40,
    enabled = true,
}
```
Setting `enabled` to `true` enables bots and bot balancing for the selected mode while setting it to `false` disables bots and bot balancing for that particular mode.

>Note: The `name` and `maxPlayers` fields should **not** be modified as they are defaults necessary for proper plugin functionality.
>Max player count can be overridden using a separate setting described below.


## Environment Variables

BotBalancerPlus supports configuration through environment variables.



### Global Settings

| Variable                           | Description                        | Default |
| ---------------------------------- | ---------------------------------- | ------- |
| `BOT_BALANCER_GAME_DENSITY`        | % of max players to fill (0.1–1.0) | `0.8`   |
| `BOT_BALANCER_SERVER_PLAYER_LIMIT` | Maximum server player count        | `40`    |



### Player Count Overrides

Override max player counts for each mode:

#### Vanilla Modes

| Variable                             | Mode               |
| ------------------------------------ | ------------------ |
| `BOT_BALANCER_SUPREMACY_PLAYERS`     | Supremacy          |
| `BOT_BALANCER_GALACTIC_PLAYERS`      | Galactic Assault   |
| `BOT_BALANCER_HVV_PLAYERS`           | Heroes vs Villains |
| `BOT_BALANCER_BLAST_PLAYERS`         | Blast              |
| `BOT_BALANCER_EWOK_PLAYERS `         | Ewok Hunt          |
| `BOT_BALANCER_CO_OP_PLAYERS`         | Co-Op              |
| `BOT_BALANCER_STRIKE_PLAYERS `       | Strike             |
| `BOT_BALANCER_EXTRACTION_PLAYERS`    | Extraction         |
| `BOT_BALANCER_JETPACK_PLAYERS`       | Jetpack Cargo      |


#### BF+ and IOI Modes


| Variable                             | Mode                    |
| ------------------------------------ | ----------------------- |
| `BOT_BALANCER_SUPREMACY_UR_PLAYERS`  | Supremacy Unrestricted  |
| `BOT_BALANCER_REINFORCEMENT_PLAYERS` | Reinforcement Clash     |
| `BOT_BALANCER_HERO_EXTRACT_PLAYERS`  | Hero Extraction         |
| `BOT_BALANCER_TURNING_PT_PLAYERS`    | Turning Point           |


Example:

```bash
BOT_BALANCER_HVV_PLAYERS=40
```



### Enable / Disable Game Modes

Toggle on/off bots and bot balancing for game modes:

#### Vanilla Modes

| Variable                               | Mode               |
| -------------------------------------- | ------------------ |
| `BOT_BALANCER_ENABLE_SUPREMACY`        | Supremacy          |
| `BOT_BALANCER_ENABLE_HVV`              | Heroes vs Villains |
| `BOT_BALANCER_ENABLE_GALACTIC_ASSAULT` | Galactic Assault   |
| `BOT_BALANCER_ENABLE_BLAST`            | Blast              |
| `BOT_BALANCER_ENABLE_EWOK_HUNT`        | Ewok Hunt          |
| `BOT_BALANCER_ENABLE_CO_OP`            | Co-Op              |
| `BOT_BALANCER_ENABLE_STRIKE`           | Strike             |
| `BOT_BALANCER_ENABLE_EXTRACTION`       | Extraction         |
| `BOT_BALANCER_ENABLE_JETPACK_CARGO`    | Jetpack Cargo      |

#### BF+ and IOI Modes

| Variable                               | Mode                    |
| -------------------------------------- | ----------------------- |
| `BOT_BALANCER_ENABLE_SUPREMACY_UR`     | Supremacy Unrestricted  |
| `BOT_BALANCER_ENABLE_REINFORCEMENT`    | Reinforcement Clash     |
| `BOT_BALANCER_ENABLE_HERO_EXTRACT`     | Hero Extraction         |
| `BOT_BALANCER_ENABLE_TURNING_PT`       | Turning Point           |


Example:

```bash
BOT_BALANCER_ENABLE_HVV=false
```


## Player Balancing

When a player joins a server:

* The plugin checks team sizes (excluding bots)
* The player is placed on the smaller team
* Per team bot counts are recalculated


## Bot Calculation Logic

For each game mode the following are calculated:

* Desired bot density (without human players):

```
floor((modeMaxPlayers * gameDensity) / 2)
```

* Number of bots per team (taking into account human players):

```
bots = max(0, desiredBotDensity - humanPlayers)
```

This ensures:

* No team overfilling
* Team sizes are balanced
* Proper scaling as players leave or join a server

>Note: the variable names listed above are different than the names in the lua files for 
purposes of clarity



## Additional Plugin Behavior

* Bot balancing is **disabled automatically** for game modes not listed in `game_modes.lua`
* Uses the following `AutoPlayers` server settings internally:

  * `forceFillGameplayBotsTeam1`
  * `forceFillGameplayBotsTeam2`
* Auto-shuffles teams at the start of each game by calling `Kyber.EnableShuffleTeams = 1` internally
* Adds a delay after events (join/leave/level load) to ensure players and levels are fully initialized



## Debug Logging

Enable debug output with:

```bash
KYBER_DEV_MODE=1
```

or

```bash
KYBER_LOG_LEVEL=debug
```


## Credits

### Original BotBalancer Plugin:

* BattleDash
* Magix
* Armchair Developers

### Enhancements & Additions for BotBalancerPlus:

* LevelDreadnought



