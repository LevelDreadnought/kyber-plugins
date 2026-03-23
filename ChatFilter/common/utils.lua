-- this file contains utility functions for use in ChatFilter including
-- table and string modifiers, time and duration parsing, environment
-- variable parsing , and the debug log function

-- credit: LevelDreadnought

local Utils = {}

-- prints text to the debug log only when correct environment variable is set
function Utils.debugLog(s)

    -- get env vars
    local devMode = os.getenv("KYBER_DEV_MODE")
    local logLevel = (os.getenv("KYBER_LOG_LEVEL") or ""):lower()

    if (devMode ~= nil) or (logLevel == "debug") then

        print("[Debug] " .. s)

    end
end

-- #########################################################

-- environment variable functions

-- gets env var and checks if it is empty or nil
function Utils.getEnv(name)
    local v = os.getenv(name)
    if v == nil or v == "" then
        return nil
    end
    return v
end

-- parse env var options into bool and check format
function Utils.parseBool(v)
    -- check if v is a string
    if type(v) ~= "string" then
        return nil
    end

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
function Utils.parseNumber(v)
    local n = tonumber(v)
    if n == nil then
        return nil
    end
    return n
end

-- #########################################################

-- string and table utility functions

-- checks table for values
function Utils.contains(t, element)
    for _, value in pairs(t) do
        if value == element then
            return true
        end
    end
    return false
end

-- splits string by delimiter
-- note: sep is treated as a pattern, not a literal string

function Utils.split(str, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(str, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

-- #########################################################

-- time and duration conversion functions

-- parses duration input and converts to seconds for use in os.time()
-- 30    -> 30 minutes
-- 24h   -> 24 hours
-- 7d    -> 7 days
-- 0     -> permanent
-- returns seconds
function Utils.parseDuration(input)
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

-- properly converts time to a human readable format
function Utils.formatDuration(seconds)
    if seconds == 0 then return "permanently" end
    if seconds % 86400 == 0 then
        return (seconds / 86400) .. "d"
    elseif seconds % 3600 == 0 then
        return (seconds / 3600) .. "h"
    else
        return (seconds / 60) .. "m"
    end
end

-- #########################################################



return Utils