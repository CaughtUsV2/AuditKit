local BASE = "https://raw.githubusercontent.com/CaughtUsV2/AuditKit/master/"

local files = {
    "main.lua",
    "modules/spy.lua",
    "modules/purchase.lua",
    "modules/scripts.lua",
}

local loaded = {}
for _, f in ipairs(files) do
    local ok, src = pcall(game.HttpGet, game, BASE .. f)
    if ok then loaded[f] = src end
end

if not loaded["main.lua"] then
    warn("[AuditKit] failed to fetch main.lua")
    return
end

getgenv().__AUDITKIT_MODULES = {
    spy = loaded["modules/spy.lua"],
    purchase = loaded["modules/purchase.lua"],
    scripts = loaded["modules/scripts.lua"],
}

loadstring(loaded["main.lua"])()
