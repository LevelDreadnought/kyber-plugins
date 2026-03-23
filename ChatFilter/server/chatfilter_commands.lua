-- player chat command collection and logic for ChatFilter
-- exports a chat command registry and a command dispatcher

-- credit: LevelDreadnought

local Commands = {}
local shared = {}
local ChatFilter

-- registry of all server commands
Commands.registry = {}

-- adds shared functions, tables, and ChatFilter controls from __init__.lua
function Commands.init(filter, context)
    ChatFilter = filter
    shared = context
end

-- adds commands to registry
function Commands.register(name, options)
    Commands.registry[name] = options
end


-- ##################################################
-- commands

-- toggle block message
Commands.register("enableblockmessage", {

    permission = "admin",
    allowRemote = false,

    handler = function (cmd)

        local args = cmd.args

        ChatFilter.BlockMessage = true
        return true, "BlockMessage enabled", nil

    end
})
Commands.register("disableblockmessage", {

    permission = "admin",
    allowRemote = false,

    handler = function (cmd)

        local args = cmd.args

        ChatFilter.BlockMessage = false
        return true, "BlockMessage disabled", nil

    end
})

-- toggle logging
Commands.register("enablelogging", {

    permission = "admin",
    allowRemote = false,

    handler = function (cmd)

        local args = cmd.args

        ChatFilter.EnableLogging = true
        return true, "Logging enabled", nil

    end
})
Commands.register("disablelogging", {

    permission = "admin",
    allowRemote = false,

    handler = function (cmd)

        local args = cmd.args

        ChatFilter.EnableLogging = false
        return true, "Logging disabled", nil

    end
})

-- toggle host alert
Commands.register("enablehostalert", {

    permission = "admin",
    allowRemote = false,

    handler = function (cmd)

        local args = cmd.args

        ChatFilter.EnableHostAlert = true
        return true, "EnableHostAlert enabled", nil

    end
})
Commands.register("disablehostalert", {

    permission = "admin",
    allowRemote = false,

    handler = function (cmd)

        local args = cmd.args

        ChatFilter.EnableHostAlert = false
        return true, "EnableHostAlert disabled", nil

    end
})

-- toggle strike tracking
Commands.register("enablestriketrack", {

    permission = "admin",
    allowRemote = false,

    handler = function (cmd)

        local args = cmd.args

        ChatFilter.EnableStrikeTrack = true
        return true, "StrikeTrack enabled", nil

    end
})
Commands.register("disablestriketrack", {

    permission = "admin",
    allowRemote = false,

    handler = function (cmd)

        local args = cmd.args

        ChatFilter.EnableStrikeTrack = false
        return true, "StrikeTrack disabled", nil

    end
})

-- toggle auto mute
Commands.register("enableautomute", {

    permission = "admin",
    allowRemote = false,

    handler = function (cmd)

        local args = cmd.args

        ChatFilter.EnableAutoMute = true
        return true, "AutoMute enabled", nil

    end
})
Commands.register("disableautomute", {

    permission = "admin",
    allowRemote = false,

    handler = function (cmd)

        local args = cmd.args

        ChatFilter.EnableAutoMute = false
        return true, "AutoMute disabled", nil

    end
})

-- set max strikes (strikes to auto-mute at)
Commands.register("setmaxstrikes", {

    permission = "admin",
    allowRemote = false,

    handler = function (cmd)

        local args = cmd.args

        if #args < 1 then
            return false, "Usage: /setmaxstrikes <strikeCount>", 0
        end

        local value = tonumber(args[1])
        if not value or value < 0 then -- checks if value set is actually a valid number
            return false, "Invalid number", 0
        end

        ChatFilter.MaxStrikes = value
        return true, string.format("MaxStrikes set to " .. value), nil

    end
})

