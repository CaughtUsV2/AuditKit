local b = game:HttpGet("https://raw.githubusercontent.com/CaughtUsV2/AuditKit/master/bundle.b64")
if not b or #b < 100 then warn("[CaughtUs] fetch failed") return end
local lut = {}
local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
for i = 1, #chars do lut[chars:byte(i)] = i - 1 end
local out = {}
local val, bits = 0, 0
for i = 1, #b do
    local v = lut[b:byte(i)]
    if v then
        val = (val * 64 + v) % 16777216
        bits = bits + 6
        if bits >= 8 then
            bits = bits - 8
            local shift = 2^bits
            out[#out+1] = string.char(math.floor(val / shift) % 256)
            val = val % shift
        end
    end
end
loadstring(table.concat(out))()
