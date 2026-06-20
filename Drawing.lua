local DrawingLibrary = {}

DrawingLibrary.Drawings = {}
DrawingLibrary.Instances = {}
DrawingLibrary.ESPConnections = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local function AddDrawing(drawing)
    table.insert(DrawingLibrary.Drawings, drawing)
    return drawing
end

local function AddInstance(instance)
    table.insert(DrawingLibrary.Instances, instance)
    return instance
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

-- Расчет точного 2D бокса для персонажа на основе 3D пространства
local function GetCharacterBox(character)
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")
    if not rootPart or not head then return nil, nil, false end
    
    local rootPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
    if not onScreen then return nil, nil, false end
    
    local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
    local legPos = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
    
    local height = math.abs(headPos.Y - legPos.Y)
    local width = height / 2 -- Типичная пропорция тела Roblox
    
    local size = Vector2.new(width, height)
    local position = Vector2.new(rootPos.X - width / 2, headPos.Y)
    
    return position, size, true
end

-- Внутренняя функция создания динамического ESP для всех или одного игрока
local function CreateDynamicESP(library, target, drawingType, properties)
    local isAll = (string.lower(target) == "all")
    local specificPlayer = nil
    if not isAll then specificPlayer = Players:FindFirstChild(target) end
    
    local espObjects = {}
    local connections = {}
    
    local function CreateDrawing()
        if drawingType == "Box" then
            local obj = Drawing.new("Square")
            obj.Color = properties.Color or Color3.new(1, 1, 1)
            obj.Thickness = properties.Thickness or 1
            obj.Transparency = properties.Transparency or 1
            obj.Filled = properties.Filled or false
            return obj
        elseif drawingType == "Text" then
            local obj = Drawing.new("Text")
            obj.Color = properties.Color or Color3.new(1, 1, 1)
            obj.Size = properties.Size or 16
            obj.Center = properties.Center or true
            obj.Outline = properties.Outline or true
            obj.OutlineColor = properties.OutlineColor or Color3.new(0, 0, 0)
            obj.Font = properties.Font or 2
            return obj
        elseif drawingType == "Line" then
            local obj = Drawing.new("Line")
            obj.Color = properties.Color or Color3.new(1, 1, 1)
            obj.Thickness = properties.Thickness or 1
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
        local joinConn = Players.PlayerAdded:Connect(SetupPlayer)
        local leaveConn = Players.PlayerRemoving:Connect(RemovePlayer)
        table.insert(connections, joinConn)
        table.insert(connections, leaveConn)
        table.insert(library.ESPConnections, joinConn)
        table.insert(library.ESPConnections, leaveConn)
    elseif specificPlayer then
        SetupPlayer(specificPlayer)
    end
    
    -- ОДИН цикл RenderStepped для оптимизации производительности
    local renderConn = RunService.RenderStepped:Connect(function()
        for player, obj in pairs(espObjects) do
            if not properties.Visible then
                obj.Visible = false
                continue
            end
            
            if not player or not player.Parent or not player.Character then
                obj.Visible = false
                continue
            end
            
            local character = player.Character
            local humanoid = character:FindFirstChild("Humanoid")
            if not humanoid or humanoid.Health <= 0 then
                obj.Visible = false
                continue
            end

            local pos, size, onScreen = GetCharacterBox(character)
            if not onScreen then
                obj.Visible = false
                continue
            end
            
            if drawingType == "Box" then
                obj.Size = size
                obj.Position = pos
                obj.Visible = true
            elseif drawingType == "Text" then
                obj.Position = Vector2.new(pos.X + size.X / 2, pos.Y - obj.Size - 2)
                
                local textContent = properties.Text or "Name"
                local finalStr = ""
                local pathVal = nil
                
                -- Поддержка Path: Если это прямой Instance (workspace.MyBoolean) или строка (Attribute)
                if properties.Path then
                    if typeof(properties.Path) == "Instance" then
                        if properties.Path:IsA("ValueBase") then
                            pathVal = properties.Path.Value
                        else
                            pathVal = properties.Path.Name -- Безопасный возврат
                        end
                    elseif type(properties.Path) == "string" then
                        pathVal = player:GetAttribute(properties.Path)
                        if pathVal == nil and character then
                            pathVal = character:GetAttribute(properties.Path)
                        end
                        if pathVal == nil then
                            local child = player:FindFirstChild(properties.Path) or (character and character:FindFirstChild(properties.Path))
                            if child and child:IsA("ValueBase") then
                                pathVal = child.Value
                            end
                        end
                    end
                end
                
                -- Форматируем итоговый текст
                if type(textContent) == "function" then
                    finalStr = textContent(player, pathVal) or ""
                elseif type(textContent) == "string" then
                    if string.lower(textContent) == "name" then
                        finalStr = player.Name
                    elseif string.lower(textContent) == "health" then
                        finalStr = "HP: " .. tostring(math.floor(humanoid.Health))
                    else
                        finalStr = textContent
                        if pathVal ~= nil then
                            if string.find(finalStr, "{value}") then
                                finalStr = string.gsub(finalStr, "{value}", tostring(pathVal))
                            else
                                finalStr = finalStr .. tostring(pathVal)
                            end
                        end
                    end
                else
                    finalStr = tostring(textContent)
                end
                
                obj.Text = finalStr
                obj.Visible = true
            elseif drawingType == "Line" then
                local viewport = Camera.ViewportSize
                obj.From = properties.From or Vector2.new(viewport.X / 2, viewport.Y)
                obj.To = Vector2.new(pos.X + size.X / 2, pos.Y + size.Y)
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
        end
    }
    return AddDrawing(wrapper)
