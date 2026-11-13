-- Example.lua — все возможности Library.lua (синтаксис как в Linoria)

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/whoisthisxor/assets/refs/heads/main/j.lua"))()

local Window = Library:CreateWindow({
	Title = "my script",
	Version = "1.0",
	Folder = "my script", -- папка для конфигов/тем/ассетов
})

------------------------------------------------------------------
-- ГРУППЫ И ТАБЫ
-- Window:AddTab кладёт таб в последнюю группу (по умолчанию "main")
------------------------------------------------------------------

local Tabs = {}

Window:AddGroup("combat")
Tabs.Aimbot = Window:AddTab("aimbot")
Tabs.Trigger = Window:AddTab("triggerbot")

local VisualsGroup = Window:AddGroup("visuals")
Tabs.Players = VisualsGroup:AddTab("players")
Tabs.World = VisualsGroup:AddTab("world")

Window:AddGroup("misc")
Tabs.Misc = Window:AddTab("main")
Tabs.List = Window:AddTab("players")

------------------------------------------------------------------
-- GROUPBOX'Ы (колонка делится поровну между ними)
------------------------------------------------------------------

local Main = Tabs.Aimbot:AddLeftGroupbox("main")
local Settings = Tabs.Aimbot:AddRightGroupbox("settings")
local Extra = Tabs.Aimbot:AddRightGroupbox("extra")

------------------------------------------------------------------
-- TOGGLE
------------------------------------------------------------------

Main:AddToggle("AimEnabled", {
	Text = "enabled",
	Default = false,
	Callback = function(Value)
		print("[cb] aimbot:", Value)
	end,
})

Toggles.AimEnabled:OnChanged(function()
	print("aimbot changed:", Toggles.AimEnabled.Value)
end)

------------------------------------------------------------------
-- TOGGLE + KEYPICKER / COLORPICKER / SLIDER (в одной строке)
------------------------------------------------------------------

Main:AddToggle("AimKeyEnabled", { Text = "aim key" }):AddKeyPicker("AimKey", {
	Default = "E", -- "E", "MB2" или Enum.KeyCode.E
	Callback = function()
		print("[cb] клавиша нажата")
	end,
	ChangedCallback = function(New)
		print("[cb] новая клавиша:", New)
	end,
})

Options.AimKey:OnClick(function()
	print("AimKey clicked")
end)

Main:AddToggle("FovCircle", { Text = "draw fov" }):AddColorPicker("FovColor", {
	Default = Color3.fromRGB(255, 255, 255),
	Transparency = 0.5,
})

Main:AddToggle("HitChanceEnabled", { Text = "hit chance" }):AddSlider("HitChance", {
	Default = 100,
	Min = 0,
	Max = 100,
	Suffix = "%",
})

------------------------------------------------------------------
-- SLIDER
------------------------------------------------------------------

Main:AddSlider("Fov", {
	Text = "fov",
	Default = 120,
	Min = 0,
	Max = 500,
	Rounding = 0,
	Suffix = "px",
	Callback = function(Value)
		print("[cb] fov:", Value)
	end,
})

Main:AddSlider("Smooth", { Text = "smoothness", Default = 0.25, Min = 0, Max = 1, Rounding = 2 })
Main:AddSlider("Prediction", { Text = "prediction", Default = 0, Min = 0, Max = 10, MinText = "off", MaxText = "max" })

Options.Fov:OnChanged(function()
	print("fov:", Options.Fov.Value)
end)

------------------------------------------------------------------
-- DROPDOWN
------------------------------------------------------------------

Settings:AddDropdown("HitPart", {
	Text = "hit part",
	Values = { "head", "torso", "closest" },
	Default = 1, -- индекс или строка
	Callback = function(Value)
		print("[cb] hit part:", Value) -- строка
	end,
})

Settings:AddDropdown("Checks", {
	Text = "checks",
	Values = { "team", "visible", "forcefield", "alive" },
	Default = { "team", "alive" },
	Multi = true,
})

