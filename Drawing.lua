local DrawingLibrary = {}

DrawingLibrary.Drawings = {}
DrawingLibrary.Instances = {}
DrawingLibrary.ESPConnections = {}

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer      = Players.LocalPlayer
local Camera           = workspace.CurrentCamera

local function getRoot()
    local ok, hui = pcall(gethui)
    if ok and hui then return hui end
    return game:GetService("CoreGui")
end

local _gradGui do
    local sg = Instance.new("ScreenGui")
    sg.Name           = "\0\0GradESP"
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = getRoot()
    _gradGui          = sg
end

local function buildSequence(colors)
    local n = #colors
    if n == 0 then return ColorSequence.new(Color3.new(1,1,1)) end
    if n == 1 then return ColorSequence.new(colors[1]) end
    local kps = {}
    for i = 1, n do
        kps[i] = ColorSequenceKeypoint.new((i-1)/(n-1), colors[i])
    end
    return ColorSequence.new(kps)
end

local function patchColor(colors, index, newColor)
    local copy = {}
    for i, c in ipairs(colors) do copy[i] = c end
    local idx = math.clamp(index, 1, #copy)
    copy[idx] = newColor
    return copy, buildSequence(copy)
end

local function AddDrawing(drawing)
    table.insert(DrawingLibrary.Drawings, drawing)
    return drawing
end

local function AddInstance(instance)
    table.insert(DrawingLibrary.Instances, instance)
    return instance
end


local MAX_HP_SEGMENTS = 12

local function GetCharacterBox(character)
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local head     = character:FindFirstChild("Head")
    if not rootPart or not head then return nil, nil, false end

    local rootPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
    if not onScreen then return nil, nil, false end

    local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
    local legPos  = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))

    local height   = math.abs(headPos.Y - legPos.Y)
    local width    = height / 2
    local size     = Vector2.new(width, height)
    local position = Vector2.new(rootPos.X - width / 2, headPos.Y)

    return position, size, true
end

local function GetWeaponName(player, character, customPath)
    if customPath then
        if typeof(customPath) == "Instance" then
            return customPath.Name
        elseif type(customPath) == "string" then
            local root = game
            for segment in string.gmatch(customPath, "[^/]+") do
                root = root:FindFirstChild(segment)
                if not root then break end
            end
            if root then return root.Name end
        end
    end
    if character then
        for _, obj in ipairs(character:GetChildren()) do
            if obj:IsA("Tool") then return obj.Name end
        end
    end
    if player then
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            for _, obj in ipairs(backpack:GetChildren()) do
                if obj:IsA("Tool") then return obj.Name end
            end
        end
    end
    return "None"
end

function DrawingLibrary:ClearAll()
    for _, conn in pairs(self.ESPConnections) do
        if conn.Disconnect then conn:Disconnect() end
    end
    self.ESPConnections = {}

    for _, drawing in pairs(self.Drawings) do
        if drawing.Remove then drawing:Remove() end
    end
    self.Drawings = {}

    for _, instance in pairs(self.Instances) do
        if instance.Destroy then instance:Destroy() end
    end
    self.Instances = {}
end