end

function DrawingLibrary:MakeBox(targetOrProperties, properties)
    if type(targetOrProperties) == "table" then
        properties = targetOrProperties
        local box = Drawing.new("Square")
        box.Visible = properties.Visible or false
        box.Color = properties.Color or Color3.new(1, 1, 1)
        box.Thickness = properties.Thickness or 1
        box.Transparency = properties.Transparency or 1
        box.Filled = properties.Filled or false
        box.Position = properties.Position or Vector2.new(0, 0)
        box.Size = properties.Size or Vector2.new(100, 100)
        
        return AddDrawing({ Object = box, UpdateVisible = function(self, state) self.Object.Visible = state end, Remove = function(self) self.Object:Remove() end })
    elseif type(targetOrProperties) == "string" then
        return CreateDynamicESP(self, targetOrProperties, "Box", properties or {})
    end
end

function DrawingLibrary:MakeText(targetOrProperties, properties)
    if type(targetOrProperties) == "table" then
        properties = targetOrProperties
        local textObj = Drawing.new("Text")
        textObj.Visible = properties.Visible or false
        textObj.Color = properties.Color or Color3.new(1, 1, 1)
        textObj.Text = properties.Text or "Text"
        textObj.Size = properties.Size or 16
        textObj.Center = properties.Center or true
        textObj.Outline = properties.Outline or true
        textObj.OutlineColor = properties.OutlineColor or Color3.new(0, 0, 0)
        textObj.Position = properties.Position or Vector2.new(0, 0)
        textObj.Font = properties.Font or 2
        
        return AddDrawing({
            Object = textObj,
            UpdateText = function(self, newText) self.Object.Text = tostring(newText) end,
            UpdateSize = function(self, newSize) self.Object.Size = newSize end,
            UpdatePosition = function(self, newPos) self.Object.Position = newPos end,
            UpdateColor = function(self, newCol) self.Object.Color = newCol end,
            UpdateVisible = function(self, state) self.Object.Visible = state end,
            Remove = function(self) self.Object:Remove() end
        })
    elseif type(targetOrProperties) == "string" then
        return CreateDynamicESP(self, targetOrProperties, "Text", properties or {})
    end
end

function DrawingLibrary:MakeName(targetOrProperties, properties)
    return self:MakeText(targetOrProperties, properties)
end

function DrawingLibrary:MakeLine(targetOrProperties, properties)
    if type(targetOrProperties) == "table" then
        properties = targetOrProperties
        local line = Drawing.new("Line")
        line.Visible = properties.Visible or false
        line.Color = properties.Color or Color3.new(1, 1, 1)
        line.Thickness = properties.Thickness or 1
        line.Transparency = properties.Transparency or 1
        line.From = properties.From or Vector2.new(0, 0)
        line.To = properties.To or Vector2.new(100, 100)
        
        return AddDrawing({ Object = line, UpdateVisible = function(self, state) self.Object.Visible = state end, Remove = function(self) self.Object:Remove() end })
    elseif type(targetOrProperties) == "string" then
        return CreateDynamicESP(self, targetOrProperties, "Line", properties or {})
    end
end

