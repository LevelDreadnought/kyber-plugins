-- local TimerModule = require "common/timer"
-- local Timer = TimerModule.Timer
-- local SetTimeout = TimerModule.SetTimeout

-- prints text to the debug log only when env is set
local DebugLog = function(s)
    if (os.getenv("KYBER_DEV_MODE") ~= nil) or ((os.getenv("KYBER_LOG_LEVEL") or ""):lower() == "debug") then
        print("[Debug] " .. s)
    end
end


-- ============================================================
-- Kyber End-of-Game Player Stats Logger
-- ============================================================
-- Prints player stats to server log when a game completes
-- Compatible with a docker sidecar for discord integration
-- ============================================================

local isHvv = false

-- Listen for end-of-level event
EventManager.Listen("Level:Complete", function()

    -- debug isHvv check
    if isHvv then
        DebugLog("[gamemode] isHvv = true")
    end
    if not isHvv then
        DebugLog("[gamemode] isHvv = false")
    end

    print("====================================================")
    print("[StatsLogger] Match Complete - Player Stats Summary")
    print("====================================================")

    -- Get all current players
    local players = PlayerManager.GetPlayers()

    if players == nil or #players == 0 then
        print("[StatsLogger] No players found.")
        print("====================================================")
        return
    end

    for _, player in ipairs(players) do

        -- Safety check
        if player ~= nil then
            local name = player.name or "Unknown"
            local id = player.playerId or "N/A"
            local team = player.team or "N/A"
            local battlepoints = player.battlepoints or 0
            local score = player.score or 0
            local kills = player.kills or 0
            local assists = player.assists or 0
            local deaths = player.deaths or 0

            -- use either score or battlepoints depending on game-mode
            -- if using score
            if isHvv then
                print(string.format(
                    "[Player] Name: %s | ID: %s | Team: %s | Score: %d | K: %d | A: %d | D: %d",
                    name,
                    id,
                    team,
                    score,
                    kills,
                    assists,
                    deaths
                ))
            end

            -- if using battlepoints
            if not isHvv then
                print(string.format(
                "[Player] Name: %s | ID: %s | Team: %s | Score: %d | BP: %d | K: %d | A: %d | D: %d",
                name,
                id,
                team,
                score,
                battlepoints,
                kills,
                assists,
                deaths
            ))
            end


        end
    end

    print("====================================================")
end)

-- check game-mode to determine if battlepoints or score are used
EventManager.Listen("ResourceManager:PartitionLoaded", function(name, instance)

    -- only load assets with game-mode types
    if instance.typeInfo.name ~= "GameModeInformationAsset" then
        return
    end

    -- will eventually track loaded gamemodes on server start

end)

EventManager.Listen("Level:Loaded", function(levelName, gameModeId)

    -- set isHvv to true if the game-mode is HvV
    if gameModeId == "HeroesVersusVillains" then
        DebugLog("HvV game-mode detected")
        isHvv = true
    else
        -- set isHvv to false if game-mode is not HvV
        DebugLog("non-hvv game-mode detected")
        isHvv = false
    end

end)