local function CreateDynamicESP(library, target, drawingType, properties)
    local isAll = (string.lower(target) == "all")
    local specificPlayer = not isAll and Players:FindFirstChild(target) or nil

    local espObjects = {}
    local connections = {}

    local function CreateDrawing()
        if drawingType == "Box" then
            local obj = Drawing.new("Square")
            obj.Color        = properties.Color        or Color3.new(1, 1, 1)
            obj.Thickness    = properties.Thickness    or 1
            obj.Transparency = properties.Transparency or 1
            obj.Filled       = false
            return obj
        elseif drawingType == "Text" then
            local obj = Drawing.new("Text")
            obj.Color        = properties.Color        or Color3.new(1, 1, 1)
            obj.Size         = properties.Size         or 16
            obj.Center       = properties.Center       ~= nil and properties.Center or true
            obj.Outline      = properties.Outline      ~= nil and properties.Outline or true
            obj.OutlineColor = properties.OutlineColor or Color3.new(0, 0, 0)
            obj.Font         = properties.Font         or 2
            return obj
        elseif drawingType == "Line" then
            local obj = Drawing.new("Line")
            obj.Color        = properties.Color        or Color3.new(1, 1, 1)
            obj.Thickness    = properties.Thickness    or 1
            obj.Transparency = properties.Transparency or 1
            return obj
        end
    end

    local function SetupPlayer(player)
        if player == LocalPlayer and not properties.ShowLocal then return end
        if not espObjects[player] then
            espObjects[player] = CreateDrawing()
        end
    end

    local function RemovePlayer(player)
        if espObjects[player] then
            espObjects[player]:Remove()
            espObjects[player] = nil
        end
    end

    if isAll then
        for _, p in ipairs(Players:GetPlayers()) do SetupPlayer(p) end
        local jc = Players.PlayerAdded:Connect(SetupPlayer)
        local lc = Players.PlayerRemoving:Connect(RemovePlayer)
        table.insert(connections, jc); table.insert(library.ESPConnections, jc)
        table.insert(connections, lc); table.insert(library.ESPConnections, lc)
    elseif specificPlayer then
        SetupPlayer(specificPlayer)
    end

    local renderConn = RunService.RenderStepped:Connect(function()
        for player, obj in pairs(espObjects) do
            if not properties.Visible then obj.Visible = false continue end

            if properties.IgnoreTeammates
                and player.Team == LocalPlayer.Team
                and player.Team ~= nil
            then obj.Visible = false continue end

            if not player or not player.Parent or not player.Character then
                obj.Visible = false continue
            end

            local character = player.Character
            local humanoid  = character:FindFirstChild("Humanoid")
            if not humanoid or humanoid.Health <= 0 then obj.Visible = false continue end

            local pos, size, onScreen = GetCharacterBox(character)
            if not onScreen then obj.Visible = false continue end

            if drawingType == "Box" then
                obj.Size     = size
                obj.Position = pos
                obj.Visible  = true

            elseif drawingType == "Text" then
                obj.Position = Vector2.new(pos.X + size.X / 2, pos.Y - obj.Size - 2)

                local textContent = properties.Text or "Name"
                local finalStr    = ""
                local pathVal     = nil

                if properties.Path then
                    if typeof(properties.Path) == "Instance" then
                        pathVal = properties.Path:IsA("ValueBase") and properties.Path.Value or properties.Path.Name
                    elseif type(properties.Path) == "string" then
                        pathVal = player:GetAttribute(properties.Path)
                        if pathVal == nil and character then pathVal = character:GetAttribute(properties.Path) end
                        if pathVal == nil then
                            local child = player:FindFirstChild(properties.Path)
                                or (character and character:FindFirstChild(properties.Path))
                            if child and child:IsA("ValueBase") then pathVal = child.Value end
                        end
                    end
                end

                if type(textContent) == "function" then
                    finalStr = textContent(player, pathVal) or ""
                elseif type(textContent) == "string" then
                    if string.find(textContent, "[health]", 1, true) then
                        finalStr = string.gsub(textContent, "%[health%]", tostring(math.floor(humanoid.Health)))
                    elseif string.lower(textContent) == "health" then
                        finalStr = "HP: " .. tostring(math.floor(humanoid.Health))
                    else
                        finalStr = textContent
                    end
                    if pathVal ~= nil then
                        if string.find(finalStr, "{value}", 1, true) then
                            finalStr = string.gsub(finalStr, "{value}", tostring(pathVal))
                        else
                            finalStr = finalStr .. tostring(pathVal)
                        end
                    end
                else
                    finalStr = tostring(textContent)
                end

                obj.Text    = finalStr
                obj.Visible = true

            elseif drawingType == "Line" then
                local viewport = Camera.ViewportSize
                obj.From    = properties.From or Vector2.new(viewport.X / 2, viewport.Y)
                obj.To      = Vector2.new(pos.X + size.X / 2, pos.Y + size.Y)
                obj.Visible = true
            end
        end
    end)
    table.insert(connections, renderConn)
    table.insert(library.ESPConnections, renderConn)

    local wrapper = {
        Objects = espObjects,
        UpdateVisible = function(self, state)
            properties.Visible = state
            if not state then
                for _, obj in pairs(self.Objects) do obj.Visible = false end
            end
        end,
        UpdateTeamCheck = function(self, state)
            properties.IgnoreTeammates = state
            for player, obj in pairs(self.Objects) do
                if state and player.Team == LocalPlayer.Team and player.Team ~= nil then
                    obj.Visible = false
                else
                    obj.Visible = properties.Visible
                end
            end
        end,
        UpdateColor = function(self, newColor)
            properties.Color = newColor
            for _, obj in pairs(self.Objects) do obj.Color = newColor end
        end,
        UpdateText = function(self, newText)
            properties.Text = newText
        end,
        UpdateSize = function(self, newSize)
            properties.Size = newSize
            for _, obj in pairs(self.Objects) do if obj.Size then obj.Size = newSize end end
        end,
        Remove = function(self)
            for _, conn in pairs(connections) do if conn.Disconnect then conn:Disconnect() end end
            for _, obj in pairs(self.Objects) do obj:Remove() end
            self.Objects = {}
        end,
    }
    return AddDrawing(wrapper)
end

