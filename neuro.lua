local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Config = {
	GUI_NAME = "NeurothycalUI",
	CONFIG_FOLDER = "neurothycal",
	CONFIG_ATTRIBUTE = "NeurothycalUIConfig",
	TITLE = "Neurothycal.wtf",
	WATERMARK = "Neurothycal.wtf",
	VERSION = "1.3.9.2",
	SUBSCRIPTION_TEXT = "29d 3h left",

	ICON_IMAGES = { rage = "", legit = "", visuals = "", inventory = "", misc = "", hotkeys = "" },
	LUCIDE_URL = "https://raw.githubusercontent.com/whoisthisxor/assets/refs/heads/main/lucide.lua",

	LUCIDE_ICONS = {
		rage = "crosshair",
		legit = "mouse",
		visuals = "image",
		inventory = "layers",
		misc = "settings-2",
		hotkeys = "keyboard",
		user = "user",
		users = "users",
		globe = "globe",
		movement = "footprints",
		gear = "settings",
		search = "search",
		flame = "flame",
		volume = "volume-2",
		cart = "shopping-cart",
		box = "package",
		sun = "sun",
		star = "sparkles",
	},
}

local Layout = {
	TITLE_SIZE = 17,

	MIN_EFFECTIVE_SCALE = 1.05,
	MAX_DENSITY = 1.4,
	WINDOW = Vector2.new(440, 410),

	MIN_SIZE = Vector2.new(410, 350),
	MAX_SIZE = Vector2.new(820, 640),
	PREVIEW = Vector2.new(236, 392),
	PREVIEW_GAP = 8,
	HEADER = 36,
	TABS_HEIGHT = 22,
	BOTTOM = 22,
	COLUMN_GAP = 8,
	PANEL_WIDTH = 170,
	TOOLTIP_WIDTH = 170,
	HEIGHTS = { check = 18, color = 18, keybind = 18, button = 22, slider = 31, dropdown = 34, input = 34 },
}

local Runtime = {
	menuKey = Enum.KeyCode.RightShift,
	menuOpen = false,
	baseScale = 1,
	windowTarget = UDim2.fromScale(0.5, 0.5),
	activeDrag = nil,
	activeDragEnd = nil,
	listeningBind = nil,
	current = {},
	watchers = {},
	bindings = {},
	currentTab = nil,
	currentPage = nil,
	tooltipToken = 0,
	tooltipShown = false,
	notifyOrder = 0,

	density = 1,
	rows = {},
	panelSections = {},
	navScales = {},
	hotkeyListEnabled = true,
	notificationsEnabled = true,
	searchText = "",
}

local UI = {}

local Theme = {
	Accent = Color3.fromRGB(255, 45, 140),
	Window = Color3.fromRGB(23, 23, 25),
	WindowStroke = Color3.fromRGB(52, 52, 56),
	Card = Color3.fromRGB(28, 28, 30),
	CardStroke = Color3.fromRGB(50, 50, 54),
	RowHover = Color3.fromRGB(46, 46, 50),
	Text = Color3.fromRGB(228, 228, 231),
	TextOff = Color3.fromRGB(142, 142, 148),
	TextMuted = Color3.fromRGB(108, 108, 114),
	Field = Color3.fromRGB(47, 47, 51),
	FieldHover = Color3.fromRGB(58, 58, 63),
	CheckOff = Color3.fromRGB(44, 44, 47),
	Popup = Color3.fromRGB(32, 32, 35),
	PopupStroke = Color3.fromRGB(58, 58, 62),
	SwatchStroke = Color3.fromRGB(78, 78, 84),
	Black = Color3.new(0, 0, 0),
	White = Color3.new(1, 1, 1),
}

local function familyOf(enumName, fallback)
	local ok, family = pcall(function()
		return Font.fromEnum(Enum.Font[enumName]).Family
	end)
	return ok and family or fallback
end

local Family = familyOf("Ubuntu", "rbxasset://fonts/families/BuilderSans.json")

local Fonts = {
	Regular = Font.new(Family, Enum.FontWeight.Regular),
	Medium = Font.new(Family, Enum.FontWeight.Medium),
	Bold = Font.new(Family, Enum.FontWeight.Bold),
}

local guiParent = playerGui
do
	local getHui = getfenv().gethui
	if getHui then
		local ok, container = pcall(getHui)
		if ok and container then
			guiParent = container
		end
	end
end

for _, parent in ipairs({ guiParent, playerGui }) do
	local existing = parent:FindFirstChild(Config.GUI_NAME)
	if existing then
		existing:Destroy()
	end
end

local Lucide = nil
do
	local ok, result = pcall(function()
		return loadstring(game:HttpGet(Config.LUCIDE_URL))()
	end)
	if ok and type(result) == "table" then
		Lucide = result
	else
		warn("[Neurothycal UI] Lucide не загружен, используются векторные иконки:", result)
	end
end

local FileApi = {}
do
	local environment = getfenv()
	FileApi.write, FileApi.read, FileApi.exists = environment.writefile, environment.readfile, environment.isfile
	FileApi.list, FileApi.delete = environment.listfiles, environment.delfile
	FileApi.makeFolder, FileApi.folderExists = environment.makefolder, environment.isfolder
end

local connections = {}

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function create(className, props, children)
	local instance = Instance.new(className)
	if instance:IsA("GuiObject") then
		instance.BorderSizePixel = 0
	end
	for key, value in pairs(props or {}) do
		if key == "Font" and typeof(value) == "Font" then
			instance.FontFace = value
		elseif key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

local function tween(instance, props, duration, style)
	local info = TweenInfo.new(duration or 0.15, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local animation = TweenService:Create(instance, info, props)
	animation:Play()
	return animation
end

local function corner(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function round()
	return create("UICorner", { CornerRadius = UDim.new(1, 0) })
end

local function stroke(color, thickness, parent)
	return create("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function padding(top, right, bottom, left)
	return create("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right),
		PaddingBottom = UDim.new(0, bottom),
		PaddingLeft = UDim.new(0, left),
	})
end

local function list(spacing, direction, verticalAlign)
	return create("UIListLayout", {
		Padding = UDim.new(0, spacing or 0),
		FillDirection = direction or Enum.FillDirection.Vertical,
		VerticalAlignment = verticalAlign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

local function label(props, children)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Fonts.Regular
	props.TextColor3 = props.TextColor3 or Theme.Text
	props.TextSize = props.TextSize or 10
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return create("TextLabel", props, children)
end

local function button(props, children)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.AutoButtonColor = false
	props.Text = props.Text or ""
	return create("TextButton", props, children)
end

local function textBox(props, children)
	props.ClearTextOnFocus = false
	props.Font = props.Font or Fonts.Regular
	props.TextSize = props.TextSize or 10
	props.TextColor3 = props.TextColor3 or Theme.Text
	props.PlaceholderColor3 = Theme.TextMuted
	props.Text = props.Text or ""
	return create("TextBox", props, children)
end

local function isDragInput(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function copyValue(value)
	return type(value) == "table" and table.clone(value) or value
end

local function trim(text)
	return string.match(text, "^%s*(.-)%s*$")
end

local function parseColor(value)
	if type(value) ~= "string" then
		return nil
	end
	local hex = (string.gsub(value, "#", ""))
	if #hex ~= 6 and #hex ~= 8 then
		return nil
	end
	local ok, color = pcall(Color3.fromHex, string.sub(hex, 1, 6))
	if not ok then
		return nil
	end
	local alpha = #hex == 8 and (tonumber(string.sub(hex, 7, 8), 16) or 255) / 255 or 1
	return color, alpha
end

local function formatColor(color, alpha)
	return string.upper(color:ToHex()) .. string.format("%02X", math.floor(alpha * 255 + 0.5))
end

local function collectFadeTargets(parent, targets)
	local function add(instance, property)
		if instance[property] < 1 then
			table.insert(targets, { instance, property, instance[property] })
		end
	end
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("UIStroke") then
			add(child, "Transparency")
		elseif child:IsA("CanvasGroup") then
			if child.Visible then
				add(child, "GroupTransparency")
			end
		elseif child:IsA("GuiObject") and child.Visible then
			add(child, "BackgroundTransparency")
			if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
				add(child, "TextTransparency")
			elseif child:IsA("ImageLabel") or child:IsA("ImageButton") or child:IsA("ViewportFrame") then
				add(child, "ImageTransparency")
			elseif child:IsA("ScrollingFrame") then
				add(child, "ScrollBarImageTransparency")
			end
			if not child:IsA("ViewportFrame") then
				collectFadeTargets(child, targets)
			end
		end
	end
end

local function createFader(props, pop)
	local fader = { token = 0 }

	local hostProps = { BackgroundTransparency = 1, Visible = false }
	for key, value in pairs(props) do
		hostProps[key] = value
	end
	fader.plain = create("Frame", hostProps)
	local host = fader.plain
	if pop then
		fader.popScale = create("UIScale", { Parent = host })
	end

	function fader.setContent(content)
		content.Parent = host
		fader.content = content
	end

	function fader.set(property, value)
		host[property] = value
	end

	function fader.position()
		return host.Position
	end

	local function restore()
		for _, target in ipairs(fader.targets or {}) do
			target[1][target[2]] = target[3]
		end
		fader.targets = nil
	end

	function fader.snap(shown)
		fader.token += 1
		restore()
		host.Visible = shown
	end

	function fader.fade(show, duration, style, from, to)

		if host.Visible == show and not fader.targets then
			return
		end
		fader.token += 1
		local token = fader.token

		if not fader.targets then
			fader.targets = {}
			collectFadeTargets(host, fader.targets)
			if show then
				for _, target in ipairs(fader.targets) do
					target[1][target[2]] = 1
				end
				if from then
					host.Position = from
				end
				if fader.popScale then
					fader.popScale.Scale = 0.95
				end
			end
		end
		host.Visible = true

		for _, target in ipairs(fader.targets) do
			tween(target[1], { [target[2]] = show and target[3] or 1 }, duration, style)
		end
		if to then
			tween(host, { Position = to }, duration, style)
		end
		if fader.popScale then
			tween(fader.popScale, { Scale = show and 1 or 0.95 }, duration, style)
		end

		task.delay(duration, function()
			if token ~= fader.token then
				return
			end
			if show then
				fader.targets = nil
			else
				host.Visible = false
				restore()
			end
		end)
	end

	return fader
end

local accentTargets = {}
local accentRefreshers = {}

local function accented(instance, property)
	instance[property] = Theme.Accent
	table.insert(accentTargets, { instance, property })
	return instance
end

local function setAccent(value)
	local color = parseColor(value)
	if not color or color == Theme.Accent then
		return
	end
	Theme.Accent = color
	for _, target in ipairs(accentTargets) do
		target[1][target[2]] = color
	end
	for _, refresh in ipairs(accentRefreshers) do
		refresh()
	end
end

local function shape(parent, x, y, width, height, color, rotation)
	return create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = color,
		Rotation = rotation or 0,
		Parent = parent,
	}, { round() })
end

local function ring(parent, x, y, width, height, thickness, color, radius)
	return create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1,
		Parent = parent,
	}, { radius and corner(radius) or round(), stroke(color, thickness) })
end

local IconPaths = {}

function IconPaths.rage(pen)
	pen.circle(12, 12, 10)
	pen.line(22, 12, 18, 12)
	pen.line(6, 12, 2, 12)
	pen.line(12, 6, 12, 2)
	pen.line(12, 22, 12, 18)
end

function IconPaths.legit(pen)
	pen.rect(5, 2, 14, 20, 7)
	pen.line(12, 6, 12, 10)
end

function IconPaths.visuals(pen)
	pen.rect(3, 3, 18, 18, 2)
	pen.circle(9, 9, 2)
	pen.poly({ { 21, 15 }, { 17.9, 11.9 }, { 16.5, 11.35 }, { 15.1, 11.9 }, { 6, 21 } })
end

function IconPaths.inventory(pen)
	pen.poly({ { 12, 2.2 }, { 2.3, 7 }, { 12, 11.8 }, { 21.7, 7 }, { 12, 2.2 } })
	pen.poly({ { 2, 12 }, { 12, 16.8 }, { 22, 12 } })
	pen.poly({ { 2, 17 }, { 12, 21.8 }, { 22, 17 } })
end

function IconPaths.misc(pen)
	pen.line(14, 17, 5, 17)
	pen.line(19, 7, 10, 7)
	pen.circle(17, 17, 3)
	pen.circle(7, 7, 3)
end

function IconPaths.hotkeys(pen)
	pen.rect(2, 4, 20, 16, 2)
	for _, x in ipairs({ 6, 10, 14, 18 }) do
		pen.dot(x, 8, 0.3)
	end
	for _, x in ipairs({ 8, 12, 16 }) do
		pen.dot(x, 12, 0.3)
	end
	pen.line(7, 16, 17, 16)
end

function IconPaths.user(pen)
	pen.circle(12, 7, 4)
	pen.poly({ { 5, 21 }, { 5, 19 }, { 6.2, 16.2 }, { 9, 15 }, { 15, 15 }, { 17.8, 16.2 }, { 19, 19 }, { 19, 21 } })
end

function IconPaths.users(pen)
	pen.circle(9, 7, 4)
	pen.poly({ { 2, 21 }, { 2, 19 }, { 3.2, 16.2 }, { 6, 15 }, { 12, 15 }, { 14.8, 16.2 }, { 16, 19 }, { 16, 21 } })
	pen.poly({ { 16, 3.2 }, { 19, 5 }, { 19, 9 }, { 16, 10.8 } })
	pen.poly({ { 19, 15.2 }, { 21.5, 17 }, { 22, 19 }, { 22, 21 } })
end

function IconPaths.globe(pen)
	pen.circle(12, 12, 10)
	pen.ellipse(12, 12, 4.5, 10)
	pen.line(2, 12, 22, 12)
end

function IconPaths.movement(pen)
	pen.circle(14, 4.5, 2)
	pen.poly({ { 9, 11 }, { 13, 8.5 }, { 15, 11 }, { 18.5, 12.5 } })
	pen.poly({ { 13, 8.5 }, { 11.5, 15 }, { 15, 18 }, { 15.5, 22 } })
	pen.poly({ { 11.5, 15 }, { 9, 18.5 }, { 5, 20 } })
end

function IconPaths.gear(pen)
	pen.circle(12, 12, 3)
	pen.circle(12, 12, 7.5)
	for index = 0, 7 do
		local angle = math.rad(index * 45)
		pen.line(12 + math.cos(angle) * 8.5, 12 + math.sin(angle) * 8.5, 12 + math.cos(angle) * 10.5, 12 + math.sin(angle) * 10.5)
	end
end

function IconPaths.search(pen)
	pen.circle(11, 11, 8)
	pen.line(21, 21, 16.65, 16.65)
end

function IconPaths.flame(pen)
	pen.poly({ { 12, 2 }, { 16, 8 }, { 18.5, 12 }, { 18, 17 }, { 15, 21 }, { 12, 22 }, { 9, 21 }, { 6, 17 }, { 5.5, 12 }, { 8, 9 }, { 9.5, 11 }, { 12, 2 } })
end

function IconPaths.volume(pen)
	pen.poly({ { 11, 5 }, { 6, 9 }, { 2, 9 }, { 2, 15 }, { 6, 15 }, { 11, 19 }, { 11, 5 } })
	pen.poly({ { 15.5, 8.5 }, { 17, 12 }, { 15.5, 15.5 } })
	pen.poly({ { 19, 5 }, { 22, 12 }, { 19, 19 } })
end

function IconPaths.cart(pen)
	pen.poly({ { 2, 3 }, { 5, 3 }, { 8, 15 }, { 19, 15 }, { 21, 7 }, { 6, 7 } })
	pen.circle(9, 20, 1.5)
	pen.circle(18, 20, 1.5)
end

function IconPaths.box(pen)
	pen.rect(3, 7, 18, 14, 2)
	pen.line(3, 12, 21, 12)
	pen.poly({ { 8, 7 }, { 8, 3 }, { 16, 3 }, { 16, 7 } })
end

function IconPaths.sun(pen)
	pen.circle(12, 12, 4)
	for index = 0, 7 do
		local angle = math.rad(index * 45)
		pen.line(12 + math.cos(angle) * 7, 12 + math.sin(angle) * 7, 12 + math.cos(angle) * 10, 12 + math.sin(angle) * 10)
	end
end

function IconPaths.star(pen)
	pen.poly({ { 12, 2 }, { 15, 9 }, { 22, 9.5 }, { 16.5, 14 }, { 18.5, 21 }, { 12, 17 }, { 5.5, 21 }, { 7.5, 14 }, { 2, 9.5 }, { 9, 9 }, { 12, 2 } })
end

local function lucideAsset(iconName)

	local lucideName = Config.LUCIDE_ICONS[iconName] or (not IconPaths[iconName] and iconName)
	if not Lucide or not lucideName then
		return nil
	end
	local ok, asset = pcall(Lucide.GetAsset, lucideName, 48)
	return ok and asset or nil
end

local function createIcon(parent, iconName, size, color, position, anchor)
	local image = Config.ICON_IMAGES[iconName]
	local asset = not (image and image ~= "") and lucideAsset(iconName) or nil
	if asset or (image and image ~= "") then
		return create("ImageLabel", {
			AnchorPoint = anchor or Vector2.new(0.5, 0.5),
			Position = position or UDim2.new(),
			Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 1,
			Image = asset and asset.Url or image,
			ImageRectSize = asset and asset.ImageRectSize or Vector2.zero,
			ImageRectOffset = asset and asset.ImageRectOffset or Vector2.zero,
			ImageColor3 = color,
			ScaleType = Enum.ScaleType.Fit,
			Parent = parent,
		})
	end

	local holder = create("Frame", {
		AnchorPoint = anchor or Vector2.new(0.5, 0.5),
		Position = position or UDim2.new(),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	if not IconPaths[iconName] then
		return holder
	end
	local k = size / 24
	local thickness = 2.2 * k

	local pen = {}
	function pen.line(x1, y1, x2, y2)
		local dx, dy = (x2 - x1) * k, (y2 - y1) * k
		local length = math.sqrt(dx * dx + dy * dy)
		shape(holder, (x1 + x2) / 2 * k, (y1 + y2) / 2 * k, length + thickness, thickness, color, math.deg(math.atan2(dy, dx)))
	end
	function pen.poly(points)
		for index = 1, #points - 1 do
			pen.line(points[index][1], points[index][2], points[index + 1][1], points[index + 1][2])
		end
	end
	function pen.ellipse(cx, cy, rx, ry)
		ring(holder, cx * k, cy * k, 2 * rx * k - thickness, 2 * ry * k - thickness, thickness, color)
	end
	function pen.circle(cx, cy, r)
		pen.ellipse(cx, cy, r, r)
	end
	function pen.rect(x, y, width, height, radius)
		ring(holder, (x + width / 2) * k, (y + height / 2) * k, width * k - thickness, height * k - thickness, thickness, color, math.max(radius * k - thickness / 2, 0))
	end
	function pen.dot(cx, cy, r)
		shape(holder, cx * k, cy * k, 2 * r * k + thickness, 2 * r * k + thickness, color)
	end

	IconPaths[iconName](pen)
	return holder
end

local function tintIcon(icon, color, duration)
	if icon:IsA("ImageLabel") then
		tween(icon, { ImageColor3 = color }, duration)
		return
	end
	for _, descendant in ipairs(icon:GetDescendants()) do
		if descendant:IsA("UIStroke") then
			tween(descendant, { Color = color }, duration)
		elseif descendant:IsA("Frame") and descendant.BackgroundTransparency < 1 then
			tween(descendant, { BackgroundColor3 = color }, duration)
		end
	end
end

local function triangle(parent, color, rightInset)
	local holder = create("CanvasGroup", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -rightInset, 0.5, 0),
		Size = UDim2.fromOffset(9, 5),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	return create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(4.5, 0),
		Size = UDim2.fromOffset(6.4, 6.4),
		Rotation = 45,
		BackgroundColor3 = color,
		Parent = holder,
	}, { corner(1) })
end

local Store = { Values = {}, Global = {} }

local function readValue(item)
	local value = Store.Values[item.key]
	if value == nil then
		value = item.default
	end
	return copyValue(value)
end

local function notifyWatchers(key, value, instant)
	Runtime.current[key] = value
	for _, watcher in ipairs(Runtime.watchers[key] or {}) do
		watcher(value, instant)
	end
end

local function watch(key, watcher)
	Runtime.watchers[key] = Runtime.watchers[key] or {}
	table.insert(Runtime.watchers[key], watcher)
	watcher(Runtime.current[key], true)
end

local function runCallback(item, value)
	if not item.callback then
		return
	end
	local ok, message = xpcall(item.callback, debug.traceback, value)
	if not ok then
		warn(string.format("[Neurothycal UI] callback of %s failed:\n%s", tostring(item.key), tostring(message)))
	end
end

local function bind(item, apply)
	local function refresh()
		local value = apply(readValue(item), true)
		notifyWatchers(item.key, value, true)
		runCallback(item, value)
	end
	table.insert(Runtime.bindings, refresh)

	local value = apply(readValue(item), true)
	notifyWatchers(item.key, value, true)
	if string.sub(item.key, 1, 5) == "menu_" then
		runCallback(item, value)
	end

	return function(newValue)
		newValue = apply(newValue, false)
		Store.Values[item.key] = copyValue(newValue)
		notifyWatchers(item.key, newValue, false)
		Runtime.saveMenuValue(item.key)
		runCallback(item, newValue)
	end
end

local function refreshAll()
	for _, refresh in ipairs(Runtime.bindings) do
		refresh()
	end
end

local Files = {}

function Files.path(name)
	return Config.CONFIG_FOLDER .. "/" .. name .. ".json"
end

function Files.memory()
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute(Config.CONFIG_ATTRIBUTE) or "{}")
	return ok and type(decoded) == "table" and decoded or {}
