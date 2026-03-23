local Commands = require "chatfilter_commands"

local Moderation = require "moderation"

local roles = require "admins"

local admins = roles.Admins or {}
local moderators = roles.Moderators or {}

local TimerModule = require "common/timer"
local Timer = TimerModule.Timer
local SetTimeout = TimerModule.SetTimeout

local dkjson = require "common/dkjson"

local Utils = require "common/utils"

-- initialize http
local HttpRouter = require "http_router"
local HttpServer = require "http_server"

local router = HttpRouter.new()


-- ===================================================================
-- Kyber Chat Filter Plugin
-- ===================================================================
--  - Filters and blocks banned words from game chat
--  - Normalizes input to prevent basic bypass attempts
--  - Logs violations with player name and player ID
--  - Strike tracking with auto-mute, auto-kick and auto-ban abilities
--  - Alerts online hosts in event log (wip)
--  - Admin chat commands can toggle and adjust features
--  - Remote command input and state sync supported via http
--  - Environment variables can override default settings
--
--  - Credit: LevelDreadnought
-- ===================================================================


local ChatFilter = {}


-- configuration default settings


ChatFilter.BannedWords          = require "filtered_word_list"

ChatFilter.AlertPrefix          = "Detection:"
ChatFilter.ErrorPrefix          = "Error:"
ChatFilter.ActionPrefix         = "Action:"
ChatFilter.BlockMessage         = true
ChatFilter.EnableLogging        = true
ChatFilter.EnableHostAlert      = false

-- strike / mute / kick / ban system toggles
ChatFilter.EnableStrikeTrack    = true
ChatFilter.EnableAutoMute       = true
ChatFilter.EnableAutoKick       = true
ChatFilter.EnableAutoBan        = false
ChatFilter.EnableTimedAutoBan   = true

ChatFilter.MaxStrikes           = 3      -- strikes before mute
ChatFilter.MuteDuration         = 5      -- time in minutes, (set to 0 for permanent mute)
ChatFilter.AutoBanDuration      = 60     -- time in minutes, 60 default
ChatFilter.KickAtStrikes        = 5
ChatFilter.BanAtStrikes         = 7

-- remote moderation settings
ChatFilter.EnableRemoteCommands = true

-- persistence toggles / settings
ChatFilter.EnablePersistence    = false  -- enables persistence via http -> docker image
ChatFilter.AuthToken            = "CHANGE_ME_SECRET" -- http auth token


-- environment variables

local AdditionalAdmins <const>     = "KYBER_CHAT_FILTER_ADMINS"     -- format: ="<playerId_1>:<playerId_2>"
local AdditionalModerators <const> = "KYBER_CHAT_FILTER_MODERATORS" -- format: ="<playerId_1>:<playerId_2>"

local BlockMessageEnvName <const>  = "KYBER_CHAT_FILTER_BLOCK_MESSAGE"
local LoggingEnvName <const>       = "KYBER_CHAT_FILTER_LOGGING"
local HostAlertEnvName <const>     = "KYBER_CHAT_FILTER_HOST_ALERT"
local StrikeTrackEnvName <const>   = "KYBER_CHAT_FILTER_STRIKE_TRACK"
local AutoMuteEnvName <const>      = "KYBER_CHAT_FILTER_AUTO_MUTE"
local AutoKickEnvName <const>      = "KYBER_CHAT_FILTER_AUTO_KICK"
local AutoBanEnvName <const>       = "KYBER_CHAT_FILTER_AUTO_BAN"
local TimedAutoBanEnvName <const>  = "KYBER_CHAT_FILTER_TIMED_BAN"

local MaxStrikesEnvName <const>    = "KYBER_CHAT_FILTER_MAX_STRIKES"
local MuteDurationEnvName <const>  = "KYBER_CHAT_FILTER_MUTE_TIME"
local BanDurationEnvName <const>   = "KYBER_CHAT_FILTER_BAN_TIME"
local KickAtEnvName <const>        = "KYBER_CHAT_FILTER_KICK_AT"
local BanAtEnvName <const>         = "KYBER_CHAT_FILTER_BAN_AT"

local RemoteModEnvName <const>     = "KYBER_CHAT_FILTER_REMOTE_COMMANDS"

