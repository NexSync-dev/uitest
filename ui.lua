local Library = {}
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Create main GUI
Library.ScreenGui = Instance.new("ScreenGui")
Library.ScreenGui.Parent = game.CoreGui

Library.MainFrame = Instance.new("Frame")
Library.MainFrame.Size = UDim2.new(0, 350, 0, 450)
Library.MainFrame.Position = UDim2.new(0.5, -175, 0.5, -225)
Library.MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Library.MainFrame.BorderSizePixel = 0
Library.MainFrame.Parent = Library.ScreenGui

-- Enable Dragging
local dragging, dragInput, dragStart, startPos
Library.MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = Library.MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
Library.MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)
UIS.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        Library.MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

Library.Tabs = {} -- Stores tab buttons
Library.Sections = {} -- Stores sections
Library.InfoDisplays = {} -- Stores info panels

function Library.addTab(name)
    local Tab = Instance.new("TextButton")
    Tab.Size = UDim2.new(0, 110, 0, 35)
    Tab.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    Tab.TextColor3 = Color3.fromRGB(255, 255, 255)
    Tab.Font = Enum.Font.Gotham
    Tab.TextSize = 14
    Tab.Text = name
    Tab.Parent = Library.MainFrame
    
    local ContentFrame = Instance.new("Frame")
    ContentFrame.Size = UDim2.new(1, 0, 1, -40)
    ContentFrame.Position = UDim2.new(0, 0, 0, 40)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.Visible = false
    ContentFrame.Parent = Library.MainFrame
    
    Tab.MouseButton1Click:Connect(function()
        for _, v in pairs(Library.MainFrame:GetChildren()) do
            if v:IsA("Frame") and v ~= ContentFrame then
                v.Visible = false
            end
        end
        ContentFrame.Visible = true
    end)
    
    Library.Tabs[name] = ContentFrame
    return ContentFrame
end

function Library.addButton(tab, name, callback)
    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(1, -10, 0, 40)
    Button.Position = UDim2.new(0, 5, 0, #tab:GetChildren() * 45)
    Button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    Button.Font = Enum.Font.Gotham
    Button.TextSize = 14
    Button.Text = name
    Button.Parent = tab
    
    Button.MouseButton1Click:Connect(callback)
end

function Library.addSection(tab, name)
    local Section = Instance.new("Frame")
    Section.Size = UDim2.new(1, -10, 0, 60)
    Section.Position = UDim2.new(0, 5, 0, #tab:GetChildren() * 65)
    Section.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    Section.Parent = tab
    
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 0, 25)
    Label.TextColor3 = Color3.fromRGB(255, 255, 255)
    Label.Font = Enum.Font.Gotham
    Label.TextSize = 14
    Label.Text = name
    Label.Parent = Section
    
    Library.Sections[name] = Section
    return Section
end

function Library.addTooltip(element, text)
    local Tooltip = Instance.new("TextLabel")
    Tooltip.Size = UDim2.new(0, 160, 0, 30)
    Tooltip.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Tooltip.TextColor3 = Color3.fromRGB(255, 255, 255)
    Tooltip.Font = Enum.Font.Gotham
    Tooltip.TextSize = 14
    Tooltip.Text = text
    Tooltip.Visible = false
    Tooltip.Parent = Library.ScreenGui
    
    element.MouseEnter:Connect(function()
        Tooltip.Visible = true
        Tooltip.Position = UDim2.new(0, UIS:GetMouseLocation().X + 10, 0, UIS:GetMouseLocation().Y + 10)
    end)
    element.MouseLeave:Connect(function()
        Tooltip.Visible = false
    end)
end

function Library.addInfoDisplay()
    local Info = Instance.new("Frame")
    Info.Size = UDim2.new(0, 220, 0, 120)
    Info.Position = UDim2.new(1, -230, 0, 10)
    Info.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Info.Parent = Library.ScreenGui
    
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 1, 0)
    Label.TextColor3 = Color3.fromRGB(255, 255, 255)
    Label.Font = Enum.Font.Gotham
    Label.TextSize = 14
    Label.Parent = Info
    
    RunService.RenderStepped:Connect(function()
        local ping = Players.LocalPlayer:GetNetworkPing() * 1000
        local fps = math.floor(1 / RunService.RenderStepped:Wait())
        Label.Text = string.format("FPS: %d | Ping: %d ms | Username: %s", fps, ping, Players.LocalPlayer.Name)
    end)
    
    return Info
end

function Library.setKeybind(key)
    UIS.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == key then
            Library.MainFrame.Visible = not Library.MainFrame.Visible
        end
    end)
end

return Library