-- set strikes to auto-kick player at
Commands.register("setkickat", {

    permission = "admin",
    allowRemote = false,

    handler = function (cmd)

        local args = cmd.args

        if #args < 1 then
            return false, "Usage: /setkickat <strikeCount>", 0
        end

        local value = tonumber(args[1])
        if not value or value < 0 then -- checks if value set is actually a valid number
            return false, "Invalid number", 0
        end

        ChatFilter.KickAtStrikes = value
        return true, string.format("KickAtStrikes set to " .. value), nil

    end
})

-- set strikes to auto-ban player at
Commands.register("setbanat", {

    permission = "admin",
    allowRemote = false,

    handler = function (cmd)

        local args = cmd.args

        if #args < 1 then
            return false, "Usage: /setbanat <strikeCount>", 0
        end

        local value = tonumber(args[1])
        if not value or value < 0 then -- checks if value set is actually a valid number
            return false, "Invalid number", 0
        end

        ChatFilter.BanAtStrikes = value
        return true, string.format("BanAtStrikes set to " .. value), nil

    end
})

-- set auto-mute duration
Commands.register("setmuteduration", {

    permission = "admin",
    allowRemote = false,

    handler = function (cmd)

        local args = cmd.args

        if #args < 1 then
            return false, "Usage: /setmuteduration <strikeCount>", 0
        end

        local duration = shared.parseDuration(args[1])
        if duration == nil then -- checks if value set is actually a valid duration time
            return false, "Invalid duration format", 0
        end

        ChatFilter.MuteDuration = duration

        return true, string.format("MuteDuration set to " .. shared.formatDuration(duration)), nil

    end
})

-- set auto-ban duration
Commands.register("setautobanduration", {

    permission = "admin",
    allowRemote = false,

    handler = function (cmd)

        local args = cmd.args

        if #args < 1 then
            return false, "Usage: /setautobanduration <strikeCount>", 0
        end

        local duration = shared.parseDuration(args[1])
        if duration == nil then -- checks if value set is actually a valid duration time
            return false, "Invalid duration format", 0
        end

        ChatFilter.AutoBanDuration = duration

        return true, string.format("AutoBanDuration set to " .. shared.formatDuration(duration)), nil

    end
})

-- mute player by passing playerName in chat
Commands.register("mute", {

    permission = "moderator",
    allowRemote = true,

    handler = function(cmd)

        local args = cmd.args

        -- define command source
        local isRemote = cmd.source

        if #args < 2 then
            return false, "Usage: /mute <playerName> [time (0 for permanent)]", 0
        end

        local targetName = args[1]
        local duration = shared.parseDuration(args[2])

        -- convert player name to player ID
        local targetId, resolvedName = shared.getPlayerIdByName(targetName)

        if not targetId then
            return false, "Player not found", 0
        end

        -- prevent muting admins
        if shared.isAdmin(targetId) then
            return false, "Cannot mute an admin", 0
        end

        -- prevent moderators from muting other moderators
        if shared.isModerator(targetId) and not cmd.isAdmin then
            return false, "Cannot mute another moderator", 0
        end

        -- apply mute
        shared.mutedPlayers[targetId] = {
            expires = (duration and duration > 0)
            and (os.time() + duration)
            or nil
        }

        -- return log differently if command origin is remote or in-game

        if isRemote == "remote" then
            -- return mute event from remote command
            return true, "Player " .. targetName .. " muted for " .. args[2]
        elseif isRemote == "game" then
            -- return mute event from in-game command
            return true, string.format(cmd.player.name .. " muted " .. resolvedName .. " (" .. targetId .. ")"), 2
        else
            return false, "Command source error", 0
        end


    end
})