end

function Files.setMemory(memory)
	local ok, data = pcall(HttpService.JSONEncode, HttpService, memory)
	if ok then
		player:SetAttribute(Config.CONFIG_ATTRIBUTE, data)
	end
end

function Files.write(name, data)
	if FileApi.write then
		if FileApi.makeFolder and FileApi.folderExists and not FileApi.folderExists(Config.CONFIG_FOLDER) then
			FileApi.makeFolder(Config.CONFIG_FOLDER)
		end
		return (pcall(FileApi.write, Files.path(name), data))
	end
	local memory = Files.memory()
	memory[name] = data
	Files.setMemory(memory)
	return true
end

function Files.read(name)
	if FileApi.read and FileApi.exists then
		if select(2, pcall(FileApi.exists, Files.path(name))) ~= true then
			return nil
		end
		local ok, content = pcall(FileApi.read, Files.path(name))
		return ok and content or nil
	end
	return Files.memory()[name]
end

function Files.delete(name)
	if FileApi.delete then
		pcall(FileApi.delete, Files.path(name))
		return
	end
	local memory = Files.memory()
	memory[name] = nil
	Files.setMemory(memory)
end

function Files.configs()
	local names = {}
	if FileApi.list then
		local ok, paths = pcall(FileApi.list, Config.CONFIG_FOLDER)
		for _, path in ipairs(ok and paths or {}) do
			local name = string.match(path, "([^/\\]+)%.json$")
			if name and string.sub(name, 1, 1) ~= "_" then
				table.insert(names, name)
			end
		end
	else
		for name in pairs(Files.memory()) do
			if string.sub(name, 1, 1) ~= "_" then
				table.insert(names, name)
			end
		end
	end
	table.sort(names)
	return names
end

local function isServiceKey(key)
	return string.sub(key, 1, 5) == "menu_" or string.sub(key, 1, 7) == "config_"
end

local function saveGlobal()
	local menu = {}
	for key, value in pairs(Store.Values) do
		if string.sub(key, 1, 5) == "menu_" then
			menu[key] = value
		end
	end
	Store.Global.menu = menu
	local ok, data = pcall(HttpService.JSONEncode, HttpService, Store.Global)
	if ok then
		Files.write("_global", data)
	end
end

local function scheduleGlobalSave()
	if Runtime.globalSavePending then
		return
	end
	Runtime.globalSavePending = true
	task.delay(1, function()
		Runtime.globalSavePending = false
		saveGlobal()
	end)
end

local function loadGlobal()
	local data = Files.read("_global")
	if type(data) ~= "string" then
		return
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, data)
	if ok and type(decoded) == "table" then
		Store.Global = decoded
		for key, value in pairs(type(decoded.menu) == "table" and decoded.menu or {}) do
			Store.Values[key] = value
		end
	end
end

local function saveConfig(name)
	local values = {}
	for key, value in pairs(Store.Values) do
		if not isServiceKey(key) then
			values[key] = value
		end
	end
	local ok, data = pcall(HttpService.JSONEncode, HttpService, values)
	return ok and Files.write(name, data)
end

local function loadConfig(name)
	local data = Files.read(name)
	if type(data) ~= "string" then
		return false
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, data)
	if not ok or type(decoded) ~= "table" then
		return false
	end
	for key, value in pairs(Store.Values) do
		if isServiceKey(key) then
			decoded[key] = value
		end
	end
	Store.Values = decoded
	refreshAll()
	return true
end
loadGlobal()

function Runtime.saveMenuValue(key)
	if string.sub(key, 1, 5) == "menu_" then
		scheduleGlobalSave()
	end
end

do
	local saved = type(Store.Global.windowSize) == "table" and Store.Global.windowSize or {}
	Runtime.windowSize = Vector2.new(
		math.clamp(tonumber(saved.x) or Layout.WINDOW.X, Layout.MIN_SIZE.X, Layout.MAX_SIZE.X),
		math.clamp(tonumber(saved.y) or Layout.WINDOW.Y, Layout.MIN_SIZE.Y, Layout.MAX_SIZE.Y)
	)
end

UI.screenGui = create("ScreenGui", {
	Name = Config.GUI_NAME,
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 50,
	Parent = guiParent,
})

UI.windowFader = createFader({
	Name = "Window",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = Runtime.windowTarget,
	Size = UDim2.fromOffset(Runtime.windowSize.X, Runtime.windowSize.Y),
	Parent = UI.screenGui,
})
UI.windowScales = { create("UIScale", { Parent = UI.windowFader.plain }) }

UI.root = create("Frame", {
	Position = UDim2.fromOffset(1, 1),
	Size = UDim2.new(1, -2, 1, -2),
	BackgroundColor3 = Theme.Window,
	BackgroundTransparency = 0.04,
	Active = true,
}, { corner(7), stroke(Theme.WindowStroke) })
UI.windowFader.setContent(UI.root)

UI.backdrop = create("CanvasGroup", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Parent = UI.root,
}, { corner(7) })

accented(create("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.fromScale(1, 0.45),
	Parent = UI.backdrop,
}, {
	create("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new(1, 0.72),
	}),
}), "BackgroundColor3")

UI.watermark = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(1420, 1060),
	BackgroundTransparency = 1,
	Rotation = -18,
	Parent = UI.backdrop,
})
UI.backdropLabels = {}
for rowIndex = 0, 12 do
	for column = 0, 6 do
		table.insert(UI.backdropLabels, accented(label({
			Text = Config.WATERMARK,
			Font = Fonts.Bold,
			TextSize = 27,
			TextTransparency = 0.86,
			Position = UDim2.fromOffset(column * 235 - (rowIndex % 2) * 110, rowIndex * 88),
			Size = UDim2.fromOffset(230, 40),
			Parent = UI.watermark,
		}), "TextColor3"))
	end
end

UI.overlay = create("Frame", {
	Name = "Overlay",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = Runtime.windowTarget,
	Size = UDim2.fromOffset(Runtime.windowSize.X, Runtime.windowSize.Y),
	BackgroundTransparency = 1,
	ZIndex = 5,
	Parent = UI.screenGui,
})
UI.overlayScale = create("UIScale", { Parent = UI.overlay })

local function startDrag(onMove, onEnd)
	Runtime.activeDrag, Runtime.activeDragEnd = onMove, onEnd
end

local function cancelListening()
	if Runtime.listeningBind then
		Runtime.listeningBind(nil)
	end
end

local function glide(objects, position)
	for _, object in ipairs(objects) do
		tween(object, { Position = position }, 0.09)
	end
end

local popupStack = {}
local hideTooltip

local function closePopups(level)
	if hideTooltip then
		hideTooltip()
	end
	for index = #popupStack, level or 1, -1 do
		local entry = popupStack[index]
		popupStack[index] = nil
		entry.catcher:Destroy()
		entry.close()
	end
end

local function pushPopup(level, close)
	closePopups(level)
	local catcher = button({
		Position = UDim2.fromOffset(-5000, -5000),
		Size = UDim2.fromOffset(10000, 10000),
		ZIndex = level * 2,
		Parent = UI.overlay,
	})
	catcher.MouseButton1Click:Connect(function()
		closePopups(level)
	end)
	popupStack[level] = { catcher = catcher, close = close }
end

local function popupPosition(anchor, width, height, alignRight)
	local scale = UI.overlayScale.Scale
	local position = (anchor.AbsolutePosition - UI.overlay.AbsolutePosition) / scale
	local size = anchor.AbsoluteSize / scale
	local x = alignRight and (position.X + size.X - width) or position.X
	local y = position.Y + size.Y + 3
	if y + height > Runtime.windowSize.Y - 4 then
		y = position.Y - height - 3
	end
	return math.clamp(x, 4, Runtime.windowSize.X - width - 4), math.max(y, 4)
end

local function openFloating(anchor, level, width, height)
	local x, y = popupPosition(anchor, width, height, false)
	local target = UDim2.fromOffset(x, y)
	local hidden = target + UDim2.fromOffset(0, -5)
	local fader = createFader({
		Position = target,
		Size = UDim2.fromOffset(width, height),
		ZIndex = level * 2 + 1,
		Parent = UI.overlay,
	}, true)
	local frame = create("Frame", {
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = Theme.Popup,
		ClipsDescendants = true,
		Active = true,
	}, { corner(4), stroke(Theme.PopupStroke) })
	fader.setContent(frame)

	pushPopup(level, function()
		fader.fade(false, 0.16, Enum.EasingStyle.Quad, nil, hidden)
		task.delay(0.2, function()
			fader.plain:Destroy()
		end)
	end)
	fader.fade(true, 0.24, Enum.EasingStyle.Quint, hidden, target)
	return frame, fader
end

