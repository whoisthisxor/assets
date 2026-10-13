local DrawingLibrary = {}

DrawingLibrary.Drawings = {}
DrawingLibrary.Instances = {}
DrawingLibrary.ESPConnections = {}

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer    = Players.LocalPlayer
local Camera         = workspace.CurrentCamera

local function AddDrawing(drawing)
    table.insert(DrawingLibrary.Drawings, drawing)
    return drawing
end

local function AddInstance(instance)
    table.insert(DrawingLibrary.Instances, instance)
    return instance
end


local MAX_FILL_LINES = 64
local GRAD_STEPS     = 12
local MAX_HP_SEGMENTS = 12

local function lerpColor(a, b, t)
    t = math.clamp(t, 0, 1)
    return Color3.new(
        a.R + (b.R - a.R) * t,
        a.G + (b.G - a.G) * t,
        a.B + (b.B - a.B) * t
    )
end

local function setupFillLines(count)
    local lines = {}
    local n = count or MAX_FILL_LINES
    for i = 1, n do
        local l = Drawing.new("Line")
        l.Thickness    = 4
        l.Transparency = 0.3
        l.Visible      = false
        lines[i] = l
    end
    return lines
end

local function drawFillGradient360(fillLines, x, y, w, h, colorA, colorB, angle)
    local dx     = math.cos(angle)
    local dy     = math.sin(angle)
    local cx     = x + w * 0.5
    local cy     = y + h * 0.5
    local maxDot = math.max((math.abs(dx) * w + math.abs(dy) * h) * 0.5, 1)

    local targetRows = math.clamp(math.floor(h * 0.8), 15, #fillLines)
    local rowH       = h / targetRows

    for i = 1, targetRows do
        local py   = y + (i - 0.5) * rowH
        local dotL = ((x     - cx) * dx + (py - cy) * dy) / maxDot
        local dotR = ((x + w - cx) * dx + (py - cy) * dy) / maxDot
        local tL   = math.clamp(dotL * 0.5 + 0.5, 0, 1)
        local tR   = math.clamp(dotR * 0.5 + 0.5, 0, 1)

        local line     = fillLines[i]
        line.Color     = lerpColor(colorA, colorB, (tL + tR) * 0.5)
        line.Thickness = math.clamp(rowH + 1.5, 2, 8)
        line.From      = Vector2.new(x + 1,     py)
        line.To        = Vector2.new(x + w - 1, py)
        line.Visible   = true
    end
    for i = targetRows + 1, #fillLines do
        fillLines[i].Visible = false
    end
end

local function drawBoxOutlineGradient(gradLines, x, y, w, h, colorA, colorB, rotOff)
    local perim = 2 * (w + h)
    if perim <= 0 then return end

    local total = #gradLines
    if total == 0 then return end

    local step_len = perim / total

    for i = 1, total do
        local t_start = ((i - 1) / total + rotOff) % 1
        local t_end   = (i / total + rotOff) % 1

        local function perim_pos(t)
            local d = t * perim
            if d < w then
                return x + d, y
            elseif d < w + h then
                return x + w, y + (d - w)
            elseif d < w + h + w then
                return x + w - (d - w - h), y + h
            else
                return x, y + h - (d - w - h - w)
            end
        end

        local x1, y1 = perim_pos(t_start)
        local x2, y2 = perim_pos(t_end)

        local line = gradLines[i]
        line.From    = Vector2.new(x1, y1)
        line.To      = Vector2.new(x2, y2)
        line.Color   = lerpColor(colorA, colorB, t_start)
        line.Visible = true
    end
end

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


local GRAD_LINE_COUNT = GRAD_STEPS * 4

local function CreateBoxObjects(properties)
    local outline = Drawing.new("Square")
    outline.Color        = properties.Color        or Color3.new(1, 1, 1)
    outline.Thickness    = properties.Thickness    or 1
    outline.Transparency = properties.Transparency or 1
    outline.Filled       = false
    outline.Visible      = false

    local fill = Drawing.new("Square")
    fill.Filled       = true
    fill.Thickness    = 0
    fill.Color        = properties.FillColor        or Color3.new(1, 1, 1)
    fill.Transparency = properties.FillTransparency ~= nil and properties.FillTransparency or 0.7
    fill.Visible      = false

    local gradLines = {}
    for i = 1, GRAD_LINE_COUNT do
        local l = Drawing.new("Line")
        l.Thickness    = properties.Thickness or 1
        l.Transparency = 1
        l.Visible      = false
        gradLines[i]   = l
    end

    local fillLines = setupFillLines(MAX_FILL_LINES)

    return {
        outline   = outline,
        fill      = fill,
        gradLines = gradLines,
        fillLines = fillLines,
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
        obj.fill:Remove()
        for _, l in ipairs(obj.gradLines) do l:Remove() end
        for _, l in ipairs(obj.fillLines) do l:Remove() end
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
        rotAngle = (rotAngle + dt * (properties.GradientSpeed or 2)) % (math.pi * 2)
        local rotOff = rotAngle / (math.pi * 2)

        for player, obj in pairs(espObjects) do
            local function hideAll()
                obj.outline.Visible = false
                obj.fill.Visible    = false
                for _, l in ipairs(obj.gradLines) do l.Visible = false end
                for _, l in ipairs(obj.fillLines) do l.Visible = false end
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

            local x, y = pos.X, pos.Y
            local w, h = size.X, size.Y

            local useGradientOutline = properties.Gradient
            local useFlatFill        = properties.Fill and not properties.FillGradient
            local useGradFill        = properties.Fill and properties.FillGradient
            local useFlatOutline     = not useGradientOutline

            if useGradFill then
                local fA    = properties.FillColorA or properties.GradientColorA or Color3.new(1, 1, 1)
                local fB    = properties.FillColorB or properties.GradientColorB or Color3.new(0, 1, 1)
                local angle = properties.FillAngle  or rotAngle
                drawFillGradient360(obj.fillLines, x, y, w, h, fA, fB, angle)
            else
                for _, l in ipairs(obj.fillLines) do l.Visible = false end
            end

            if useFlatFill then
                obj.fill.Position    = pos
                obj.fill.Size        = size
                obj.fill.Color       = properties.FillColor        or Color3.new(1, 1, 1)
                obj.fill.Transparency = properties.FillTransparency ~= nil
                    and properties.FillTransparency or 0.7
                obj.fill.Visible     = true
            else
                obj.fill.Visible = false
            end

            if useGradientOutline then
                local cA = properties.GradientColorA or Color3.new(1, 1, 1)
                local cB = properties.GradientColorB or Color3.new(0, 1, 1)
                for _, l in ipairs(obj.gradLines) do
                    l.Thickness = properties.Thickness or 1
                end
                drawBoxOutlineGradient(obj.gradLines, x, y, w, h, cA, cB, rotOff)
                obj.outline.Visible = false
            else
                for _, l in ipairs(obj.gradLines) do l.Visible = false end
            end

            if useFlatOutline then
                obj.outline.Position    = pos
                obj.outline.Size        = size
                obj.outline.Color       = properties.Color        or Color3.new(1, 1, 1)
                obj.outline.Thickness   = properties.Thickness    or 1
                obj.outline.Transparency = properties.Transparency or 1
                obj.outline.Visible     = true
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
                    obj.outline.Visible = false
                    obj.fill.Visible    = false
                    for _, l in ipairs(obj.gradLines) do l.Visible = false end
                    for _, l in ipairs(obj.fillLines) do l.Visible = false end
                end
            end
        end,

        UpdateColor = function(self, newColor)
            properties.Color = newColor
            for _, obj in pairs(self.Objects) do obj.outline.Color = newColor end
        end,

        UpdateFillColor = function(self, newColor)
            properties.FillColor = newColor
            for _, obj in pairs(self.Objects) do obj.fill.Color = newColor end
        end,

        UpdateFillTransparency = function(self, alpha)
            properties.FillTransparency = alpha
            for _, obj in pairs(self.Objects) do obj.fill.Transparency = alpha end
        end,

        UpdateGradient = function(self, state)
            properties.Gradient = state
        end,

        UpdateFill = function(self, state)
            properties.Fill = state
            if not state then
                for _, obj in pairs(self.Objects) do
                    obj.fill.Visible = false
                    for _, l in ipairs(obj.fillLines) do l.Visible = false end
                end
            end
        end,

        UpdateFillGradient = function(self, state)
            properties.FillGradient = state
            if not state then
                for _, obj in pairs(self.Objects) do
                    for _, l in ipairs(obj.fillLines) do l.Visible = false end
                end
            end
        end,

        UpdateFillAngle = function(self, angle)
            properties.FillAngle = angle
        end,

        UpdateFillGradientColors = function(self, colorA, colorB)
            properties.FillColorA = colorA
            properties.FillColorB = colorB
        end,

        UpdateGradientColors = function(self, colorA, colorB)
            properties.GradientColorA = colorA
            properties.GradientColorB = colorB
        end,

        UpdateGradientSpeed = function(self, speed)
            properties.GradientSpeed = speed
        end,

        UpdateThickness = function(self, thickness)
            properties.Thickness = thickness
            for _, obj in pairs(self.Objects) do
                obj.outline.Thickness = thickness
                for _, l in ipairs(obj.gradLines) do l.Thickness = thickness end
            end
        end,

        UpdateTransparency = function(self, alpha)
            properties.Transparency = alpha
            for _, obj in pairs(self.Objects) do
                obj.outline.Transparency = alpha
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
    local fovCircle = Drawing.new("Circle")
    fovCircle.Visible      = properties.Visible      or false
    fovCircle.Color        = properties.Color        or Color3.new(1, 1, 1)
    fovCircle.Thickness    = properties.Thickness    or 1
    fovCircle.Transparency = properties.Transparency or 1
    fovCircle.Filled       = properties.Filled       or false
    fovCircle.Radius       = properties.Radius       or 100
    fovCircle.NumSides     = properties.NumSides     or 64

    local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

    local fovObject = {
        Circle     = fovCircle,
        Connection = nil,

        UpdateRadius  = function(self, r)     self.Circle.Radius  = r end,
        UpdateVisible = function(self, state) self.Circle.Visible = state end,
        UpdateColor   = function(self, color) self.Circle.Color   = color end,
        UpdateWallCheck  = function(self, state) properties.CheckWalls       = state end,
        UpdateTeamCheck  = function(self, state) properties.IgnoreTeammates  = state end,

        GetClosestPlayer = function(self)
            local closestPlayer   = nil
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
            if self.Circle and self.Circle.Remove then self.Circle:Remove() end
        end,
    }

    fovObject.Connection = RunService.RenderStepped:Connect(function()
        if not fovObject.Circle then fovObject.Connection:Disconnect() return end
        if isMobile then
            local vp = Camera.ViewportSize
            fovObject.Circle.Position = Vector2.new(vp.X / 2, vp.Y / 2)
        else
            fovObject.Circle.Position = UserInputService:GetMouseLocation()
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

    local barObjects  = {}
    local connections = {}

    local function CreateBarForPlayer(player)
        if player == LocalPlayer and not properties.ShowLocal then return end
        if barObjects[player] then return end

        local bg = Drawing.new("Square")
        bg.Filled       = true
        bg.Color        = properties.BackgroundColor or Color3.new(0, 0, 0)
        bg.Transparency = properties.BackgroundAlpha ~= nil and properties.BackgroundAlpha or 0.5
        bg.Thickness    = 1
        bg.Visible      = false

        local segs = {}
        for i = 1, MAX_HP_SEGMENTS do
            local l = Drawing.new("Line")
            l.Thickness    = properties.BarWidth or 4
            l.Transparency = 1
            l.Visible      = false
            segs[i]        = l
        end

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
            background = bg,
            segments   = segs,
            distText   = distText,
            weapText   = weapText,
        }
    end

    local function RemoveBarForPlayer(player)
        local obj = barObjects[player]
        if not obj then return end
        obj.background:Remove()
        for _, s in ipairs(obj.segments) do s:Remove() end
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
                obj.background.Visible = false
                for _, s in ipairs(obj.segments) do s.Visible = false end
                obj.distText.Visible = false
                obj.weapText.Visible = false
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
            local startY = by + (bh - barH)

            obj.background.Position = Vector2.new(bx - 1, by - 1)
            obj.background.Size     = Vector2.new(barW + 2, bh + 2)
            obj.background.Visible  = true

            local topColor    = properties.TopColor    or Color3.new(0, 1, 0)
            local bottomColor = properties.BottomColor or Color3.new(1, 0, 0)
            local activeSeg   = math.clamp(math.floor(MAX_HP_SEGMENTS * frac), 1, MAX_HP_SEGMENTS)
            local segH        = barH / activeSeg
            local cx          = bx + barW * 0.5

            for i = 1, MAX_HP_SEGMENTS do
                local seg = obj.segments[i]
                if i <= activeSeg then
                    local t   = (i - 0.5) / MAX_HP_SEGMENTS
                    local py1 = startY + (i - 1) * segH
                    local py2 = startY + i        * segH
                    seg.Color     = lerpColor(bottomColor, topColor, t)
                    seg.Thickness = barW
                    seg.From      = Vector2.new(cx, py1)
                    seg.To        = Vector2.new(cx, py2)
                    seg.Visible   = true
                else
                    seg.Visible = false
                end
            end

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
                    obj.background.Visible = false
                    for _, s in ipairs(obj.segments) do s.Visible = false end
                    obj.distText.Visible = false
                    obj.weapText.Visible = false
                end
            end
        end,

        UpdateColors = function(self, topColor, bottomColor)
            properties.TopColor    = topColor
            properties.BottomColor = bottomColor
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