local function CreateBoxObjects(properties)
    local outline = Drawing.new("Square")
    outline.Color        = properties.Color     or Color3.new(1, 1, 1)
    outline.Thickness    = properties.Thickness or 1
    outline.Transparency = properties.Transparency ~= nil and properties.Transparency or 1
    outline.Filled       = false
    outline.Visible      = false

    local defaultColors = properties.GradientColors or {
        Color3.fromRGB(255, 0, 0),
        Color3.fromRGB(0, 255, 0),
        Color3.fromRGB(0, 0, 255),
    }

    local frame = Instance.new("Frame")
    frame.BorderSizePixel        = 0
    frame.BackgroundColor3       = Color3.new(1, 1, 1)
    frame.BackgroundTransparency = properties.FillTransparency ~= nil
        and properties.FillTransparency or 0.5
    frame.Visible                = false
    frame.ZIndex                 = 2
    frame.Parent                 = _gradGui

    local uig = Instance.new("UIGradient")
    uig.Color    = buildSequence(defaultColors)
    uig.Rotation = properties.GradientRotation or 0
    uig.Parent   = frame

    local borderDraw = Drawing.new("Square")
    borderDraw.Filled    = false
    borderDraw.Thickness = properties.BorderThickness or 1
    borderDraw.Color     = properties.BorderColor     or Color3.new(0, 0, 0)
    borderDraw.Visible   = false

    return {
        outline    = outline,
        borderDraw = borderDraw,
        frame      = frame,
        uig        = uig,
        colors     = defaultColors,
        spin       = 0,
    }
end

function DrawingLibrary:MakeBox(targetOrProperties, properties)
    if type(targetOrProperties) == "table" then
        properties = targetOrProperties
        local box = Drawing.new("Square")
        box.Visible      = properties.Visible      or false
        box.Color        = properties.Color        or Color3.new(1, 1, 1)
        box.Thickness    = properties.Thickness    or 1
        box.Transparency = properties.Transparency or 1
        box.Filled       = properties.Filled       or false
        box.Position     = properties.Position     or Vector2.new(0, 0)
        box.Size         = properties.Size         or Vector2.new(100, 100)
        return AddDrawing({
            Object        = box,
            UpdateVisible = function(self, state) self.Object.Visible = state end,
            Remove        = function(self)        self.Object:Remove() end,
        })
    end

    if type(targetOrProperties) ~= "string" then return end
    properties = properties or {}

    local isAll          = (string.lower(targetOrProperties) == "all")
    local specificPlayer = not isAll and Players:FindFirstChild(targetOrProperties) or nil

    local espObjects  = {}
    local connections = {}
    local rotAngle    = 0

    local function SetupPlayer(player)
        if player == LocalPlayer and not properties.ShowLocal then return end
        if not espObjects[player] then
            espObjects[player] = CreateBoxObjects(properties)
        end
    end

    local function RemovePlayer(player)
        local obj = espObjects[player]
        if not obj then return end
        obj.outline:Remove()
        obj.borderDraw:Remove()
        obj.frame:Destroy()
        espObjects[player] = nil
    end

    if isAll then
        for _, p in ipairs(Players:GetPlayers()) do SetupPlayer(p) end
        local jc = Players.PlayerAdded:Connect(SetupPlayer)
        local lc = Players.PlayerRemoving:Connect(RemovePlayer)
        table.insert(connections, jc); table.insert(self.ESPConnections, jc)
        table.insert(connections, lc); table.insert(self.ESPConnections, lc)
    elseif specificPlayer then
        SetupPlayer(specificPlayer)
    end

    local renderConn = RunService.RenderStepped:Connect(function(dt)
        rotAngle = (rotAngle + dt * (properties.GradientSpeed or 90)) % 360

        for player, obj in pairs(espObjects) do
            local function hideAll()
                obj.outline.Visible    = false
                obj.borderDraw.Visible = false
                obj.frame.Visible      = false
            end

            if not properties.Visible then hideAll() continue end

            if properties.IgnoreTeammates
                and player.Team == LocalPlayer.Team
                and player.Team ~= nil
            then hideAll() continue end

            if not player or not player.Parent or not player.Character then
                hideAll() continue
            end

            local character = player.Character
            local humanoid  = character:FindFirstChild("Humanoid")
            if not humanoid or humanoid.Health <= 0 then hideAll() continue end

            local pos, size, onScreen = GetCharacterBox(character)
            if not onScreen then hideAll() continue end

            obj.outline.Position    = pos
            obj.outline.Size        = size
            obj.outline.Color       = properties.Color       or Color3.new(1, 1, 1)
            obj.outline.Thickness   = properties.Thickness   or 1
            obj.outline.Transparency = properties.Transparency ~= nil
                and properties.Transparency or 1
            obj.outline.Visible     = true

            obj.frame.Position = UDim2.fromOffset(pos.X, pos.Y)
            obj.frame.Size     = UDim2.fromOffset(size.X, size.Y)
            obj.frame.BackgroundTransparency = properties.FillTransparency ~= nil
                and properties.FillTransparency or 0.5
            obj.frame.Visible  = properties.Fill ~= false

            if properties.GradientSpin ~= false then
                obj.uig.Rotation = rotAngle % 360
            end

            if properties.GradientColors then
                obj.uig.Color = buildSequence(properties.GradientColors)
            end

            if properties.ShowBorder then
                obj.borderDraw.Position    = pos
                obj.borderDraw.Size        = size
                obj.borderDraw.Color       = properties.BorderColor     or Color3.new(0, 0, 0)
                obj.borderDraw.Thickness   = properties.BorderThickness or 1
                obj.borderDraw.Visible     = true
            else
                obj.borderDraw.Visible = false
            end
        end
    end)
    table.insert(connections, renderConn)
    table.insert(self.ESPConnections, renderConn)

    local wrapper = {
        Objects = espObjects,

        UpdateVisible = function(self, state)
            properties.Visible = state
            if not state then
                for _, obj in pairs(self.Objects) do
                    obj.outline.Visible    = false
                    obj.borderDraw.Visible = false
                    obj.frame.Visible      = false
                end
            end
        end,

        UpdateColor = function(self, newColor)
            properties.Color = newColor
            for _, obj in pairs(self.Objects) do obj.outline.Color = newColor end
        end,

        UpdateThickness = function(self, thickness)
            properties.Thickness = thickness
            for _, obj in pairs(self.Objects) do obj.outline.Thickness = thickness end
        end,

        UpdateFillTransparency = function(self, alpha)
            properties.FillTransparency = alpha
            for _, obj in pairs(self.Objects) do
                obj.frame.BackgroundTransparency = alpha
            end
        end,

        UpdateGradientColors = function(self, colors)
            properties.GradientColors = colors
            local seq = buildSequence(colors)
            for _, obj in pairs(self.Objects) do obj.uig.Color = seq end
        end,

        UpdateGradientColor = function(self, index, newColor)
            local base = properties.GradientColors or {
                Color3.fromRGB(255, 0, 0),
                Color3.fromRGB(0, 255, 0),
                Color3.fromRGB(0, 0, 255),
            }
            local newColors, seq = patchColor(base, index, newColor)
            properties.GradientColors = newColors
            for _, obj in pairs(self.Objects) do obj.uig.Color = seq end
        end,

        UpdateGradientSpeed = function(self, speed)
            properties.GradientSpeed = speed
        end,

        UpdateGradientSpin = function(self, state)
            properties.GradientSpin = state
        end,

        UpdateFill = function(self, state)
            properties.Fill = state
            if not state then
                for _, obj in pairs(self.Objects) do obj.frame.Visible = false end
            end
        end,

        UpdateTeamCheck = function(self, state)
            properties.IgnoreTeammates = state
        end,

        Remove = function(self)
            for _, conn in pairs(connections) do
                if conn.Disconnect then conn:Disconnect() end
            end
            for player, _ in pairs(self.Objects) do RemovePlayer(player) end
            self.Objects = {}
        end,
    }
    return AddDrawing(wrapper)