local function createPickerWidget(parent, top, width, svHeight, minimal)
	local innerWidth = width - 16
	local hueY = top + 8 + svHeight + 6
	local alphaY = hueY + 12
	local hexY = alphaY + 12

	local svMap = create("Frame", {
		Position = UDim2.fromOffset(8, top + 8),
		Size = UDim2.fromOffset(innerWidth, svHeight),
		BackgroundColor3 = Color3.new(1, 0, 0),
		Parent = parent,
	}, {
		corner(4),
		create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.White,
		}, { corner(4), create("UIGradient", { Transparency = NumberSequence.new(0, 1) }) }),
		create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Black,
		}, { corner(4), create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }) }),
	})

	local accentStrokes = {}
	local svCursor = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(8, 8),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = svMap,
	}, { round(), stroke(Theme.White, 1.5) })
	table.insert(accentStrokes, stroke(Theme.Accent, 1, create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 3, 1, 3),
		BackgroundTransparency = 1,
		Parent = svCursor,
	}, { round() })))

	local hueKeypoints = {}
	for index = 0, 6 do
		table.insert(hueKeypoints, ColorSequenceKeypoint.new(index / 6, Color3.fromHSV(index / 6, 1, 1)))
	end
	local hueBar = create("Frame", {
		Position = UDim2.fromOffset(8, hueY),
		Size = UDim2.fromOffset(innerWidth, 7),
		BackgroundColor3 = Theme.White,
		Parent = parent,
	}, { corner(3), create("UIGradient", { Color = ColorSequence.new(hueKeypoints) }) })
	local hueCursor = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 3, 1, 2),
		BackgroundColor3 = Theme.White,
		ZIndex = 2,
		Parent = hueBar,
	}, { round() })
	table.insert(accentStrokes, stroke(Theme.Accent, 1, hueCursor))

	local alphaBar = create("Frame", {
		Position = UDim2.fromOffset(8, alphaY),
		Size = UDim2.fromOffset(innerWidth, 7),
		BackgroundTransparency = 1,
		Parent = parent,
	})

	local alphaClip = create("CanvasGroup", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(205, 205, 208),
		Parent = alphaBar,
	}, { corner(3) })
	for column = 0, math.ceil(innerWidth / 3.5) do
		create("Frame", {
			Position = UDim2.fromOffset(column * 3.5, (column % 2) * 3.5),
			Size = UDim2.fromOffset(3.5, 3.5),
			BackgroundColor3 = Color3.fromRGB(120, 120, 126),
			Parent = alphaClip,
		})
	end
	local alphaFill = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.White,
		Parent = alphaClip,
	}, { create("UIGradient", { Transparency = NumberSequence.new(1, 0) }) })
	local alphaCursor = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 3, 1, 2),
		BackgroundColor3 = Theme.White,
		ZIndex = 2,
		Parent = alphaBar,
	}, { round() })
	table.insert(accentStrokes, stroke(Theme.Accent, 1, alphaCursor))

	local state = { h = 0, s = 0, v = 1, a = 1, onChange = nil }
	local hexBox

	local function display(notify)
		local color = Color3.fromHSV(state.h, state.s, state.v)
		svMap.BackgroundColor3 = Color3.fromHSV(state.h, 1, 1)
		svCursor.Position = UDim2.fromScale(state.s, 1 - state.v)
		hueCursor.Position = UDim2.fromScale(state.h, 0.5)
		alphaFill.BackgroundColor3 = color
		alphaCursor.Position = UDim2.fromScale(state.a, 0.5)
		if hexBox then
			hexBox.Text = string.upper(color:ToHex())
		end
		if notify and state.onChange then
			state.onChange(formatColor(color, state.a))
		end
	end

	local function setColor(color)
		local h, s, v = color:ToHSV()
		if s > 0 and v > 0 then
			state.h = h
		end
		state.s, state.v = s, v
	end

	local function dragArea(area, update)
		local hit = button({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 6, 1, 4),
			ZIndex = 3,
			Parent = area,
		})
		hit.InputBegan:Connect(function(input)
			if not isDragInput(input) then
				return
			end
			local function move(position)
				local relative = (Vector2.new(position.X, position.Y) - area.AbsolutePosition) / area.AbsoluteSize
				update(math.clamp(relative.X, 0, 1), math.clamp(relative.Y, 0, 1))
				display(true)
			end
			move(input.Position)
			startDrag(move)
		end)
	end

	dragArea(svMap, function(x, y)
		state.s, state.v = x, 1 - y
	end)
	dragArea(hueBar, function(x)
		state.h = x
	end)
	dragArea(alphaBar, function(x)
		state.a = x
	end)

	local widget = { height = alphaY + 7 + 8 - top }

	if not minimal then
		hexBox = textBox({
			Position = UDim2.fromOffset(8, hexY),
			Size = UDim2.fromOffset(innerWidth, 15),
			BackgroundColor3 = Theme.Field,
			TextSize = 9,
			PlaceholderText = "hex",
			Parent = parent,
		}, { corner(3) })
		hexBox.FocusLost:Connect(function()
			local color = parseColor(trim(hexBox.Text))
			if color then
				setColor(color)
			end
			display(color ~= nil)
		end)

		widget.height = hexY + 15 + 8 - top
	end

	function widget.open(value, onChange)
		for _, accentStroke in ipairs(accentStrokes) do
			accentStroke.Color = Theme.Accent
		end
		local color, alpha = parseColor(value)
		state.onChange = nil
		setColor(color or Theme.White)
		state.a = alpha or 1
		display(false)
		state.onChange = onChange
	end

	function widget.release()
		state.onChange = nil
	end

	return widget
end

local function openList(anchor, level, width, options, isSelected, onPick, settings)
	settings = settings or {}
	local density = Runtime.density
	local searchHeight = settings.search and 24 or 0
	local itemHeight = math.floor(17 * density + 0.5)
	local overflow = #options > 9
	local listHeight = math.min(#options, 9) * itemHeight + 6

	local baseHeight = listHeight + searchHeight + 2
	local frame, fader = openFloating(anchor, level, width, baseHeight)

	local picker, pickerOption

	local function setPopupHeight(height)
		local size = UDim2.fromOffset(width, height)
		tween(fader.plain, { Size = size }, 0.24, Enum.EasingStyle.Quint)
	end

	local function togglePicker(option, swatch)
		if pickerOption == option then
			pickerOption = nil
			picker.release()
			setPopupHeight(baseHeight)
			return
		end
		picker = picker or createPickerWidget(frame, searchHeight + listHeight, width - 2, 104, true)
		pickerOption = option
		picker.open(settings.colorOf(option), function(value)
			swatch.BackgroundColor3 = parseColor(value)
			settings.onColor(option, value)
		end)
		setPopupHeight(baseHeight + picker.height)
	end

	local entries = {}
	local function refresh()
		for _, entry in ipairs(entries) do
			entry.text.TextColor3 = isSelected(entry.option) and Theme.Accent or Theme.TextOff
		end
	end

	if settings.search then
		local input = textBox({
			Position = UDim2.fromOffset(5, 5),
			Size = UDim2.new(1, -10, 0, 15),
			BackgroundColor3 = Theme.Field,
			PlaceholderText = "search...",
			Parent = frame,
		}, { corner(3) })
		input:GetPropertyChangedSignal("Text"):Connect(function()
			local query = string.lower(input.Text)
			for _, entry in ipairs(entries) do
				entry.button.Visible = query == "" or string.find(string.lower(entry.option), query, 1, true) ~= nil
			end
		end)
	end

	local scroll = create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, searchHeight),
		Size = UDim2.new(1, 0, 0, listHeight),
		BackgroundTransparency = 1,

		ScrollingEnabled = overflow,
		ScrollBarThickness = overflow and 2 or 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = overflow and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarImageColor3 = Theme.Accent,
		Parent = frame,
	}, { list(0), padding(3, 3, 3, 3) })

	for index, option in ipairs(options) do
		local entryButton = button({
			Size = UDim2.new(1, 0, 0, itemHeight),
			BackgroundColor3 = Theme.RowHover,
			LayoutOrder = index,
			Parent = scroll,
		}, { corner(3) })
		local text = label({
			Text = option,
			TextSize = 10 * density,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(6, 0),
			Size = UDim2.new(1, -10, 1, 0),
			Parent = entryButton,
		})
		table.insert(entries, { option = option, text = text, button = entryButton })

		if settings.colorOf then
			local swatch = button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -4, 0.5, 0),
				Size = UDim2.fromOffset(10 * density, 10 * density),
				BackgroundColor3 = parseColor(settings.colorOf(option)) or Theme.White,
				BackgroundTransparency = 0,
				Parent = entryButton,
			}, { corner(2), stroke(Theme.SwatchStroke) })
			swatch.MouseButton1Click:Connect(function()
				togglePicker(option, swatch)
			end)
		end

		entryButton.MouseEnter:Connect(function()
			tween(entryButton, { BackgroundTransparency = 0 }, 0.1)
		end)
		entryButton.MouseLeave:Connect(function()
			tween(entryButton, { BackgroundTransparency = 1 }, 0.1)
		end)
		entryButton.MouseButton1Click:Connect(function()
			onPick(option)
			refresh()
		end)
	end
	refresh()
	return frame
end

local function createFloatingPanel(width, height)
	local panel = createFader({
		Size = UDim2.fromOffset(width, height),
		Parent = UI.overlay,
	}, true)
	local holder = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = true,
	})
	panel.setContent(holder)
	local inner = create("Frame", {
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = Theme.Popup,
		Parent = holder,
	}, { corner(5), stroke(Theme.PopupStroke) })

	local dragHandle = button({ Size = UDim2.fromScale(1, 1), Parent = inner })
	connect(dragHandle.InputBegan, function(input)
		if not isDragInput(input) then
			return
		end
		local startPosition = panel.position()
		local startInput = input.Position
		startDrag(function(position)
			local delta = (position - startInput) / UI.overlayScale.Scale
			glide({ panel.plain }, startPosition + UDim2.fromOffset(delta.X, delta.Y))
		end)
	end)
	return panel, inner
end

local function showPanel(panel, anchor, level, onClose)
	local size = panel.plain.Size
	local x, y = popupPosition(anchor, size.X.Offset, size.Y.Offset, true)
	local offset = UDim2.fromOffset(0, 5)

	panel.set("ZIndex", level * 2 + 1)
	pushPopup(level, function()
		if onClose then
			onClose()
		end
		panel.fade(false, 0.18, Enum.EasingStyle.Quad, nil, panel.position() + offset)
	end)
	panel.fade(true, 0.28, Enum.EasingStyle.Quint, UDim2.fromOffset(x, y) + offset, UDim2.fromOffset(x, y))
end

local Builders

local function rowHeight(item)
	return item.height or Layout.HEIGHTS[item.type]
end

local function createPanel(level)
	local function heightFor(contentHeight)
		return contentHeight + 12
	end
local panel, inner = createFloatingPanel(Layout.PANEL_WIDTH, heightFor(0))
	local body = create("Frame", {
		Position = UDim2.fromOffset(0, 5),
		Size = UDim2.new(1, 0, 1, -10),
		BackgroundTransparency = 1,
		Parent = inner,
	}, { list(0) })

	local section = { body = body, rows = {}, level = level + 1 }
	function section.relayout(instant)
		local visibleHeight = 0
		for _, row in ipairs(section.rows) do
			if not row.hidden then
				visibleHeight += row.height
			end
		end
		local size = UDim2.fromOffset(Layout.PANEL_WIDTH * Runtime.density, heightFor(visibleHeight * Runtime.density))
		if instant then
			panel.set("Size", size)
		else
			tween(panel.plain, { Size = size }, 0.2, Enum.EasingStyle.Quint)
		end
	end

	table.insert(Runtime.panelSections, section)
	return panel, section
end

UI.tooltip = createFader({
	Size = UDim2.fromOffset(Layout.TOOLTIP_WIDTH, 40),
	ZIndex = 40,
	Parent = UI.overlay,
}, true)
UI.tooltipFrame = create("Frame", {
	Position = UDim2.fromOffset(1, 1),
	Size = UDim2.new(1, -2, 1, -2),
	BackgroundColor3 = Theme.Window,
}, { corner(3), stroke(Theme.PopupStroke) })
UI.tooltip.setContent(UI.tooltipFrame)
UI.tooltipText = label({
	TextSize = 9,
	TextColor3 = Theme.Text,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	Position = UDim2.fromOffset(6, 5),
	Size = UDim2.new(1, -12, 1, -10),
	Parent = UI.tooltipFrame,
})

hideTooltip = function()
	Runtime.tooltipToken += 1
	if Runtime.tooltipShown then
		Runtime.tooltipShown = false
		UI.tooltip.fade(false, 0.16)
	end
end

local function measureTooltip(text)
	local ok, bounds = pcall(function()
		local params = Instance.new("GetTextBoundsParams")
		params.Text = text
		params.Font = Fonts.Regular
		params.Size = 9
		params.Width = Layout.TOOLTIP_WIDTH - 14
		return TextService:GetTextBoundsAsync(params)
	end)
	if ok then
		return bounds.Y
	end
	return math.ceil(#text * 5 / (Layout.TOOLTIP_WIDTH - 14)) * 11
end

local function scheduleTooltip(text)
	Runtime.tooltipToken += 1
	local token = Runtime.tooltipToken
	task.delay(0.35, function()
		if token ~= Runtime.tooltipToken then
			return
		end
		local height = measureTooltip(text) + 12
		if token ~= Runtime.tooltipToken then
			return
		end
		local mouse = UserInputService:GetMouseLocation()
		local position = (mouse - UI.overlay.AbsolutePosition) / UI.overlayScale.Scale
		local target = UDim2.fromOffset(position.X + 12, position.Y + 12)
		UI.tooltipText.Text = text
		UI.tooltip.set("Size", UDim2.fromOffset(Layout.TOOLTIP_WIDTH, height))
		Runtime.tooltipShown = true
		UI.tooltip.fade(true, 0.24, Enum.EasingStyle.Quint, target + UDim2.fromOffset(0, 5), target)
	end)
end

local function buildColorPicker()
	local panel, inner = createFloatingPanel(124, 157)
	local innerScale = create("UIScale", { Parent = inner })
	local titleLabel = label({
		Font = Fonts.Medium,
		TextSize = 10,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(8, 5),
		Size = UDim2.new(1, -16, 0, 13),
		ZIndex = 2,
		Parent = inner,
	})
	local widget = createPickerWidget(inner, 14, 122, 80)

	return function(anchor, level, value, onChange, title, onClose)

		local density = Runtime.density
		panel.set("Size", UDim2.fromOffset(124 * density, 157 * density))
		inner.Size = UDim2.new(1 / density, -2 / density, 1 / density, -2 / density)
		innerScale.Scale = density

		titleLabel.Text = title or "color"
		widget.open(value, onChange)
		showPanel(panel, anchor, level, function()
			widget.release()
			if onClose then
				onClose()
			end
		end)
	end
end

local function openColorPicker(anchor, level, value, onChange, title, onClose)
	Runtime.openPicker = Runtime.openPicker or buildColorPicker()
	Runtime.openPicker(anchor, level, value, onChange, title, onClose)
end

local Hotkeys = {
	MODES = { "hold", "toggle", "always" },
	entries = {},
	refresh = function() end,
}

local function keyLabel(name)
	local short = { MouseButton1 = "m1", MouseButton2 = "m2", MouseButton3 = "m3", None = "none" }
	return short[name] or string.lower(name)
end

local function createRow(section, item, order, onHover)
	local height = rowHeight(item)
	local density = Runtime.density

	local outer = create("Frame", {
		Name = item.name,
		Size = UDim2.new(1, 0, 0, height * density),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = section.body,
	})
	local row = create("Frame", {
		Size = UDim2.fromScale(1 / density, 1 / density),
		BackgroundTransparency = 1,
	})
	local rowEntry = {
		frame = outer,
		body = row,
		scale = create("UIScale", { Scale = density, Parent = row }),
		name = string.lower(item.name),
		height = height,
	}
	if item.depends then
		rowEntry.fader = createFader({
			Size = UDim2.new(1, 0, 0, height * density),
			Parent = outer,
		})
		rowEntry.fader.setContent(row)
	else
		row.Parent = outer
	end
	table.insert(section.rows, rowEntry)
	table.insert(Runtime.rows, rowEntry)

	local highlight = create("Frame", {
		Position = UDim2.fromOffset(3, 0),
		Size = UDim2.new(1, -6, 1, 0),
		BackgroundColor3 = Theme.RowHover,
		BackgroundTransparency = 1,
		Parent = row,
	}, { corner(3) })

	local inside = {}
	local hovered = false
	local function update()
		local now = next(inside) ~= nil
		if now == hovered then
			return
		end
		hovered = now
		tween(highlight, { BackgroundTransparency = now and 0.5 or 1 }, 0.12)
		if item.tooltip then
			if now then
				scheduleTooltip(item.tooltip)
			else
				hideTooltip()
			end
		end
		if onHover then
			onHover(now)
		end
	end
	local function track(object)
		connect(object.MouseEnter, function()
			inside[object] = true
			update()
		end)
		connect(object.MouseLeave, function()
			inside[object] = nil
			update()
		end)
	end
	track(row)

	if item.depends then
		local depends = type(item.depends) == "table" and item.depends or { item.depends }
		local key = (item.dependsPrefix or "") .. depends[1]
		outer.ClipsDescendants = true
		watch(key, function(value, instant)
			local shown
			if depends[2] == nil then
				shown = value == true
			elseif type(depends[2]) == "table" then
				shown = table.find(depends[2], value) ~= nil
			else
				shown = value == depends[2]
			end
			if rowEntry.hidden == not shown then
				return
			end
			rowEntry.hidden = not shown
			rowEntry.token = (rowEntry.token or 0) + 1
			local token = rowEntry.token

			local goal = { Size = UDim2.new(1, 0, 0, shown and height * Runtime.density or 0) }
			if shown then
				outer.Visible = not rowEntry.searchHidden
			end
			if instant then
				outer.Size = goal.Size
				outer.Visible = shown and not rowEntry.searchHidden
				rowEntry.fader.snap(shown)
			else

				rowEntry.fader.fade(shown, shown and 0.3 or 0.16, Enum.EasingStyle.Quint)
				tween(outer, goal, 0.26, Enum.EasingStyle.Quint).Completed:Once(function()
					if token == rowEntry.token and rowEntry.hidden then
						outer.Visible = false
					end
				end)
			end
			if section.relayout then
				section.relayout(instant)
			end
		end)
	end

	return row, track
end

local function iconButton(row, inset, iconName, color)
	local holder = button({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -inset, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		Parent = row,
	})
	return holder, createIcon(holder, iconName, 10, color, UDim2.fromScale(0.5, 0.5))
end

local function CreateSwatch(row, section, colorItem, inset)
	local swatch = button({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -inset, 0.5, 0),
		Size = UDim2.fromOffset(11, 11),
		BackgroundTransparency = 0,
		Parent = row,
	}, { corner(2) })
	local swatchStroke = stroke(Theme.SwatchStroke, 1, swatch)
	local opened = false

	local function paintStroke(active)
		tween(swatchStroke, { Color = active and Theme.Accent or Theme.SwatchStroke }, 0.12)
	end
	connect(swatch.MouseEnter, function()
		paintStroke(true)
	end)
	connect(swatch.MouseLeave, function()
		paintStroke(opened)
	end)

	local current
	local commit = bind(colorItem, function(value)
		local color, alpha = parseColor(value)
		if not color then
			value = colorItem.default
			color, alpha = parseColor(value)
		end
		current = value
		swatch.BackgroundColor3 = color
		swatch.BackgroundTransparency = (1 - alpha) * 0.75
		return current
	end)
	connect(swatch.MouseButton1Click, function()
		opened = true
		paintStroke(true)
		openColorPicker(swatch, section.level, current, commit, colorItem.title and colorItem.title(), function()
			opened = false
			paintStroke(false)
		end)
	end)
	return commit
