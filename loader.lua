-- CaughtUs v1.0.0
local h = game.HttpGet
local b = h(game, "https://raw.githubusercontent.com/CaughtUsV2/AuditKit/master/bundle.b64")
if not b or #b < 100 then warn("[CaughtUs] fetch failed") return end
local dec = ""
local lut = {}
local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
for i = 1, #chars do lut[chars:sub(i,i)] = i - 1 end
local buf, bits = 0, 0
for i = 1, #b do
    local c = b:sub(i,i)
    if lut[c] then
        buf = buf * 64 + lut[c]
        bits = bits + 6
        if bits >= 8 then
            bits = bits - 8
            dec = dec .. string.char(math.floor(buf / (2^bits)) % 256)
        end
    end
end
loadstring(dec)()
