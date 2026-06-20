DrawingLibrary Functions

DrawingLibrary:ClearAll()

Removes all drawings, highlights, instances, and disconnects all active ESP connections.

DrawingLibrary:ClearAll()

---

DrawingLibrary:MakeBox(targetOrProperties, properties)

Creates either a static square drawing or a dynamic Box ESP.

Static Example

local Box = DrawingLibrary:MakeBox({
    Visible = true,
    Position = Vector2.new(100,100),
    Size = Vector2.new(200,300)
})

Dynamic Example

local ESP = DrawingLibrary:MakeBox("all", {
    Visible = true,
    Color = Color3.fromRGB(255,0,0)
})

Returns: ESP/Box object.

---

DrawingLibrary:MakeText(targetOrProperties, properties)

Creates either a static text drawing or a dynamic Text ESP.

Static Example

local Text = DrawingLibrary:MakeText({
    Visible = true,
    Text = "Hello"
})

Dynamic Example

DrawingLibrary:MakeText("all", {
    Visible = true,
    Text = "Name"
})

Returns: Text ESP object.

---

DrawingLibrary:MakeName(targetOrProperties, properties)

Alias for "MakeText()".

DrawingLibrary:MakeName("all", {
    Visible = true,
    Text = "Name"
})

Returns: Text ESP object.

---

DrawingLibrary:MakeLine(targetOrProperties, properties)

Creates either a static line or a dynamic tracer ESP.

Static Example

local Line = DrawingLibrary:MakeLine({
    Visible = true,
    From = Vector2.new(0,0),
    To = Vector2.new(500,500)
})

Dynamic Example

DrawingLibrary:MakeLine("all", {
    Visible = true
})

Returns: Line ESP object.

---

DrawingLibrary:MakeHighlight(targetOrProperties, properties)

Creates either a Roblox Highlight or a dynamic Highlight ESP.

Static Example

DrawingLibrary:MakeHighlight({
    Adornee = workspace.Part
})

Dynamic Example

DrawingLibrary:MakeHighlight("all", {
    FillColor = Color3.fromRGB(255,0,0)
})

Returns: Highlight object.

---

DrawingLibrary:MakeCircle(properties)

Creates a normal Drawing circle.

local Circle = DrawingLibrary:MakeCircle({
    Visible = true,
    Radius = 100
})

Returns: Circle object.

---

DrawingLibrary:MakeFov(properties)

Creates a FOV circle that follows the mouse (PC) or screen center (Mobile).

local FOV = DrawingLibrary:MakeFov({
    Visible = true,
    Radius = 150
})

Returns: FOV object.

---

ESP Object Methods

ESP:UpdateVisible(state)

Shows or hides the ESP.

ESP:UpdateVisible(true)

---

ESP:UpdateColor(color)

Changes ESP color.

ESP:UpdateColor(Color3.fromRGB(0,255,0))

---

ESP:UpdateText(text)

(Text ESP only)

ESP:UpdateText("Enemy")

---

ESP:UpdateSize(size)

(Text ESP only)

ESP:UpdateSize(24)

---

ESP:Remove()

Destroys the ESP and disconnects all related events.

ESP:Remove()

---

FOV Object Methods

FOV:UpdateRadius(radius)

Changes circle radius.

FOV:UpdateRadius(250)

---

FOV:UpdateVisible(state)

Shows or hides the FOV.

FOV:UpdateVisible(true)

---

FOV:UpdateColor(color)

Changes FOV color.

FOV:UpdateColor(Color3.fromRGB(255,0,0))

---

FOV:GetClosestPlayer()

Returns the closest valid player inside the FOV.

local Player = FOV:GetClosestPlayer()

Returns: Player or nil.

---

FOV:Remove()

Removes the FOV circle.

FOV:Remove()