end

function DrawingLibrary:MakeText(targetOrProperties, properties)
    if type(targetOrProperties) == "table" then
        properties = targetOrProperties
        local textObj = Drawing.new("Text")
        textObj.Visible      = properties.Visible      or false
        textObj.Color        = properties.Color        or Color3.new(1, 1, 1)
        textObj.Text         = properties.Text         or "Text"
        textObj.Size         = properties.Size         or 16
        textObj.Center       = properties.Center       ~= nil and properties.Center or true
        textObj.Outline      = properties.Outline      ~= nil and properties.Outline or true
        textObj.OutlineColor = properties.OutlineColor or Color3.new(0, 0, 0)
        textObj.Position     = properties.Position     or Vector2.new(0, 0)
        textObj.Font         = properties.Font         or 2
        return AddDrawing({
            Object          = textObj,
            UpdateText      = function(self, v) self.Object.Text     = tostring(v) end,
            UpdateSize      = function(self, v) self.Object.Size     = v end,
            UpdatePosition  = function(self, v) self.Object.Position = v end,
            UpdateColor     = function(self, v) self.Object.Color    = v end,
            UpdateVisible   = function(self, v) self.Object.Visible  = v end,
            Remove          = function(self)    self.Object:Remove() end,
        })
    elseif type(targetOrProperties) == "string" then
        return CreateDynamicESP(self, targetOrProperties, "Text", properties or {})
    end
end


function DrawingLibrary:MakeName(targetOrProperties, properties)
    properties = properties or {}
    if type(targetOrProperties) == "string" then
        properties.Text = function(player) return player.Name end
    end
    return self:MakeText(targetOrProperties, properties)
end

function DrawingLibrary:MakeLine(targetOrProperties, properties)
    if type(targetOrProperties) == "table" then
        properties = targetOrProperties
        local line = Drawing.new("Line")
        line.Visible      = properties.Visible      or false
        line.Color        = properties.Color        or Color3.new(1, 1, 1)
        line.Thickness    = properties.Thickness    or 1
        line.Transparency = properties.Transparency or 1
        line.From         = properties.From         or Vector2.new(0, 0)
        line.To           = properties.To           or Vector2.new(100, 100)
        return AddDrawing({
            Object        = line,
            UpdateVisible = function(self, state) self.Object.Visible = state end,
            Remove        = function(self)        self.Object:Remove() end,
        })
    elseif type(targetOrProperties) == "string" then
        return CreateDynamicESP(self, targetOrProperties, "Line", properties or {})
    end
end


