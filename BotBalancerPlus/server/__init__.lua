-- Enhanced Bot Balancer plugin with additional features and support for all Kyber,
-- BF+, BF Expanded, and vanilla BF2 game-modes

-- Credits: 
--  Original code - BattleDash, Magix, Armchair Developers
--  Changes & additions - LevelDreadnought

local TimerModule = require "common/timer"
local SetTimeout = TimerModule.SetTimeout

-- default game-modes info and configuration
local gameModeConfig = require "game_modes"
-- default game-modes table: stores name, default player count, and enabled or disabled
local gameModes = gameModeConfig.gameModes
-- game-mode to player count override map
local modeToPlayerCountMap = gameModeConfig.modeToPlayerCountMap


-- prints text to the debug log only when env is set
local function debugLog(s)

    -- get env vars
    local devMode = os.getenv("KYBER_DEV_MODE")
    local logLevel = (os.getenv("KYBER_LOG_LEVEL") or ""):lower()

    if (devMode ~= nil) or (logLevel == "debug") then

        print("[Debug] " .. s)

    end
end

-- This is the desired game density, which is the percentage of the maximum number of players
-- If it's 80%, and the maximum number of players is 8, then the desired number of players is 6.
-- This is used to determine how many bots should be added or removed.
--
-- We don't want to add too many bots, because a game completely full of bots is not fun,
-- and we want to leave room for human players to join.
-- value must be between 0.1 and 1
local desiredGameDensity = 0.8

-- max stable player count for dedicated servers
local ServerPlayerLimit = 40

-- game-mode player count overrides
-- this allows the mode's default player count to be changed for large servers,
-- for example, HvV Chaos with 40 players instead of the HvV default of 8

-- 0 = no override
local PlayerCount = {}

PlayerCount.Supremacy            = 0
PlayerCount.EwokHunt             = 0
PlayerCount.JetpackCargo         = 0
PlayerCount.Extraction           = 0
PlayerCount.CoOp                 = 0
PlayerCount.GalacticAssault      = 0
PlayerCount.HvV                  = 40
PlayerCount.Blast                = 40
PlayerCount.Strike               = 0
-- bf+ and IOI game-modes
PlayerCount.SupremacyUr          = 0    -- supremacy unrestricted
PlayerCount.ReinforcementClash   = 0
PlayerCount.HeroExtraction       = 0
PlayerCount.TurningPoint         = 0



-- environment variables to override default settings and player counts
local SupremacyPlayers <const>        = "BOT_BALANCER_SUPREMACY_PLAYERS"
local EwokHuntPlayers <const>         = "BOT_BALANCER_EWOK_PLAYERS"
local JetpackCargoPlayers <const>     = "BOT_BALANCER_JETPACK_PLAYERS"
local ExtractionPlayers <const>       = "BOT_BALANCER_EXTRACTION_PLAYERS"
local CoOpPlayers <const>             = "BOT_BALANCER_CO_OP_PLAYERS"
local GalacticAssaultPlayers <const>  = "BOT_BALANCER_GALACTIC_PLAYERS"
local HvvPlayers <const>              = "BOT_BALANCER_HVV_PLAYERS"
local BlastPlayers <const>            = "BOT_BALANCER_BLAST_PLAYERS"
local StrikePlayers <const>           = "BOT_BALANCER_STRIKE_PLAYERS"
-- BF+ and IOI game-modes
local SupremacyUrPlayers <const>      = "BOT_BALANCER_SUPREMACY_UR_PLAYERS"
local ReinforcementClPlayers <const>  = "BOT_BALANCER_REINFORCEMENT_PLAYERS"
local HeroExtractionPlayers <const>   = "BOT_BALANCER_HERO_EXTRACT_PLAYERS"
local TurningPointPlayers <const>     = "BOT_BALANCER_TURNING_PT_PLAYERS"


