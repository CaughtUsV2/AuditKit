local module = {}

local function flash(btn, msg)
    local orig = btn.Text
    btn.Text = msg
    task.delay(1, function()
        if btn and btn.Parent then btn.Text = orig end
    end)
end

function module.init(container)
    local SCRIPTS_PATH = "AuditKit/scripts/"
    local scriptFiles = {}

    -- left: file list
    local leftPanel = Instance.new("Frame")
    leftPanel.Size = UDim2.new(0, 180, 1, -4)
    leftPanel.Position = UDim2.new(0, 2, 0, 2)
    leftPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    leftPanel.BorderSizePixel = 0
    leftPanel.Parent = container
    Instance.new("UICorner", leftPanel).CornerRadius = UDim.new(0, 4)

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -8, 0, 20)
    titleLbl.Position = UDim2.new(0, 4, 0, 4)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = "Scripts"
    titleLbl.TextColor3 = Color3.fromRGB(140, 140, 155)
    titleLbl.Font = Enum.Font.Code
    titleLbl.TextSize = 11
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = leftPanel

    local refreshBtn = Instance.new("TextButton")
    refreshBtn.Size = UDim2.new(1, -8, 0, 22)
    refreshBtn.Position = UDim2.new(0, 4, 0, 26)
    refreshBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
    refreshBtn.BorderSizePixel = 0
    refreshBtn.Text = "Refresh"
    refreshBtn.TextColor3 = Color3.fromRGB(180, 180, 190)
    refreshBtn.Font = Enum.Font.Code
    refreshBtn.TextSize = 11
    refreshBtn.Parent = leftPanel
    Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 3)

    local fileList = Instance.new("ScrollingFrame")
    fileList.Size = UDim2.new(1, -4, 1, -56)
    fileList.Position = UDim2.new(0, 2, 0, 52)
    fileList.BackgroundTransparency = 1
    fileList.BorderSizePixel = 0
    fileList.ScrollBarThickness = 3
    fileList.ScrollBarImageColor3 = Color3.fromRGB(55, 55, 65)
    fileList.CanvasSize = UDim2.new(0, 0, 0, 0)
    fileList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    fileList.Parent = leftPanel
    local fll = Instance.new("UIListLayout")
    fll.SortOrder = Enum.SortOrder.Name
    fll.Padding = UDim.new(0, 2)
    fll.Parent = fileList

    -- right: editor
    local editorPanel = Instance.new("Frame")
    editorPanel.Size = UDim2.new(1, -188, 1, -38)
    editorPanel.Position = UDim2.new(0, 184, 0, 2)
    editorPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    editorPanel.BorderSizePixel = 0
    editorPanel.ClipsDescendants = true
    editorPanel.Parent = container
    Instance.new("UICorner", editorPanel).CornerRadius = UDim.new(0, 4)

    local fileNameLbl = Instance.new("TextLabel")
    fileNameLbl.Size = UDim2.new(1, -8, 0, 16)
    fileNameLbl.Position = UDim2.new(0, 4, 0, 2)
    fileNameLbl.BackgroundTransparency = 1
    fileNameLbl.Text = "No file selected"
    fileNameLbl.TextColor3 = Color3.fromRGB(90, 90, 105)
    fileNameLbl.Font = Enum.Font.Code
    fileNameLbl.TextSize = 10
    fileNameLbl.TextXAlignment = Enum.TextXAlignment.Left
    fileNameLbl.Parent = editorPanel

    local editorBox = Instance.new("TextBox")
    editorBox.Size = UDim2.new(1, -8, 1, -22)
    editorBox.Position = UDim2.new(0, 4, 0, 20)
    editorBox.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
    editorBox.BorderSizePixel = 0
    editorBox.Text = ""
    editorBox.PlaceholderText = "Paste or write a script here..."
    editorBox.TextColor3 = Color3.fromRGB(200, 200, 210)
    editorBox.PlaceholderColor3 = Color3.fromRGB(60, 60, 70)
    editorBox.Font = Enum.Font.Code
    editorBox.TextSize = 12
    editorBox.TextXAlignment = Enum.TextXAlignment.Left
    editorBox.TextYAlignment = Enum.TextYAlignment.Top
    editorBox.ClearTextOnFocus = false
    editorBox.MultiLine = true
    editorBox.TextWrapped = true
    editorBox.Parent = editorPanel
    Instance.new("UICorner", editorBox).CornerRadius = UDim.new(0, 3)

    -- bottom buttons
    local btnBar = Instance.new("Frame")
    btnBar.Size = UDim2.new(1, -188, 0, 30)
    btnBar.Position = UDim2.new(0, 184, 1, -34)
    btnBar.BackgroundTransparency = 1
    btnBar.Parent = container

    local function mkBtn(text, pos, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 80, 0, 26)
        b.Position = pos
        b.BackgroundColor3 = color or Color3.fromRGB(38, 38, 46)
        b.BorderSizePixel = 0
        b.Text = text
        b.TextColor3 = Color3.fromRGB(200, 200, 210)
        b.Font = Enum.Font.Code
        b.TextSize = 11
        b.Parent = btnBar
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        return b
    end

    local runBtn  = mkBtn("Run",   UDim2.new(0, 0, 0, 0), Color3.fromRGB(36, 55, 40))
    local saveBtn = mkBtn("Save",  UDim2.new(0, 84, 0, 0))
    local copyBtn = mkBtn("Copy",  UDim2.new(0, 168, 0, 0))
    local newBtn  = mkBtn("New",   UDim2.new(0, 252, 0, 0))
    local delBtn  = mkBtn("Delete", UDim2.new(0, 336, 0, 0), Color3.fromRGB(60, 30, 30))

    local currentFile = nil

    local function loadFileList()
        for _, c in ipairs(fileList:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        scriptFiles = {}

        if not listfiles then return end
        local ok, files = pcall(listfiles, SCRIPTS_PATH)
        if not ok then
            pcall(function() makefolder(SCRIPTS_PATH) end)
            return
        end

        for _, path in ipairs(files) do
            if path:match("%.lua$") then
                local name = path:match("([^/\\]+)$")
                table.insert(scriptFiles, {name = name, path = path})

                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, -4, 0, 22)
                btn.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
                btn.BorderSizePixel = 0
                btn.Text = "  " .. name
                btn.TextColor3 = Color3.fromRGB(180, 180, 195)
                btn.Font = Enum.Font.Code
                btn.TextSize = 10
                btn.TextXAlignment = Enum.TextXAlignment.Left
                btn.TextTruncate = Enum.TextTruncate.AtEnd
                btn.AutoButtonColor = false
                btn.Name = name
                btn.Parent = fileList
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 2)

                btn.MouseButton1Click:Connect(function()
                    currentFile = path
                    fileNameLbl.Text = name
                    local rok, content = pcall(readfile, path)
                    editorBox.Text = rok and content or "failed to read"
                    for _, c in ipairs(fileList:GetChildren()) do
                        if c:IsA("TextButton") then
                            c.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
                        end
                    end
                    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
                end)
            end
        end
    end

    refreshBtn.MouseButton1Click:Connect(loadFileList)

    runBtn.MouseButton1Click:Connect(function()
        local src = editorBox.Text
        if src == "" then return end
        local fn = loadstring(src)
        if fn then task.spawn(fn); flash(runBtn, "Ran")
        else flash(runBtn, "Err") end
    end)

    saveBtn.MouseButton1Click:Connect(function()
        if not currentFile then flash(saveBtn, "No file"); return end
        if writefile then
            pcall(writefile, currentFile, editorBox.Text)
            flash(saveBtn, "Saved")
        end
    end)

    copyBtn.MouseButton1Click:Connect(function()
        if setclipboard then setclipboard(editorBox.Text) end
        flash(copyBtn, "Copied")
    end)

    newBtn.MouseButton1Click:Connect(function()
        if not writefile then return end
        local name = "script_" .. math.random(1000, 9999) .. ".lua"
        pcall(function()
            makefolder(SCRIPTS_PATH)
        end)
        pcall(writefile, SCRIPTS_PATH .. name, "-- " .. name)
        currentFile = SCRIPTS_PATH .. name
        fileNameLbl.Text = name
        editorBox.Text = "-- " .. name
        loadFileList()
        flash(newBtn, "Created")
    end)

    delBtn.MouseButton1Click:Connect(function()
        if not currentFile then return end
        if delfile then
            pcall(delfile, currentFile)
            currentFile = nil
            fileNameLbl.Text = "No file selected"
            editorBox.Text = ""
            loadFileList()
            flash(delBtn, "Deleted")
        end
    end)

    loadFileList()

    return function()
        currentFile = nil
        scriptFiles = {}
    end
end

return module
