local BASE = "https://raw.githubusercontent.com/CaughtUsV2/AuditKit/master/"
local TOKEN = "YOUR_TOKEN_HERE"

local files = {
    "main.lua",
    "modules/spy.lua",
    "modules/purchase.lua",
    "modules/scripts.lua",
}

local loaded = {}
for _, f in ipairs(files) do
    local ok, res = pcall(request, {
        Url = BASE .. f,
        Method = "GET",
        Headers = {
            ["Authorization"] = "token " .. TOKEN
        }
    })
    if ok and res and res.StatusCode == 200 then
        loaded[f] = res.Body
    end
end

if not loaded["main.lua"] then
    warn("[AuditKit] failed to fetch - check your token")
    return
end

getgenv().__AUDITKIT_MODULES = {
    spy = loaded["modules/spy.lua"],
    purchase = loaded["modules/purchase.lua"],
    scripts = loaded["modules/scripts.lua"],
}

loadstring(loaded["main.lua"])()