local SupremacyEnabled <const>        = "BOT_BALANCER_ENABLE_SUPREMACY"
local EwokHuntEnabled <const>         = "BOT_BALANCER_ENABLE_EWOK_HUNT"
local JetpackCargoEnabled <const>     = "BOT_BALANCER_ENABLE_JETPACK_CARGO"
local ExtractionEnabled <const>       = "BOT_BALANCER_ENABLE_EXTRACTION"
local CoOpEnabled <const>             = "BOT_BALANCER_ENABLE_CO_OP"
local GalacticAssaultEnabled <const>  = "BOT_BALANCER_ENABLE_GALACTIC_ASSAULT"
local HvVEnabled <const>              = "BOT_BALANCER_ENABLE_HVV"
local BlastEnabled <const>            = "BOT_BALANCER_ENABLE_BLAST"
local StrikeEnabled <const>           = "BOT_BALANCER_ENABLE_STRIKE"
-- BF+ and IOI game-modes
local SupremacyUrEnabled <const>      = "BOT_BALANCER_ENABLE_SUPREMACY_UR"
local ReinforcementClEnabled <const>  = "BOT_BALANCER_ENABLE_REINFORCEMENT"
local HeroExtractionEnabled <const>   = "BOT_BALANCER_ENABLE_HERO_EXTRACT"
local TurningPointEnabled <const>     = "BOT_BALANCER_ENABLE_TURNING_PT"

-- bot balancing settings
local GameDensityEnvVar <const>       = "BOT_BALANCER_GAME_DENSITY"
local ServerLimitEnvVar <const>       = "BOT_BALANCER_SERVER_PLAYER_LIMIT"



-- This is so we don't touch the player manager before it is actually constructed.
-- Set to true once Server:Init has fired
local hasServerInitialized = false


-- This is current the game mode that we're balancing bots for.
local gameMode = nil


-- #########################################################

-- environment variable functions

-- gets env var and checks if it is empty or nil
local function getEnv(name)
    local v = os.getenv(name)
    if v == nil or v == "" then
        return nil
    end
    return v
end

-- parse env var options into bool and check format
local function parseBool(v)
    v = v:lower()
    if v == "1" or v == "true" or v == "yes" or v == "on" then
        return true
    end
    if v == "0" or v == "false" or v == "no" or v == "off" then
        return false
    end
    return nil
end

-- parse env var options into number and check format
local function parseNumber(v)
    local n = tonumber(v)
    if n == nil then
        return nil
    end
    return n
end

-- checks if game-mode is enabled
function IsGameModeEnabled(mode)
    if gameModes[mode] and gameModes[mode].enabled then
        return true
    end
    -- if not enabled
    return false
end

-- #########################################################

-- apply environment variable overrides if set and not nil
-- print env override to the debug log

-- player count override table
local PlayerCountEnvMap = {
    Supremacy = SupremacyPlayers,
    EwokHunt = EwokHuntPlayers,
    JetpackCargo = JetpackCargoPlayers,
    Extraction = ExtractionPlayers,
    CoOp = CoOpPlayers,
    GalacticAssault = GalacticAssaultPlayers,
    HvV = HvvPlayers,
    Blast = BlastPlayers,
    Strike = StrikePlayers,

    -- BF+ / IOI modes
    SupremacyUr = SupremacyUrPlayers,
    ReinforcementClash = ReinforcementClPlayers,
    HeroExtraction = HeroExtractionPlayers,
    TurningPoint = TurningPointPlayers
}

