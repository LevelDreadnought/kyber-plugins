local TimerModule = require "common/timer"
local Timer = TimerModule.Timer
local SetTimeout = TimerModule.SetTimeout

-- prints text to the debug log only when env is set
local DebugLog = function(s)
    if (os.getenv("KYBER_DEV_MODE") ~= nil) or ((os.getenv("KYBER_LOG_LEVEL") or ""):lower() == "debug") then
        print("[Debug] " .. s)
    end
end

local roles = require "admins"

local admins = roles.Admins or {}
local moderators = roles.Moderators or {}


-- ==========================================================
-- Kyber Chat Filter Plugin
-- ==========================================================
--  - Filters and blocks banned words from game chat
--  - Normalizes input to prevent basic bypass attempts
--  - Logs violations with player name and player ID
--  - Strike tracking and auto-mute ability
--  - Alerts online hosts in event log (wip)
--  - Admin chat commands can toggle features
--  - Environment variables can override default settings
-- ==========================================================


local ChatFilter = {}


-- Configuration


ChatFilter.BannedWords         = require "filtered_word_list"

ChatFilter.AlertPrefix         = "Detection:"
ChatFilter.ErrorPrefix         = "Error:"
ChatFilter.ActionPrefix        = "Action:"
ChatFilter.BlockMessage        = true
ChatFilter.EnableLogging       = true
ChatFilter.EnableHostAlert     = false

-- strike / mute / kick / ban system toggles
ChatFilter.EnableStrikeTrack   = true
ChatFilter.EnableAutoMute      = true
ChatFilter.EnableAutoKick      = true
ChatFilter.EnableAutoBan       = false
ChatFilter.EnableTimedAutoBan  = true

ChatFilter.MaxStrikes          = 3     -- strikes before mute
ChatFilter.MuteDuration        = 5     -- time in minutes, (set to 0 for permanent mute)
ChatFilter.AutoBanDuration     = 60    -- time in minutes, 60 default
ChatFilter.KickAtStrikes       = 5
ChatFilter.BanAtStrikes        = 7


-- environment variables

local AdditionalAdmins <const>     = "KYBER_CHAT_FILTER_ADMINS" -- format: ="<playerId_1>:<playerId_2>"
local AdditionalModerators <const> = "KYBER_CHAT_FILTER_MODERATORS" -- format: ="<playerId_1>:<playerId_2>"

local BlockMessageEnvName <const>  = "KYBER_CHAT_FILTER_BLOCK_MESSAGE"
local LoggingEnvName <const>       = "KYBER_CHAT_FILTER_LOGGING"
local HostAlertEnvName <const>     = "KYBER_CHAT_FILTER_HOST_ALERT"
local StrikeTrackEnvName <const>   = "KYBER_CHAT_FILTER_STRIKE_TRACK"
local AutoMuteEnvName <const>      = "KYBER_CHAT_FILTER_AUTO_MUTE"
local AutoKickEnvName <const>      = "KYBER_CHAT_FILTER_AUTO_KICK"
local AutoBanEnvName <const>       = "KYBER_CHAT_FILTER_AUTO_BAN"

local MaxStrikesEnvName <const>    = "KYBER_CHAT_FILTER_MAX_STRIKES"
local MuteDurationEnvName <const>  = "KYBER_CHAT_FILTER_MUTE_TIME"
local KickAtEnvName <const>        = "KYBER_CHAT_FILTER_KICK_AT"
local BanAtEnvName <const>         = "KYBER_CHAT_FILTER_BAN_AT"



-- internal variables