-- unmute player by passing playerName in chat
Commands.register("unmute", {

    permission = "moderator",
    allowRemote = true,

    handler = function(cmd)

        local args = cmd.args

        if #args < 1 then
            return false, "Usage: /unmute <playerName>", 0
        end

        local targetName = args[1]
        local targetId, resolvedName = shared.getPlayerIdByName(targetName)

        if not targetId then
            return false, string.format("Player not found: " .. targetName), 0
        end

        -- set muted player to nil
        shared.mutedPlayers[targetId] = nil

        -- return log differently if command origin is remote or in-game
        -- define command source
        local isRemote = cmd.source

        if isRemote == "remote" then
            -- return unmute event from remote command
            return true, "Admin unmuted player " .. targetName
        elseif isRemote == "game" then
            -- return unmute event from in-game command
            return true, string.format(cmd.player.name .. " unmuted " .. resolvedName .. " (" .. targetId .. ")"), 2
        else
            return false, "Command source error", 0
        end


    end
})

-- manual ban by passing playerName in chat
Commands.register("ban", {

    permission = "moderator",
    allowRemote = true,

    handler = function(cmd)

        local args = cmd.args

        -- define command source
        local isRemote = cmd.source

        if #args < 2 then
            return false, "Usage: /ban <playerName> <duration> <reason>", 0
        end

        local targetName = args[1]
        local targetId, resolvedName = shared.getPlayerIdByName(targetName)

        -- parses ban duration and reason from chat, reason default set if empty
        local durationInput = args[2]
        local duration = shared.parseDuration(durationInput)

        local reasonStartIndex = duration and 3 or 2
        local reason = table.concat(args, " ", reasonStartIndex)
        if reason == "" then
            reason = "You have been banned"
        end

        -- check if player exists and is online
        if not targetId then
            return false, string.format("Player not found: " .. targetName), 0
        end

        -- prevent banning admins
        if shared.isAdmin(targetId) then
            return false, "Cannot ban an admin", 0
        end

        -- prevent moderators from banning other moderators
        if shared.isModerator(targetId) and not cmd.isAdmin then
            return false, "Cannot ban another moderator", 0
        end

        -- checks if player is already banned
        if shared.isBanned(targetId) then
            return false, string.format(resolvedName .. " is already banned"), 0
        end

        -- add to banned list with a manual ban marker and reason
        shared.banPlayer(targetId, resolvedName, duration, reason, true)

        -- reset strikes
        shared.strikes[targetId] = nil

        -- log ban action
        local durationText = duration and shared.formatDuration(duration) or "permanently"
        local logText = string.format(cmd.player.name .. " banned " .. resolvedName .. " (" .. targetId .. ")"
            .. " for " .. durationText
            .. " | Reason: " .. reason)


        -- kick immediately if online
        local targetPlayer = shared.getPlayerById(targetId)
        if targetPlayer then
            targetPlayer:Kick(reason)
        end

        -- return log differently if command origin is remote or in-game

        if isRemote == "remote" then
            -- return ban event from remote command
            return true, "Player " .. targetName ..  " banned for " .. args[2]
        elseif isRemote == "game" then
            -- return ban event log text from in-game command
            return true, logText, 2
        else
            return false, "Command source error", 0
        end


    end
})