local PersistenceEnvName <const>   = "KYBER_CHAT_FILTER_PERSISTENCE"
local HttpAuthToken <const>        = "KYBER_CHAT_FILTER_AUTH"


-- environment variable maps

local BoolEnvMap = {
    [BlockMessageEnvName]  = "BlockMessage",
    [LoggingEnvName]       = "EnableLogging",
    [HostAlertEnvName]     = "EnableHostAlert",
    [StrikeTrackEnvName]   = "EnableStrikeTrack",
    [AutoMuteEnvName]      = "EnableAutoMute",
    [AutoKickEnvName]      = "EnableAutoKick",
    [AutoBanEnvName]       = "EnableAutoBan",
    [RemoteModEnvName]     = "EnableRemoteCommands",
    [PersistenceEnvName]   = "EnablePersistence",
    [TimedAutoBanEnvName]  = "EnableTimedAutoBan",
}

local NumberEnvMap = {
    [MaxStrikesEnvName]   = { key = "MaxStrikes", min = 0 },
    [MuteDurationEnvName] = { key = "MuteDuration", min = 0 },
    [BanDurationEnvName]  = { key = "AutoBanDuration",  min = 0 },
    [KickAtEnvName]       = { key = "KickAtStrikes", min = 0 },
    [BanAtEnvName]        = { key = "BanAtStrikes",  min = 0 },
}


-- internal variables
-- note: strikes, mutedPlayers, and bannedPlayers have been moved to moderation.lua

local bannedLookup  = {}
local bannedPatterns = {}



-- #########################################################

-- additional environment variable functions
-- main env var functions are located in common/utils.lua

-- adds additional admins and moderators to existing lists in admins.lua
local function addAdminByEnv(adminList, playerId)
    for _, id in ipairs(adminList) do
        if id == playerId then
            return false -- already exists
        end
    end
    table.insert(adminList, playerId)
    return true
end


-- #########################################################

-- apply environment variable overrides if set and not nil
-- print env override to the debug log

do
    local v

    -- batch process bool value env vars
    for envVar, field in pairs(BoolEnvMap) do
        v = Utils.getEnv(envVar)
        if v then
            local b = Utils.parseBool(v)
            if b ~= nil then
                ChatFilter[field] = b
                Utils.debugLog("Env override: " .. field .. " = " .. tostring(b))
            end
        end
    end

    -- batch process int value env vars
    for envVar, config in pairs(NumberEnvMap) do
        v = Utils.getEnv(envVar)
        if v then
            local n = Utils.parseNumber(v)
            if n and (not config.min or n >= config.min) then
                ChatFilter[config.key] = n
                Utils.debugLog("Env override: " .. config.key .. " = " .. n)
            end
        end
    end

    -- gets adminIds from env var and checks for dupes against the list from admin.lua
    v = Utils.getEnv(AdditionalAdmins)
    if v then
        for rawId in v:gmatch("([^:]+)") do
            -- trim whitespace just in case
            local id = tonumber(rawId:match("^%s*(.-)%s*$"))

            if id then
                local added = addAdminByEnv(admins, id)
                if added then
                    Utils.debugLog("Env override: added admin " .. id)
                end
            end
        end
    end

    -- gets moderator IDs from env var and checks for dupes against the list from admin.lua
    v = Utils.getEnv(AdditionalModerators)
    if v then
        for rawId in v:gmatch("([^:]+)") do
            local id = tonumber(rawId:match("^%s*(.-)%s*$"))

            if id then
                local added = addAdminByEnv(moderators, id)
                if added then
                    Utils.debugLog("Env override: added moderator " .. id)
                end
            end
        end
    end

    -- checks auth token env var
    v = Utils.getEnv(HttpAuthToken)
    if v then
        local token = v
        if token ~= nil then
            ChatFilter.AuthToken = token
            Utils.debugLog("Env override: AuthToken set")
        end
    end


end

-- #########################################################

-- initialize moderation.lua
Moderation.init(ChatFilter)

-- time conversion functions
-- additional time conversion functions are located in common/utils.lua

-- duration input conversion chart
-- 30    -> 30 minutes
-- 24h   -> 24 hours
-- 7d    -> 7 days
-- 0     -> permanent

