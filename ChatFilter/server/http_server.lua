-- http server for use with http_router.lua in kyber server plugins

-- Credits:
--  Original code: Armchair Developers
--  Changes and additions: LevelDreadnought

local Utils = require "common/utils"


local HttpRequest = {}
HttpRequest.__index = HttpRequest


function HttpRequest.new(server, client, method, path, headers, body)

    local obj = {
        server = server,
        client = client,
        method = method,
        path = path,
        headers = headers,
        body = body
    }

    function obj.send(data)
        client:Send(
            "HTTP/1.1 200 OK\r\n" ..
            "Content-Length: " .. #data .. "\r\n" ..
            "Connection: close\r\n\r\n" ..
            data
        )
    end

    function obj.sendNoContent()
        client:Send(
            "HTTP/1.1 204 No Content\r\n" ..
            "Content-Type: text/plain\r\n" ..
            "Connection: close\r\n\r\n"
        )
    end

    function obj.sendNotFound()
        client:Send(
            "HTTP/1.1 404 Not Found\r\n" ..
            "Content-Type: text/plain\r\n" ..
            "Connection: close\r\n\r\n"
        )
    end

    return obj
end

local function parseHttpRequest(request)
    local method, path, version = request:match("^(%S+)%s(%S+)%s(HTTP/%d%.%d)\r?\n")
    if not method or not path or not version then
        return nil, "Invalid HTTP request line"
    end

    local headers = {}
    local bodyStart = request:find("\r\n\r\n")
    local headersPart = request:sub(#method + #path + #version + 4, bodyStart and bodyStart - 1 or #request)

    for line in headersPart:gmatch("[^\r\n]+") do
        local key, value = line:match("^(.-):%s*(.*)$")
        if key and value then
            headers[key] = value
        end
    end

    local body = bodyStart and request:sub(bodyStart + 4) or ""

    return {
        method = method,
        path = path,
        headers = headers,
        body = body
    }
end

HttpServer = {}
HttpServer.__index = HttpServer

function HttpServer.new(port, requestCallback)
    local obj = setmetatable({}, HttpServer)
    obj.socket = SocketManager.Create(port)
    obj.clients = {}
    obj.requestCallback = requestCallback
    if obj.socket == nil then
        print("Failed to create socket")
        return nil
    end

    EventManager.Listen("Server:UpdatePre", function(_, deltaSecs)
        obj:update(deltaSecs)
    end)

    print("HttpServer listening on port " .. port)
    return obj
end

function HttpServer:update(deltaSecs)

    -- accept new clients
    do
        local client = self.socket:Accept()
        if client then
            table.insert(self.clients, {
                socket = client,
                buffer = "",
                headersParsed = false,
                contentLength = 0
            })
        end
    end

    -- process existing clients
    for i = #self.clients, 1, -1 do
        local entry = self.clients[i]
        local client = entry.socket

        -- fixes 10038 socket error
        local ok, chunk = pcall(function()
            return client:Recv(4096)
        end)

        if not ok then
            client:Close()
            table.remove(self.clients, i)
            goto continue
        end

        -- no data yet
        if not chunk then
            goto continue
        end

        -- client disconnected
        if chunk == "" then
            client:Close()
            table.remove(self.clients, i)
            goto continue
        end

        entry.buffer = entry.buffer .. chunk
        Utils.debugLog("Buffer now:" .. entry.buffer)

        -- parse headers if not parsed yet
        if not entry.headersParsed then

            local headerEnd = entry.buffer:find("\r\n\r\n", 1, true)
            local delimiterLength = 4

                if not headerEnd then
                    headerEnd = entry.buffer:find("\n\n", 1, true)
                    delimiterLength = 2
                end

            if not headerEnd then
                goto continue
            end

            -- extract header portion (exclude delimiter)
            local headerPart = entry.buffer:sub(1, headerEnd - 1)

            local method, path = headerPart:match("^(%S+)%s(%S+)")
            if not method or not path then
                client:Close()
                table.remove(self.clients, i)
                goto continue
            end

            entry.method = method
            entry.path = path

            local contentLength = headerPart:match("[Cc]ontent%-[Ll]ength:%s*(%d+)")

            entry.contentLength = tonumber(contentLength) or 0

            entry.headersParsed = true
            entry.headerEndIndex = headerEnd + delimiterLength
        end

        -- if headers parsed, check if full body has arrived
        if entry.headersParsed then
            local body = entry.buffer:sub(entry.headerEndIndex)

            if #body < entry.contentLength then
                goto continue
            end

            -- trim body to exact Content-Length
            if entry.contentLength > 0 then
                body = body:sub(1, entry.contentLength)
            else
                body = ""
            end

            -- debug
            Utils.debugLog(">>> Invoking requestCallback for " .. entry.method .. " " .. entry.path)

            local okHandler, handlerErr = pcall(function()

                local request = HttpRequest.new(
                    self,
                    client,
                    entry.method,
                    entry.path,
                    {}, -- headers (not parsed yet)
                    body
                )

                self.requestCallback(request)
            end)

            -- prints handler errors to server log
            if not okHandler then
                print("HTTP handler error: " .. tostring(handlerErr))
            end

            client:Close()
            table.remove(self.clients, i)
        end

        ::continue::
    end
end

function HttpServer:removeClient(client)
    -- fixed client close issue
    for i = #self.clients, 1, -1 do
        if self.clients[i].socket == client then
            table.remove(self.clients, i)
            return
        end
    end
end

return HttpServer