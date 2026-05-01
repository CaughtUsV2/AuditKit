local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local BASE_PATH = "AuditKit/modules/"
local FETCHED = getgenv().__AUDITKIT_MODULES or {}

local modules = {
    {name = "Spy",      file = "spy",      desc = "Remote dumper"},
    {name = "Purchase", file = "purchase", desc = "Fake buy tester"},
    {name = "Scripts",  file = "scripts",  desc = "Script loader"},
}

local activeModule = nil
local activeCleanup = nil
local ui

local function createHub()
    if ui then ui:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "AuditKit_" .. math.random(1000, 9999)
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    if syn and syn.protect_gui then
        syn.protect_gui(sg)
        sg.Parent = game:GetService("CoreGui")
    elseif gethui then
        sg.Parent = gethui()
    else
        sg.Parent = game:GetService("CoreGui")
    end
    ui = sg

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 780, 0, 480)
    main.Position = UDim2.new(0.5, -390, 0.5, -240)
    main.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    main.Parent = sg
    local mc = Instance.new("UICorner")
    mc.CornerRadius = UDim.new(0, 8)
    mc.Parent = main

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(40, 40, 50)
    stroke.Thickness = 1
    stroke.Parent = main

    -- top bar
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 32)
    topBar.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
    topBar.BorderSizePixel = 0
    topBar.Parent = main

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0, 200, 1, 0)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "AuditKit"
    title.TextColor3 = Color3.fromRGB(160, 160, 175)
    title.Font = Enum.Font.Code
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = topBar

    local gameLabel = Instance.new("TextLabel")
    gameLabel.Size = UDim2.new(0, 300, 1, 0)
    gameLabel.Position = UDim2.new(0, 100, 0, 0)
    gameLabel.BackgroundTransparency = 1
    gameLabel.TextColor3 = Color3.fromRGB(80, 80, 95)
    gameLabel.Font = Enum.Font.Code
    gameLabel.TextSize = 11
    gameLabel.TextXAlignment = Enum.TextXAlignment.Left
    gameLabel.Parent = topBar
    pcall(function()
        local info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
        gameLabel.Text = info.Name .. " [" .. game.PlaceId .. "]"
    end)

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 24, 0, 22)
    closeBtn.Position = UDim2.new(1, -30, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(130, 35, 35)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
    closeBtn.Font = Enum.Font.Code
    closeBtn.TextSize = 11
    closeBtn.Parent = topBar
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 3)

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 24, 0, 22)
    minBtn.Position = UDim2.new(1, -58, 0, 5)
    minBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
    minBtn.BorderSizePixel = 0
    minBtn.Text = "_"
    minBtn.TextColor3 = Color3.fromRGB(200, 200, 205)
    minBtn.Font = Enum.Font.Code
    minBtn.TextSize = 11
    minBtn.Parent = topBar
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 3)

    local minimized = false
    local savedSize = main.Size
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        main.Size = minimized and UDim2.new(0, 780, 0, 32) or savedSize
    end)

    closeBtn.MouseButton1Click:Connect(function()
        if activeCleanup then pcall(activeCleanup) end
        sg:Destroy()
        ui = nil
    end)

    -- drag
    local dragging, dragStart, startPos
    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = input.Position; startPos = main.Position
        end
    end)
    topBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)

    -- sidebar
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 130, 1, -32)
    sidebar.Position = UDim2.new(0, 0, 0, 32)
    sidebar.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    sidebar.BorderSizePixel = 0
    sidebar.Parent = main

    local sideLayout = Instance.new("UIListLayout")
    sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sideLayout.Padding = UDim.new(0, 2)
    sideLayout.Parent = sidebar
    local sidePad = Instance.new("UIPadding")
    sidePad.PaddingTop = UDim.new(0, 6)
    sidePad.PaddingLeft = UDim.new(0, 4)
    sidePad.PaddingRight = UDim.new(0, 4)
    sidePad.Parent = sidebar

    -- content area
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -134, 1, -36)
    content.Position = UDim2.new(0, 132, 0, 34)
    content.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
    content.BorderSizePixel = 0
    content.ClipsDescendants = true
    content.Parent = main
    Instance.new("UICorner", content).CornerRadius = UDim.new(0, 4)

    local tabBtns = {}

    local function switchModule(idx)
        if activeCleanup then
            pcall(activeCleanup)
            activeCleanup = nil
        end
        for _, c in ipairs(content:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end

        activeModule = idx
        for i, btn in ipairs(tabBtns) do
            btn.BackgroundColor3 = i == idx and Color3.fromRGB(45, 45, 60) or Color3.fromRGB(28, 28, 34)
        end

        local mod = modules[idx]
        local ok, loaded = pcall(function()
            if FETCHED[mod.file] then
                return loadstring(FETCHED[mod.file])()
            end
            if loadfile then
                local fn = loadfile(BASE_PATH .. mod.file .. ".lua")
                if fn then return fn() end
            end
            if readfile then
                local src = readfile(BASE_PATH .. mod.file .. ".lua")
                return loadstring(src)()
            end
        end)

        if ok and loaded and loaded.init then
            activeCleanup = loaded.init(content)
        else
            local errLbl = Instance.new("TextLabel")
            errLbl.Size = UDim2.new(1, -20, 0, 60)
            errLbl.Position = UDim2.new(0, 10, 0, 10)
            errLbl.BackgroundTransparency = 1
            errLbl.Text = "Failed to load " .. mod.file .. ".lua\nMake sure its in your executor workspace under AuditKit/modules/"
            errLbl.TextColor3 = Color3.fromRGB(220, 80, 80)
            errLbl.Font = Enum.Font.Code
            errLbl.TextSize = 12
            errLbl.TextWrapped = true
            errLbl.TextXAlignment = Enum.TextXAlignment.Left
            errLbl.TextYAlignment = Enum.TextYAlignment.Top
            errLbl.Parent = content
        end
    end

    for i, mod in ipairs(modules) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 36)
        btn.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
        btn.BorderSizePixel = 0
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.LayoutOrder = i
        btn.Parent = sidebar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

        local nameL = Instance.new("TextLabel")
        nameL.Size = UDim2.new(1, -10, 0, 16)
        nameL.Position = UDim2.new(0, 8, 0, 3)
        nameL.BackgroundTransparency = 1
        nameL.Text = mod.name
        nameL.TextColor3 = Color3.fromRGB(200, 200, 210)
        nameL.Font = Enum.Font.Code
        nameL.TextSize = 12
        nameL.TextXAlignment = Enum.TextXAlignment.Left
        nameL.Parent = btn

        local descL = Instance.new("TextLabel")
        descL.Size = UDim2.new(1, -10, 0, 12)
        descL.Position = UDim2.new(0, 8, 0, 20)
        descL.BackgroundTransparency = 1
        descL.Text = mod.desc
        descL.TextColor3 = Color3.fromRGB(80, 80, 95)
        descL.Font = Enum.Font.Code
        descL.TextSize = 9
        descL.TextXAlignment = Enum.TextXAlignment.Left
        descL.Parent = btn

        tabBtns[i] = btn
        btn.MouseButton1Click:Connect(function() switchModule(i) end)
    end

    switchModule(1)
    return sg
end

createHub()
