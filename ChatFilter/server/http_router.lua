-- http router for use with http_server.lua in kyber server plugins

-- Credits:
--  Original code: Armchair Developers
--  Changes and additions: LevelDreadnought

local HttpRouter = {}
HttpRouter.__index = HttpRouter

function HttpRouter.new()
    local obj = setmetatable({}, HttpRouter)
    obj.routes = {}
    return obj
end

-- handle GET requests
function HttpRouter:handleGET(path, callback)
    table.insert(self.routes, {method = "GET", path = path, callback = callback})
end

-- handle POST requests
function HttpRouter:handlePOST(path, callback)
    table.insert(self.routes, {method = "POST", path = path, callback = callback})
end

function HttpRouter:handleRequest(req)
    for _, route in ipairs(self.routes) do
        -- match route based on method and path
        if req.method == route.method and req.path == route.path then
            route.callback(req)  -- call the appropriate handler
            return
        end
    end

    if req.sendNotFound then
        req.sendNotFound() -- mend 404 if no match found
    else
        print("Router error: req has no sendNotFound")
        req.client:Send("HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n")
    end

end

return HttpRouter