-- game-mode enabled override table
local ModeEnabledEnvMap = {
    [SupremacyEnabled] = {"Mode1"},
    [EwokHuntEnabled] = {"Mode3"},
    [JetpackCargoEnabled] = {"ModeC"},
    [ExtractionEnabled] = {"Mode5"},
    [CoOpEnabled] = {"Mode9", "ModeDefend"},
    [GalacticAssaultEnabled] = { "PlanetaryBattles", "IOIGANoFun", "IOIGAAlternateMaps"},
    [HvVEnabled] = {"HeroesVersusVillains", "IOIHvsVAlt02", "IOIHvsVAlt03"},
    [BlastEnabled] = {"Blast", "SkirmishBlast"},
    [StrikeEnabled] = {"PlanetaryMissions"},

    -- BF+ / IOI modes
    [SupremacyUrEnabled] = {"IOISupremacyUnrestricted"},
    [ReinforcementClEnabled] = {"IOIRvsRAlt01", "IOIRvsRAlt02", "IOIRvsRAlt03"},
    [HeroExtractionEnabled] = {"IOIHeroExtraction"},
    [TurningPointEnabled] = {"IOITurningPoint"}
}

do
    local v

    -- checks player count override env variables
    for key, envVar in pairs(PlayerCountEnvMap) do
        v = getEnv(envVar)
        if v then
            local n = parseNumber(v)
            if n and n > 0 then
                PlayerCount[key] = n
                debugLog("Env override: " .. key .. "Players = " .. n)
            end
        end
    end

    -- checks game-mode enabled override env variables
    for envVar, modeList in pairs(ModeEnabledEnvMap) do
        v = getEnv(envVar)
        if v then
            local b = parseBool(v)
            if b ~= nil then
                for _, modeId in ipairs(modeList) do
                    if gameModes[modeId] then
                        gameModes[modeId].enabled = b
                    end
                end
                debugLog("Env override: " .. envVar .. " = " .. tostring(b))
            end
        end
    end

    -- bot balancing settings

    -- checks desiredGameDensity
    v = getEnv(GameDensityEnvVar)
    if v then
        local n = parseNumber(v)
        if n and n >= 0.1 and n <= 1 then
            desiredGameDensity = n
            debugLog("Env override: desiredGameDensity = " .. n)
        end
    end

    -- checks server player limit
    v = getEnv(ServerLimitEnvVar)
    if v then
        local n = parseNumber(v)
        if n and n > 0 then
            ServerPlayerLimit = n
        end
    end


end

-- safety check for game density
desiredGameDensity = math.max(0.1, math.min(desiredGameDensity, 1.0))

-- #########################################################

function getTeamCounts()
    -- Count up the current human players on each team.
    local teamCounts = {0, 0}

    local players = PlayerManager.GetPlayers()
    for _, player in ipairs(players) do
        if player.isBot then
            goto continue
        end

        local team = player.team
        teamCounts[team] = (teamCounts[team] or 0) + 1
        ::continue::
    end

    return teamCounts
end


-- get current player count of non ai
function getPlayerCount()
    -- Quick and dirty method of just adding up all the numbers from getTeamCounts()
    local teamCounts = getTeamCounts()
    return teamCounts[1] + teamCounts[2]
end


-- This function will be called every time a player joins or leaves the
-- server or if a new level is loaded
function balanceBots()
    -- A level with a gamemode we're aware of is not currently loaded.
    if gameMode == nil then
        return
    end

    -- If you press the '~' key while in-game, and type AutoPlayers, you will see
    -- the settings that we're modifying here.
    local settings = Console.GetSettings("AutoPlayers")
    if settings == nil then
        print("AutoPlayers settings not found! Bot balancing disabled.")
        -- timer:cancel()
        return
    end

    -- Count up the current human players on each team.
    local teamCounts = getTeamCounts()

    -- Calculate how many bots we currently need on each team.
    local desiredPlayersPerTeam = math.floor(math.floor(gameMode.maxPlayers * desiredGameDensity) / 2)

    local neededBotsPerTeam = {}
    for team, count in pairs(teamCounts) do
        neededBotsPerTeam[team] = math.max(0, desiredPlayersPerTeam - count)
    end

    -- Apply these values to the AutoPlayers settings.
    function BalanceTeam(team, settingsVariable)
        local neededBots = neededBotsPerTeam[team]
        if settings[settingsVariable] == neededBots then
            return
        end

        settings[settingsVariable] = neededBots
        print(string.format("Balancing team %d: %d bots", team, neededBots))
    end

    BalanceTeam(1, "forceFillGameplayBotsTeam1")
    BalanceTeam(2, "forceFillGameplayBotsTeam2")