-- Highlight работает через Instance, поэтому здесь нужен отдельный контроллер
function DrawingLibrary:MakeHighlight(targetOrProperties, properties)
    if type(targetOrProperties) == "table" then
        properties = targetOrProperties
        local highlight = Instance.new("Highlight")
        highlight.Adornee = properties.Adornee or nil
        highlight.Parent = properties.Parent or game:GetService("CoreGui")
        highlight.FillColor = properties.FillColor or Color3.new(1, 1, 1)
        highlight.OutlineColor = properties.OutlineColor or Color3.new(1, 1, 1)
        highlight.FillTransparency = properties.FillTransparency or 0.5
        highlight.OutlineTransparency = properties.OutlineTransparency or 0
        highlight.DepthMode = properties.DepthMode or Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Enabled = properties.Enabled == nil and true or properties.Enabled
        
        return AddInstance({ Object = highlight, Remove = function(self) self.Object:Destroy() end })
    elseif type(targetOrProperties) == "string" then
        local target = targetOrProperties
        properties = properties or {}
        local isAll = (string.lower(target) == "all")
        local highlights = {}
        local connections = {}
        
        local function SetupHighlight(player)
            if player == LocalPlayer and not properties.ShowLocal then return end
            
            local function onCharAdded(char)
                local hl = Instance.new("Highlight")
                hl.Adornee = char
                hl.Parent = properties.Parent or game:GetService("CoreGui")
                hl.FillColor = properties.FillColor or Color3.new(1, 1, 1)
                hl.OutlineColor = properties.OutlineColor or Color3.new(1, 1, 1)
                hl.FillTransparency = properties.FillTransparency or 0.5
                hl.OutlineTransparency = properties.OutlineTransparency or 0
                hl.DepthMode = properties.DepthMode or Enum.HighlightDepthMode.AlwaysOnTop
                hl.Enabled = properties.Enabled == nil and true or properties.Enabled
                highlights[player] = hl
            end
            
            if player.Character then onCharAdded(player.Character) end
            local conn = player.CharacterAdded:Connect(onCharAdded)
            table.insert(connections, conn)
            table.insert(self.ESPConnections, conn)
        end
        
        if isAll then
            for _, p in ipairs(Players:GetPlayers()) do SetupHighlight(p) end
            local joinConn = Players.PlayerAdded:Connect(SetupHighlight)
            table.insert(connections, joinConn)
            table.insert(self.ESPConnections, joinConn)
        else
            local specificPlayer = Players:FindFirstChild(target)
            if specificPlayer then SetupHighlight(specificPlayer) end
        end
        
        local wrapper = {
            UpdateVisible = function(self, state)
                properties.Enabled = state
                for _, hl in pairs(highlights) do hl.Enabled = state end
            end,
            UpdateColor = function(self, newColor)
                properties.FillColor = newColor
                for _, hl in pairs(highlights) do hl.FillColor = newColor end
            end,
            Remove = function()
                for _, conn in pairs(connections) do if conn.Disconnect then conn:Disconnect() end end
                for _, hl in pairs(highlights) do if hl and hl.Parent then hl:Destroy() end end
                highlights = {}
            end
        }
        return AddInstance(wrapper)
    end
end

function DrawingLibrary:MakeCircle(properties)
    properties = properties or {}
    local circle = Drawing.new("Circle")
    circle.Visible = properties.Visible or false
    circle.Color = properties.Color or Color3.new(1, 1, 1)
    circle.Thickness = properties.Thickness or 1
    circle.Transparency = properties.Transparency or 1
    circle.Filled = properties.Filled or false
    circle.Position = properties.Position or Vector2.new(0, 0)
    circle.Radius = properties.Radius or 50
    circle.NumSides = properties.NumSides or 50
    
    return AddDrawing({ Object = circle, Remove = function(self) self.Object:Remove() end })
end

function DrawingLibrary:MakeFov(properties)
    properties = properties or {}
    local fovCircle = Drawing.new("Circle")
    fovCircle.Visible = properties.Visible or false
    fovCircle.Color = properties.Color or Color3.new(1, 1, 1)
    fovCircle.Thickness = properties.Thickness or 1
    fovCircle.Transparency = properties.Transparency or 1
    fovCircle.Filled = properties.Filled or false
    fovCircle.Radius = properties.Radius or 100
    fovCircle.NumSides = properties.NumSides or 64
    
    local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
    
    local fovObject = {
        Circle = fovCircle,
        Connection = nil,
        
        UpdateRadius = function(self, newRadius) self.Circle.Radius = newRadius end,
        UpdateVisible = function(self, state) self.Circle.Visible = state end,
        UpdateColor = function(self, color) self.Circle.Color = color end,
        
        GetClosestPlayer = function(self)
            local closestPlayer = nil
            local shortestDistance = self.Circle.Radius
            
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    local humanoid = player.Character:FindFirstChild("Humanoid")
                    if humanoid and humanoid.Health > 0 then
                        local pos, onScreen = Camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position)
                        if onScreen then
                            local screenPos = Vector2.new(pos.X, pos.Y)
                            local dist = (screenPos - self.Circle.Position).Magnitude
                            if dist < shortestDistance then
                                shortestDistance = dist
                                closestPlayer = player
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
        end
    }
    
    fovObject.Connection = RunService.RenderStepped:Connect(function()
        if not fovObject.Circle then fovObject.Connection:Disconnect() return end
        if isMobile then
            local viewport = Camera.ViewportSize
            fovObject.Circle.Position = Vector2.new(viewport.X / 2, viewport.Y / 2)
        else
            fovObject.Circle.Position = UserInputService:GetMouseLocation()
        end
    end)
    
    return AddDrawing(fovObject)
end

return DrawingLibrary
