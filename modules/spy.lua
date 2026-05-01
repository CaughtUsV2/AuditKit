local MPS_svc = game:GetService("MarketplaceService")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local logs = {}
local selected = nil
local paused = false
local maxLogs = 800
local logCounter = 0

local excludedInstances = {}
local excludedNames = {}
local blockedInstances = {}
local blockedNames = {}
local freqMap = {}

local remoteList, codeBox, lineNums, infoLabel, logCountLbl
local hookCleanup = {}

local function serializeType(v)
    local t = typeof(v)
    if t == "Instance" then return v:GetFullName()
    elseif t == "EnumItem" then return tostring(v)
    elseif t == "CFrame" then
        local c = {v:GetComponents()}
        return "CFrame.new(" .. table.concat(c, ", ") .. ")"
    elseif t == "Vector3" then return ("Vector3.new(%s, %s, %s)"):format(v.X, v.Y, v.Z)
    elseif t == "Vector2" then return ("Vector2.new(%s, %s)"):format(v.X, v.Y)
    elseif t == "Color3" then return ("Color3.new(%s, %s, %s)"):format(v.R, v.G, v.B)
    elseif t == "UDim2" then return ("UDim2.new(%s, %s, %s, %s)"):format(v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset)
    elseif t == "UDim" then return ("UDim.new(%s, %s)"):format(v.Scale, v.Offset)
    elseif t == "BrickColor" then return ("BrickColor.new(\"%s\")"):format(v.Name)
    elseif t == "Ray" then
        return ("Ray.new(Vector3.new(%s, %s, %s), Vector3.new(%s, %s, %s))"):format(
            v.Origin.X, v.Origin.Y, v.Origin.Z, v.Direction.X, v.Direction.Y, v.Direction.Z)
    elseif t == "NumberRange" then return ("NumberRange.new(%s, %s)"):format(v.Min, v.Max)
    elseif t == "Rect" then return ("Rect.new(%s, %s, %s, %s)"):format(v.Min.X, v.Min.Y, v.Max.X, v.Max.Y)
    elseif t == "ColorSequence" or t == "NumberSequence" then return tostring(v)
    end
    return nil
end

local function serialize(v, depth)
    depth = depth or 0
    if depth > 6 then return "{ ... }" end
    local t = typeof(v)
    if v == nil then return "nil"
    elseif t == "boolean" then return tostring(v)
    elseif t == "number" then return tostring(v)
    elseif t == "string" then return ("%q"):format(v)
    elseif t == "table" then
        if next(v) == nil then return "{}" end
        local parts = {}
        local indent = ("    "):rep(depth + 1)
        local closeIndent = ("    "):rep(depth)
        local isArray = true
        local n = 0
        for k in pairs(v) do
            n = n + 1
            if k ~= n then isArray = false; break end
        end
        if isArray then
            for i, val in ipairs(v) do
                parts[i] = indent .. serialize(val, depth + 1)
            end
        else
            for k, val in pairs(v) do
                local key
                if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                    key = k
                else
                    key = "[" .. serialize(k, depth + 1) .. "]"
                end
                table.insert(parts, indent .. key .. " = " .. serialize(val, depth + 1))
            end
        end
        return "{\n" .. table.concat(parts, ",\n") .. "\n" .. closeIndent .. "}"
    else
        local s = serializeType(v)
        if s then return s end
        return tostring(v)
    end
end

local function buildPath(remote)
    local path = 'game:GetService("' .. remote:GetFullName():match("^([^%.]+)") .. '")'
    local parts = remote:GetFullName():split(".")
    for i = 2, #parts do
        if parts[i]:match("^[%a_][%w_]*$") then
            path = path .. "." .. parts[i]
        else
            path = path .. '["' .. parts[i] .. '"]'
        end
    end
    return path
end

local function argsToScript(method, remote, args)
    local path = buildPath(remote)
    local argStrs = {}
    for i, a in ipairs(args) do argStrs[i] = serialize(a, 0) end
    local argStr = table.concat(argStrs, ", ")
    return path .. ":" .. method .. "(" .. argStr .. ")"
end

local function argsToVarScript(method, remote, args)
    local lines = {}
    local path = buildPath(remote)
    table.insert(lines, "local remote = " .. path)
    local varNames = {}
    for i, a in ipairs(args) do
        local vn = "arg" .. i
        varNames[i] = vn
        table.insert(lines, "local " .. vn .. " = " .. serialize(a, 0))
    end
    if method == "FireServer" then
        table.insert(lines, "remote:FireServer(" .. table.concat(varNames, ", ") .. ")")
    else
        table.insert(lines, "local result = remote:InvokeServer(" .. table.concat(varNames, ", ") .. ")")
    end
    return table.concat(lines, "\n")
