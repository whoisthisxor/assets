local Library = loadstring(game:HttpGet("ССЫЛКА_НА/NeurothycalLibrary.lua"))()
-- Или как ModuleScript:
-- local Library = require(game:GetService("ReplicatedStorage"):WaitForChild("NeurothycalLibrary"))

local Options = Library.Options
local Toggles = Library.Toggles

local Window = Library:CreateWindow({
	Title = "Neurothycal.wtf",
	Subscription = "29d 3h left",
	Version = "1.0.0",
	MenuKey = Enum.KeyCode.RightShift,
})

-- Вкладка сверху. Второй аргумент — иконка: rage, legit, visuals, inventory, misc, hotkeys, user,
-- users, globe, movement, gear, search, flame, volume, cart, box, sun, star или любое имя из Lucide
local Tabs = {
	Main = Window:AddTab("main", "rage"),
}

-- Подвкладки внизу окна необязательны: группы можно добавлять и прямо во вкладку
local Elements = Tabs.Main:AddSubTab("elements", "misc")
local Extra = Tabs.Main:AddSubTab("extra", "star")

local LeftGroupBox = Elements:AddLeftGroupbox("groupbox")

-- Toggle. Tooltip — обычное свойство: подсказка появляется при наведении на строку
LeftGroupBox:AddToggle("MyToggle", {
	Text = "this is a toggle",
	Default = true,
	Tooltip = "this is a tooltip",
	Callback = function(value)
		print("[cb] MyToggle changed to:", value)
	end,
})

-- Читать значение можно в любой момент, менять — через SetValue
print(Toggles.MyToggle.Value)
Toggles.MyToggle:SetValue(false)

-- OnChanged вызывается сразу с текущим значением, затем при каждом изменении
Toggles.MyToggle:OnChanged(function(value)
	print("MyToggle is now:", value)
end)

-- К строке можно прикрепить значки. Они ставятся справа налево в порядке вызова
LeftGroupBox:AddToggle("ColoredToggle", { Text = "toggle with extras" })
	:AddKeyPicker("ColoredToggleKey", { Default = "None", Mode = "toggle", Text = "colored toggle" })
	:AddColorPicker("ToggleColor2", { Default = Color3.fromRGB(255, 45, 140) })
	:AddColorPicker("ToggleColor1", {
		Default = "FFFFFF",
		Title = "my color", -- без Title в пикере будет "toggle with extras color 1"
		Callback = function(color, transparency)
			print("[cb] color:", color, "transparency:", transparency)
		end,
	})

-- Шестерёнка: всплывающее окно, в которое добавляются те же элементы
local GearToggle = LeftGroupBox:AddToggle("GearToggle", { Text = "toggle with gear" })
local Gear = GearToggle:AddGear()
Gear:AddDropdown("GearMode", { Text = "mode", Values = { "arrow", "circle" }, Default = "arrow" })
Gear:AddSlider("GearSize", { Text = "size", Min = 16, Max = 128, Default = 64, Suffix = "px" })

-- Slider
LeftGroupBox:AddSlider("MySlider", {
	Text = "this is my slider",
	Default = 0,
	Min = 0,
	Max = 5,
	Rounding = 1, -- знаков после запятой
	Suffix = "x",
	Tooltip = "right click the bar to type a number",
	Callback = function(value)
		print("[cb] MySlider was changed to:", value)
	end,
})

-- Textbox
LeftGroupBox:AddInput("MyTextbox", {
	Text = "this is a textbox",
	Default = "my textbox",
	Placeholder = "placeholder text",
	Tooltip = "this is a tooltip",
	Finished = false, -- true: значение применяется только по Enter или при потере фокуса
	Callback = function(value)
		print("[cb] text updated:", value)
	end,
})

LeftGroupBox:AddInput("MyNumber", {
	Text = "numbers only",
	Numeric = true,
	MaxLength = 6,
	Finished = true,
})

-- Кнопка
LeftGroupBox:AddButton({
	Text = "this is a button",
	Tooltip = "this is a tooltip",
	Func = function()
		Library:Notify("you clicked a button!", 3)
	end,
})

local RightGroupBox = Elements:AddRightGroupbox("groupbox #2")

-- Dropdown
RightGroupBox:AddDropdown("MyDropdown", {
	Text = "a dropdown",
	Values = { "this", "is", "a", "dropdown" },
	Default = "this",
	Tooltip = "this is a tooltip",
	Callback = function(value)
		print("[cb] dropdown got changed:", value)
	end,
})

-- Multi dropdown: значение — список выбранных вариантов
RightGroupBox:AddDropdown("MyMultiDropdown", {
	Text = "a multi dropdown",
	Values = { "this", "is", "a", "multi", "dropdown" },
	Default = { "this", "dropdown" },
	Multi = true,
})

-- OptionColors: у вариантов свой цвет, большой пикер открывается прямо внутри списка
RightGroupBox:AddDropdown("MyColorDropdown", {
	Text = "dropdown with colors",
	Values = { "stars", "rain", "snow" },
	Default = { "stars" },
	Multi = true,
	OptionColors = { stars = "FF9ADAFF", rain = "62BDF5FF", snow = "FFFFFFFF" },
})

-- Label: тоже может нести значки
RightGroupBox:AddLabel("this is a label")
RightGroupBox:AddLabel("label with color"):AddColorPicker("LabelColor", { Default = "FF2D8C" })

-- Paragraph: заголовок и текст с переносом строк
RightGroupBox:AddParagraph({
	Title = "paragraph",
	Content = "this is a paragraph. long text wraps onto the next lines and the row grows to fit it.",
})

-- Dependency: DependsOn скрывает элемент, пока условие не выполнено
local DependencyBox = Extra:AddLeftGroupbox("dependency")
DependencyBox:AddToggle("ShowExtras", { Text = "show extras" })
DependencyBox:AddSlider("ExtraSlider", { Text = "only when enabled", Min = 0, Max = 100, Default = 50, DependsOn = "ShowExtras" })
DependencyBox:AddDropdown("ExtraMode", { Text = "mode", Values = { "simple", "advanced" }, Default = "simple", DependsOn = "ShowExtras" })
-- Условие по значению: { id, значение } или { id, { значения } }
DependencyBox:AddInput("AdvancedText", { Text = "advanced only", DependsOn = { "ExtraMode", "advanced" } })

-- Настройки меню и конфиги. SetupConfigs вызывается последним, чтобы автозагрузка
-- применилась ко всем добавленным элементам
Window:AddSettingsTab("settings")
Library:SetupConfigs("settings")

Library:Notify("example loaded", 3)
