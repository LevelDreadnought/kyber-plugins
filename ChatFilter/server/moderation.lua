-- this lua file contains the moderation logic used in ChatFilter as well as
-- the current moderation state (strikes, mutedPlayers, and bannedPlayers)

-- credit: LevelDreadnought

local Moderation = {}

-- internal moderation state
local strikes = {}
local mutedPlayers = {}
local bannedPlayers = {}

-- config variables reference
local ChatFilter

-- initialize ChatFilter configuration
function Moderation.init(filter)
    ChatFilter = filter
end

--#############################################

-- current moderation state accessors
function Moderation.getStrikes()
    return strikes
end

function Moderation.getMutedPlayers()
    return mutedPlayers
end

function Moderation.getBannedPlayers()
    return bannedPlayers
end

--#############################################

-- moderation logic and functions (moved here from __init__.lua)

-- checks if the passed player is muted
function Moderation.isMuted(playerId)
    local mute = mutedPlayers[playerId]
    if not mute then return false end

     -- permanent mute
    if mute.expires == nil then
        return true
    end

    -- timed mute
    if mute.expires and os.time() >= mute.expires then
        return false
    end

    return true
end

-- add strike to passed player by ID
function Moderation.addStrike(playerId)
    if not ChatFilter.EnableStrikeTrack then return 0 end

    strikes[playerId] = (strikes[playerId] or 0) + 1
    return strikes[playerId]
end

-- sets a player as muted by ID
function Moderation.mutePlayer(playerId)
    if not ChatFilter.EnableAutoMute then return end

    -- convert to seconds
    local durationSeconds = ChatFilter.MuteDuration

    if durationSeconds == 0 then
        -- permanent mute when 0
        mutedPlayers[playerId] = {
            expires = nil
        }
    else
        mutedPlayers[playerId] = {
            expires = os.time() + durationSeconds
        }
    end
end

-- kicks player after a certain number of strikes
function Moderation.kickPlayer(player, reason)
    if not ChatFilter.EnableAutoKick then return end
    if player then
        player:Kick(reason or "Auto-kicked by server moderation")
    end
end

-- bans player after a certain number of strikes
function Moderation.banPlayer(playerId, name, duration, reason, manual)
    local expires = nil

    if duration and duration > 0 then
        expires = os.time() + duration
    end

    bannedPlayers[playerId] = {
        name = name,
        time = os.time(),
        expires = expires,
        reason = reason,
        manual = manual or false
    }
end

-- checks if player is banned and for how long
function Moderation.isBanned(playerId)
    local ban = bannedPlayers[playerId]
    if not ban then return false end

    if ban.expires == nil then
        return true
    end

    if os.time() >= ban.expires then
        return false
    end

    return true
end

-- removes expired bans and mutes from the list
function Moderation.pruneExpiredEntries()

    local now = os.time()

    -- prune bans
    for id, data in pairs(bannedPlayers) do
        if data.expires and data.expires <= now then
            bannedPlayers[id] = nil
            strikes[id] = nil
        end
    end

    -- prune mutes
    for id, data in pairs(mutedPlayers) do
        if data.expires and data.expires <= now then
            mutedPlayers[id] = nil
        end
    end
end

-- state management function for mutedPlayers and bannedPlayers
function Moderation.replaceState(newBans, newMutes)
    -- clear existing tables
    for k in pairs(bannedPlayers) do
        bannedPlayers[k] = nil
    end

    for k in pairs(mutedPlayers) do
        mutedPlayers[k] = nil
    end

    -- copy in new data to tables
    for k, v in pairs(newBans) do
        bannedPlayers[k] = v
    end

    for k, v in pairs(newMutes) do
        mutedPlayers[k] = v
    end
end

return Moderation