Options.Checks:OnChanged(function()
	for key, value in Options.Checks.Value do -- { team = true, alive = true }
		print(key, value)
	end
end)

------------------------------------------------------------------
-- ШЕСТЕРЕНКА (AddGear) — внутри всё то же, что в groupbox
------------------------------------------------------------------

local Gear = Settings:AddToggle("SilentAim", { Text = "silent aim" }):AddGear()
Gear:AddDropdown("SilentMethod", { Text = "method", Values = { "raycast", "namecall", "index" }, Default = 1 })
Gear:AddSlider("SilentChance", { Text = "chance", Default = 100, Min = 0, Max = 100, Suffix = "%" })
Gear:AddToggle("SilentWallbang", { Text = "wallbang" })

-- шестеренка с двумя колонками
local Gear2 = Settings:AddToggle("Resolver", { Text = "resolver" }):AddGear(2)
Gear2:Column(1):AddToggle("ResolverPitch", { Text = "pitch" })
Gear2:Column(2):AddToggle("ResolverYaw", { Text = "yaw" })

------------------------------------------------------------------
-- INPUT / LABEL / DIVIDER / BUTTON
------------------------------------------------------------------

Extra:AddInput("Whitelist", {
	Text = "whitelist",
	Default = "",
	Callback = function(Value)
		print("[cb] текст:", Value)
	end,
})

local Target = Extra:AddLabel("target:")
Target:SetValue("none") -- текст справа

Extra:AddLabel("color"):AddColorPicker("LabelColor", { Default = Color3.new(0, 1, 0) })
Extra:AddLabel("menu key"):AddKeyPicker("MenuKey", { Default = "End" })

Extra:AddDivider()

Extra:AddButton({
	Text = "print values",
	Func = function()
		print("fov =", Options.Fov.Value, "aim =", Toggles.AimEnabled.Value)
		Library:Notify("значения в консоли", 3, "success")
	end,
})

Extra:AddButton({
	Text = "reset aimbot",
	DoubleClick = true, -- "are you sure?"
	Func = function()
		Toggles.AimEnabled:SetValue(false)
		Options.Fov:SetValue(120)
		Options.HitPart:SetValue("head")
		Library:Notify("aimbot сброшен", 3, "warning")
	end,
}):AddButton("sub button", function()
	print("sub button")
end)

------------------------------------------------------------------
-- DEPENDENCY BOX
------------------------------------------------------------------

local Trig = Tabs.Trigger:AddLeftGroupbox("triggerbot")
Trig:AddToggle("TrigEnabled", { Text = "enabled" })

local Depbox = Trig:AddDependencyBox()
Depbox:AddSlider("TrigDelay", { Text = "delay", Default = 50, Min = 0, Max = 500, Suffix = "ms" })
Depbox:AddToggle("TrigBurst", { Text = "burst" })

local SubDepbox = Depbox:AddDependencyBox()
SubDepbox:AddSlider("BurstCount", { Text = "burst count", Default = 3, Min = 1, Max = 10 })

Depbox:SetupDependencies({ { Toggles.TrigEnabled, true } })
SubDepbox:SetupDependencies({ { Toggles.TrigBurst, true } })

------------------------------------------------------------------
-- VISUALS
------------------------------------------------------------------

local Esp = Tabs.Players:AddLeftGroupbox("esp")
local Style = Tabs.Players:AddRightGroupbox("style")

for _, name in { "box", "name", "health", "distance", "tracer" } do
	Esp:AddToggle("Esp_" .. name, { Text = name }):AddColorPicker("Esp_" .. name .. "_color", {
		Default = Color3.fromRGB(255, 255, 255),
	})
end

Style:AddDropdown("BoxType", { Text = "box type", Values = { "2d", "corner" }, Default = 1 })
Style:AddButton("add 3d option", function()
	Options.BoxType:SetValues({ "2d", "corner", "3d" })
end)