local bannedLookup  = {}
local bannedPatterns = {}
local strikes = {}
local mutedPlayers = {}
local bannedPlayers = {}


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

    -- checks block message env var
    v = getEnv(BlockMessageEnvName)
    if v then
        local b = parseBool(v)
        if b ~= nil then
            ChatFilter.BlockMessage = b
            DebugLog("Env override: BlockMessage = " .. tostring(b))
        end
    end

    -- checks logging env var
    v = getEnv(LoggingEnvName)
    if v then
        local b = parseBool(v)
        if b ~= nil then
            ChatFilter.EnableLogging = b
            DebugLog("Env override: EnableLogging = " .. tostring(b))
        end
    end

    -- checks host alert env var
    v = getEnv(HostAlertEnvName)
    if v then
        local b = parseBool(v)
        if b ~= nil then
            ChatFilter.EnableHostAlert = b
            DebugLog("Env override: EnableHostAlert = " .. tostring(b))
        end
    end

    -- checks strike track env var
    v = getEnv(StrikeTrackEnvName)
    if v then
        local b = parseBool(v)
        if b ~= nil then
            ChatFilter.EnableStrikeTrack = b
            DebugLog("Env override: EnableStrikeTrack = " .. tostring(b))
        end
    end

    -- checks auto mute env var
    v = getEnv(AutoMuteEnvName)
    if v then
        local b = parseBool(v)
        if b ~= nil then
            ChatFilter.EnableAutoMute = b
            DebugLog("Env override: EnableAutoMute = " .. tostring(b))
        end
    end

    -- checks auto kick env var
    v = getEnv(AutoKickEnvName)
    if v then
        local b = parseBool(v)
        if b ~= nil then
            ChatFilter.EnableAutoKick = b
            DebugLog("Env override: EnableAutoKick = " .. tostring(b))
        end
    end

    -- checks auto ban env var
    v = getEnv(AutoBanEnvName)
    if v then
        local b = parseBool(v)
        if b ~= nil then
            ChatFilter.EnableAutoBan = b
            DebugLog("Env override: EnableAutoBan = " .. tostring(b))
        end
    end

    -- checks max strikes env var
    v = getEnv(MaxStrikesEnvName)
    if v then
        local n = parseNumber(v)
        if n and n >= 0 then
            ChatFilter.MaxStrikes = n
            DebugLog("Env override: MaxStrikes = " .. n)
        end
    end

    -- checks mute duration env var
    v = getEnv(MuteDurationEnvName)
    if v then
        local n = parseNumber(v)
        if n and n >= 0 then
            ChatFilter.MuteDuration = n
            DebugLog("Env override: MuteDuration = " .. n)
        end
    end

    -- gets adminIds from env var and checks for dupes against the list from admin.lua
    v = getEnv(AdditionalAdmins)
    if v then
        for rawId in v:gmatch("([^:]+)") do
            -- trim whitespace just in case
            local id = tonumber(rawId:match("^%s*(.-)%s*$"))

            if id then
                local added = addAdminByEnv(admins, id)
                if added then
                    DebugLog("Env override: added admin " .. id)
                end
            end
        end
    end

    -- gets moderator IDs from env var and checks for dupes against the list from admin.lua
    v = getEnv(AdditionalModerators)
    if v then
        for rawId in v:gmatch("([^:]+)") do
            local id = tonumber(rawId:match("^%s*(.-)%s*$"))

            if id then
                local added = addAdminByEnv(moderators, id)
                if added then
                    DebugLog("Env override: added moderator " .. id)
                end
            end
        end
    end

end

-- #########################################################

-- time conversion functions

-- parses duration input and converts to seconds for use in os.time()
-- 30    -> 30 minutes
-- 24h   -> 24 hours
-- 7d    -> 7 days
-- 0     -> permanent
-- returns seconds
local function parseDuration(input)
    if input == nil then return nil end

    input = tostring(input):lower():gsub("%s+", "")

    if input == "0" then
        return 0
    end

    -- days format "d" (e.g. 7d)
    local days = input:match("^(%d+)d$")
    if days then
        return tonumber(days) * 24 * 60 * 60
    end

    -- hours format "h" (e.g., 24h)
    local hours = input:match("^(%d+)h$")
    if hours then
        return tonumber(hours) * 60 * 60
    end

    -- plain number = minutes
    local minutes = tonumber(input)
    if minutes then
        return minutes * 60
    end

    return nil