end

local function CreateGear(row, section, inset)
	local gear, icon = iconButton(row, inset, "gear", Theme.TextOff)
	local panel, panelSection = createPanel(section.level)
	connect(gear.MouseEnter, function()
		tintIcon(icon, Theme.Accent)
	end)
	connect(gear.MouseLeave, function()
		tintIcon(icon, Theme.TextOff)
	end)
	connect(gear.MouseButton1Click, function()
		showPanel(panel, gear, section.level)
	end)
	return panelSection
end

local function openBindPopup(section, entry, commitKey, commitMode)
	local density = Runtime.density
	local itemHeight = math.floor(17 * density + 0.5)
	local anchor = { AbsolutePosition = UserInputService:GetMouseLocation(), AbsoluteSize = Vector2.zero }
	local frame = openFloating(anchor, section.level, 110 * density, itemHeight * 4 + 5 + 8)
	local body = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = frame,
	}, { list(0), padding(3, 3, 3, 3) })

	local function addRow(order)
		local rowButton = button({
			Size = UDim2.new(1, 0, 0, itemHeight),
			BackgroundColor3 = Theme.RowHover,
			LayoutOrder = order,
			Parent = body,
		}, { corner(3) })
		local text = label({
			TextSize = 10 * density,
			TextColor3 = Theme.TextOff,
			Position = UDim2.fromOffset(6, 0),
			Size = UDim2.new(1, -10, 1, 0),
			Parent = rowButton,
		})
		rowButton.MouseEnter:Connect(function()
			tween(rowButton, { BackgroundTransparency = 0 }, 0.1)
		end)
		rowButton.MouseLeave:Connect(function()
			tween(rowButton, { BackgroundTransparency = 1 }, 0.1)
		end)
		return rowButton, text
	end

	local keyButton, keyText = addRow(1)
	local function paintKey(listening)
		local name = entry.key == "None" and "None" or keyLabel(entry.key)
		keyText.Text = "key: " .. (listening and "..." or name)
	end
	paintKey(false)

	create("Frame", {
		Size = UDim2.new(1, 0, 0, 5),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = body,
	}, {
		create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 4, 0.5, 0),
			Size = UDim2.new(1, -8, 0, 1),
			BackgroundColor3 = Theme.PopupStroke,
		}),
	})

	local modeTexts = {}
	local function paintModes()
		for mode, text in pairs(modeTexts) do
			text.TextColor3 = mode == entry.mode and Theme.Accent or Theme.TextOff
		end
	end
	for index, mode in ipairs(Hotkeys.MODES) do
		local modeButton, text = addRow(2 + index)
		text.Text = mode
		modeTexts[mode] = text
		modeButton.MouseButton1Click:Connect(function()
			commitMode(mode)
			paintModes()
		end)
	end
	paintModes()

	keyButton.MouseButton1Click:Connect(function()
		cancelListening()
		paintKey(true)
		Runtime.listeningBind = function(input)
			local name
			if input == nil then
				name = entry.key
			elseif input.UserInputType == Enum.UserInputType.Keyboard then
				name = input.KeyCode == Enum.KeyCode.Escape and "None" or input.KeyCode.Name
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
				name = input.UserInputType.Name
			else
				return
			end
			Runtime.listeningBind = nil
			commitKey(name)
			paintKey(false)
		end
	end)

	local popup = popupStack[section.level]
	local close = popup.close
	popup.close = function()
		cancelListening()
		close()
	end
end

local function CreateBindIcon(row, section, item, inset, setter)
	local icon = createIcon(row, "legit", 10, Theme.TextOff, UDim2.new(1, -inset, 0.5, 0))
	local entry = { label = item.name, key = "None", mode = "toggle", active = false, setter = setter }
	table.insert(Hotkeys.entries, entry)

	local function paint()
		tintIcon(icon, entry.key ~= "None" and Theme.Accent or Theme.TextOff)
	end
	table.insert(accentRefreshers, paint)

	local commitKey = bind({ key = item.key, default = item.default or "None" }, function(value)
		entry.key = type(value) == "string" and value or "None"
		paint()
		Hotkeys.refresh()
		return entry.key
	end)
	local commitMode = bind({ key = item.key .. ":mode", default = item.mode or "toggle" }, function(value)
		entry.mode = table.find(Hotkeys.MODES, value) and value or "toggle"
		Hotkeys.refresh()
		return entry.mode
	end)

	function entry.open()
		openBindPopup(section, entry, commitKey, commitMode)
	end
	return entry
end

local function CreateCheck(section, item, order)
	local boxStroke
	local enabled = false
	local row, track = createRow(section, item, order, function(hovered)
		tween(boxStroke, { Transparency = hovered and 0 or 1 }, 0.12)
	end)

	local box = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(11, 11),
		BackgroundColor3 = Theme.CheckOff,
		Parent = row,
	}, { corner(2) })
	boxStroke = accented(stroke(Theme.Accent, 1, box), "Color")
	boxStroke.Transparency = 1
	local text = label({
		Text = item.name,
		TextColor3 = Theme.TextOff,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(25, 0),
		Size = UDim2.new(1, -30, 1, 0),
		Parent = row,
	})

	local control = { row = row, section = section }
	local function apply(value, instant)
		enabled = value == true
		local duration = instant and 0 or 0.14
		tween(box, { BackgroundColor3 = enabled and Theme.Accent or Theme.CheckOff }, duration)
		tween(text, { TextColor3 = enabled and Theme.Text or Theme.TextOff }, duration)
		if control.bindEntry then
			control.bindEntry.active = enabled
			Hotkeys.refresh()
		end
		return enabled
	end
	local commit = bind(item, apply)
	control.commit = commit
	table.insert(accentRefreshers, function()
		apply(enabled, true)
	end)

	local hit = button({ Size = UDim2.fromScale(1, 1), Parent = row })
	track(hit)
	connect(hit.MouseButton1Click, function()
		commit(not enabled)
	end)
	connect(hit.MouseButton2Click, function()
		if control.bindEntry then
			control.bindEntry.open()
		end
	end)

	return control
end

local function CreateColorRow(section, item, order)
	local row = createRow(section, item, order)
	local text = label({
		Text = item.name,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -40, 1, 0),
		Parent = row,
	})
	return { row = row, section = section, text = text }
end

local function CreateParagraph(section, item, order)
	local row = createRow(section, item, order)
	label({
		Text = item.name,
		Font = Fonts.Medium,
		Position = UDim2.fromOffset(8, 2),
		Size = UDim2.new(1, -16, 0, 13),
		Parent = row,
	})
	local text = label({
		Text = item.text,
		TextSize = 9,
		TextColor3 = Theme.TextOff,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(8, 15),
		Size = UDim2.new(1, -16, 1, -16),
		Parent = row,
	})
	return { row = row, section = section, text = text }
end

local function CreateInput(section, item, order)
	local row, track = createRow(section, item, order)
	label({
		Text = item.name,
		Position = UDim2.fromOffset(8, 1),
		Size = UDim2.new(1, -16, 0, 13),
		Parent = row,
	})
	local box = textBox({
		Position = UDim2.fromOffset(8, 15),
		Size = UDim2.new(1, -16, 0, 16),
		BackgroundColor3 = Theme.Field,
		ClipsDescendants = true,
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Left,
		PlaceholderText = item.placeholder or "",
		Parent = row,
	}, { corner(3), padding(0, 6, 0, 6) })
	track(box)
	local boxStroke = accented(stroke(Theme.Accent, 1, box), "Color")
	boxStroke.Transparency = 1

	local function clean(value)
		local text = tostring(value or "")
		if item.numeric then
			text = string.match(text, "^%-?%d*%.?%d*") or ""
		end
		if item.maxLength then
			text = string.sub(text, 1, item.maxLength)
		end
		return text
	end

	local commit = bind(item, function(value)
		local text = clean(value)
		if box.Text ~= text then
			box.Text = text
		end
		return text
	end)

	connect(box.Focused, function()
		tween(boxStroke, { Transparency = 0 })
	end)
	connect(box.FocusLost, function()
		tween(boxStroke, { Transparency = 1 })
		commit(box.Text)
	end)
	if not item.finished then
		connect(box:GetPropertyChangedSignal("Text"), function()
			commit(box.Text)
		end)
	end
	return { row = row, section = section, commit = commit }
end

local function CreateSlider(section, item, order)
	local row, track = createRow(section, item, order)
	local min, max, decimals = item.min, item.max, item.decimals or 0
	local factor = 10 ^ decimals
	local suffix = item.suffix or ""

	label({
		Text = item.name,
		Position = UDim2.fromOffset(8, 1),
		Size = UDim2.new(1, -16, 0, 13),
		Parent = row,
	})
	local bar = create("Frame", {
		Position = UDim2.fromOffset(8, 15),
		Size = UDim2.new(1, -16, 0, 12),
		BackgroundColor3 = Theme.Field,
		Parent = row,
	}, { corner(3) })
	local fill = accented(create("Frame", {
		Size = UDim2.fromScale(0, 1),
		Parent = bar,
	}, {
		corner(3),
		create("UIGradient", { Transparency = NumberSequence.new(0.75, 0.3) }),
	}), "BackgroundColor3")
	local handle = accented(create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 3, 1, 0),
		Parent = bar,
	}), "BackgroundColor3")
	local valueBox = textBox({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		TextSize = 9,
		ZIndex = 2,
		Parent = bar,
	})
	local hit = button({ Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = bar })
	track(hit)

	local current = min
	local function apply(value, instant)
		value = math.clamp(tonumber(value) or current, min, max)
		current = math.floor(value * factor + 0.5) / factor
		local alpha = (current - min) / (max - min)
		local duration = instant and 0 or 0.08
		tween(fill, { Size = UDim2.fromScale(alpha, 1) }, duration)
		tween(handle, { Position = UDim2.fromScale(alpha, 0.5) }, duration)
		valueBox.Text = (decimals > 0 and string.format("%." .. decimals .. "f", current) or tostring(current)) .. suffix
		return current
	end
	local commit = bind(item, apply)

	local function updateFromPosition(position)
		local alpha = math.clamp((position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		commit(min + (max - min) * alpha)
	end

	connect(hit.InputBegan, function(input)
		if isDragInput(input) then
			updateFromPosition(input.Position)
			startDrag(updateFromPosition)
		end
	end)
	connect(hit.MouseButton2Click, function()
		hit.Visible = false
		valueBox:CaptureFocus()
	end)
	connect(valueBox.FocusLost, function()
		hit.Visible = true
		commit(tonumber(string.match(valueBox.Text, "%-?[%d%.]+") or "") or current)
	end)
	return { row = row, section = section, commit = commit }
end

local function CreateDropdown(section, item, order)
	local row, track = createRow(section, item, order)
	label({
		Text = item.name,
		Position = UDim2.fromOffset(8, 1),
		Size = UDim2.new(1, -16, 0, 13),
		Parent = row,
	})
	local box = button({
		Position = UDim2.fromOffset(8, 15),
		Size = UDim2.new(1, -16, 0, 16),
		BackgroundColor3 = Theme.Field,
		BackgroundTransparency = 0,
		Parent = row,
	}, { corner(3) })
	track(box)
	local boxStroke = accented(stroke(Theme.Accent, 1, box), "Color")
	boxStroke.Transparency = 1
	local text = label({
		TextSize = 9,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(1, -24, 1, 0),
		Parent = box,
	})
	local arrow = triangle(box, Theme.TextOff, 7)

	local value
	local commit = bind(item, function(newValue, instant)
		if not instant then
			text.TextTransparency = 1
			tween(text, { TextTransparency = 0 }, 0.22)
		end
		if item.multi then
			local selected = {}
			if type(newValue) == "table" then
				for _, option in ipairs(item.options) do
					if table.find(newValue, option) then
						table.insert(selected, option)
					end
				end
			end
			value = selected
			text.Text = #selected > 0 and table.concat(selected, ", ") or "none"
		else
			value = table.find(item.options, newValue) and newValue or item.options[1]
			text.Text = value or "none"
		end
		return value
	end)

	local listSettings = { search = item.multi or #item.options >= 5 }
	if item.optionColors then
		local function colorItem(option)
			return { key = item.key .. ":option:" .. option, default = item.optionColors[option] or "FFFFFF" }
		end
		function listSettings.colorOf(option)
			return readValue(colorItem(option))
		end
		function listSettings.onColor(option, value)
			Store.Values[colorItem(option).key] = value
		end
	end

	connect(box.MouseEnter, function()
		tween(box, { BackgroundColor3 = Theme.FieldHover })
	end)
	connect(box.MouseLeave, function()
		tween(box, { BackgroundColor3 = Theme.Field })
	end)
	connect(box.MouseButton1Click, function()
		openList(box, section.level, box.AbsoluteSize.X / UI.overlayScale.Scale, item.options, function(option)
			if item.multi then
				return table.find(value, option) ~= nil
			end
			return option == value
		end, function(option)
			if item.multi then
				local nextValue = table.clone(value)
				local index = table.find(nextValue, option)
				if index then
					table.remove(nextValue, index)
				else
					table.insert(nextValue, option)
				end
				commit(nextValue)
			else
				commit(option)
				closePopups(section.level)
			end
		end, listSettings)

		tween(boxStroke, { Transparency = 0 })
		tween(arrow, { Position = UDim2.fromOffset(4.5, 5), BackgroundColor3 = Theme.Accent }, 0.18)
		local entry = popupStack[section.level]
		local close = entry.close
		entry.close = function()
			tween(boxStroke, { Transparency = 1 })
			tween(arrow, { Position = UDim2.fromOffset(4.5, 0), BackgroundColor3 = Theme.TextOff }, 0.18)
			close()
		end
	end)
	return { row = row, section = section, commit = commit }
end

local function CreateKeybind(section, item, order)
	local row = createRow(section, item, order)
	label({
		Text = item.name,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -80, 1, 0),
		Parent = row,
	})
	local box = button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(64, 14),
		BackgroundColor3 = Theme.Field,
		BackgroundTransparency = 0,
		Font = Fonts.Regular,
		TextSize = 9,
		TextColor3 = Theme.Text,
		Parent = row,
	}, { corner(3) })

	local current = "None"
	local commit = bind(item, function(value)
		current = type(value) == "string" and value or "None"
		box.Text = keyLabel(current)
		return current
	end)
	connect(box.MouseButton1Click, function()
		cancelListening()
		box.Text = "..."
		Runtime.listeningBind = function(input)
			local name
			if input == nil then
				name = current
			elseif input.UserInputType == Enum.UserInputType.Keyboard then
				name = input.KeyCode == Enum.KeyCode.Escape and "None" or input.KeyCode.Name
			else
				return
			end
			Runtime.listeningBind = nil
			commit(name)
		end
	end)
	return { row = row, section = section, commit = commit }