function DrawingLibrary:MakeHighlight(targetOrProperties, properties)
    if type(targetOrProperties) == "table" then
        properties = targetOrProperties
        local hl = Instance.new("Highlight")
        hl.Adornee            = properties.Adornee            or nil
        hl.Parent             = properties.Parent             or game:GetService("CoreGui")
        hl.FillColor          = properties.FillColor          or Color3.new(1, 1, 1)
        hl.OutlineColor       = properties.OutlineColor       or Color3.new(1, 1, 1)
        hl.FillTransparency   = properties.FillTransparency   or 0.5
        hl.OutlineTransparency = properties.OutlineTransparency or 0
        hl.DepthMode          = properties.DepthMode          or Enum.HighlightDepthMode.AlwaysOnTop
        hl.Enabled            = properties.Enabled == nil and true or properties.Enabled
        return AddInstance({ Object = hl, Remove = function(self) self.Object:Destroy() end })
    elseif type(targetOrProperties) == "string" then
        local target     = targetOrProperties
        properties       = properties or {}
        local isAll      = (string.lower(target) == "all")
        local highlights = {}
        local connections = {}

        local function SetupHighlight(player)
            if player == LocalPlayer and not properties.ShowLocal then return end
            local function onCharAdded(char)
                local hl = Instance.new("Highlight")
                hl.Adornee             = char
                hl.Parent              = properties.Parent             or game:GetService("CoreGui")
                hl.FillColor           = properties.FillColor          or Color3.new(1, 1, 1)
                hl.OutlineColor        = properties.OutlineColor       or Color3.new(1, 1, 1)
                hl.FillTransparency    = properties.FillTransparency   or 0.5
                hl.OutlineTransparency = properties.OutlineTransparency or 0
                hl.DepthMode           = properties.DepthMode          or Enum.HighlightDepthMode.AlwaysOnTop
                hl.Enabled             = properties.Enabled == nil and true or properties.Enabled
                highlights[player]     = hl
            end
            if player.Character then onCharAdded(player.Character) end
            local conn = player.CharacterAdded:Connect(onCharAdded)
            table.insert(connections, conn)
            table.insert(self.ESPConnections, conn)
        end

        if isAll then
            for _, p in ipairs(Players:GetPlayers()) do SetupHighlight(p) end
            local jc = Players.PlayerAdded:Connect(SetupHighlight)
            table.insert(connections, jc)
            table.insert(self.ESPConnections, jc)
        else
            local sp = Players:FindFirstChild(target)
            if sp then SetupHighlight(sp) end
        end

        local renderConn = RunService.RenderStepped:Connect(function()
            for player, hl in pairs(highlights) do
                if hl and hl.Parent then
                    local enabled = properties.Enabled == nil and true or properties.Enabled
                    if properties.IgnoreTeammates
                        and player.Team == LocalPlayer.Team
                        and player.Team ~= nil
                    then enabled = false end
                    if properties.TeamColors then
                        local team  = player.Team
                        local color = (team and properties.TeamColors[team.Name])
                            or properties.TeamColors.Default
                            or Color3.new(1, 1, 1)
                        hl.FillColor    = color
                        hl.OutlineColor = color
                    end
                    hl.Enabled = enabled
                end
            end
        end)
        table.insert(connections, renderConn)
        table.insert(self.ESPConnections, renderConn)

        local wrapper = {
            UpdateVisible = function(self, state)
                properties.Enabled = state
                for _, hl in pairs(highlights) do hl.Enabled = state end
            end,
            UpdateColor = function(self, newColor)
                properties.FillColor = newColor
                for _, hl in pairs(highlights) do hl.FillColor = newColor end
            end,
            UpdateOutlineColor = function(self, newColor)
                properties.OutlineColor = newColor
                for _, hl in pairs(highlights) do hl.OutlineColor = newColor end
            end,
            UpdateTeamCheck = function(self, state)
                properties.IgnoreTeammates = state
            end,
            UpdateTeamColors = function(self, colors)
                properties.TeamColors = colors
                for player, hl in pairs(highlights) do
                    local team  = player.Team
                    local color = (team and colors[team.Name]) or colors.Default or Color3.new(1, 1, 1)
                    hl.FillColor    = color
                    hl.OutlineColor = color
                end
            end,
            Remove = function()
                for _, conn in pairs(connections) do if conn.Disconnect then conn:Disconnect() end end
                for _, hl in pairs(highlights) do if hl and hl.Parent then hl:Destroy() end end
                highlights = {}
            end,
        }
        return AddInstance(wrapper)
    end
end

function DrawingLibrary:MakeCircle(properties)
    properties = properties or {}
    local circle = Drawing.new("Circle")
    circle.Visible      = properties.Visible      or false
    circle.Color        = properties.Color        or Color3.new(1, 1, 1)
    circle.Thickness    = properties.Thickness    or 1
    circle.Transparency = properties.Transparency or 1
    circle.Filled       = properties.Filled       or false
    circle.Position     = properties.Position     or Vector2.new(0, 0)
    circle.Radius       = properties.Radius       or 50
    circle.NumSides     = properties.NumSides     or 50
    return AddDrawing({ Object = circle, Remove = function(self) self.Object:Remove() end })
end