end


EventManager.Listen("Server:Init", function()
    hasServerInitialized = true
end)


function ResetBots()
    local settings = Console.GetSettings("AutoPlayers")
    if settings == nil then
        print("AutoPlayers settings not found! Bot balancing disabled.")
        return
    end

    settings.forceFillGameplayBotsTeam1 = 0
    settings.forceFillGameplayBotsTeam2 = 0
    gameMode = nil
end

-- adds a delay to allow server events (Level:Loaded, ServerPlayer:Disconnect)
-- to fully stabilize in the frostbite engine before bot balancing
local function ScheduleBalance(time)
    SetTimeout(balanceBots, time)
end


-- This event is triggered when a level is loaded.
-- The game modes will have been loaded by this point,
-- so we can determine the max player count of the mode.
EventManager.Listen("Level:Loaded", function(levelName, gameModeId)
    if gameModes[gameModeId] == nil then
        print("Unknown or unsupported game mode ID: " .. gameModeId)
        ResetBots()
        return
    end

    if not IsGameModeEnabled(gameModeId) then
        print("Game mode not enabled: " .. gameModes[gameModeId].name .. " (" .. gameModeId .. ")")
        ResetBots()
        return
    end

    -- sets current game mode
    local currentMode = gameModes[gameModeId]

    gameMode = {
        name = currentMode.name,
        maxPlayers = currentMode.maxPlayers,
        enabled = currentMode.enabled
    }

    -- apply PlayerCount override if set (>0)
    local key = modeToPlayerCountMap[gameModeId]
    if key ~= nil then
        local override = PlayerCount[key]
        if override ~= nil and override > 0 then
            debugLog("Applying PlayerCount override for " .. key .. ": " .. override)

            local effectiveMax = override

            -- apply server safety cap
            if ServerPlayerLimit ~= nil and ServerPlayerLimit > 0 then
                if effectiveMax > ServerPlayerLimit then
                    debugLog("Clamping override to server slot limit: " .. ServerPlayerLimit)
                    effectiveMax = ServerPlayerLimit
                end
            end

            gameMode.maxPlayers = effectiveMax

        end
    end

    print(string.format("Balancing bots for game mode '%s' with %d max players", gameMode.name, gameMode.maxPlayers))

    Console.Execute(string.format("Kyber.Broadcast **KYBER:** Bot balancing enabled with %.0f%% backfill capacity.", desiredGameDensity * 100))

    -- enable shuffle teams
    local kyberSettings = Console.GetSettings("Kyber")
    kyberSettings.EnableShuffleTeams = 1

    -- balance bots
    ScheduleBalance(12)

end)

-- Team balancing

-- Finds the best fit team by looking at both team player counts, ignoring bots
-- If equal, set team to first
function balancePlayer(player)
    local teamCounts = getTeamCounts()

    if teamCounts[1] > teamCounts[2] then
        player:SetTeam(2)
    else
        -- then teams are either equal (which we want to set to team 1) or
        -- Team 2 has more and we want to set to team 1
        player:SetTeam(1)
    end

    print(string.format("Balanced player '%s' to team %d.", player.name, player.team))
end


-- This event is triggered when a player joins the server.
-- We will determine the best team to set them to here
EventManager.Listen("ServerPlayer:Joined", function(player)
    if player == nil then
        print("Given invalid player on Server:PlayerJoined")
        return
    end

    -- Only run the player balancer if bot balancer is enabled for that game-mode
    if gameMode == nil or not gameMode.enabled then
        return
    end

    balancePlayer(player)

    -- balance bots
    ScheduleBalance(2)
end)

-- runs balanceBots when a player leaves the server
EventManager.Listen("ServerPlayer:Disconnect", function (player)
    debugLog("PLayer left the server. ServerPlayer:Disconnect")
    ScheduleBalance(2)
end)