-- convert mute duration (minutes/hours format) to seconds
local parsedMute = Utils.parseDuration(ChatFilter.MuteDuration)
if parsedMute then
    ChatFilter.MuteDuration = parsedMute
end

-- convert auto-ban duration to seconds
local parsedBan = Utils.parseDuration(ChatFilter.AutoBanDuration)
if parsedBan then
    ChatFilter.AutoBanDuration = parsedBan
end


-- #########################################################

-- properly handles escape characters
local function escapePattern(s)
    return s:gsub("(%W)", "%%%1")
end

-- handles three letter words and proper spaces via regex-like spaced-letter patterns
local function buildSpacedPattern(word)
    -- "ban" → b[%s%p]*a[%s%p]*n
    local pattern = {}

    for c in word:gmatch(".") do
        local escaped = escapePattern(c)
        table.insert(pattern, escaped)
    end

    -- require at least one separator somewhere in the message
    return table.concat(pattern, "[%s%p]*")
end


-- Convert banned word list into a lookup table (is much faster than an array/list)

for _, word in ipairs(ChatFilter.BannedWords) do
    local w = word:lower()
    bannedLookup[w] = true

    -- word-boundary regex to reduce false positives (%f[])
    table.insert(bannedPatterns, {
        word = w,
        boundaryPattern = "%f[%w]" .. w .. "%f[%W]",
        spacedPattern = "%f[%w]" .. buildSpacedPattern(w) .. "%f[%W]"
    })
end

-- replaces imported word list with the lookup table created above
ChatFilter.BannedWords = bannedLookup

-- general chat obfuscation pairs

local obfuscationMap = {
    { "@", "a" },
    { "4", "a" },
    { "3", "e" },
    { "1", "i" },
    { "!", "i" },
    { "0", "o" },
    { "$", "s" },
    { "5", "s" },
    { "7", "t" },
    { "8", "a" },
}


-- #########################################################

-- utility functions
-- additional utility functions can be found in common/utils.lua


-- normalizes chat message based on obfuscationMap
local function normalizeObfuscation(msg)
    for _, pair in ipairs(obfuscationMap) do
        local pattern = escapePattern(pair[1])
        msg = msg:gsub(pattern, pair[2])
    end
    return msg
end


-- fully converts message via regex
local function fullyNormalizeChat(msg)
    msg = msg:lower()
    msg = normalizeObfuscation(msg)
    msg = msg:gsub("[^%w%s]", " ")
    msg = msg:gsub("%s+", " ")
    return msg
end

-- finds playerId by player name (case-insensitive)
local function getPlayerIdByName(name)
    if not name then return nil end

    -- makes name case insensitive
    local target = name:lower()
    local players = PlayerManager.GetPlayers()

    -- skip if player is a bot
    for _, p in pairs(players) do
        if not p.isBot and p.name and p.name:lower() == target then
            return p.playerId, p.name
        end
    end

    return nil
end

-- checks for online players bu ID
-- returns player object if player is online, returns nil if offline
local function getPlayerById(playerId)

    local players = PlayerManager.GetPlayers()
    for _, p in ipairs(players) do
        if not p.isBot and p.playerId == playerId then
            return p
        end
    end

    return nil
end

-- checks if player is admin and converts playerId to string if player.playerID returns an int
local function isAdmin(playerId)
    return Utils.contains(admins, playerId)
end

-- checks if player is admin and converts playerId to string if player.playerID returns an int
local function isModerator(playerId)
    return Utils.contains(moderators, playerId)
end


-- function to print text to the Kyber server log
-- can select prefix (0 = ErrorPrefix, 1 = AlertPrefix, 2 = ActionPrefix, leave empty for no prefix)
local function logEvent(text, prefix)
    if ChatFilter.EnableLogging then

        -- ** the optional discord relay and discord bot use these prefixes to distinguish messages**
        if prefix == 0 then
            print(ChatFilter.ErrorPrefix .. " " .. text)
        elseif prefix == 1 then
            print(ChatFilter.AlertPrefix .. " " .. text)
        elseif prefix == 2 then
            print(ChatFilter.ActionPrefix .. " " .. text)
        else
            print(text)
        end

    end
end