function DrawingLibrary:MakeFov(properties)
    properties = properties or {}

    local radius   = properties.Radius or 100
    local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

    local fovCircle = Drawing.new("Circle")
    fovCircle.Visible      = properties.Visible      or false
    fovCircle.Color        = properties.Color        or Color3.new(1, 1, 1)
    fovCircle.Thickness    = properties.Thickness    or 1
    fovCircle.Transparency = properties.Transparency ~= nil and properties.Transparency or 1
    fovCircle.Filled       = false
    fovCircle.Radius       = radius
    fovCircle.NumSides     = properties.NumSides or 64

    local defaultColors = properties.GradientColors or {
        Color3.fromRGB(255, 0, 0),
        Color3.fromRGB(0, 255, 0),
        Color3.fromRGB(0, 0, 255),
    }

    local fovFrame = Instance.new("Frame")
    fovFrame.BorderSizePixel        = 0
    fovFrame.BackgroundColor3       = Color3.new(1, 1, 1)
    fovFrame.BackgroundTransparency = properties.FillTransparency ~= nil
        and properties.FillTransparency or 0.7
    fovFrame.Size    = UDim2.fromOffset(radius * 2, radius * 2)
    fovFrame.Visible = properties.Visible or false
    fovFrame.ZIndex  = 2
    fovFrame.Parent  = _gradGui

    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(1, 0)
    uiCorner.Parent       = fovFrame

    local fovUIG = Instance.new("UIGradient")
    fovUIG.Color    = buildSequence(defaultColors)
    fovUIG.Rotation = 0
    fovUIG.Parent   = fovFrame

    local gradSpin = 0

    local fovObject = {
        Circle    = fovCircle,
        Frame     = fovFrame,
        Gradient  = fovUIG,
        Connection = nil,

        UpdateRadius = function(self, r)
            properties.Radius   = r
            self.Circle.Radius  = r
            self.Frame.Size     = UDim2.fromOffset(r * 2, r * 2)
        end,

        UpdateVisible = function(self, state)
            properties.Visible  = state
            self.Circle.Visible = state
            self.Frame.Visible  = state and (properties.Fill ~= false)
        end,

        UpdateColor = function(self, color)
            properties.Color    = color
            self.Circle.Color   = color
        end,

        UpdateFillTransparency = function(self, alpha)
            properties.FillTransparency = alpha
            self.Frame.BackgroundTransparency = alpha
        end,

        UpdateGradientColors = function(self, colors)
            properties.GradientColors = colors
            self.Gradient.Color = buildSequence(colors)
        end,

        UpdateGradientColor = function(self, index, newColor)
            local base = properties.GradientColors or {
                Color3.fromRGB(255, 0,   0),
                Color3.fromRGB(0,   255, 0),
                Color3.fromRGB(0,   0, 255),
            }
            local newColors, seq = patchColor(base, index, newColor)
            properties.GradientColors = newColors
            self.Gradient.Color = seq
        end,

        UpdateGradientSpeed = function(self, speed)
            properties.GradientSpeed = speed
        end,

        UpdateFill = function(self, state)
            properties.Fill    = state
            self.Frame.Visible = state and (properties.Visible or false)
        end,

        UpdateWallCheck = function(self, state) properties.CheckWalls      = state end,
        UpdateTeamCheck = function(self, state) properties.IgnoreTeammates = state end,

        GetClosestPlayer = function(self)
            local closestPlayer    = nil
            local shortestDistance = self.Circle.Radius
            local raycastParams
            if properties.CheckWalls and LocalPlayer.Character then
                raycastParams = RaycastParams.new()
                raycastParams.FilterType = Enum.RaycastFilterType.Exclude
                raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
            end
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character
                    and player.Character:FindFirstChild("HumanoidRootPart")
                then
                    if properties.IgnoreTeammates
                        and player.Team == LocalPlayer.Team
                        and player.Team ~= nil
                    then continue end
                    local humanoid = player.Character:FindFirstChild("Humanoid")
                    if humanoid and humanoid.Health > 0 then
                        local targetPart = player.Character:FindFirstChild("Head")
                            or player.Character.HumanoidRootPart
                        local pos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                        if onScreen then
                            local dist = (Vector2.new(pos.X, pos.Y) - self.Circle.Position).Magnitude
                            if dist < shortestDistance then
                                if properties.CheckWalls and raycastParams
                                    and LocalPlayer.Character:FindFirstChild("Head")
                                then
                                    local headPos = LocalPlayer.Character.Head.Position
                                    local result  = workspace:Raycast(
                                        headPos, targetPart.Position - headPos, raycastParams)
                                    if result and not result.Instance:IsDescendantOf(player.Character) then
                                        continue
                                    end
                                end
                                shortestDistance = dist
                                closestPlayer    = player
                            end
                        end
                    end
                end
            end
            return closestPlayer
        end,

        Remove = function(self)
            if self.Connection then self.Connection:Disconnect(); self.Connection = nil end
            if self.Circle     then self.Circle:Remove() end
            if self.Frame      then self.Frame:Destroy() end
        end,
    }

    fovObject.Connection = RunService.RenderStepped:Connect(function(dt)
        if not fovObject.Circle then fovObject.Connection:Disconnect() return end

        local center
        if isMobile then
            local vp = Camera.ViewportSize
            center   = Vector2.new(vp.X / 2, vp.Y / 2)
        else
            center = UserInputService:GetMouseLocation()
        end

        local r = fovObject.Circle.Radius
        fovObject.Circle.Position = center
        fovObject.Frame.Position  = UDim2.fromOffset(center.X - r, center.Y - r)
        fovObject.Frame.Size      = UDim2.fromOffset(r * 2, r * 2)

        if properties.GradientSpin ~= false then
            gradSpin = (gradSpin + dt * (properties.GradientSpeed or 90)) % 360
            fovObject.Gradient.Rotation = gradSpin
        end
    end)

    return AddDrawing(fovObject)