end

-- convert mute duration (minutes/hours format) to seconds
local parsedMute = parseDuration(ChatFilter.MuteDuration)
if parsedMute then
    ChatFilter.MuteDuration = parsedMute
end

-- convert auto-ban duration to seconds
local parsedBan = parseDuration(ChatFilter.AutoBanDuration)
if parsedBan then
    ChatFilter.AutoBanDuration = parsedBan
end



-- #########################################################

-- properly handles escape characters
local function escapePattern(s)
    return s:gsub("(%W)", "%%%1")
end

-- handles three letter words and proper spaces via regex spaced-letter pattern
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
}


-- #########################################################

-- utility functions


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

-- checks table for values
table.contains = function(t, element)
    for _, value in pairs(t) do
        if value == element then
            return true
        end
    end
    return false
end

-- splits string by delimiter
-- note: sep is treated as a pattern, not a literal string

string.split = function(str, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(str, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

-- properly converts time to a human readable format
local function formatDuration(seconds)
    if seconds == 0 then return "permanently" end
    if seconds % 86400 == 0 then
        return (seconds / 86400) .. "d"
    elseif seconds % 3600 == 0 then
        return (seconds / 3600) .. "h"
    else
        return (seconds / 60) .. "m"
    end
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
    return table.contains(admins, playerId)
end

-- checks if player is admin and converts playerId to string if player.playerID returns an int
local function isModerator(playerId)
    return table.contains(moderators, playerId)
end


-- function to print text to the Kyber server log
-- can select prefix (0 = ErrorPrefix, 1 = AlertPrefix, 2 = ActionPrefix, leave empty for no prefix)
local function logEvent(text, prefix)
    if ChatFilter.EnableLogging then

        -- ** if discord api is implemented, this is where the api and push calls would live **
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


-- checks if the passed player is muted
local function isMuted(playerId)
    local mute = mutedPlayers[playerId]
    if not mute then return false end

     -- unlimited mute
    if mute.expires == nil then
        return true
    end

    -- timed mute
    if os.time() >= mute.expires then
        mutedPlayers[playerId] = nil
        return false
    end

    return true
end

-- add strike to passed player by ID
local function addStrike(playerId)
    if not ChatFilter.EnableStrikeTrack then return 0 end

    strikes[playerId] = (strikes[playerId] or 0) + 1
    return strikes[playerId]
end

-- sets a player as muted by ID
local function mutePlayer(playerId)
    if not ChatFilter.EnableAutoMute then return end

    -- convert to seconds
    local durationSeconds = ChatFilter.MuteDuration -- parseDuration(ChatFilter.MuteDuration)

    if durationSeconds == 0 then
        -- unlimited mute when 0
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
local function kickPlayer(player, reason)
    if not ChatFilter.EnableAutoKick then return end
    if player then
        player:Kick(reason or "Kicked by server moderation")
    end
end

-- bans player after a certain number of strikes
local function banPlayer(playerId, name, duration, reason, manual)
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
local function isBanned(playerId)
    local ban = bannedPlayers[playerId]
    if not ban then return false end

    if ban.expires == nil then
        return true
    end

    if os.time() >= ban.expires then
        -- end ban and reset strikes
        bannedPlayers[playerId] = nil
        strikes[playerId] = nil
        return false
    end

    return true
end




-- #########################################################

-- chat filter logic functions

-- checks for spaced letter obfuscation, returns boolean
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
            DebugLog("word flagged by check 1 boundary match")
            return true, entry.word
        end

        if normalized:find(entry.spacedPattern) then
            -- check 2: spaced / punctuated letters (safe for 3-letter words)
            DebugLog("word flagged by check 2 spaced match")
            return true, entry.word
        end
    end

    -- if word is not flagged, return false to let message be sent as normal
    DebugLog("no match, message not flagged")
    return false
end


-- Kyber chat reading function
-- takes actions based on strikes and options set

function ChatFilter.OnPlayerChat(player, message)
    local playerName = player.name or "Unknown"
    local playerId   = player.playerId or "N/A"

    -- mute enforcement
    if isMuted(playerId) and not isAdmin(playerId) then
        logEvent("Blocked message from muted player: " .. playerName ..
            " | Message: " .. message)
        return false
    end

    local hit, word = ChatFilter.ContainsBannedWord(message)
    if not hit then
        return true
    end

    local strikeCount = addStrike(playerId)

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
            and not isBanned(playerId) then

            -- check if player is admin, return false if true
            if isAdmin(playerId) then
                DebugLog("Admin exempt from auto-ban")
                return false
            end

            -- checks if timed auto bans are enabled
            local duration = nil
            if ChatFilter.EnableTimedAutoBan then
                duration = ChatFilter.AutoBanDuration -- parseDuration(ChatFilter.AutoBanDuration)
            end

            banPlayer(
                playerId,
                playerName,
                duration,
                "Auto-ban: repeated chat violations",
                false
            )

            logEvent(playerName .. " (" .. playerId .. ") has been auto-banned", 2)
            kickPlayer(player, "You have been banned for repeated chat filter violations")
            return false
        end

        -- kick logic
        if ChatFilter.EnableAutoKick
            and ChatFilter.KickAtStrikes > 0
            and strikeCount >= ChatFilter.KickAtStrikes then

            -- check if player is admin, return false if true
            if isAdmin(playerId) then
                DebugLog("Admin exempt from auto-kick")
                return false
            end

            logEvent(playerName .. " (" .. playerId .. ") has been auto-kicked for repeated chat filter violations", 2)
            kickPlayer(player, "Kicked for repeated chat filter violations")
            return false
        end

        -- mute logic
        if ChatFilter.EnableAutoMute
            and ChatFilter.MaxStrikes > 0
            and strikeCount >= ChatFilter.MaxStrikes
            and not isMuted(playerId)
            and not isAdmin(playerId) then

            mutePlayer(playerId)

            if ChatFilter.MuteDuration == 0 then
                logEvent(playerName .. " (" .. playerId .. ") muted permanently", 2)
            else
                logEvent(playerName .. " (" .. playerId .. ") muted for "
                    .. formatDuration(ChatFilter.MuteDuration), 2)
            end
        end
    end

    return not ChatFilter.BlockMessage
end


-- runs script on chat message event being triggered

EventManager.Listen("ServerPlayer:SendMessage", function(player, message)
    DebugLog("message event hooked")

    -- define admins and mods
    local isAdminUser = isAdmin(player.playerId)
    local isModUser   = isModerator(player.playerId)

    -- check if player is admin and handle commands if true
    if isAdminUser or isModUser then

        local messageSplit = string.split(message)

        if #messageSplit <= 0 then return end
        if messageSplit[1]:sub(1, 1) == '/' then

            local command = messageSplit[1]:lower():sub(2)

            -- block command from appearing in game chat
            EventManager.SetCancelled(true)

            -- different commands to turn features on or off

            -- toggle block message
            if command == "enableblockmessage" then
                -- checks for admin permissions
                if not requireAdmin(player) then return end

                ChatFilter.BlockMessage = true
                logEvent("BlockMessage enabled")
                return
            end
            if command == "disableblockmessage" then
                -- checks for admin permissions
                if not requireAdmin(player) then return end

                ChatFilter.BlockMessage = false
                logEvent("BlockMessage disabled")
                return
            end

            -- toggle logging
            if command == "enablelogging" then
                -- checks for admin permissions
                if not requireAdmin(player) then return end

                ChatFilter.EnableLogging = true
                logEvent("Logging enabled")
                return
            end
            if command == "disablelogging" then
                -- checks for admin permissions
                if not requireAdmin(player) then return end

                ChatFilter.EnableLogging = false
                logEvent("Logging disabled")
                return
            end

            -- toggle host alert

            if command == "enablehostalert" then
                -- checks for admin permissions
                if not requireAdmin(player) then return end

                ChatFilter.EnableHostAlert = true
                logEvent("EnableHostAlert enabled")
                return
            end
            if command == "disablehostalert" then
                -- checks for admin permissions
                if not requireAdmin(player) then return end

                ChatFilter.EnableHostAlert = false
                logEvent("EnableHostAlert disabled")
                return
            end

            -- toggle strike tracking

            if command == "enablestriketrack" then
                -- checks for admin permissions
                if not requireAdmin(player) then return end

                ChatFilter.EnableStrikeTrack = true
                logEvent("StrikeTrack enabled")
                return
            end
            if command == "disablestriketrack" then
                -- checks for admin permissions
                if not requireAdmin(player) then return end

                ChatFilter.EnableStrikeTrack = false
                logEvent("StrikeTrack disabled")
                return
            end

            -- toggle auto mute

            if command == "enableautomute" then
                -- checks for admin permissions
                if not requireAdmin(player) then return end

                ChatFilter.EnableAutoMute = true
                logEvent("AutoMute enabled")
                return
            end
            if command == "disableautomute" then
                -- checks for admin permissions
                if not requireAdmin(player) then return end

                ChatFilter.EnableAutoMute = false
                logEvent("AutoMute disabled")
                return
            end

            -- set max strikes
            if command == "setmaxstrikes" then

                -- checks for admin permissions
                if not requireAdmin(player) then return end

                if #messageSplit <= 1 then
                    logEvent("Command is missing parameters", 0)
                    return
                end

                local strikeNumber = table.concat(messageSplit, " ", 2)
                local value = tonumber(strikeNumber)
                if not value or value < 0 then -- checks if value set is actually a valid number
                    logEvent("Invalid number", 0)
                    return
                end

                ChatFilter.MaxStrikes = value
                logEvent("MaxStrikes set to " .. ChatFilter.MaxStrikes)
                return

            end

            -- set strikes to auto-kick player at
            if command == "setkickat" then

                -- checks for admin permissions
                if not requireAdmin(player) then return end

                if #messageSplit <= 1 then
                    logEvent("Usage: /setkickat <number>", 0)
                    return
                end

                local value = tonumber(messageSplit[2])
                if not value or value < 0 then -- checks if value set is actually a valid number
                    logEvent("Invalid number", 0)
                    return
                end

                ChatFilter.KickAtStrikes = value
                logEvent("KickAtStrikes set to " .. ChatFilter.KickAtStrikes)
                return
            end

            -- set strikes to auto-ban player at
            if command == "setbanat" then

                -- checks for admin permissions
                if not requireAdmin(player) then return end

                if #messageSplit <= 1 then
                    logEvent("Usage: /setbanat <number>", 0)
                    return
                end

                local value = tonumber(messageSplit[2])
                if not value or value < 0 then -- checks if value set is actually a valid number
                    logEvent("Invalid number", 0)
                    return
                end

                ChatFilter.BanAtStrikes = value
                logEvent("BanAtStrikes set to " .. ChatFilter.BanAtStrikes)
                return
            end

            -- set mute duration
            if command == "setmuteduration" then

                -- checks for admin permissions
                if not requireAdmin(player) then return end

                if #messageSplit <= 1 then
                    logEvent("Usage: /setmuteduration [time (0 for permanent)]", 0)
                    return
                end

                local duration = parseDuration(messageSplit[2])
                if duration == nil then -- checks if value set is actually a number
                    logEvent("Invalid duration format", 0)
                    return
                end

                ChatFilter.MuteDuration = duration

                logEvent("MuteDuration set to " .. formatDuration(ChatFilter.MuteDuration))
                return

            end

            -- mute player by passing playerName in chat
            if command == "mute" then
                if #messageSplit < 2 then
                    logEvent("Usage: /mute <playerName> [time (0 for permanent)]", 0)
                    return
                end

                local targetName = messageSplit[2]
                local duration = parseDuration(messageSplit[3])

                -- convert player name to player ID
                local targetId, resolvedName = getPlayerIdByName(targetName)
                if not targetId then
                    logEvent("Player not found: " .. targetName, 0)
                    return
                end


                -- prevent muting admins
                if isAdmin(targetId) then
                    logEvent("Cannot mute an admin", 0)
                    return
                end

                -- prevent moderators from muting other moderators
                if isModerator(targetId) and not isAdminUser then
                    logEvent("Cannot mute another moderator", 0)
                    return
                end

                -- apply mute
                mutedPlayers[targetId] = {
                    expires = (duration and duration > 0)
                    and (os.time() + duration)
                    or nil
                }

                -- log mute event
                logEvent("Admin muted " .. resolvedName .. " (" .. targetId .. ")", 2)
                return
            end

            -- unmute player by passing playerName in chat
            if command == "unmute" then
                if #messageSplit < 2 then
                    logEvent("Usage: /unmute <playerName>", 0)
                    return
                end

                -- convert player name to player ID
                local targetName = messageSplit[2]
                local targetId, resolvedName = getPlayerIdByName(targetName)

                if not targetId then
                    logEvent("Player not found: " .. targetName, 0)
                    return
                end

                -- set muted player to nil
                mutedPlayers[targetId] = nil
                logEvent("Admin unmuted " .. resolvedName .. " (" .. targetId .. ")", 2)
                return
            end

            -- manual ban by passing playerName in chat
            if command == "ban" then
                if #messageSplit < 2 then
                    logEvent("Usage: /ban <playerName> <duration> <reason>", 0)
                    return
                end

                local targetName = messageSplit[2]
                local targetId, resolvedName = getPlayerIdByName(targetName)

                -- parses ban duration and reason from chat, reason default set if empty
                local durationInput = messageSplit[3]
                local duration = parseDuration(durationInput)

                local reasonStartIndex = duration and 4 or 3
                local reason = table.concat(messageSplit, " ", reasonStartIndex)
                if reason == "" then
                    reason = "You have been banned"
                end


                if not targetId then
                    logEvent("Player not found: " .. targetName, 0)
                    return
                end

                -- prevent banning admins
                if isAdmin(targetId) then
                    logEvent("Cannot ban an admin", 0)
                    return
                end

                -- prevent moderators from banning other moderators
                if isModerator(targetId) and not isAdminUser then
                    logEvent("Cannot ban another moderator", 0)
                    return
                end

                -- checks if player is already banned
                if isBanned(targetId) then
                    logEvent(resolvedName .. " is already banned", 0)
                    return
                end

                -- add to banned list with a manual ban marker and reason
                banPlayer(targetId, resolvedName, duration, reason, true)

                -- reset strikes
                strikes[targetId] = nil

                -- log ban action
                local durationText = duration and formatDuration(duration) or "permanently"
                logEvent("Admin banned " .. resolvedName .. " (" .. targetId .. ")"
                    .. " for " .. durationText
                    .. " | Reason: " .. reason, 2)


                -- kick immediately if online
                local targetPlayer = getPlayerById(targetId)
                if targetPlayer then
                    targetPlayer:Kick(reason)
                end

                return
            end

            -- manual offline ban by passing playerId
            if command == "banoffline" then

                if #messageSplit < 2 then
                    logEvent("Usage: /banoffline <playerId> [duration] [reason]", 0)
                    return
                end

                -- parse playerId
                local targetId = tonumber(messageSplit[2])
                if not targetId then
                    logEvent("Invalid playerId", 0)
                    return
                end

                -- prevent banning admins
                if isAdmin(targetId) then
                    logEvent("Cannot ban an admin", 0)
                    return
                end

                -- prevent moderators from banning other moderators
                if isModerator(targetId) and not isAdminUser then
                    logEvent("Cannot ban another moderator", 0)
                    return
                end

                -- checks if player is already banned
                if isBanned(targetId) then
                    logEvent("PlayerId " .. targetId .. " is already banned", 0)
                    return
                end

                -- parse duration
                local durationInput = messageSplit[3]
                local duration = parseDuration(durationInput)

                -- parse reason
                local reasonStartIndex = duration and 4 or 3
                local reason = table.concat(messageSplit, " ", reasonStartIndex)

                if reason == "" then
                    reason = "You have been banned"
                end

                -- add to banned list with a manual ban marker and reason
                banPlayer(targetId, "OfflinePlayer", duration, reason, true)

                local durationText = duration and formatDuration(duration) or "permanently"
                logEvent("Admin offline-banned OfflinePlayer (" .. targetId .. ")"
                    .. " for " .. durationText
                    .. " | Reason: " .. reason, 2)

                return
            end

            -- unbans player by passing playerID in chat
            if command == "unban" then
                if #messageSplit < 2 then
                    logEvent("Usage: /unban <playerId>", 0)
                    return
                end

                -- convert player ID string to int
                local targetId = tonumber(messageSplit[2])

                if not targetId then
                    logEvent("Invalid playerId", 0)
                    return
                end

                -- check if player is not banned
                if not bannedPlayers[targetId] then
                    logEvent("PlayerId " .. targetId .. " is not banned", 0)
                    return
                end

                -- set banned player to nil and reset strikes
                bannedPlayers[targetId] = nil
                strikes[targetId] = nil
                logEvent("Admin unbanned playerId " .. targetId, 2)
                return
            end

            -- command to list all banned players
            if command == "listbans" then

                local entries = {}
                local now = os.time()

                for id, data in pairs(bannedPlayers) do

                    -- Auto-clean expired bans
                    if data.expires and data.expires <= now then
                        bannedPlayers[id] = nil

                    else
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

                            remainingText = formatDuration(remaining)
                            originalText = formatDuration(originalDuration)
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
                end

                if #entries == 0 then
                    logEvent("No active bans.")
                else
                    logEvent(table.concat(entries, " || "))
                end

                return
            end

            -- command to list admins (online and offline)
            if command == "listadmins" then
                -- checks for admin permissions
                if not requireAdmin(player) then return end

                logEvent("Admins:")

                for _, adminId in ipairs(admins) do
                    local p = getPlayerById(adminId)

                    if p then
                        logEvent(p.name .. " (" .. adminId .. ")")
                    else
                        -- admin is offline
                        logEvent("Offline (" .. adminId .. ")")
                    end
                end

                return
            end

            -- command to list moderators (online and offline)
            if command == "listmods" then
                logEvent("Moderators:")

                for _, modId in ipairs(moderators) do
                    local p = getPlayerById(modId)

                    if p then
                        logEvent(p.name .. " (" .. modId .. ")")
                    else
                        logEvent("Offline (" .. modId .. ")")
                    end
                end

                return
            end

            -- set health and set max health (for admins and mods only spawned in as klaud)
            if command == "sethealth" then

                if #messageSplit <= 1 then
                    logEvent("Usage: /sethealth <number>", 0)
                    return
                end

                local value = tonumber(messageSplit[2])
                if not value or value <= 0 then -- checks if value set is a valid number and non zero
                    logEvent("Invalid number", 0)
                    return
                end

                -- sets player health and max health
                player:SetMaxHealth(value)
                player:SetHealth(value)

                logEvent("Player health set to " .. value)
                return
            end


            -- if message doesn't match a listed command, log error
            logEvent("Invalid command", 0)
            return


        end

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
    if isBanned(player.playerId) then
        local ban = bannedPlayers[player.playerId]

        -- update stored name if placeholder from offline ban
        if ban.name == "OfflinePlayer" then
            ban.name = player.name
        end

        local msg = ban.reason or "You are banned from this server"
        -- Delay kick slightly to ensure player is fully initialized
        SetTimeout(function()
            if player then
                print("Kicking banned player " .. player.name .. " (" .. player.playerId .. ")")
                player:Kick(msg)
            end
        end, 5)

    end

end)