end

local function getFuncInfo(remote)
    local lines = {}
    table.insert(lines, "Name: " .. remote.Name)
    table.insert(lines, "Class: " .. remote.ClassName)
    table.insert(lines, "Path: " .. remote:GetFullName())
    if remote.Parent then
        table.insert(lines, "Parent: " .. remote.Parent:GetFullName())
        table.insert(lines, "Parent Class: " .. remote.Parent.ClassName)
    end
    table.insert(lines, "Times Fired: " .. (freqMap[remote:GetFullName()] or 0))
    local siblings = 0
    if remote.Parent then
        for _, c in ipairs(remote.Parent:GetChildren()) do
            if c.ClassName == remote.ClassName and c ~= remote then siblings = siblings + 1 end
        end
    end
    table.insert(lines, "Sibling Remotes: " .. siblings)
    return table.concat(lines, "\n")
end

local function addLineNums(text)
    local lines = text:split("\n")
    local nums = {}
    for i = 1, #lines do nums[i] = tostring(i) end
    return table.concat(nums, "\n")
end

local function flash(btn, msg)
    local orig = btn.Text
    btn.Text = msg
    task.delay(1, function()
        if btn and btn.Parent then btn.Text = orig end
    end)
end

local function selectEntry(entry)
    selected = entry
    if not codeBox then return end
    codeBox.Text = entry.script
    lineNums.Text = addLineNums(entry.script)
    infoLabel.Text = entry.type .. " | " .. entry.name .. " | " .. entry.path
    for _, c in ipairs(remoteList:GetChildren()) do
        if c:IsA("TextButton") then
            c.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
        end
    end
    local btn = remoteList:FindFirstChild("entry_" .. entry.id)
    if btn then btn.BackgroundColor3 = Color3.fromRGB(50, 50, 65) end
end

local function isBlocked(remote)
    return blockedInstances[remote:GetFullName()] or blockedNames[remote.Name]
end

local addLogEntry

local module = {}