end

function DrawingLibrary:MakeHealthBar(target, properties)
    properties = properties or {}
    if type(target) ~= "string" then
        warn("MakeHealthBar: target must be a player name string or \"all\"")
        return
    end

    local isAll          = (string.lower(target) == "all")
    local specificPlayer = not isAll and Players:FindFirstChild(target) or nil

    local function getColors()
        return properties.GradientColors or {
            Color3.fromRGB(255, 0,   0),
            Color3.fromRGB(255, 200, 0),
            Color3.fromRGB(0,   255, 0),
        }
    end

    local barObjects  = {}
    local connections = {}

    local function CreateBarForPlayer(player)
        if player == LocalPlayer and not properties.ShowLocal then return end
        if barObjects[player] then return end

        local bgFrame = Instance.new("Frame")
        bgFrame.BorderSizePixel        = 0
        bgFrame.BackgroundColor3       = properties.BackgroundColor or Color3.fromRGB(0, 0, 0)
        bgFrame.BackgroundTransparency = properties.BackgroundAlpha ~= nil
            and properties.BackgroundAlpha or 0.5
        bgFrame.Visible                = false
        bgFrame.ZIndex                 = 2
        bgFrame.Parent                 = _gradGui

        local fillFrame = Instance.new("Frame")
        fillFrame.BorderSizePixel        = 0
        fillFrame.BackgroundColor3       = Color3.new(1, 1, 1)
        fillFrame.BackgroundTransparency = properties.BarTransparency ~= nil
            and properties.BarTransparency or 0
        fillFrame.Visible                = false
        fillFrame.ZIndex                 = 3
        fillFrame.Parent                 = _gradGui

        local uig = Instance.new("UIGradient")
        uig.Color    = buildSequence(getColors())
        uig.Rotation = 270
        uig.Parent   = fillFrame

        local distText = Drawing.new("Text")
        distText.Center       = true
        distText.Outline      = true
        distText.OutlineColor = Color3.new(0, 0, 0)
        distText.Font         = 2
        distText.Color        = properties.DistanceColor or Color3.new(1, 1, 1)
        distText.Size         = properties.DistanceSize  or 13
        distText.Visible      = false

        local weapText = Drawing.new("Text")
        weapText.Center       = true
        weapText.Outline      = true
        weapText.OutlineColor = Color3.new(0, 0, 0)
        weapText.Font         = 2
        weapText.Color        = properties.WeaponColor or Color3.new(1, 1, 1)
        weapText.Size         = properties.WeaponSize  or 13
        weapText.Visible      = false

        barObjects[player] = {
            bgFrame    = bgFrame,
            fillFrame  = fillFrame,
            uig        = uig,
            distText   = distText,
            weapText   = weapText,
        }
    end

    local function RemoveBarForPlayer(player)
        local obj = barObjects[player]
        if not obj then return end
        obj.bgFrame:Destroy()
        obj.fillFrame:Destroy()
        obj.distText:Remove()
        obj.weapText:Remove()
        barObjects[player] = nil
    end

    if isAll then
        for _, p in ipairs(Players:GetPlayers()) do CreateBarForPlayer(p) end
        local jc = Players.PlayerAdded:Connect(CreateBarForPlayer)
        local lc = Players.PlayerRemoving:Connect(RemoveBarForPlayer)
        table.insert(connections, jc); table.insert(self.ESPConnections, jc)
        table.insert(connections, lc); table.insert(self.ESPConnections, lc)
    elseif specificPlayer then
        CreateBarForPlayer(specificPlayer)
    end

    local renderConn = RunService.RenderStepped:Connect(function()
        local camPos = Camera.CFrame.Position

        for player, obj in pairs(barObjects) do
            local function hideAll()
                obj.bgFrame.Visible   = false
                obj.fillFrame.Visible = false
                obj.distText.Visible  = false
                obj.weapText.Visible  = false
            end

            if not properties.Visible then hideAll() continue end

            if properties.IgnoreTeammates
                and player.Team == LocalPlayer.Team
                and player.Team ~= nil
            then hideAll() continue end

            if not player or not player.Parent or not player.Character then
                hideAll() continue
            end

            local character = player.Character
            local humanoid  = character:FindFirstChild("Humanoid")
            if not humanoid or humanoid.Health <= 0 then hideAll() continue end

            local pos, size, onScreen = GetCharacterBox(character)
            if not onScreen then hideAll() continue end

            local barW   = properties.BarWidth or 4
            local offset = properties.Offset   or 6
            local bx     = pos.X - offset - barW
            local by     = pos.Y
            local bh     = size.Y

            local maxHp  = humanoid.MaxHealth > 0 and humanoid.MaxHealth or 100
            local frac   = math.clamp(humanoid.Health / maxHp, 0, 1)
            local barH   = bh * frac

            obj.bgFrame.Position             = UDim2.fromOffset(bx - 1, by - 1)
            obj.bgFrame.Size                 = UDim2.fromOffset(barW + 2, bh + 2)
            obj.bgFrame.BackgroundColor3     = properties.BackgroundColor or Color3.fromRGB(0,0,0)
            obj.bgFrame.BackgroundTransparency = properties.BackgroundAlpha ~= nil
                and properties.BackgroundAlpha or 0.5
            obj.bgFrame.Visible              = true

            local fillY = by + (bh - barH)
            obj.fillFrame.Position             = UDim2.fromOffset(bx, fillY)
            obj.fillFrame.Size                 = UDim2.fromOffset(barW, barH)
            obj.fillFrame.BackgroundTransparency = properties.BarTransparency ~= nil
                and properties.BarTransparency or 0
            obj.fillFrame.Visible              = true

            obj.uig.Color = buildSequence(getColors())

            if properties.ShowDistance then
                local root = character.PrimaryPart
                    or character:FindFirstChild("HumanoidRootPart")
                    or character:FindFirstChildWhichIsA("BasePart")
                local dist = root and math.floor((camPos - root.Position).Magnitude) or 0
                obj.distText.Text     = tostring(dist) .. "m"
                obj.distText.Color    = properties.DistanceColor or Color3.new(1, 1, 1)
                obj.distText.Size     = properties.DistanceSize  or 13
                obj.distText.Position = Vector2.new(pos.X + size.X / 2, pos.Y + size.Y + 2)
                obj.distText.Visible  = true
            else
                obj.distText.Visible = false
            end

            if properties.ShowWeapon then
                local wn   = GetWeaponName(player, character, properties.WeaponPath)
                local yOff = properties.ShowDistance and 16 or 2
                obj.weapText.Text     = "[" .. wn .. "]"
                obj.weapText.Color    = properties.WeaponColor or Color3.new(1, 1, 1)
                obj.weapText.Size     = properties.WeaponSize  or 13
                obj.weapText.Position = Vector2.new(pos.X + size.X / 2, pos.Y + size.Y + yOff)
                obj.weapText.Visible  = true
            else
                obj.weapText.Visible = false
            end
        end
    end)
    table.insert(connections, renderConn)
    table.insert(self.ESPConnections, renderConn)

    local wrapper = {
        Objects = barObjects,

        UpdateVisible = function(self, state)
            properties.Visible = state
            if not state then
                for _, obj in pairs(self.Objects) do
                    obj.bgFrame.Visible   = false
                    obj.fillFrame.Visible = false
                    obj.distText.Visible  = false
                    obj.weapText.Visible  = false
                end
            end
        end,

        UpdateGradientColors = function(self, colors)
            properties.GradientColors = colors
            local seq = buildSequence(colors)
            for _, obj in pairs(self.Objects) do obj.uig.Color = seq end
        end,

        UpdateGradientColor = function(self, index, newColor)
            local base = properties.GradientColors or {
                Color3.fromRGB(255, 0,   0),
                Color3.fromRGB(255, 200, 0),
                Color3.fromRGB(0,   255, 0),
            }
            local newColors, seq = patchColor(base, index, newColor)
            properties.GradientColors = newColors
            for _, obj in pairs(self.Objects) do obj.uig.Color = seq end
        end,

        UpdateBarTransparency = function(self, alpha)
            properties.BarTransparency = alpha
            for _, obj in pairs(self.Objects) do
                obj.fillFrame.BackgroundTransparency = alpha
            end
        end,

        UpdateBackgroundAlpha = function(self, alpha)
            properties.BackgroundAlpha = alpha
            for _, obj in pairs(self.Objects) do
                obj.bgFrame.BackgroundTransparency = alpha
            end
        end,

        UpdateBackgroundColor = function(self, color)
            properties.BackgroundColor = color
            for _, obj in pairs(self.Objects) do
                obj.bgFrame.BackgroundColor3 = color
            end
        end,

        UpdateBarWidth = function(self, w)
            properties.BarWidth = w
        end,

        UpdateTeamCheck = function(self, state)
            properties.IgnoreTeammates = state
        end,

        Remove = function(self)
            for _, conn in pairs(connections) do
                if conn.Disconnect then conn:Disconnect() end
            end
            for player, _ in pairs(self.Objects) do RemoveBarForPlayer(player) end
        end,
    }

    return AddDrawing(wrapper)
end

return DrawingLibrary