-- manual offline ban by passing playerId
Commands.register("banoffline", {

    permission = "moderator",
    allowRemote = true,

    handler = function(cmd)

        local args = cmd.args

        -- define command source
        local isRemote = cmd.source

        if #args < 2 then
            return false, "Usage: /banoffline <playerId> [duration] [reason]", 0
        end

        -- parse playerId
        local targetId = tonumber(args[1])
        if not targetId then
            return false, string.format("Invalid playerId: " .. args[1]), 0
        end

        -- prevent banning admins
        if shared.isAdmin(targetId) then
            return false, "Cannot ban an admin", 0
        end

        -- prevent moderators from banning other moderators
        if shared.isModerator(targetId) and not cmd.isAdmin then
            return false, "Cannot ban another moderator", 0
        end

        -- checks if player is already banned
        if shared.isBanned(targetId) then
            return false, string.format("PlayerId " .. targetId .. " is already banned"), 0
        end

        -- parse duration
        local durationInput = args[2]
        local duration = shared.parseDuration(durationInput)

        -- parse reason
        local reasonStartIndex = duration and 3 or 2
        local reason = table.concat(args, " ", reasonStartIndex)

        if reason == "" then
            reason = "You have been banned"
        end

        -- add to banned list with a manual ban marker and reason
        shared.banPlayer(targetId, "OfflinePlayer", duration, reason, true)

        local durationText = duration and shared.formatDuration(duration) or "permanently"
        local logText = string.format(cmd.player.name .. " offline-banned OfflinePlayer (" .. targetId .. ")"
            .. " for " .. durationText
            .. " | Reason: " .. reason)

        -- return log differently if command origin is remote or in-game

        if isRemote == "remote" then
            -- return banoffline event from remote command
            return true, "Player " .. targetId .. " offline-banned for " .. args[2]
        elseif isRemote == "game" then
            -- return banoffline event log text from in-game command
            return true, logText, 2
        else
            return false, "Command source error", 0
        end

    end
})

-- unbans player by passing playerID in chat
Commands.register("unban", {

    permission = "moderator",
    allowRemote = true,

    handler = function(cmd)

        local args = cmd.args

        if #args < 1 then
            return false, "Usage: /unban <playerId>", 0
        end

        -- convert player ID string to int
        local targetId = tonumber(args[1])

        if not targetId then
            return false, string.format("Invalid playerId: " .. targetId), 0
        end

        -- check if player is not banned
        if not shared.bannedPlayers[targetId] then
            return false, string.format("PlayerId " .. args[1] .. " is not banned"), 0
        end

        -- set banned player to nil and reset strikes
        shared.bannedPlayers[targetId] = nil
        shared.strikes[targetId] = nil

        -- return log differently if command origin is remote or in-game
        -- define command source
        local isRemote = cmd.source

        if isRemote == "remote" then
            -- return unban event from remote command
            return true, "Unbanned player " .. targetId
        elseif isRemote == "game" then
            -- return unban event log text from in-game command
            return true, string.format("Admin unbanned playerId " .. targetId), 2
        else
            return false, "Command source error", 0
        end

    end
})

-- command to list all banned players
Commands.register("listbans", {

    permission = "moderator",
    allowRemote = true,

    handler = function(cmd)

        local entries = {}
        local now = os.time()

        -- remove expired bans
        shared.pruneExpiredEntries()

        for id, data in pairs(shared.bannedPlayers) do

            local name = data.name or "Unknown"
            local reason = data.reason or "No reason"
            local banType = data.manual and "Manual" or "Auto"

            local remainingText
            local originalText

            if not data.expires then
                -- Permanent
                remainingText = "Permanent"
                originalText = "Permanent"
            else
                local remaining = math.max(0, data.expires - now)
                local originalDuration = data.expires - data.time

                remainingText = shared.formatDuration(remaining)
                originalText = shared.formatDuration(originalDuration)
            end

            local entry = string.format(
                "%s (%s) | Remaining: %s | Original: %s | Type: %s | Reason: %s",
                name,
                id,
                remainingText,
                originalText,
                banType,
                reason
            )

            table.insert(entries, entry)

        end

        if #entries == 0 then
            return true, "No active bans.", nil
        else
            return true, string.format(table.concat(entries, " || ")), nil
        end


    end
})

-- command to list admins (online and offline)
Commands.register("listadmins", {

    permission = "admin",
    allowRemote = false,

    handler = function(cmd)

        local entries = {}

        for _, adminId in pairs(shared.getAdmins()) do
            local p = shared.getPlayerById(adminId)

            if p then
                local entry = string.format(p.name .. " (" .. adminId .. ")")
                table.insert(entries, entry)
            else
                -- admin is offline
                local entry = string.format("Offline (" .. adminId .. ")")
                table.insert(entries, entry)
            end
        end

        return true, string.format("Admins:\n%s", table.concat(entries, " || ")), nil

    end
})