-- once implemented, will alert the host via the Kyber client event log
local function alertHost(text)
    if ChatFilter.EnableHostAlert then
        -- function or api call to send print() or logEvent() text to event viewer
    end
end


-- #########################################################
-- initialize chat commands with necessary functions and tables
-- commands live in chatfilter_commands.lua

Commands.init(ChatFilter, {
    mutedPlayers = Moderation.getMutedPlayers(),
    bannedPlayers = Moderation.getBannedPlayers(),
    strikes = Moderation.getStrikes(),

    -- exposed admins and moderators as getters instead of tables
    getAdmins = function() return admins end,
    getModerators = function() return moderators end,

    parseDuration = Utils.parseDuration,
    formatDuration = Utils.formatDuration,

    getPlayerIdByName = getPlayerIdByName,
    getPlayerById = getPlayerById,

    banPlayer = Moderation.banPlayer,
    isBanned = Moderation.isBanned,

    pruneExpiredEntries = Moderation.pruneExpiredEntries,

    isAdmin = isAdmin,
    isModerator = isModerator,

    logEvent = logEvent
})

-- #########################################################

-- http and remote administration functions

-- handles incoming http admin commands (sync lists with sidecar)
function ChatFilter.HandleRemoteCommand(command, args)

    -- send remote command data to chatfilter_commands.lua
    command = command:lower()

    local context = {
        source = "remote",
        player = nil,
        command = command,
        args = args,
        isAdmin = true,
        isModerator = true
    }

    -- return log and success state from chatfilter_commands.lua
    local success, msg,_ = Commands.execute(context)
    return success, msg

end

-- handles /sync requests over http
router:handlePOST("/sync", function(req)

    if #req.body > 65536 then
        req.client:Send(
            "HTTP/1.1 413 Payload Too Large\r\n" ..
            "Connection: close\r\n\r\n")
        return
    end

    local data, pos, err = dkjson.decode(req.body)

    -- checks for bad or malformed requests
    if type(data) ~= "table" then
        req.client:Send(
            "HTTP/1.1 400 Bad Request\r\n" ..
            "Content-Type: text/plain\r\n" ..
            "Content-Length: 11\r\n" ..
            "Connection: close\r\n\r\n" ..
            "Invalid JSON"
        )
        return
    end

    -- checks for bad or malformed requests within table
    if type(data.bans) ~= "table" or type(data.mutes) ~= "table" then
        req.client:Send(
            "HTTP/1.1 400 Bad Request\r\n" ..
            "Connection: close\r\n\r\n")
        return
    end

    -- check for auth token
    if data.token ~= ChatFilter.AuthToken then
        req.client:Send(
            "HTTP/1.1 401 Unauthorized\r\n" ..
            "Connection: close\r\n\r\n")
        return
    end

    local newBans = {}
    local newMutes  = {}

    if type(data.bans) == "table" then
        for id, banData in pairs(data.bans) do
            local numericId = tonumber(id)
            if numericId and type(banData) == "table" then
                newBans[numericId] = banData
            end
        end
    end

    if type(data.mutes) == "table" then
        for id, muteData in pairs(data.mutes) do
            local numericId = tonumber(id)
            if numericId and type(muteData) == "table" then
                newMutes[numericId] = muteData
            end
        end
    end

    -- replaces mutedPlayers and bannedPlayers with new data from /sync
    Moderation.replaceState(newBans, newMutes)

    Moderation.pruneExpiredEntries()

    logEvent("State synced from sidecar", 2)

    req.client:Send(
        "HTTP/1.1 204 No Content\r\n" ..
        "Connection: close\r\n\r\n")
end)

-- handles /state http response
router:handleGET("/state", function(req)

    -- debug
    Utils.debugLog(">>> /state handler executing")

    Moderation.pruneExpiredEntries()

    local snapshot = {
        bans  = Moderation.getBannedPlayers(),
        mutes = Moderation.getMutedPlayers()
    }

    local json = dkjson.encode(snapshot)

    local response =
        "HTTP/1.1 200 OK\r\n" ..
        "Content-Type: application/json\r\n" ..
        "Content-Length: " .. #json .. "\r\n" ..
        "Connection: close\r\n\r\n" ..
        json

    req.client:Send(response)

end)

