local DrawingLibrary = {}

DrawingLibrary.Drawings = {}
DrawingLibrary.Instances = {}

local function AddDrawing(drawing)
    table.insert(DrawingLibrary.Drawings, drawing)
    return drawing
end

local function AddInstance(instance)
    table.insert(DrawingLibrary.Instances, instance)
    return instance
end

function DrawingLibrary:ClearAll()
    for _, drawing in pairs(self.Drawings) do
        if drawing.Remove then
            drawing:Remove()
        end
    end
    self.Drawings = {}
    
    for _, instance in pairs(self.Instances) do
        if instance.Destroy then
            instance:Destroy()
        end
    end
    self.Instances = {}
end

function DrawingLibrary:MakeBox(properties)
    properties = properties or {}
    local box = Drawing.new("Square")
    box.Visible = properties.Visible or false
    box.Color = properties.Color or Color3.new(1, 1, 1)
    box.Thickness = properties.Thickness or 1
    box.Transparency = properties.Transparency or 1
    box.Filled = properties.Filled or false
    box.Position = properties.Position or Vector2.new(0, 0)
    box.Size = properties.Size or Vector2.new(100, 100)
    
    return AddDrawing(box)
end

function DrawingLibrary:MakeText(properties)
    properties = properties or {}
    local textObj = Drawing.new("Text")
    textObj.Visible = properties.Visible or false
    textObj.Color = properties.Color or Color3.new(1, 1, 1)
    textObj.Text = properties.Text or "Text"
    textObj.Size = properties.Size or 16
    textObj.Center = properties.Center or true
    textObj.Outline = properties.Outline or true
    textObj.OutlineColor = properties.OutlineColor or Color3.new(0, 0, 0)
    textObj.Position = properties.Position or Vector2.new(0, 0)
    textObj.Font = properties.Font or 2 -- UI Font
    
    local textWrapper = {
        Object = textObj,
        

        UpdateText = function(self, newText)
            self.Object.Text = tostring(newText)
        end,
        
        UpdatePosition = function(self, newPosition)
            self.Object.Position = newPosition
        end,
        
        UpdateColor = function(self, newColor)
            self.Object.Color = newColor
        end,
        
        Remove = function(self)
            if self.Object and self.Object.Remove then
                self.Object:Remove()
            end
        end
    }
    
    return AddDrawing(textWrapper)
end

function DrawingLibrary:MakeName(properties)
    return self:MakeText(properties)
end

function DrawingLibrary:MakeHighlight(properties)
    properties = properties or {}
    local highlight = Instance.new("Highlight")
    highlight.Adornee = properties.Adornee or nil
    highlight.Parent = properties.Parent or game:GetService("CoreGui")
    highlight.FillColor = properties.FillColor or Color3.new(1, 1, 1)
    highlight.OutlineColor = properties.OutlineColor or Color3.new(1, 1, 1)
    highlight.FillTransparency = properties.FillTransparency or 0.5
    highlight.OutlineTransparency = properties.OutlineTransparency or 0
    highlight.DepthMode = properties.DepthMode or Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = properties.Enabled or true
    
    return AddInstance(highlight)
end

function DrawingLibrary:MakeLine(properties)
    properties = properties or {}
    local line = Drawing.new("Line")
    line.Visible = properties.Visible or false
    line.Color = properties.Color or Color3.new(1, 1, 1)
    line.Thickness = properties.Thickness or 1
    line.Transparency = properties.Transparency or 1
    line.From = properties.From or Vector2.new(0, 0)
    line.To = properties.To or Vector2.new(100, 100)
    
    return AddDrawing(line)
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
    
    return AddDrawing(circle)
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
    
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local Camera = workspace.CurrentCamera
    
    local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
    
    local fovObject = {
        Circle = fovCircle,
        Connection = nil,
        
        UpdateRadius = function(self, newRadius)
            self.Circle.Radius = newRadius
        end,
        
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
            if self.Connection then
                self.Connection:Disconnect()
                self.Connection = nil
            end
            if self.Circle and self.Circle.Remove then
                self.Circle:Remove()
            end
        end
    }
    
    fovObject.Connection = RunService.RenderStepped:Connect(function()
        if not fovObject.Circle then 
            fovObject.Connection:Disconnect()
            return 
        end
        
        if isMobile then
            local viewport = Camera.ViewportSize
            fovObject.Circle.Position = Vector2.new(viewport.X / 2, viewport.Y / 2)
        else
            local mousePos = UserInputService:GetMouseLocation()
            fovObject.Circle.Position = mousePos
        end
    end)
    
    return AddDrawing(fovObject)
end

return DrawingLibrary