local Lighting = Tabs.World:AddLeftGroupbox("lighting")
Lighting:AddToggle("Ambient", { Text = "ambient" }):AddColorPicker("AmbientColor", { Default = Color3.fromRGB(120, 120, 255) })
Lighting:AddSlider("Time", { Text = "time", Default = 14, Min = 0, Max = 24, Rounding = 1 })

------------------------------------------------------------------
-- PANEL — список с поиском (ПКМ -> избранное, если Favorites = true)
------------------------------------------------------------------

local PlayerList = Tabs.List:AddLeftPanel("player list", { Favorites = true })
local PlayerInfo = Tabs.List:AddRightGroupbox("player info")

local Selected = PlayerInfo:AddLabel("selected:")
Selected:SetValue("none")

for _, plr in game:GetService("Players"):GetPlayers() do
	PlayerList:AddItem(plr.Name, "@" .. plr.DisplayName)
end

PlayerList:OnChanged(function(name)
	Selected:SetValue(name or "none")
end)

PlayerInfo:AddButton("mark red", function()
	if PlayerList.Value then
		PlayerList:SetItemColor(PlayerList.Value, Color3.fromRGB(255, 60, 60))
	end
end)

PlayerInfo:AddButton("remove", function()
	if PlayerList.Value then
		PlayerList:RemoveItem(PlayerList.Value)
	end
end)

PlayerInfo:AddButton("clear list", function()
	PlayerList:Clear()
end)

------------------------------------------------------------------
-- MISC — уведомления, акцент, кейбинд-лист, группы, удаление, unload
------------------------------------------------------------------

local Menu = Tabs.Misc:AddLeftGroupbox("menu")

Menu:AddButton("notify success", function() Library:Notify("success", 3, "success") end)
Menu:AddButton("notify warning", function() Library:Notify("warning", 3, "warning") end)
Menu:AddButton("notify error", function() Library:Notify("error", 3, "error") end)

Menu:AddLabel("accent"):AddColorPicker("Accent", {
	Default = Color3.fromRGB(140, 120, 255),
	Callback = function(Value)
		Library:SetAccent(Value)
	end,
})

-- Change Dpi: масштаб всего меню (на телефоне стартовое значение подбирается под экран)
Menu:AddSlider("MenuDpi", {
	Text = "change dpi",
	Default = Library:GetDpi(),
	Min = 0.5,
	Max = 2,
	Rounding = 2,
	Suffix = "x",
	Callback = function(Value)
		Library:SetDpi(Value)
	end,
})

Menu:AddDropdown("DpiPreset", {
	Text = "dpi preset",
	Values = { "50%", "75%", "100%", "125%", "150%", "200%" },
	Callback = function(Value)
		if Value then
			Options.MenuDpi:SetValue(tonumber((Value:gsub("%%", ""))) / 100)
		end
	end,
	AllowNull = true,
})

Menu:AddLabel("device:"):SetValue(Library.IsMobile and "mobile" or "pc")

Menu:AddToggle("KeybindList", {
	Text = "keybind list",
	Callback = function(Value)
		Library:ShowKeybinds(Value)
	end,
})

Menu:AddToggle("HideVisuals", {
	Text = "hide visuals group",
	Callback = function(Value)
		if Value then VisualsGroup:Hide() else VisualsGroup:Show() end
	end,
})

local Temp
Temp = Menu:AddButton("i will be removed", function()
	Temp:Remove()
end)

Menu:AddButton({ Text = "unload", DoubleClick = true, Func = function() Library:Unload() end })

Library:OnUnload(function()
	print("unloaded!")
end)

------------------------------------------------------------------
-- КОНФИГИ (готовая вкладка, файлы в <Folder>/configs)
------------------------------------------------------------------

Window:AddConfigs("settings")

Library:Notify("example loaded", 3, "success")
