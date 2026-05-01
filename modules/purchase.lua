local MPS = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local captured = {}

local function flash(btn, msg)
    local orig = btn.Text
    btn.Text = msg
    task.delay(1, function()
        if btn and btn.Parent then btn.Text = orig end
    end)
end

local module = {}

function module.init(container)
    captured = {}
    local activeTab = "Scanner"

    -- tab bar
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, -8, 0, 28)
    tabBar.Position = UDim2.new(0, 4, 0, 4)
    tabBar.BackgroundTransparency = 1
    tabBar.Parent = container

    local function makeTab(text, pos)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1/3, -4, 1, 0)
        b.Position = pos
        b.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
        b.BorderSizePixel = 0
        b.Text = text
        b.TextColor3 = Color3.fromRGB(180, 180, 190)
        b.Font = Enum.Font.Code
        b.TextSize = 12
        b.Parent = tabBar
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        return b
    end

    local scanTab = makeTab("Scanner", UDim2.new(0, 0, 0, 0))
    local listenTab = makeTab("Listener", UDim2.new(1/3, 2, 0, 0))
    local actionTab = makeTab("Action", UDim2.new(2/3, 4, 0, 0))

    local contentArea = Instance.new("Frame")
    contentArea.Size = UDim2.new(1, -8, 1, -38)
    contentArea.Position = UDim2.new(0, 4, 0, 36)
    contentArea.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
    contentArea.BorderSizePixel = 0
    contentArea.ClipsDescendants = true
    contentArea.Parent = container
    Instance.new("UICorner", contentArea).CornerRadius = UDim.new(0, 4)

    -- scanner frame
    local scannerFrame = Instance.new("Frame")
    scannerFrame.Size = UDim2.new(1, 0, 1, 0)
    scannerFrame.BackgroundTransparency = 1
    scannerFrame.Parent = contentArea

    local scanIdBox = Instance.new("TextBox")
    scanIdBox.Size = UDim2.new(1, -16, 0, 30)
    scanIdBox.Position = UDim2.new(0, 8, 0, 8)
    scanIdBox.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    scanIdBox.BorderSizePixel = 0
    scanIdBox.Text = ""
    scanIdBox.PlaceholderText = "Product ID"
    scanIdBox.TextColor3 = Color3.fromRGB(200, 200, 210)
    scanIdBox.PlaceholderColor3 = Color3.fromRGB(80, 80, 90)
    scanIdBox.Font = Enum.Font.Code
    scanIdBox.TextSize = 13
    scanIdBox.ClearTextOnFocus = false
    scanIdBox.Parent = scannerFrame
    Instance.new("UICorner", scanIdBox).CornerRadius = UDim.new(0, 4)

    local warnLbl = Instance.new("TextLabel")
    warnLbl.Size = UDim2.new(1, -16, 0, 24)
    warnLbl.Position = UDim2.new(0, 8, 0, 42)
    warnLbl.BackgroundTransparency = 1
    warnLbl.Text = "This won't actually purchase the product, This just fakes it."
    warnLbl.TextColor3 = Color3.fromRGB(220, 60, 60)
    warnLbl.Font = Enum.Font.Code
    warnLbl.TextSize = 10
    warnLbl.TextWrapped = true
    warnLbl.TextXAlignment = Enum.TextXAlignment.Left
    warnLbl.Parent = scannerFrame

    local function makeSignalBtn(parent, text, yPos, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 150, 0, 28)
        b.Position = UDim2.new(0, 8, 0, yPos)
        b.BackgroundColor3 = color or Color3.fromRGB(38, 38, 48)
        b.BorderSizePixel = 0
        b.Text = text
        b.TextColor3 = Color3.fromRGB(200, 200, 210)
        b.Font = Enum.Font.Code
        b.TextSize = 12
        b.Parent = parent
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        return b
    end

    local function wireSignalBtns(parent, idSource, yStart)
        local sigProduct  = makeSignalBtn(parent, "Signal Product",  yStart, Color3.fromRGB(45, 45, 60))
        local sigGamepass = makeSignalBtn(parent, "Signal Gamepass", yStart + 32)
        local sigBulk     = makeSignalBtn(parent, "Signal Bulk",    yStart + 64, Color3.fromRGB(45, 45, 60))
        local sigPurchase = makeSignalBtn(parent, "Signal Purchase", yStart + 96)

        sigProduct.MouseButton1Click:Connect(function()
            local id = tonumber(idSource())
            if not id then flash(sigProduct, "Bad ID"); return end
            if firesignal then
                firesignal(MPS.PromptProductPurchaseFinished, lp.UserId, id, true)
                flash(sigProduct, "Signaled")
            end
        end)
        sigGamepass.MouseButton1Click:Connect(function()
            local id = tonumber(idSource())
            if not id then flash(sigGamepass, "Bad ID"); return end
            if firesignal then
                firesignal(MPS.PromptGamePassPurchaseFinished, lp, id, true)
                flash(sigGamepass, "Signaled")
            end
        end)
        sigBulk.MouseButton1Click:Connect(function()
            local id = tonumber(idSource())
            if not id then flash(sigBulk, "Bad ID"); return end
            if firesignal then
                for _ = 1, 5 do
                    firesignal(MPS.PromptProductPurchaseFinished, lp.UserId, id, true)
                    task.wait(0.1)
                end
                flash(sigBulk, "5x Sent")
            end
        end)
        sigPurchase.MouseButton1Click:Connect(function()
            local id = tonumber(idSource())
            if not id then flash(sigPurchase, "Bad ID"); return end
            if firesignal then
                firesignal(MPS.PromptPurchaseFinished, lp, id, true)
                flash(sigPurchase, "Signaled")
            end
        end)
    end

    wireSignalBtns(scannerFrame, function() return scanIdBox.Text end, 70)

    -- listener frame
    local listenerFrame = Instance.new("Frame")
    listenerFrame.Size = UDim2.new(1, 0, 1, 0)
    listenerFrame.BackgroundTransparency = 1
    listenerFrame.Visible = false
    listenerFrame.Parent = contentArea

    local listScroll = Instance.new("ScrollingFrame")
    listScroll.Size = UDim2.new(1, -8, 1, -8)
    listScroll.Position = UDim2.new(0, 4, 0, 4)
    listScroll.BackgroundTransparency = 1
    listScroll.BorderSizePixel = 0
    listScroll.ScrollBarThickness = 4
    listScroll.ScrollBarImageColor3 = Color3.fromRGB(55, 55, 65)
    listScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    listScroll.Parent = listenerFrame
    local lsl = Instance.new("UIListLayout")
    lsl.SortOrder = Enum.SortOrder.LayoutOrder
    lsl.Padding = UDim.new(0, 3)
    lsl.Parent = listScroll

    -- action frame
    local actionFrame = Instance.new("Frame")
    actionFrame.Size = UDim2.new(1, 0, 1, 0)
    actionFrame.BackgroundTransparency = 1
    actionFrame.Visible = false
    actionFrame.Parent = contentArea

    local actionIdBox = Instance.new("TextBox")
    actionIdBox.Size = UDim2.new(1, -16, 0, 30)
    actionIdBox.Position = UDim2.new(0, 8, 0, 8)
    actionIdBox.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    actionIdBox.BorderSizePixel = 0
    actionIdBox.Text = ""
    actionIdBox.PlaceholderText = "Product ID"
    actionIdBox.TextColor3 = Color3.fromRGB(200, 200, 210)
    actionIdBox.PlaceholderColor3 = Color3.fromRGB(80, 80, 90)
    actionIdBox.Font = Enum.Font.Code
    actionIdBox.TextSize = 13
    actionIdBox.ClearTextOnFocus = false
    actionIdBox.Parent = actionFrame
    Instance.new("UICorner", actionIdBox).CornerRadius = UDim.new(0, 4)

    local actionWarn = Instance.new("TextLabel")
    actionWarn.Size = UDim2.new(1, -16, 0, 24)
    actionWarn.Position = UDim2.new(0, 8, 0, 42)
    actionWarn.BackgroundTransparency = 1
    actionWarn.Text = "This won't actually purchase the product, This just fakes it."
    actionWarn.TextColor3 = Color3.fromRGB(220, 60, 60)
    actionWarn.Font = Enum.Font.Code
    actionWarn.TextSize = 10
    actionWarn.TextWrapped = true
    actionWarn.TextXAlignment = Enum.TextXAlignment.Left
    actionWarn.Parent = actionFrame

    wireSignalBtns(actionFrame, function() return actionIdBox.Text end, 70)

    -- tab switching
    local function switchTab(name)
        activeTab = name
        scannerFrame.Visible = name == "Scanner"
        listenerFrame.Visible = name == "Listener"
        actionFrame.Visible = name == "Action"
        scanTab.BackgroundColor3 = name == "Scanner" and Color3.fromRGB(50, 50, 65) or Color3.fromRGB(35, 35, 42)
        listenTab.BackgroundColor3 = name == "Listener" and Color3.fromRGB(50, 50, 65) or Color3.fromRGB(35, 35, 42)
        actionTab.BackgroundColor3 = name == "Action" and Color3.fromRGB(50, 50, 65) or Color3.fromRGB(35, 35, 42)
    end
    scanTab.MouseButton1Click:Connect(function() switchTab("Scanner") end)
    listenTab.MouseButton1Click:Connect(function() switchTab("Listener") end)
    actionTab.MouseButton1Click:Connect(function() switchTab("Action") end)
    switchTab("Scanner")

    -- capture logic
    local function addCaptured(name, id, ptype)
        for _, v in ipairs(captured) do
            if v.id == id then return end
        end
        table.insert(captured, {name = name, id = id, ptype = ptype})

        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -4, 0, 38)
        row.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
        row.BorderSizePixel = 0
        row.Parent = listScroll
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

        local nLbl = Instance.new("TextLabel")
        nLbl.Size = UDim2.new(1, -65, 0, 16)
        nLbl.Position = UDim2.new(0, 8, 0, 2)
        nLbl.BackgroundTransparency = 1
        nLbl.Text = name .. " (" .. ptype .. ")"
        nLbl.TextColor3 = Color3.fromRGB(200, 200, 210)
        nLbl.Font = Enum.Font.Code
        nLbl.TextSize = 11
        nLbl.TextXAlignment = Enum.TextXAlignment.Left
        nLbl.TextTruncate = Enum.TextTruncate.AtEnd
        nLbl.Parent = row

        local idLbl = Instance.new("TextLabel")
        idLbl.Size = UDim2.new(1, -65, 0, 14)
        idLbl.Position = UDim2.new(0, 8, 0, 19)
        idLbl.BackgroundTransparency = 1
        idLbl.Text = tostring(id)
        idLbl.TextColor3 = Color3.fromRGB(200, 180, 50)
        idLbl.Font = Enum.Font.Code
        idLbl.TextSize = 10
        idLbl.TextXAlignment = Enum.TextXAlignment.Left
        idLbl.Parent = row

        local copyBtn = Instance.new("TextButton")
        copyBtn.Size = UDim2.new(0, 22, 0, 22)
        copyBtn.Position = UDim2.new(1, -52, 0, 8)
        copyBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
        copyBtn.BorderSizePixel = 0
        copyBtn.Text = "C"
        copyBtn.TextColor3 = Color3.fromRGB(170, 170, 180)
        copyBtn.Font = Enum.Font.Code
        copyBtn.TextSize = 10
        copyBtn.Parent = row
        Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 3)

        local useBtn = Instance.new("TextButton")
        useBtn.Size = UDim2.new(0, 22, 0, 22)
        useBtn.Position = UDim2.new(1, -26, 0, 8)
        useBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
        useBtn.BorderSizePixel = 0
        useBtn.Text = ">"
        useBtn.TextColor3 = Color3.fromRGB(170, 170, 180)
        useBtn.Font = Enum.Font.Code
        useBtn.TextSize = 10
        useBtn.Parent = row
        Instance.new("UICorner", useBtn).CornerRadius = UDim.new(0, 3)

        copyBtn.MouseButton1Click:Connect(function()
            if setclipboard then setclipboard(tostring(id)) end
            flash(copyBtn, "ok")
        end)
        useBtn.MouseButton1Click:Connect(function()
            scanIdBox.Text = tostring(id)
            actionIdBox.Text = tostring(id)
        end)
    end

    -- hook purchase prompts
    pcall(function()
        local oldPP = MPS.PromptProductPurchase
        hookfunction(oldPP, newcclosure(function(self, player, productId, ...)
            local name = "unknown"
            pcall(function()
                local info = MPS:GetProductInfo(productId, Enum.InfoType.Product)
                if info and info.Name then name = info.Name end
            end)
            addCaptured(name, productId, "Product")
            return oldPP(self, player, productId, ...)
        end))
    end)

    pcall(function()
        local oldGP = MPS.PromptGamePassPurchase
        hookfunction(oldGP, newcclosure(function(self, player, gpId, ...)
            local name = "unknown"
            pcall(function()
                local info = MPS:GetProductInfo(gpId, Enum.InfoType.GamePass)
                if info and info.Name then name = info.Name end
            end)
            addCaptured(name, gpId, "Gamepass")
            return oldGP(self, player, gpId, ...)
        end))
    end)

    pcall(function()
        local oldAP = MPS.PromptPurchase
        hookfunction(oldAP, newcclosure(function(self, player, assetId, ...)
            local name = "unknown"
            pcall(function()
                local info = MPS:GetProductInfo(assetId, Enum.InfoType.Asset)
                if info and info.Name then name = info.Name end
            end)
            addCaptured(name, assetId, "Asset")
            return oldAP(self, player, assetId, ...)
        end))
    end)

    return function()
        captured = {}
    end
end

return module