function module.init(container)
    logs = {}
    selected = nil
    logCounter = 0
    freqMap = {}

    -- left panel: filter + remote list
    local leftPanel = Instance.new("Frame")
    leftPanel.Size = UDim2.new(0, 180, 1, -4)
    leftPanel.Position = UDim2.new(0, 2, 0, 2)
    leftPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    leftPanel.BorderSizePixel = 0
    leftPanel.Parent = container
    Instance.new("UICorner", leftPanel).CornerRadius = UDim.new(0, 4)

    local filterBox = Instance.new("TextBox")
    filterBox.Size = UDim2.new(1, -8, 0, 22)
    filterBox.Position = UDim2.new(0, 4, 0, 4)
    filterBox.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
    filterBox.BorderSizePixel = 0
    filterBox.Text = ""
    filterBox.PlaceholderText = "Filter..."
    filterBox.TextColor3 = Color3.fromRGB(190, 190, 195)
    filterBox.PlaceholderColor3 = Color3.fromRGB(70, 70, 78)
    filterBox.Font = Enum.Font.Code
    filterBox.TextSize = 11
    filterBox.ClearTextOnFocus = false
    filterBox.Parent = leftPanel
    Instance.new("UICorner", filterBox).CornerRadius = UDim.new(0, 3)

    logCountLbl = Instance.new("TextLabel")
    logCountLbl.Size = UDim2.new(1, -8, 0, 14)
    logCountLbl.Position = UDim2.new(0, 4, 0, 28)
    logCountLbl.BackgroundTransparency = 1
    logCountLbl.Text = "0 calls"
    logCountLbl.TextColor3 = Color3.fromRGB(70, 70, 80)
    logCountLbl.Font = Enum.Font.Code
    logCountLbl.TextSize = 9
    logCountLbl.TextXAlignment = Enum.TextXAlignment.Left
    logCountLbl.Parent = leftPanel

    remoteList = Instance.new("ScrollingFrame")
    remoteList.Size = UDim2.new(1, -4, 1, -48)
    remoteList.Position = UDim2.new(0, 2, 0, 44)
    remoteList.BackgroundTransparency = 1
    remoteList.BorderSizePixel = 0
    remoteList.ScrollBarThickness = 3
    remoteList.ScrollBarImageColor3 = Color3.fromRGB(55, 55, 65)
    remoteList.CanvasSize = UDim2.new(0, 0, 0, 0)
    remoteList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    remoteList.Parent = leftPanel
    local rll = Instance.new("UIListLayout")
    rll.SortOrder = Enum.SortOrder.LayoutOrder
    rll.Padding = UDim.new(0, 1)
    rll.Parent = remoteList

    filterBox:GetPropertyChangedSignal("Text"):Connect(function()
        local f = filterBox.Text:lower()
        for _, c in ipairs(remoteList:GetChildren()) do
            if c:IsA("TextButton") then
                c.Visible = f == "" or c.Name:lower():find(f, 1, true) ~= nil
            end
        end
    end)

    -- right: code panel
    local codePanel = Instance.new("Frame")
    codePanel.Size = UDim2.new(1, -188, 1, -142)
    codePanel.Position = UDim2.new(0, 184, 0, 2)
    codePanel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    codePanel.BorderSizePixel = 0
    codePanel.ClipsDescendants = true
    codePanel.Parent = container
    Instance.new("UICorner", codePanel).CornerRadius = UDim.new(0, 4)

    infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, -8, 0, 16)
    infoLabel.Position = UDim2.new(0, 4, 0, 2)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = "Select a remote"
    infoLabel.TextColor3 = Color3.fromRGB(90, 90, 105)
    infoLabel.Font = Enum.Font.Code
    infoLabel.TextSize = 10
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.TextTruncate = Enum.TextTruncate.AtEnd
    infoLabel.Parent = codePanel

    local codeScroll = Instance.new("ScrollingFrame")
    codeScroll.Size = UDim2.new(1, 0, 1, -20)
    codeScroll.Position = UDim2.new(0, 0, 0, 18)
    codeScroll.BackgroundTransparency = 1
    codeScroll.BorderSizePixel = 0
    codeScroll.ScrollBarThickness = 4
    codeScroll.ScrollBarImageColor3 = Color3.fromRGB(55, 55, 65)
    codeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    codeScroll.AutomaticCanvasSize = Enum.AutomaticSize.XY
    codeScroll.Parent = codePanel

    lineNums = Instance.new("TextLabel")
    lineNums.Size = UDim2.new(0, 28, 1, 0)
    lineNums.Position = UDim2.new(0, 2, 0, 0)
    lineNums.BackgroundTransparency = 1
    lineNums.Text = "1"
    lineNums.TextColor3 = Color3.fromRGB(60, 60, 72)
    lineNums.Font = Enum.Font.Code
    lineNums.TextSize = 12
    lineNums.TextXAlignment = Enum.TextXAlignment.Right
    lineNums.TextYAlignment = Enum.TextYAlignment.Top
    lineNums.Parent = codeScroll

    codeBox = Instance.new("TextLabel")
    codeBox.Size = UDim2.new(1, -38, 1, 0)
    codeBox.Position = UDim2.new(0, 36, 0, 0)
    codeBox.BackgroundTransparency = 1
    codeBox.Text = ""
    codeBox.TextColor3 = Color3.fromRGB(200, 200, 210)
    codeBox.Font = Enum.Font.Code
    codeBox.TextSize = 12
    codeBox.TextXAlignment = Enum.TextXAlignment.Left
    codeBox.TextYAlignment = Enum.TextYAlignment.Top
    codeBox.TextWrapped = false
    codeBox.Parent = codeScroll

    -- button grid
    local btnGrid = Instance.new("Frame")
    btnGrid.Size = UDim2.new(1, -188, 0, 134)
    btnGrid.Position = UDim2.new(0, 184, 1, -138)
    btnGrid.BackgroundTransparency = 1
    btnGrid.Parent = container
    local bgl = Instance.new("UIGridLayout")
    bgl.CellSize = UDim2.new(1/3, -4, 0, 24)
    bgl.CellPadding = UDim2.new(0, 4, 0, 3)
    bgl.SortOrder = Enum.SortOrder.LayoutOrder
    bgl.Parent = btnGrid

    local function mkBtn(text, order, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 0, 0, 24)
        b.BackgroundColor3 = color or Color3.fromRGB(38, 38, 46)
        b.BorderSizePixel = 0
        b.Text = text
        b.TextColor3 = Color3.fromRGB(200, 200, 210)
        b.Font = Enum.Font.Code
        b.TextSize = 11
        b.LayoutOrder = order
        b.Parent = btnGrid
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        return b
    end

    local copyCode     = mkBtn("Copy Code", 1)
    local copyRemote   = mkBtn("Copy Remote", 2)
    local runCode      = mkBtn("Run Code", 3)
    local getScript    = mkBtn("Get Script", 4)
    local funcInfo     = mkBtn("Function Info", 5)
    local clrLogs      = mkBtn("Clr Logs", 6)
    local excludeI     = mkBtn("Exclude (i)", 7)
    local excludeN     = mkBtn("Exclude (n)", 8)
    local blockI       = mkBtn("Block (i)", 9)
    local blockN       = mkBtn("Block (n)", 10)
    local clrBlacklist = mkBtn("Clr Blacklist", 11)
    local clrBlocklist = mkBtn("Clr Blocklist", 12)
    local exportReport = mkBtn("Export Report", 13, Color3.fromRGB(36, 50, 40))
    local freqBtn      = mkBtn("Frequency", 14, Color3.fromRGB(36, 50, 40))
    local copyAll      = mkBtn("Copy All", 15, Color3.fromRGB(36, 50, 40))

    copyCode.MouseButton1Click:Connect(function()
        if not selected then return end
        if setclipboard then setclipboard(selected.script) end
        flash(copyCode, "Copied")
    end)
    copyRemote.MouseButton1Click:Connect(function()
        if not selected then return end
        if setclipboard then setclipboard(buildPath(selected.remoteRef)) end
        flash(copyRemote, "Copied")
    end)
    runCode.MouseButton1Click:Connect(function()
        if not selected then return end
        local fn = loadstring(selected.script)
        if fn then task.spawn(fn); flash(runCode, "Ran") end
    end)
    getScript.MouseButton1Click:Connect(function()
        if not selected then return end
        local full = argsToVarScript(selected.type, selected.remoteRef, selected.args)
        codeBox.Text = full; lineNums.Text = addLineNums(full)
        if setclipboard then setclipboard(full) end
        flash(getScript, "Copied")
    end)
    funcInfo.MouseButton1Click:Connect(function()
        if not selected then return end
        local info = getFuncInfo(selected.remoteRef)
        codeBox.Text = info; lineNums.Text = addLineNums(info)
        if setclipboard then setclipboard(info) end
        flash(funcInfo, "Copied")
    end)
    clrLogs.MouseButton1Click:Connect(function()
        logs = {}; selected = nil; logCounter = 0
        for _, c in ipairs(remoteList:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        codeBox.Text = ""; lineNums.Text = "1"
        infoLabel.Text = "Select a remote"; logCountLbl.Text = "0 calls"
    end)
    excludeI.MouseButton1Click:Connect(function()
        if not selected then return end
        excludedInstances[selected.path] = true; flash(excludeI, "Done")
    end)
    excludeN.MouseButton1Click:Connect(function()
        if not selected then return end
        excludedNames[selected.name] = true; flash(excludeN, "Done")
    end)
    blockI.MouseButton1Click:Connect(function()
        if not selected then return end
        blockedInstances[selected.path] = true; flash(blockI, "Blocked")
    end)
    blockN.MouseButton1Click:Connect(function()
        if not selected then return end
        blockedNames[selected.name] = true; flash(blockN, "Blocked")
    end)
    clrBlacklist.MouseButton1Click:Connect(function()
        excludedInstances = {}; excludedNames = {}; flash(clrBlacklist, "Cleared")
    end)
    clrBlocklist.MouseButton1Click:Connect(function()
        blockedInstances = {}; blockedNames = {}; flash(clrBlocklist, "Cleared")
    end)
    exportReport.MouseButton1Click:Connect(function()
        local lines = {}
        table.insert(lines, "=== AUDIT REPORT ===")
        pcall(function()
            table.insert(lines, "Game: " .. MPS_svc:GetProductInfo(game.PlaceId).Name)
        end)
        table.insert(lines, "PlaceId: " .. game.PlaceId)
        table.insert(lines, "Date: " .. os.date("%Y-%m-%d %H:%M:%S"))
        table.insert(lines, "Total Calls Logged: " .. #logs)
        table.insert(lines, "")
        table.insert(lines, "--- REMOTE FREQUENCY ---")
        local sorted = {}
        for path, count in pairs(freqMap) do
            table.insert(sorted, {path = path, count = count})
        end
        table.sort(sorted, function(a, b) return a.count > b.count end)
        for _, v in ipairs(sorted) do
            table.insert(lines, v.count .. "x  " .. v.path)
        end
        table.insert(lines, "")
        table.insert(lines, "--- ALL CALLS ---")
        for i, log in ipairs(logs) do
            table.insert(lines, "\n-- [" .. i .. "] " .. log.type .. " | " .. log.name)
            table.insert(lines, log.script)
        end
        local report = table.concat(lines, "\n")
        if setclipboard then setclipboard(report) end
        codeBox.Text = report; lineNums.Text = addLineNums(report)
        flash(exportReport, "Copied")
    end)
    freqBtn.MouseButton1Click:Connect(function()
        local lines = {"--- REMOTE FREQUENCY ---", ""}
        local sorted = {}
        for path, count in pairs(freqMap) do
            table.insert(sorted, {path = path, count = count})
        end
        table.sort(sorted, function(a, b) return a.count > b.count end)
        for _, v in ipairs(sorted) do
            table.insert(lines, v.count .. "x  " .. v.path)
        end
        local txt = table.concat(lines, "\n")
        codeBox.Text = txt; lineNums.Text = addLineNums(txt)
        if setclipboard then setclipboard(txt) end
        flash(freqBtn, "Copied")
    end)
    copyAll.MouseButton1Click:Connect(function()
        local lines = {}
        for i, log in ipairs(logs) do
            lines[i] = "-- [" .. log.type .. "] " .. log.name .. "\n" .. log.script
        end
        if setclipboard then setclipboard(table.concat(lines, "\n\n")) end
        flash(copyAll, "Copied")
    end)

    -- pause toggle via topbar (reuse parent's)
    -- we just handle paused state internally

    addLogEntry = function(method, remote, args)
        if paused then return end
        local path = remote:GetFullName()
        local name = remote.Name
        if excludedInstances[path] or excludedNames[name] then return end

        logCounter = logCounter + 1
        freqMap[path] = (freqMap[path] or 0) + 1
        local scriptStr = argsToScript(method, remote, args)

        local entry = {
            type = method, name = name, path = path,
            args = args, script = scriptStr, remoteRef = remote,
            time = os.clock(), id = logCounter
        }
        table.insert(logs, entry)
        if #logs > maxLogs then table.remove(logs, 1) end

        if logCountLbl then logCountLbl.Text = logCounter .. " calls" end

        local typeColor = method == "FireServer" and Color3.fromRGB(100, 160, 255) or Color3.fromRGB(100, 255, 160)
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -2, 0, 20)
        row.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
        row.BorderSizePixel = 0
        row.Text = "  " .. name
        row.TextColor3 = typeColor
        row.Font = Enum.Font.Code
        row.TextSize = 10
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.TextTruncate = Enum.TextTruncate.AtEnd
        row.Name = "entry_" .. entry.id
        row.LayoutOrder = logCounter
        row.AutoButtonColor = false
        row.Parent = remoteList
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 2)
        row.MouseButton1Click:Connect(function() selectEntry(entry) end)

        if not selected then selectEntry(entry) end
        remoteList.CanvasPosition = Vector2.new(0, remoteList.AbsoluteCanvasSize.Y)
    end

    -- install hooks
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if not checkcaller() then
            if method == "FireServer" and self:IsA("RemoteEvent") then
                if isBlocked(self) then return end
                addLogEntry("FireServer", self, {...})
            elseif method == "InvokeServer" and self:IsA("RemoteFunction") then
                if isBlocked(self) then return end
                addLogEntry("InvokeServer", self, {...})
            end
        end
        return oldNamecall(self, ...)
    end))

    local oldFire = Instance.new("RemoteEvent").FireServer
    local fireRef = hookfunction(oldFire, newcclosure(function(self, ...)
        if not checkcaller() and typeof(self) == "Instance" and self:IsA("RemoteEvent") then
            if isBlocked(self) then return end
            addLogEntry("FireServer", self, {...})
        end
        return fireRef(self, ...)
    end))

    local oldInvoke = Instance.new("RemoteFunction").InvokeServer
    local invokeRef = hookfunction(oldInvoke, newcclosure(function(self, ...)
        if not checkcaller() and typeof(self) == "Instance" and self:IsA("RemoteFunction") then
            if isBlocked(self) then return end
            addLogEntry("InvokeServer", self, {...})
        end
        return invokeRef(self, ...)
    end))

    return function()
        logs = {}; selected = nil; logCounter = 0
        remoteList = nil; codeBox = nil; lineNums = nil; infoLabel = nil; logCountLbl = nil
    end
end

return module