-- handles /command, receives admin commands over http
router:handlePOST("/command", function(req)

    --debug
    Utils.debugLog(">>> /command handler executing")

    -- checks if EnableRemoteCommands is enabled
    if not ChatFilter.EnableRemoteCommands then
        req.client:Send(
            "HTTP/1.1 403 Forbidden\r\n" ..
            "Connection: close\r\n\r\n")
        return
    end

    if #req.body > 4096 then
        req.client:Send(
            "HTTP/1.1 413 Payload Too Large\r\n" ..
            "Connection: close\r\n\r\n")
        return
    end

    local data, pos, err = dkjson.decode(req.body)

    if type(data) ~= "table" then
        req.client:Send(
            "HTTP/1.1 400 Bad Request\r\n" ..
            "Connection: close\r\n\r\n")
        return
    end

    if data.token ~= ChatFilter.AuthToken then
        req.client:Send(
            "HTTP/1.1 401 Unauthorized\r\n" ..
            "Connection: close\r\n\r\n")
        return
    end

    if not data.command then
        req.client:Send(
            "HTTP/1.1 400 Bad Request\r\n" ..
            "Connection: close\r\n\r\n")
        return
    end

    if type(data.args) ~= "table" then
        data.args = {}
    end

    -- Call internal command handler
    local success, msg = ChatFilter.HandleRemoteCommand(data.command, data.args)

    local result = dkjson.encode({
        success = success,
        message = msg,
        timestamp = os.time()
    })

    req.client:Send(
        "HTTP/1.1 200 OK\r\n" ..
        "Content-Type: application/json\r\n" ..
        "Content-Length: " .. #result .. "\r\n" ..
        "Connection: close\r\n\r\n" ..
        result
    )

end)

-- initializes http server if persistence is enabled
if ChatFilter.EnablePersistence or ChatFilter.EnableRemoteCommands then
    local server = HttpServer.new(8081, function(req)
        router:handleRequest(req)
    end)
end


-- #########################################################

-- chat filter logic functions

-- checks for spaced letter obfuscation, returns boolean
-- currently unused
local function hasSpacedLetters(msg)
    -- matches: w o r d / w-o-r-d / w _ o _ r _ d
    return msg:find("%w[%s%p]+%w[%s%p]+%w") ~= nil
end

-- checks for admin permissions
local function requireAdmin(player)
    if not isAdmin(player.playerId) then
        logEvent("Permission denied", 0)
        return false
    end
    return true
end


-- main chat filter logic
function ChatFilter.ContainsBannedWord(message)
    local normalized = fullyNormalizeChat(message)

    for _, entry in ipairs(bannedPatterns) do
        -- check 1: regex word-boundary detection (reduces false positives)
        if normalized:find(entry.boundaryPattern) then
            Utils.debugLog("word flagged by check 1 boundary match")
            return true, entry.word
        end

        if normalized:find(entry.spacedPattern) then
            -- check 2: spaced / punctuated letters (safe for 3-letter words)
            Utils.debugLog("word flagged by check 2 spaced match")
            return true, entry.word
        end
    end

    -- if word is not flagged, return false to let message be sent as normal
    Utils.debugLog("no match, message not flagged")
    return false
end


-- Kyber chat reading function
-- takes actions based on strikes and options set