end

local function CreateButton(section, item, order)
	local row = createRow(section, item, order)
	local action = button({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -16, 0, 16),
		BackgroundColor3 = Theme.Field,
		BackgroundTransparency = 0,
		Font = Fonts.Regular,
		TextSize = 10,
		TextColor3 = Theme.Text,
		Text = item.name,
		Parent = row,
	}, { corner(3) })
	connect(action.MouseEnter, function()
		tween(action, { BackgroundColor3 = Theme.FieldHover })
	end)
	connect(action.MouseLeave, function()
		tween(action, { BackgroundColor3 = Theme.Field })
	end)
	connect(action.MouseButton1Down, function()
		tween(action, { BackgroundColor3 = Theme.Accent }, 0.08)
	end)
	connect(action.MouseButton1Up, function()
		tween(action, { BackgroundColor3 = Theme.FieldHover }, 0.2)
	end)
	connect(action.MouseButton1Click, item.callback)
	return { row = row, section = section }
end

Builders = {
	check = CreateCheck,
	color = CreateColorRow,
	paragraph = CreateParagraph,
	input = CreateInput,
	slider = CreateSlider,
	dropdown = CreateDropdown,
	keybind = CreateKeybind,
	button = CreateButton,
}

local function CreateSection(column, page, title, order)
	local container = create("Frame", {
		Name = title,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = column,
	})
	local card = create("Frame", {
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Card,
		BackgroundTransparency = 0.25,
		Parent = container,
	}, { corner(3), stroke(Theme.CardStroke), list(0), padding(8, 0, 3, 0) })

	local header = create("Frame", {
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = container,
	})
	accented(create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = header,
	}, {
		create("UIGradient", { Transparency = NumberSequence.new(0, 0.5) }),
	}), "BackgroundColor3")
	if title ~= "" then
		label({
			Text = title,
			Font = Fonts.Medium,
			TextSize = 10,
			BackgroundColor3 = Theme.Window,
			BackgroundTransparency = 0,
			Position = UDim2.fromOffset(5, 0),
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			Parent = header,
		}, { padding(0, 3, 0, 3) })
	end

	local section = { title = string.lower(title), container = container, body = card, rows = {}, level = 1 }
	table.insert(page.sections, section)
	return section
end

local setMenuOpen

UI.headerDrag = button({
	Size = UDim2.new(1, 0, 0, Layout.HEADER),
	Parent = UI.root,
})

UI.titleHolder = create("Frame", {
	Position = UDim2.fromOffset(10, 6),
	Size = UDim2.fromOffset(240, 24),
	BackgroundTransparency = 1,
	Parent = UI.root,
})

UI.titleLetters = {}

local function titleLayer(character, parent)
	local group = create("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(Layout.TITLE_SIZE + 10, 30),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local text = label({
		Text = character,
		Font = Fonts.Medium,
		TextSize = Layout.TITLE_SIZE,
		TextColor3 = Theme.White,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = group,
	})
	return group, text
end

function UI.buildTitle(title)
	for index = 1, #title do
		local character = string.sub(title, index, index)
		local halo, haloText = titleLayer(character, UI.titleHolder)
		local letter = titleLayer(character, UI.titleHolder)
		halo.GroupTransparency = 1
		accented(haloText, "TextColor3")
		accented(create("UIStroke", { Thickness = 2.5, Transparency = 0.25, Parent = haloText }), "Color")
		table.insert(UI.titleLetters, {
			letter = letter,
			halo = halo,
			character = character,
			x = (index - 0.5) * Layout.TITLE_SIZE * 0.56,
		})
	end

	task.spawn(function()
		local x = 0
		local widths = {}
		for index, letter in ipairs(UI.titleLetters) do
			local ok, bounds = pcall(function()
				local params = Instance.new("GetTextBoundsParams")
				params.Text = letter.character
				params.Font = Fonts.Medium
				params.Size = Layout.TITLE_SIZE
				params.Width = 100
				return TextService:GetTextBoundsAsync(params)
			end)
			if not ok then
				return
			end
			widths[index] = bounds.X
		end
		for index, letter in ipairs(UI.titleLetters) do
			letter.x = x + widths[index] / 2
			x += widths[index]
		end
	end)
end

UI.searchBox = create("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -9, 0, 9),
	Size = UDim2.fromOffset(104, 17),
	BackgroundColor3 = Theme.Field,
	BackgroundTransparency = 0.25,
	Parent = UI.root,
}, { corner(3), stroke(Theme.CardStroke) })
createIcon(UI.searchBox, "search", 10, Theme.TextMuted, UDim2.new(0, 10, 0.5, 0))
UI.searchInput = textBox({
	Position = UDim2.fromOffset(19, 0),
	Size = UDim2.new(1, -23, 1, 0),
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
	PlaceholderText = "search",
	Parent = UI.searchBox,
})

do
	local keypoints = {}
	local colors = {
		Color3.fromRGB(255, 45, 140),
		Color3.fromRGB(150, 60, 230),
		Color3.fromRGB(60, 110, 255),
		Color3.fromRGB(40, 210, 220),
		Color3.fromRGB(70, 225, 110),
		Color3.fromRGB(240, 225, 70),
		Color3.fromRGB(255, 130, 50),
		Color3.fromRGB(255, 45, 90),
	}
	for index, color in ipairs(colors) do
		table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color))
	end
	create("Frame", {
		Position = UDim2.fromOffset(0, Layout.HEADER),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = Theme.White,
		Parent = UI.root,
	}, { create("UIGradient", { Color = ColorSequence.new(keypoints) }) })
end

UI.tabScroll = create("ScrollingFrame", {
	Position = UDim2.fromOffset(6, Layout.HEADER + 3),
	Size = UDim2.new(1, -12, 0, Layout.TABS_HEIGHT),
	BackgroundTransparency = 1,
	ScrollBarThickness = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	ScrollingDirection = Enum.ScrollingDirection.X,
	Parent = UI.root,
}, { list(1, Enum.FillDirection.Horizontal) })

UI.bottomBar = create("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, Layout.BOTTOM),
	BackgroundTransparency = 1,
	Parent = UI.root,
}, {
	create("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.CardStroke }),
})

UI.bottomDrag = button({ Size = UDim2.fromScale(1, 1), Parent = UI.bottomBar })

UI.userBlock = create("Frame", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -20, 0.5, 0),
	Size = UDim2.fromOffset(0, 16),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	Parent = UI.bottomBar,
}, { list(4, Enum.FillDirection.Horizontal, Enum.VerticalAlignment.Center) })
UI.userScale = create("UIScale", { Parent = UI.userBlock })

UI.avatar = create("ImageLabel", {
	Size = UDim2.fromOffset(13, 13),
	BackgroundColor3 = Theme.Black,
	LayoutOrder = 1,
	Parent = UI.userBlock,
}, { round() })
label({
	Text = string.lower(player.Name),
	TextSize = 9,
	Size = UDim2.fromScale(0, 1),
	AutomaticSize = Enum.AutomaticSize.X,
	LayoutOrder = 2,
	Parent = UI.userBlock,
})
label({
	Text = "·",
	TextSize = 9,
	TextColor3 = Theme.TextMuted,
	Size = UDim2.fromScale(0, 1),
	AutomaticSize = Enum.AutomaticSize.X,
	LayoutOrder = 3,
	Parent = UI.userBlock,
})
UI.subscriptionLabel = accented(label({
	Text = Config.SUBSCRIPTION_TEXT,
	TextSize = 9,
	Size = UDim2.fromScale(0, 1),
	AutomaticSize = Enum.AutomaticSize.X,
	LayoutOrder = 4,
	Parent = UI.userBlock,
}), "TextColor3")
UI.userSettings = button({
	Size = UDim2.fromOffset(12, 14),
	LayoutOrder = 5,
	Parent = UI.userBlock,
})
createIcon(UI.userSettings, "star", 9, Theme.TextOff, UDim2.fromScale(0.5, 0.5))

task.spawn(function()
	local ok, image = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
	if ok and UI.avatar.Parent then
		UI.avatar.Image = image
	end
end)

UI.pagesHolder = create("Frame", {
	Name = "Pages",
	Position = UDim2.fromOffset(0, Layout.HEADER + 3 + Layout.TABS_HEIGHT + 3),
	Size = UDim2.new(1, 0, 1, -(Layout.HEADER + 3 + Layout.TABS_HEIGHT + 3 + Layout.BOTTOM)),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	Parent = UI.root,
})

local function createColumn(page, xScale, xOffset)
	local column = create("ScrollingFrame", {
		Position = UDim2.new(xScale, xOffset, 0, 0),
		Size = UDim2.new(0.5, -(Layout.COLUMN_GAP + 4), 1, 0),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 2,
		ScrollBarImageTransparency = 0.4,
		Parent = page.frame,
	}, { list(5), padding(1, 3, 6, 1) })
	accented(column, "ScrollBarImageColor3")
	connect(column:GetPropertyChangedSignal("CanvasPosition"), function()
		closePopups(1)
	end)
	return column
end

local function createPage(name)
	local page = { name = name, sections = {} }
	page.fader = createFader({
		Name = name,
		Size = UDim2.fromScale(1, 1),
		Parent = UI.pagesHolder,
	})
	page.frame = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	})
	page.fader.setContent(page.frame)
	page.columns = { createColumn(page, 0, 7), createColumn(page, 0.5, 3) }
	return page
end

local function applySearch()
	local page = Runtime.currentPage
	if not page then
		return
	end
	local query = string.lower(UI.searchInput.Text)
	for _, section in ipairs(page.sections) do
		local titleMatch = query == "" or string.find(section.title, query, 1, true) ~= nil
		local anyVisible = false
		for _, row in ipairs(section.rows) do
			local matches = titleMatch or string.find(row.name, query, 1, true) ~= nil
			row.searchHidden = not matches
			row.frame.Visible = matches and not row.hidden
			anyVisible = anyVisible or (matches and not row.hidden)
		end
		section.container.Visible = anyVisible
	end
end

connect(UI.searchInput:GetPropertyChangedSignal("Text"), applySearch)

local function paintNavButton(entry, selected, duration)
	tween(entry.text, { TextColor3 = selected and Theme.Accent or Theme.Text }, duration)
	tween(entry.line, { BackgroundTransparency = selected and 0 or 1 }, duration)
	tintIcon(entry.icon, selected and Theme.Accent or Theme.Text, duration)
end

local function createNavButton(parent, name, iconName, order, height, onClick)
	local holder = button({
		Size = UDim2.fromOffset(0, height),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = order,
		Parent = parent,
	})

	local content = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = holder,
	}, {
		padding(0, 6, 0, 6),
		list(4, Enum.FillDirection.Horizontal, Enum.VerticalAlignment.Center),
	})
	local icon = createIcon(content, iconName, 11, Theme.Text)
	icon.LayoutOrder = 1
	local text = label({
		Text = name,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Parent = content,
	})
	local line = accented(create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundTransparency = 1,
		Parent = holder,
	}), "BackgroundColor3")
	table.insert(Runtime.navScales, create("UIScale", { Scale = Runtime.density, Parent = holder }))
	connect(holder.MouseButton1Click, onClick)
	return { holder = holder, icon = icon, text = text, line = line }
end

local function selectSub(tab, sub)
	local page = sub.page
	if page == Runtime.currentPage then
		return
	end
	closePopups(1)
	local previous = Runtime.currentPage
	Runtime.currentPage = page
	tab.currentSub = sub

	if previous then
		previous.fader.fade(false, 0.2, Enum.EasingStyle.Quint, nil, UDim2.fromOffset(0, -8))
	end
	page.fader.fade(true, 0.38, Enum.EasingStyle.Quint, UDim2.fromOffset(0, previous and 12 or 0), UDim2.fromOffset(0, 0))

	for _, other in ipairs(tab.subs) do
		paintNavButton(other.nav, other == sub, 0.2)
	end
	applySearch()
end

local function selectTab(tab)
	if tab == Runtime.currentTab then
		return
	end
	local previous = Runtime.currentTab
	Runtime.currentTab = tab
	if previous then
		previous.subBar.Visible = false
		paintNavButton(previous.nav, false, 0.2)
	end
	tab.subBar.Visible = #tab.subs > 1
	paintNavButton(tab.nav, true, 0.2)
	if tab.currentSub or tab.subs[1] then
		selectSub(tab, tab.currentSub or tab.subs[1])
	end

	local scroll = UI.tabScroll
	local scale = Runtime.baseScale
	local left = (tab.nav.holder.AbsolutePosition.X - scroll.AbsolutePosition.X) / scale + scroll.CanvasPosition.X
	local right = left + tab.nav.holder.AbsoluteSize.X / scale
	local visibleWidth = scroll.AbsoluteSize.X / scale
	local target = scroll.CanvasPosition.X
	if left < target then
		target = left
	elseif right > target + visibleWidth then
		target = right - visibleWidth
	end
	tween(scroll, { CanvasPosition = Vector2.new(target, 0) }, 0.25, Enum.EasingStyle.Quint)

	UI.setPreviewShown(tab.preview == true and Runtime.menuOpen)
end

UI.setPreviewShown = function() end

table.insert(accentRefreshers, function()
	local tab = Runtime.currentTab
	if tab then
		paintNavButton(tab.nav, true, 0)
		for _, sub in ipairs(tab.subs) do
			paintNavButton(sub.nav, sub == tab.currentSub, 0)
		end
	end
end)

connect(UI.userSettings.MouseButton1Click, function()
	if Runtime.settingsTab then
		selectTab(Runtime.settingsTab)
	end
end)