-- command to list moderators (online and offline)
Commands.register("listmods", {

    permission = "moderator",
    allowRemote = false,

    handler = function(cmd)

        local entries = {}

        for _, modId in pairs(shared.getModerators()) do
            local p = shared.getPlayerById(modId)

            if p then
                local entry = string.format(p.name .. " (" .. modId .. ")")
                table.insert(entries, entry)
            else
                -- moderator is offline
                local entry = string.format("Offline (" .. modId .. ")")
                table.insert(entries, entry)
            end
        end

        return true, string.format("Moderators:\n%s", table.concat(entries, " || ")), nil

    end
})

-- allows a moderator or admin to change teams to 0 = spectate,
-- 1 = light, 2 = dark
Commands.register("setteam", {

    permission = "moderator",
    allowRemote = false,

    handler = function(cmd)

        local args = cmd.args

        if #args < 1 then
            return false, "Usage: /setteam <number>", 0
        end

        local value = tonumber(args[1])
        if not value or value < 0 or value > 3 then -- checks if value set is actually a valid number
            return false, "Invalid team number", 0
        end

        -- sets player team
        cmd.player:SetTeam(value)

        return true, string.format("Player %s set team to %d", cmd.player.name, value), nil

    end
})

-- enables spectate mode by setting the moderator invisible, switching to spectator
-- team, and disabling weapons, abilities, and melee (including sabers)
Commands.register("spectate", {

    permission = "moderator",
    allowRemote = false,

    handler = function(cmd)

        local args = cmd.args

        if #args < 1 then
            return false, "Usage: /spectate <boolean>", 0
        end

        local arg = args[1]

        if not arg then
            return false, "Invalid argument", 0
        end

        arg = string.lower(arg)

        if arg ~= "true" and arg ~= "false" then
            return false, "Invalid argument", 0
        end

        -- converts to boolean
        local bool = (arg == "true")

        -- true = sets to spectator team and makes player invisible
        -- false = sets player back to default team and makes player visible
        cmd.player:SetInvisible(bool)
        cmd.player:SetInputEnabled(1018135856, not bool)
        cmd.player:SetInputEnabled(871087120, not bool)
        cmd.player:SetInputEnabled(871087121, not bool)
        cmd.player:SetInputEnabled(871087126, not bool)
        cmd.player:SetInputEnabled(622237156, not bool)

        if bool then
            cmd.player:SetTeam(0)
            return true, (string.format("Player %s enabled spectate", cmd.player.name))
        end
        if not bool then
            cmd.player:SetTeam(1)
            return true, (string.format("Player %s disabled spectate", cmd.player.name))
        end

        -- bf2 input IDs:
        -- Fire = 1018135856
        -- Left ability = 871087120
        -- Middle ability = 871087121
        -- Right ability = 871087126
        -- Melee attack = 622237156

    end
})


-- ##################################################

-- handles executing command, checks permissions, and returns result of
-- the command's success (true/false), message to log (string), and log 
-- event prefix (int) back to the caller
function Commands.execute(context)
    local command = Commands.registry[context.command]

    -- access to player object
    local player = context.player
    local playerName = player and player.name or "Remote"
    local playerId = player and player.playerId or "N/A"

    if not command then
        return false, "Invalid command", 0
    end

    -- check remote permission
    if context.source == "remote" and not command.allowRemote then
        return false, "Command not allowed remotely", 0
    end

    -- admin permission check
    if command.permission == "admin" and not context.isAdmin then
        return false, string.format("Permission denied. Player " .. playerName .. " attempted command: " .. context.command), 0
    end

    -- moderator permission check
    if command.permission == "moderator" and not (context.isAdmin or context.isModerator) then
        return false, string.format("Permission denied. Player " .. playerName .. " attempted command: " .. context.command), 0
    end

    return command.handler(context)
end

return Commands