function ChatFilter.OnPlayerChat(player, message)
    local playerName = player.name or "Unknown"
    local playerId   = player.playerId or "N/A"

    -- mute enforcement
    if Moderation.isMuted(playerId) and not isAdmin(playerId) then
        logEvent("Blocked message from muted player: " .. playerName ..
            " | Message: " .. message)
        return false
    end

    local hit, word = ChatFilter.ContainsBannedWord(message)
    if not hit then
        return true
    end

    local strikeCount = Moderation.addStrike(playerId)

    local report = string.format(
        "%s (%s) used banned word '%s' [strike %d/%d]: %s",
        playerName,
        playerId,
        word,
        strikeCount or 0,
        ChatFilter.MaxStrikes,
        message
    )

    logEvent(report, 1)
    -- alertHost(report) -- still a work in progress

    -- escalate auto-mute, auto-kick, or auto-ban player if enabled
    if ChatFilter.EnableStrikeTrack then

        -- ban logic
        if ChatFilter.EnableAutoBan
            and ChatFilter.BanAtStrikes > 0
            and strikeCount >= ChatFilter.BanAtStrikes
            and not Moderation.isBanned(playerId) then

            -- check if player is admin, return false if true
            if isAdmin(playerId) then
                Utils.debugLog("Admin exempt from auto-ban")
                return false
            end

            -- checks if timed auto bans are enabled
            local duration = nil
            if ChatFilter.EnableTimedAutoBan then
                duration = ChatFilter.AutoBanDuration -- Utils.parseDuration(ChatFilter.AutoBanDuration)
            end

            Moderation.banPlayer(
                playerId,
                playerName,
                duration,
                "Auto-ban: repeated chat violations",
                false
            )

            logEvent(playerName .. " (" .. playerId .. ") has been auto-banned", 2)
            Moderation.kickPlayer(player, "You have been auto-banned for repeated chat filter violations")
            return false
        end

        -- kick logic
        if ChatFilter.EnableAutoKick
            and ChatFilter.KickAtStrikes > 0
            and strikeCount >= ChatFilter.KickAtStrikes then

            -- check if player is admin, return false if true
            if isAdmin(playerId) then
                Utils.debugLog("Admin exempt from auto-kick")
                return false
            end

            logEvent(playerName .. " (" .. playerId .. ") has been auto-kicked for repeated chat filter violations", 2)
            Moderation.kickPlayer(player, "Auto-kicked for repeated chat filter violations")
            return false
        end

        -- mute logic
        if ChatFilter.EnableAutoMute
            and ChatFilter.MaxStrikes > 0
            and strikeCount >= ChatFilter.MaxStrikes
            and not Moderation.isMuted(playerId)
            and not isAdmin(playerId) then

            Moderation.mutePlayer(playerId)

            if ChatFilter.MuteDuration == 0 then
                logEvent(playerName .. " (" .. playerId .. ") muted permanently", 2)
            else
                logEvent(playerName .. " (" .. playerId .. ") muted for "
                    .. Utils.formatDuration(ChatFilter.MuteDuration), 2)
            end
        end
    end

    return not ChatFilter.BlockMessage
end


-- runs script on chat message event being triggered

EventManager.Listen("ServerPlayer:SendMessage", function(player, message)
    Utils.debugLog("message event hooked")

    -- define admins and mods
    local isAdminUser = isAdmin(player.playerId)
    local isModUser   = isModerator(player.playerId)

    -- check if player is admin and handle commands if true


    local messageSplit = Utils.split(message)

    if #messageSplit <= 0 then return end
    if messageSplit[1]:sub(1, 1) == '/' then

        local command = messageSplit[1]:lower():sub(2)

        -- block command from appearing in game chat
        EventManager.SetCancelled(true)

        -- different commands to turn features on or off
        local context = {
            source = "game",
            player = player,
            command = command,
            args = { table.unpack(messageSplit, 2) },
            isAdmin = isAdminUser,
            isModerator = isModUser
        }

        local success, msg, eventType = Commands.execute(context)

        -- if message text exists
        if msg then

            -- if event type is set
            if eventType ~= nil then
                logEvent(msg, eventType)
            else
                logEvent(msg)
            end

        end

        -- print error if message field is nil or ""
        if not msg then
            logEvent("Command chat message text not found.", 0)
        end

        return


    end

    -- if not an admin, moderator, or player command, filter message normally

    local allowed = ChatFilter.OnPlayerChat(player, message)
    if allowed == false then
        EventManager.SetCancelled(true)
    end

end)

-- listens for player joining server
EventManager.Listen("ServerPlayer:Joined", function(player)

    -- auto-kicks player on join if they are in the banned list
    if Moderation.isBanned(player.playerId) then
        local ban = Moderation.getBannedPlayers()[player.playerId]

        -- update stored name if placeholder from offline ban
        if ban.name == "OfflinePlayer" then
            ban.name = player.name
        end

        local msg = ban.reason or "You are banned from this server"
        -- Delay kick slightly to ensure player is fully initialized
        SetTimeout(function()
            if player then
                print("Auto-kicking banned player " .. player.name .. " (" .. player.playerId .. ")")
                player:Kick(msg)
            end
        end, 5)

    end

end)