UI.notifications = create("Frame", {
	Position = UDim2.fromOffset(10, 10),
	Size = UDim2.fromOffset(0, 0),
	AutomaticSize = Enum.AutomaticSize.XY,
	BackgroundTransparency = 1,
	Parent = UI.screenGui,
}, { list(4) })
UI.notificationsScale = create("UIScale", { Parent = UI.notifications })

do
	local saved = type(Store.Global.notifyPosition) == "table" and Store.Global.notifyPosition or {}
	Runtime.notifyTarget = UDim2.fromOffset(tonumber(saved.x) or 10, tonumber(saved.y) or 10)
	UI.notifications.Position = Runtime.notifyTarget

	local holder = create("Frame", {
		Size = UDim2.fromOffset(150, 0),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		Parent = UI.notifications,
	})
	local fader = createFader({
		Size = UDim2.fromOffset(150, 18),
		Parent = holder,
	})
	local handle = button({
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = Theme.Window,
		BackgroundTransparency = 0.08,
	}, { corner(3), stroke(Theme.WindowStroke) })
	fader.setContent(handle)
	accented(create("Frame", {
		Size = UDim2.new(0, 2, 1, 0),
		Parent = handle,
	}), "BackgroundColor3")
	label({
		Text = "notifications appear here",
		TextColor3 = Theme.TextOff,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -10, 1, 0),
		Parent = handle,
	})

	connect(handle.InputBegan, function(input)
		if not isDragInput(input) then
			return
		end
		local startPosition = Runtime.notifyTarget
		local startInput = input.Position
		startDrag(function(position)
			local delta = position - startInput
			Runtime.notifyTarget = startPosition + UDim2.fromOffset(delta.X, delta.Y)
			glide({ UI.notifications }, Runtime.notifyTarget)
		end, function()
			Store.Global.notifyPosition = { x = Runtime.notifyTarget.X.Offset, y = Runtime.notifyTarget.Y.Offset }
			saveGlobal()
		end)
	end)

	function UI.setNotifyHandleShown(shown)
		tween(holder, { Size = UDim2.fromOffset(150, shown and 18 or 0) }, 0.26, Enum.EasingStyle.Quint)
		fader.fade(shown, shown and 0.3 or 0.2, Enum.EasingStyle.Quint)
	end
end

function UI.notify(text, duration)
	if not Runtime.notificationsEnabled then
		return
	end
	Runtime.notifyOrder += 1

	local holder = create("Frame", {
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		LayoutOrder = Runtime.notifyOrder,
		Parent = UI.notifications,
	})
	local pill = create("Frame", {
		Position = UDim2.fromOffset(-12, 0),
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Window,
		BackgroundTransparency = 1,
		Parent = holder,
	}, { corner(3), padding(0, 8, 0, 8) })
	local edge = accented(create("Frame", {
		Size = UDim2.new(0, 2, 1, 0),
		Position = UDim2.fromOffset(-8, 0),
		BackgroundTransparency = 1,
		Parent = pill,
	}), "BackgroundColor3")
	local message = label({
		Text = text,
		TextTransparency = 1,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = pill,
	})

	local function fade(visible, seconds)
		tween(pill, {
			BackgroundTransparency = visible and 0.08 or 1,
			Position = UDim2.fromOffset(visible and 0 or -12, 0),
		}, seconds, Enum.EasingStyle.Quint)
		tween(edge, { BackgroundTransparency = visible and 0 or 1 }, seconds)
		tween(message, { TextTransparency = visible and 0 or 1 }, seconds)
	end
	fade(true, 0.32)

	task.delay(duration or 3.5, function()
		if not holder.Parent then
			return
		end
		fade(false, 0.3)
		task.wait(0.3)
		if holder.Parent then
			tween(holder, { Size = UDim2.fromOffset(0, 0) }, 0.18).Completed:Once(function()
				holder:Destroy()
			end)
		end
	end)
end

function Hotkeys.height(count)
	return 30 + math.max(count, 1) * 15
end

do
	local saved = type(Store.Global.hotkeyPosition) == "table" and Store.Global.hotkeyPosition or {}
	Runtime.hotkeyTarget = UDim2.fromOffset(tonumber(saved.x) or 40, tonumber(saved.y) or 300)
	Runtime.hotkeysShown = false

	UI.hotkeyFader = createFader({
		Position = Runtime.hotkeyTarget,
		Size = UDim2.fromOffset(150, Hotkeys.height(0)),
		Parent = UI.screenGui,
	})
	UI.hotkeyScales = { create("UIScale", { Parent = UI.hotkeyFader.plain }) }
	local content = create("Frame", {
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = Theme.Window,
		BackgroundTransparency = 0.05,
	}, { corner(5), stroke(Theme.WindowStroke), list(0) })
	UI.hotkeyFader.setContent(content)

	local header = button({
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 1,
		Parent = content,
	}, {
		padding(0, 8, 0, 8),
		list(5, Enum.FillDirection.Horizontal, Enum.VerticalAlignment.Center),
	})
	local icon = createIcon(header, "hotkeys", 11, Theme.Accent)
	icon.LayoutOrder = 1
	table.insert(accentRefreshers, function()
		tintIcon(icon, Theme.Accent, 0)
	end)
	accented(label({
		Text = "hotkeys",
		TextSize = 11,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Parent = header,
	}), "TextColor3")
	accented(create("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		LayoutOrder = 2,
		Parent = content,
	}), "BackgroundColor3")
	UI.hotkeyRows = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = content,
	}, { list(0), padding(3, 8, 0, 8) })
	UI.hotkeyEmpty = label({
		Text = "no keybinds",
		TextSize = 9,
		TextColor3 = Theme.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Center,
		ClipsDescendants = true,
		Size = UDim2.new(1, 0, 0, 15),
		LayoutOrder = 0,
		Parent = UI.hotkeyRows,
	})

	connect(header.InputBegan, function(input)
		if not isDragInput(input) then
			return
		end
		local startPosition = Runtime.hotkeyTarget
		local startInput = input.Position
		startDrag(function(position)
			local delta = position - startInput
			Runtime.hotkeyTarget = startPosition + UDim2.fromOffset(delta.X, delta.Y)
			glide({ UI.hotkeyFader.plain }, Runtime.hotkeyTarget)
		end, function()
			Store.Global.hotkeyPosition = { x = Runtime.hotkeyTarget.X.Offset, y = Runtime.hotkeyTarget.Y.Offset }
			saveGlobal()
		end)
	end)
end

function Hotkeys.createRow(order)
	local frame = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = order,
		Parent = UI.hotkeyRows,
	})
	local keyText = label({ TextSize = 9, TextTransparency = 1, Size = UDim2.new(0, 22, 0, 15), Parent = frame })
	local nameText = label({
		TextSize = 9,
		TextTransparency = 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(1, -60, 0, 15),
		Parent = frame,
	})
	local modeText = label({
		TextSize = 9,
		TextTransparency = 1,
		TextColor3 = Theme.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, 0, 0, 15),
		Parent = frame,
	})
	return { frame = frame, key = keyText, name = nameText, mode = modeText, shown = false }
end

Hotkeys.refresh = function()
	if not UI.hotkeyRows then
		return
	end
	local count = 0
	for index, entry in ipairs(Hotkeys.entries) do
		local shown = entry.active and entry.key ~= "None"
		if shown then
			count += 1
			entry.row = entry.row or Hotkeys.createRow(index)
		end
		local row = entry.row
		if row then
			row.key.Text = keyLabel(entry.key)
			row.name.Text = entry.label
			row.mode.Text = entry.mode
			if row.shown ~= shown then
				row.shown = shown
				tween(row.frame, { Size = UDim2.new(1, 0, 0, shown and 15 or 0) }, 0.26, Enum.EasingStyle.Quint)
				for _, text in ipairs({ row.key, row.name, row.mode }) do
					tween(text, { TextTransparency = shown and 0 or 1 }, 0.22)
				end
			end
		end
	end

	tween(UI.hotkeyEmpty, {
		Size = UDim2.new(1, 0, 0, count == 0 and 15 or 0),
		TextTransparency = count == 0 and 0 or 1,
	}, 0.22, Enum.EasingStyle.Quint)

	local size = UDim2.fromOffset(150, Hotkeys.height(count))
	tween(UI.hotkeyFader.plain, { Size = size }, 0.26, Enum.EasingStyle.Quint)

	local wanted = Runtime.hotkeyListEnabled and (count > 0 or Runtime.menuOpen)
	if wanted ~= Runtime.hotkeysShown then
		Runtime.hotkeysShown = wanted
		local hidden = Runtime.hotkeyTarget + UDim2.fromOffset(0, 7)
		if wanted then
			UI.hotkeyFader.fade(true, 0.3, Enum.EasingStyle.Quint, hidden, Runtime.hotkeyTarget)
		else
			UI.hotkeyFader.fade(false, 0.22, Enum.EasingStyle.Quad, nil, hidden)
		end
	end
end

function Hotkeys.handle(input, began)
	local name = input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode.Name or input.UserInputType.Name
	for _, entry in ipairs(Hotkeys.entries) do
		if entry.key == name then
			if entry.mode == "toggle" and began then
				entry.setter(not entry.active)
				UI.notify(entry.label .. (entry.active and " enabled" or " disabled"), 2)
			elseif entry.mode == "hold" then
				entry.setter(began)
			elseif entry.mode == "always" then
				entry.setter(true)
			end
		end
	end
end

Hotkeys.refresh()

local Preview = { tab = "enemies", shown = false }

do
	Preview.fader = createFader({
		Name = "EspPreview",
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(Layout.PREVIEW.X, Runtime.windowSize.Y),
		Parent = UI.screenGui,
	})
	Preview.scales = { create("UIScale", { Parent = Preview.fader.plain }) }
	local root = create("Frame", {
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = Color3.fromRGB(14, 14, 16),
		BackgroundTransparency = 0.04,
		Active = true,
	}, { corner(7), stroke(Theme.WindowStroke) })
	Preview.fader.setContent(root)

	accented(label({
		Text = "esp preview",
		TextSize = 9,
		Position = UDim2.fromOffset(9, 5),
		Size = UDim2.fromOffset(120, 12),
		Parent = root,
	}), "TextColor3")
	accented(create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6),
		Size = UDim2.fromOffset(7, 7),
		Parent = root,
	}), "BackgroundColor3")

	Preview.name = label({
		Text = string.lower(player.DisplayName),
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(22, 56),
		Size = UDim2.fromOffset(130, 12),
		Parent = root,
	})
	Preview.box = create("Frame", {
		Position = UDim2.fromOffset(22, 70),
		Size = UDim2.fromOffset(130, 232),
		BackgroundTransparency = 1,
		Parent = root,
	})
	Preview.boxStroke = stroke(Theme.Accent, 1, Preview.box)

	Preview.health = create("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromOffset(18, 302),
		Size = UDim2.fromOffset(2, 186),
		BackgroundColor3 = Color3.fromRGB(240, 205, 70),
		Parent = root,
	})

	local viewport = create("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Theme.White,
		LightColor = Theme.White,
		Parent = Preview.box,
	})
	Preview.camera = create("Camera", { FieldOfView = 30, Parent = viewport })
	viewport.CurrentCamera = Preview.camera
	Preview.bodyParts = {}

	local function part(size, position, color)
		local piece = Instance.new("Part")
		piece.Anchored = true
		piece.Size = size
		piece.CFrame = CFrame.new(position)
		piece.Material = Enum.Material.SmoothPlastic
		piece.Color = color or Theme.White
		piece.Parent = viewport
		return piece
	end
	for _, body in ipairs({
		{ Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 2.6, 0) },
		{ Vector3.new(2, 2, 1), Vector3.new(0, 1, 0) },
		{ Vector3.new(1, 2, 1), Vector3.new(-1.5, 1, 0) },
		{ Vector3.new(1, 2, 1), Vector3.new(1.5, 1, 0) },
		{ Vector3.new(1, 2, 1), Vector3.new(-0.5, -1, 0) },
		{ Vector3.new(1, 2, 1), Vector3.new(0.5, -1, 0) },
	}) do
		table.insert(Preview.bodyParts, part(body[1], body[2]))
	end
	part(Vector3.new(0.22, 0.24, 0.05), Vector3.new(-0.26, 2.72, 0.62), Theme.Accent)
	part(Vector3.new(0.22, 0.24, 0.05), Vector3.new(0.26, 2.72, 0.62), Theme.Accent)

	Preview.skeleton = {}
	for _, bone in ipairs({
		{ Vector3.new(0.09, 4.2, 0.09), Vector3.new(0, 1, 0) },
		{ Vector3.new(3.1, 0.09, 0.09), Vector3.new(0, 1.8, 0) },
		{ Vector3.new(0.09, 1.9, 0.09), Vector3.new(-1.5, 0.9, 0) },
		{ Vector3.new(0.09, 1.9, 0.09), Vector3.new(1.5, 0.9, 0) },
		{ Vector3.new(1.1, 0.09, 0.09), Vector3.new(0, 0, 0) },
		{ Vector3.new(0.09, 2, 0.09), Vector3.new(-0.5, -1, 0) },
		{ Vector3.new(0.09, 2, 0.09), Vector3.new(0.5, -1, 0) },
	}) do
		table.insert(Preview.skeleton, part(bone[1], bone[2]))
	end

	Preview.flags = create("Frame", {
		Position = UDim2.fromOffset(157, 70),
		Size = UDim2.fromOffset(74, 232),
		BackgroundTransparency = 1,
		Parent = root,
	}, { list(1) })
	Preview.flagIcons = {}
	for index, flag in ipairs({
		{ "SHOOT", "crosshair" },
		{ "RELOAD", "rotate-cw" },
		{ "", "circle-x" },
		{ "BURNING", "flame" },
		{ "SMOKED", "cloud" },
		{ "AIR", "wind" },
		{ "CROUCH", "arrow-down" },
		{ "WALK", "footprints" },
		{ "SCOPED", "scan" },
		{ "IMMUNE", "shield" },
		{ "LOW HP", "heart" },
		{ "AK", "swords" },
		{ "C4", "bomb" },
		{ "DEFUSE KIT", "wrench" },
		{ "HELMET", "hard-hat" },
		{ "SILENCED", "volume-x" },
		{ "$1000", "dollar-sign" },
		{ "42ms", "wifi" },
		{ "24/90", "backpack" },
	}) do
		local row = create("Frame", {
			Size = UDim2.new(1, 0, 0, 11),
			BackgroundTransparency = 1,
			LayoutOrder = index,
			Parent = Preview.flags,
		})
		table.insert(Preview.flagIcons, createIcon(row, flag[2], 8, Theme.Accent, UDim2.new(0, 4, 0.5, 0)))
		accented(label({
			Text = flag[1],
			Font = Fonts.Bold,
			TextSize = 8,
			Position = UDim2.fromOffset(11, 0),
			Size = UDim2.new(1, -11, 1, 0),
			Parent = row,
		}), "TextColor3")
	end
	table.insert(accentRefreshers, function()
		for _, icon in ipairs(Preview.flagIcons) do
			tintIcon(icon, Theme.Accent, 0)
		end
	end)

	Preview.weaponBar = accented(create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(87, 307),
		Size = UDim2.fromOffset(34, 2),
		Parent = root,
	}), "BackgroundColor3")
	Preview.weapon = label({
		Text = "CT Knife",
		TextSize = 8,
		TextColor3 = Theme.TextOff,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(22, 311),
		Size = UDim2.fromOffset(130, 11),
		Parent = root,
	})

	local tabsBar = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = root,
	}, { list(4, Enum.FillDirection.Horizontal) })

	Preview.tabs = {}
	local function paintChip(chip, selected, duration)
		chip.text.Visible = selected
		tween(chip.frame, {
			BackgroundColor3 = selected and Theme.Accent or Theme.Field,
			BackgroundTransparency = selected and 0.75 or 0,
		}, duration)
		tween(chip.text, { TextColor3 = selected and Theme.Accent or Theme.Text }, duration)
		tintIcon(chip.icon, selected and Theme.Accent or Theme.TextOff, duration)
	end
	for index, tabInfo in ipairs({
		{ "enemy", "enemies", "user" },
		{ "allies", "allies", "users" },
		{ "local", "local", "circle-dot" },
	}) do
		local frame = button({
			Size = UDim2.fromOffset(0, 16),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Theme.Field,
			BackgroundTransparency = 0,
			LayoutOrder = index,
			Parent = tabsBar,
		}, {
			corner(3),
			padding(0, 6, 0, 6),
			list(4, Enum.FillDirection.Horizontal, Enum.VerticalAlignment.Center),
		})
		local icon = createIcon(frame, tabInfo[3], 10, Theme.TextOff)
		icon.LayoutOrder = 1
		local text = label({
			Text = tabInfo[1],
			TextSize = 9,
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = 2,
			Parent = frame,
		})
		local chip = { frame = frame, icon = icon, text = text }
		table.insert(Preview.tabs, chip)
		connect(frame.MouseButton1Click, function()
			Preview.tab = tabInfo[2]
			for _, other in ipairs(Preview.tabs) do
				paintChip(other, other == chip, 0.15)
			end
			Preview.refresh()
		end)
		paintChip(chip, index == 1, 0)
	end
	table.insert(accentRefreshers, function()
		for index, chip in ipairs(Preview.tabs) do
			paintChip(chip, chip.text.Visible, 0)
		end
	end)
end

function Preview.value(field)
	if Preview.tab == "local" then
		return nil
	end
	return Runtime.current[Preview.tab .. "_" .. field]
end

function Preview.refresh()
	local boxColor = parseColor(Preview.value("box_color"))
	local nameColor = parseColor(Preview.value("name_color"))
	local chamsColor = parseColor(Preview.value("chams_color"))

	Preview.boxStroke.Transparency = Preview.value("box") and 0 or 1
	Preview.boxStroke.Color = boxColor or Theme.Accent
	Preview.name.Visible = Preview.value("name") == true
	Preview.name.TextColor3 = nameColor or Theme.Text
	Preview.weapon.Visible = Preview.value("weapon") == true
	Preview.weaponBar.Visible = Preview.weapon.Visible
	Preview.health.Visible = Preview.value("health") == true
	Preview.flags.Visible = Preview.value("flags") == true

	local chams = Preview.value("chams") == true or Preview.tab == "local"
	for _, piece in ipairs(Preview.bodyParts) do
		piece.Color = chams and (chamsColor or Theme.White) or Theme.White
		piece.Transparency = chams and 0 or 0.72
	end

	local skeletonColor = parseColor(Preview.value("skeleton_color"))
	local skeleton = Preview.value("skeleton") == true
	for _, bone in ipairs(Preview.skeleton) do
		bone.Color = skeletonColor or Theme.White
		bone.Transparency = skeleton and 0 or 1
	end
end

function Preview.bind()
	for _, section in ipairs({ "enemies", "allies" }) do
		for _, field in ipairs({
			"box", "box_color", "name", "name_color", "weapon", "health",
			"flags", "chams", "chams_color", "skeleton", "skeleton_color",
		}) do
			watch(section .. "_" .. field, Preview.refresh)
		end
	end
	Preview.refresh()
end

local function previewPosition(windowPosition)
	local offset = (Runtime.windowSize.X / 2 + Layout.PREVIEW_GAP) * Runtime.baseScale
	return windowPosition + UDim2.fromOffset(offset, 0)
end

UI.setPreviewShown = function(shown)
	if shown == Preview.shown then
		return
	end
	Preview.shown = shown
	local target = previewPosition(Runtime.windowTarget)
	if shown then
		Preview.fader.fade(true, 0.38, Enum.EasingStyle.Quint, target + UDim2.fromOffset(-14, 0), target)
	else
		Preview.fader.fade(false, 0.24, nil, nil, target + UDim2.fromOffset(-14, 0))
	end
end

local function setWindowPosition(position)
	Runtime.windowTarget = position
	glide({ UI.windowFader.plain, UI.overlay }, position)
	glide({ Preview.fader.plain }, previewPosition(position))
end

local function beginWindowDrag(input)
	if not isDragInput(input) then
		return
	end
	closePopups(1)
	local startPosition = Runtime.windowTarget
	local startInput = input.Position
	startDrag(function(position)
		local delta = position - startInput
		setWindowPosition(startPosition + UDim2.fromOffset(delta.X, delta.Y))
	end)
end

connect(UI.headerDrag.InputBegan, beginWindowDrag)
connect(UI.bottomDrag.InputBegan, beginWindowDrag)

do
	local grip = button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -2, 1, -2),
		Size = UDim2.fromOffset(16, 16),
		ZIndex = 10,
		Parent = UI.root,
	})
	local lines = {
		shape(grip, 9.5, 9.5, 11, 1.5, Theme.TextMuted, -45),
		shape(grip, 12, 12, 4.5, 1.5, Theme.TextMuted, -45),
	}
	local function paintGrip(color)
		for _, line in ipairs(lines) do
			tween(line, { BackgroundColor3 = color }, 0.12)
		end
	end
	connect(grip.MouseEnter, function()
		paintGrip(Theme.Accent)
	end)
	connect(grip.MouseLeave, function()
		paintGrip(Theme.TextMuted)
	end)

	connect(grip.InputBegan, function(input)
		if not isDragInput(input) then
			return
		end
		closePopups(1)
		local startSize = Runtime.windowSize
		local startPosition = Runtime.windowTarget
		local startInput = input.Position
		startDrag(function(position)
			local delta = (position - startInput) / Runtime.baseScale
			local size = Vector2.new(
				math.clamp(startSize.X + delta.X, Layout.MIN_SIZE.X, Layout.MAX_SIZE.X),
				math.clamp(startSize.Y + delta.Y, Layout.MIN_SIZE.Y, Layout.MAX_SIZE.Y)
			)
			Runtime.windowSize = size

			local grow = (size - startSize) * Runtime.baseScale / 2
			setWindowPosition(startPosition + UDim2.fromOffset(grow.X, grow.Y))
			for _, object in ipairs({ UI.windowFader.plain, UI.overlay }) do
				tween(object, { Size = UDim2.fromOffset(size.X, size.Y) }, 0.09)
			end
			tween(Preview.fader.plain, { Size = UDim2.fromOffset(Layout.PREVIEW.X, size.Y) }, 0.09)
		end, function()
			Store.Global.windowSize = { x = math.floor(Runtime.windowSize.X), y = math.floor(Runtime.windowSize.Y) }
			saveGlobal()
		end)
	end)
end

setMenuOpen = function(open)
	Runtime.menuOpen = open
	closePopups(1)
	cancelListening()
	for _, scale in ipairs(UI.windowScales) do
		tween(scale, { Scale = Runtime.baseScale * (open and 1 or 0.95) }, 0.3, Enum.EasingStyle.Quint)
	end
	UI.windowFader.fade(open, 0.3, Enum.EasingStyle.Quint)
	UI.setNotifyHandleShown(open and Runtime.notificationsEnabled)
	UI.setPreviewShown(open and Runtime.currentTab ~= nil and Runtime.currentTab.preview == true)
	Hotkeys.refresh()
end

connect(UserInputService.InputChanged, function(input)
	if Runtime.activeDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		Runtime.activeDrag(input.Position)
	end
end)

connect(UserInputService.InputEnded, function(input, gameProcessed)
	if not gameProcessed then
		Hotkeys.handle(input, false)
	end
	if Runtime.activeDrag and isDragInput(input) then
		local onEnd = Runtime.activeDragEnd
		Runtime.activeDrag, Runtime.activeDragEnd = nil, nil
		if onEnd then
			onEnd()
		end
	end
end)

connect(UserInputService.InputBegan, function(input, gameProcessed)
	if Runtime.listeningBind then
		Runtime.listeningBind(input)
		return
	end
	if gameProcessed then
		return
	end
	if input.KeyCode == Runtime.menuKey then
		setMenuOpen(not Runtime.menuOpen)
	end
	Hotkeys.handle(input, true)
end)

do
	local saved = type(Store.Global.watermarkPosition) == "table" and Store.Global.watermarkPosition or {}
	Runtime.watermarkTarget = UDim2.new(0.5, tonumber(saved.x) or 0, 0, tonumber(saved.y) or 8)
	UI.watermarkBar = button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = Runtime.watermarkTarget,
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Window,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = UI.screenGui,
	}, {
		corner(4),
		stroke(Theme.WindowStroke),
		padding(0, 9, 0, 9),
		list(9, Enum.FillDirection.Horizontal, Enum.VerticalAlignment.Center),
	})
	UI.watermarkScale = create("UIScale", { Parent = UI.watermarkBar })

	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	local function text(value, color)
		return label({
			Text = value,
			TextSize = 9,
			TextColor3 = color or Theme.TextOff,
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = nextOrder(),
			Parent = UI.watermarkBar,
		})
	end

	local function segment(iconName)
		local holder = create("Frame", {
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			LayoutOrder = nextOrder(),
			Parent = UI.watermarkBar,
		}, { list(3, Enum.FillDirection.Horizontal, Enum.VerticalAlignment.Center) })
		createIcon(holder, iconName, 9, Theme.TextOff).LayoutOrder = 1
		return label({
			TextSize = 9,
			TextColor3 = Theme.TextOff,
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = 2,
			Parent = holder,
		})
	end

	UI.watermarkTitle = accented(text(Config.TITLE), "TextColor3")
	segment("user").Text = string.lower(player.Name)
	UI.watermarkVersion = segment("gamepad-2")
	local playersText = segment("users")
	local sessionText = segment("timer")

	local graph = create("Frame", {
		Size = UDim2.fromOffset(38, 11),
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
		Parent = UI.watermarkBar,
	}, { list(1, Enum.FillDirection.Horizontal, Enum.VerticalAlignment.Bottom) })
	local bars = {}
	for index = 1, 13 do
		bars[index] = accented(create("Frame", {
			Size = UDim2.new(0, 2, 0.3, 0),
			LayoutOrder = index,
			Parent = graph,
		}), "BackgroundColor3")
	end

	local fpsText = segment("activity")
	local pingText = segment("wifi")
	local clockText = segment("clock")

	local started = os.clock()
	local history = {}
	task.spawn(function()
		while UI.watermarkBar.Parent do
			local fps = math.floor(1 / math.max(Runtime.frameTime or 1 / 60, 1e-3) + 0.5)
			table.insert(history, fps)
			if #history > #bars then
				table.remove(history, 1)
			end
			for index, bar in ipairs(bars) do
				local sample = history[index] or 0
				bar.Size = UDim2.new(0, 2, math.clamp(sample / 144, 0.12, 1), 0)
			end

			local elapsed = math.floor(os.clock() - started)
			sessionText.Text = string.format("%dm%02ds", math.floor(elapsed / 60), elapsed % 60)
			playersText.Text = tostring(#Players:GetPlayers())
			fpsText.Text = tostring(fps)
			pingText.Text = string.format("%d ms", math.floor(player:GetNetworkPing() * 1000 + 0.5))
			clockText.Text = os.date("%H:%M")
			task.wait(0.5)
		end
	end)

	connect(UI.watermarkBar.InputBegan, function(input)
		if not isDragInput(input) then
			return
		end
		local startPosition = Runtime.watermarkTarget
		local startInput = input.Position
		startDrag(function(position)
			local delta = position - startInput
			Runtime.watermarkTarget = startPosition + UDim2.fromOffset(delta.X, delta.Y)
			glide({ UI.watermarkBar }, Runtime.watermarkTarget)
		end, function()
			Store.Global.watermarkPosition = { x = Runtime.watermarkTarget.X.Offset, y = Runtime.watermarkTarget.Y.Offset }
			saveGlobal()
		end)
	end)
end

connect(RunService.RenderStepped, function(deltaTime)

	Runtime.frameTime = (Runtime.frameTime or deltaTime) * 0.9 + deltaTime * 0.1
	if not Runtime.menuOpen then
		return
	end
	local clock = os.clock()
	local count = #UI.titleLetters
	local radius = 4.5
	local wave = (clock * 5.5) % (count + radius * 2) - radius
	for index, letter in ipairs(UI.titleLetters) do

		local distance = math.abs(index - wave)
		local glow = distance < radius and 0.5 + 0.5 * math.cos(math.pi * distance / radius) or 0

		local lift = math.sin(clock * 2.2 + index * 0.5) * 1.3 + glow * -1.8

		local tilt = math.sin(clock * 2.2 + index * 0.5 + 1.2) * 1.4 + 0.05
		local position = UDim2.fromOffset(letter.x, 11 + lift)
		letter.letter.Position = position
		letter.letter.Rotation = tilt
		letter.letter.GroupColor3 = Theme.Text:Lerp(Theme.Accent, glow * 0.3)

		letter.halo.Visible = glow > 0.01
		if letter.halo.Visible then
			letter.halo.Position = position
			letter.halo.Rotation = tilt
			letter.halo.GroupTransparency = 1 - glow * 0.8
		end
	end

	if Preview.shown then
		local angle = math.sin(clock * 0.6) * math.rad(40)
		local eye = CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.6, 15)
		Preview.camera.CFrame = CFrame.new(eye.Position, Vector3.new(0, 0.6, 0))
	end
end)

local function applyDensity()
	local density = math.clamp(Layout.MIN_EFFECTIVE_SCALE / Runtime.baseScale, 1, Layout.MAX_DENSITY)
	if density == Runtime.density then
		return
	end
	Runtime.density = density

	for _, row in ipairs(Runtime.rows) do
		row.body.Size = UDim2.fromScale(1 / density, 1 / density)
		row.scale.Scale = density
		if not row.hidden then
			row.frame.Size = UDim2.new(1, 0, 0, row.height * density)
		end
		if row.fader then
			row.fader.set("Size", UDim2.new(1, 0, 0, row.height * density))
		end
	end
	for _, scale in ipairs(Runtime.navScales) do
		scale.Scale = density
	end
	for _, section in ipairs(Runtime.panelSections) do
		section.relayout(true)
	end
	UI.userScale.Scale = density

	local tabsHeight = Layout.TABS_HEIGHT * density
	local bottomHeight = Layout.BOTTOM * density
	local pagesTop = Layout.HEADER + 3 + tabsHeight + 3
	UI.tabScroll.Size = UDim2.new(1, -12, 0, tabsHeight)
	UI.bottomBar.Size = UDim2.new(1, 0, 0, bottomHeight)
	UI.pagesHolder.Position = UDim2.fromOffset(0, pagesTop)
	UI.pagesHolder.Size = UDim2.new(1, 0, 1, -(pagesTop + bottomHeight))
end

local function updateScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize

	Runtime.baseScale = math.clamp(math.min(viewport.X / 1400, viewport.Y / 850), 0.8, 1.5) * (Runtime.scaleMultiplier or 1)
	for _, scale in ipairs(UI.windowScales) do
		scale.Scale = Runtime.baseScale * (Runtime.menuOpen and 1 or 0.95)
	end
	for _, scale in ipairs(Preview.scales) do
		scale.Scale = Runtime.baseScale
	end
	UI.overlayScale.Scale = Runtime.baseScale
	UI.notificationsScale.Scale = Runtime.baseScale
	for _, scale in ipairs(UI.hotkeyScales) do
		scale.Scale = Runtime.baseScale
	end
	UI.watermarkScale.Scale = Runtime.baseScale
	Preview.fader.set("Position", previewPosition(Runtime.windowTarget))
	applyDensity()
	closePopups(1)
end

UI.updateScale = updateScale

local function watchCamera()
	if Runtime.cameraConnection then
		Runtime.cameraConnection:Disconnect()
	end
	local camera = workspace.CurrentCamera
	if camera then
		Runtime.cameraConnection = connect(camera:GetPropertyChangedSignal("ViewportSize"), updateScale)
	end
	updateScale()
end

connect(workspace:GetPropertyChangedSignal("CurrentCamera"), watchCamera)
watchCamera()

connect(UI.screenGui.Destroying, function()
	Runtime.listeningBind = nil
	Runtime.activeDrag, Runtime.activeDragEnd = nil, nil
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
end)

local Library = { Options = {}, Toggles = {} }

local function hexOf(color)
	if typeof(color) == "Color3" then
		return formatColor(color, 1)
	end
	return color or "FFFFFF"
end

local Element = {}

function Element.__index(self, key)
	if key == "Value" then
		local value = Runtime.current[rawget(self, "key")]
		if rawget(self, "isColor") then
			return (parseColor(value))
		end
		return value
	end
	return Element[key]
end

function Element:SetValue(value)
	self.commit(value)
	return self
end

function Element:OnChanged(callback)
	watch(self.key, function(value)
		if rawget(self, "isColor") then
			local color, alpha = parseColor(value)
			callback(color, 1 - (alpha or 1))
		else
			callback(value)
		end
	end)
	return self
end

local function register(control, key)
	control.key = key
	setmetatable(control, Element)
	if key then
		Library.Options[key] = control
	end
	return control
end

local function reserveInset(control, step)
	local inset = rawget(control, "nextInset") or 14
	control.nextInset = inset + step
	return inset
end

function Element:AddKeyPicker(idx, info)
	info = info or {}
	self.bindEntry = CreateBindIcon(self.row, self.section, {
		key = idx,
		name = info.Text or self.item.name,
		default = info.Default,
		mode = info.Mode,
	}, reserveInset(self, 15), self.commit)
	self.bindEntry.active = self.Value == true
	Hotkeys.refresh()
	return self
end

function Element:AddColorPicker(idx, info)
	info = info or {}
	self.swatchCount = (rawget(self, "swatchCount") or 0) + 1
	local position = self.swatchCount
	local commit = CreateSwatch(self.row, self.section, {
		key = idx,
		default = hexOf(info.Default),
		callback = info.Callback and function(value)
			local color, alpha = parseColor(value)
			info.Callback(color, 1 - alpha)
		end,
		title = function()
			if info.Title then
				return info.Title
			end
			local name = self.item.name
			if string.find(name, "color", 1, true) then
				return name
			end

			return string.format("%s color %d", (string.gsub(name, " esp$", "")), self.swatchCount - position + 1)
		end,
	}, reserveInset(self, 14))
	register({
		isColor = true,
		commit = function(value)
			commit(hexOf(value))
		end,
	}, idx)
	return self
end

function Element:SetText(text)
	self.text.Text = text
	return self
end

function Element:SetValues(values)
	self.item.options = values
	self.commit(self.Value)
	return self
end

local Groupbox = {}
Groupbox.__index = Groupbox

local function newGroupbox(section, title)
	return setmetatable({ section = section, title = title, order = 0 }, Groupbox)
end

function Element:AddGear()
	return newGroupbox(CreateGear(self.row, self.section, reserveInset(self, 15)), self.item.name)
end

local function addElement(group, kind, idx, item)
	group.order += 1
	item.type = kind
	item.key = idx

	local ok, control = xpcall(Builders[kind], debug.traceback, group.section, item, group.order)
	if not ok then
		warn(string.format("[Neurothycal UI] element %s (%s) failed:\n%s", tostring(idx or item.name), kind, tostring(control)))
		return setmetatable({}, {
			__index = function()
				return function(stub)
					return stub
				end
			end,
		})
	end
	control.item = item
	register(control, idx)
	if group.section.relayout then
		group.section.relayout(true)
	end
	return control
end

function Groupbox:AddToggle(idx, info)
	local tooltip = info.Tooltip
	if not tooltip and info.Text == "enabled" then
		tooltip = string.format("turns %s on or off. related settings appear when it is enabled", self.title)
	end
	local control = addElement(self, "check", idx, {
		name = info.Text,
		default = info.Default == true,
		tooltip = tooltip,
		callback = info.Callback,
		depends = info.DependsOn,
	})
	Library.Toggles[idx] = control
	return control
end

function Groupbox:AddSlider(idx, info)
	return addElement(self, "slider", idx, {
		name = info.Text,
		min = info.Min,
		max = info.Max,
		default = info.Default,
		decimals = info.Rounding,
		suffix = info.Suffix,
		tooltip = info.Tooltip,
		callback = info.Callback,
		depends = info.DependsOn,
	})
end

function Groupbox:AddDropdown(idx, info)
	return addElement(self, "dropdown", idx, {
		name = info.Text,
		options = info.Values,
		default = info.Default,
		multi = info.Multi,
		optionColors = info.OptionColors,
		tooltip = info.Tooltip,
		callback = info.Callback,
		depends = info.DependsOn,
	})
end

function Groupbox:AddInput(idx, info)
	return addElement(self, "input", idx, {
		name = info.Text,
		default = info.Default or "",
		numeric = info.Numeric,
		finished = info.Finished,
		placeholder = info.Placeholder,
		maxLength = info.MaxLength,
		tooltip = info.Tooltip,
		callback = info.Callback,
		depends = info.DependsOn,
	})
end

function Groupbox:AddParagraph(info)

	local lines = 0
	for line in string.gmatch(info.Content .. "\n", "(.-)\n") do
		lines += math.max(math.ceil(#line / 36), 1)
	end
	return addElement(self, "paragraph", nil, {
		name = info.Title,
		text = info.Content,
		height = 18 + lines * 11,
		tooltip = info.Tooltip,
		depends = info.DependsOn,
	})
end

function Groupbox:AddKeybind(idx, info)
	return addElement(self, "keybind", idx, {
		name = info.Text,
		default = info.Default or "None",
		tooltip = info.Tooltip,
		callback = info.Callback,
		depends = info.DependsOn,
	})
end

function Groupbox:AddButton(info)
	return addElement(self, "button", nil, {
		name = info.Text,
		callback = info.Func,
		tooltip = info.Tooltip,
		depends = info.DependsOn,
	})
end

function Groupbox:AddLabel(text, info)
	info = info or {}
	return addElement(self, "color", nil, {
		name = text,
		tooltip = info.Tooltip,
		depends = info.DependsOn,
	})
end

local SubTab = {}
SubTab.__index = SubTab

local function addGroupbox(subTab, column, title)
	local page = subTab.page
	local order = #page.columns[column]:GetChildren()
	return newGroupbox(CreateSection(page.columns[column], page, title or "", order), title or "")
end

function SubTab:AddLeftGroupbox(title)
	return addGroupbox(self, 1, title)
end

function SubTab:AddRightGroupbox(title)
	return addGroupbox(self, 2, title)
end

local Tab = {}
Tab.__index = Tab

function Tab:AddSubTab(name, icon)
	local tab = self
	local sub = setmetatable({ page = createPage(tab.name .. "/" .. name) }, SubTab)
	sub.nav = createNavButton(tab.subBar, name, icon or tab.icon, #tab.subs + 1, Layout.BOTTOM, function()
		selectSub(tab, sub)
	end)
	table.insert(tab.subs, sub)

	if Runtime.currentTab == tab then
		tab.subBar.Visible = #tab.subs > 1
		if not tab.currentSub then
			selectSub(tab, sub)
		end
	end
	return sub
end

local function defaultSub(tab)
	tab.defaultSub = tab.defaultSub or tab:AddSubTab("main", tab.icon)
	return tab.defaultSub
end

function Tab:AddLeftGroupbox(title)
	return defaultSub(self):AddLeftGroupbox(title)
end

function Tab:AddRightGroupbox(title)
	return defaultSub(self):AddRightGroupbox(title)
end

function Tab:AddEspPreview()
	self.preview = true
	Preview.bind()
	if Runtime.currentTab == self then
		UI.setPreviewShown(Runtime.menuOpen)
	end
	return self
end

local Window = {}
Window.__index = Window

function Window:AddTab(name, icon)
	local tab = setmetatable({ name = name, icon = icon or "misc", subs = {} }, Tab)
	self.tabCount += 1
	Runtime.tabs = Runtime.tabs or {}
	Runtime.tabs[name] = tab
	tab.subBar = create("Frame", {
		Size = UDim2.new(1, -150, 1, 0),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = UI.bottomBar,
	}, { list(1, Enum.FillDirection.Horizontal), padding(0, 0, 0, 4) })
	tab.nav = createNavButton(UI.tabScroll, name, tab.icon, self.tabCount, Layout.TABS_HEIGHT, function()
		selectTab(tab)
	end)
	if not Runtime.currentTab then
		selectTab(tab)
	end
	return tab
end

function Window:AddSettingsTab(name)
	local tab = self:AddTab(name or "settings", "gear")
	Runtime.settingsTab = tab

	local menu = tab:AddLeftGroupbox("menu")
	menu:AddKeybind("menu_key", {
		Text = "menu key",
		Default = Runtime.menuKey.Name,
		Callback = function(value)
			local ok, key = pcall(function()
				return Enum.KeyCode[value]
			end)
			Runtime.menuKey = ok and key or Enum.KeyCode.RightShift
		end,
	})
	menu:AddLabel("accent color"):AddColorPicker("menu_accent", {
		Default = formatColor(Theme.Accent, 1),
		Callback = function(color)
			setAccent(formatColor(color, 1))
		end,
	})
	menu:AddSlider("menu_scale", {
		Text = "menu scale",
		Min = 70,
		Max = 150,
		Default = 100,
		Suffix = "%",
		Callback = function(value)
			Runtime.scaleMultiplier = value / 100
			if UI.updateScale then
				UI.updateScale()
			end
		end,
	})
	menu:AddToggle("menu_background_text", {
		Text = "background text",
		Default = true,
		Callback = function(value)
			UI.watermark.Visible = value
		end,
	})
	menu:AddToggle("menu_hotkey_list", {
		Text = "hotkey list",
		Default = true,
		Callback = function(value)
			Runtime.hotkeyListEnabled = value
			Hotkeys.refresh()
		end,
	})
	menu:AddToggle("menu_notifications", {
		Text = "notifications",
		Default = true,
		Callback = function(value)
			Runtime.notificationsEnabled = value
		end,
	})

	menu:AddButton({
		Text = "unload",
		Func = function()
			Library:Unload()
		end,
	})
	return tab
end

function Library:CreateWindow(options)
	options = options or {}
	Config.TITLE = options.Title or Config.TITLE
	Config.WATERMARK = options.Watermark or Config.TITLE
	Config.SUBSCRIPTION_TEXT = options.Subscription or Config.SUBSCRIPTION_TEXT
	Config.VERSION = options.Version or Config.VERSION
	if options.ConfigFolder then
		Config.CONFIG_FOLDER = options.ConfigFolder
		loadGlobal()
	end
	if options.Accent then
		setAccent(hexOf(options.Accent))
	end
	if options.MenuKey then
		Runtime.menuKey = options.MenuKey
	end

	UI.buildTitle(Config.TITLE)
	for _, backdropLabel in ipairs(UI.backdropLabels) do
		backdropLabel.Text = Config.WATERMARK
	end
	UI.subscriptionLabel.Text = Config.SUBSCRIPTION_TEXT
	UI.watermarkTitle.Text = Config.TITLE
	UI.watermarkVersion.Text = Config.VERSION
	UI.watermarkBar.Visible = Runtime.watermarkEnabled ~= false

	task.defer(function()
		setMenuOpen(true)
	end)
	return setmetatable({ tabCount = 0 }, Window)
end

function Library:Notify(text, duration)
	UI.notify(text, duration)
end

function Library:SetAccent(color)
	setAccent(hexOf(color))
end

function Library:SetWatermarkVisible(visible)
	Runtime.watermarkEnabled = visible
	UI.watermarkBar.Visible = visible
end

function Library:Toggle(open)
	if open == nil then
		open = not Runtime.menuOpen
	end
	setMenuOpen(open)
end

function Library:SaveConfig(name)
	return saveConfig(name)
end

function Library:LoadConfig(name)
	return loadConfig(name)
end

function Library:SetupConfigs(target)
	local tab = type(target) == "string" and Runtime.tabs[target] or target
	assert(tab, "SetupConfigs: вкладка не найдена: " .. tostring(target))

	local box = tab:AddRightGroupbox("configs")
	local nameInput = box:AddInput("config_name", {
		Text = "config name",
		Placeholder = "new config",
		MaxLength = 32,
		Tooltip = "name for a new config, or the new name when renaming",
	})
	local configList = box:AddDropdown("config_list", { Text = "configs", Values = {} })
	local autoLabel

	local function refresh(selected)
		configList:SetValues(Files.configs())
		if selected then
			configList:SetValue(selected)
		end
		autoLabel:SetText("auto load: " .. (Store.Global.autoLoad or "none"))
	end

	local function newName()
		local name = trim((string.gsub(nameInput.Value or "", "[^%w%s_%-]", "")))
		if name == "" or string.sub(name, 1, 1) == "_" then
			Library:Notify("enter a config name")
			return nil
		end
		return name
	end

	local function withSelected(action)
		return function()
			local name = configList.Value
			if name then
				action(name)
			else
				Library:Notify("select a config first")
			end
		end
	end

	box:AddButton({
		Text = "create",
		Func = function()
			local name = newName()
			if not name then
				return
			end
			if Files.read(name) then
				Library:Notify(string.format('config "%s" already exists', name))
				return
			end
			Library:Notify(saveConfig(name) and string.format('created "%s"', name) or "failed to create config")
			nameInput:SetValue("")
			refresh(name)
		end,
	})
	box:AddButton({
		Text = "load",
		Func = withSelected(function(name)
			Library:Notify(loadConfig(name) and string.format('loaded "%s"', name) or "failed to load config")
		end),
	})
	box:AddButton({
		Text = "overwrite",
		Func = withSelected(function(name)
			Library:Notify(saveConfig(name) and string.format('overwrote "%s"', name) or "failed to save config")
		end),
	})
	box:AddButton({
		Text = "rename",
		Func = withSelected(function(name)
			local renamed = newName()
			if not renamed or renamed == name then
				return
			end
			if Files.read(renamed) then
				Library:Notify(string.format('config "%s" already exists', renamed))
				return
			end
			local data = Files.read(name)
			if not data or not Files.write(renamed, data) then
				Library:Notify("failed to rename config")
				return
			end
			Files.delete(name)
			if Store.Global.autoLoad == name then
				Store.Global.autoLoad = renamed
				saveGlobal()
			end
			Library:Notify(string.format('renamed to "%s"', renamed))
			nameInput:SetValue("")
			refresh(renamed)
		end),
	})
	box:AddButton({
		Text = "delete",
		Func = withSelected(function(name)
			Files.delete(name)
			if Store.Global.autoLoad == name then
				Store.Global.autoLoad = nil
				saveGlobal()
			end
			Library:Notify(string.format('deleted "%s"', name))
			refresh()
		end),
	})
	box:AddButton({
		Text = "set auto load",
		Tooltip = "loads this config every time the menu starts. press again to turn it off",
		Func = withSelected(function(name)
			Store.Global.autoLoad = Store.Global.autoLoad ~= name and name or nil
			saveGlobal()
			refresh(name)
		end),
	})
	autoLabel = box:AddLabel("auto load: none")

	refresh()
	local autoLoad = Store.Global.autoLoad
	if autoLoad then
		if loadConfig(autoLoad) then
			configList:SetValue(autoLoad)
			Library:Notify(string.format('auto loaded "%s"', autoLoad))
		else
			Library:Notify(string.format('auto load failed: "%s" not found', autoLoad))
		end
	end
	return box
end

function Library:Unload()
	setMenuOpen(false)
	task.delay(0.35, function()
		UI.screenGui:Destroy()
	end)
end

return Library
