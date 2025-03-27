local Library = {}
local UIS = game:GetService("UserInputService")

-- Create main GUI
Library.ScreenGui = Instance.new("ScreenGui")
Library.ScreenGui.Parent = game.CoreGui

Library.MainFrame = Instance.new("Frame")
Library.MainFrame.Size = UDim2.new(0, 300, 0, 400)
Library.MainFrame.Position = UDim2.new(0, 50, 0, 50)
Library.MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Library.MainFrame.BorderSizePixel = 0
Library.MainFrame.Parent = Library.ScreenGui

Library.Tabs = {} -- Stores tab buttons
Library.Sections = {} -- Stores sections
Library.InfoDisplays = {} -- Stores info panels

function Library.addTab(name)
    local Tab = Instance.new("TextButton")
    Tab.Size = UDim2.new(0, 100, 0, 30)
    Tab.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Tab.Text = name
    Tab.Parent = Library.MainFrame
    
    local ContentFrame = Instance.new("Frame")
    ContentFrame.Size = UDim2.new(1, 0, 1, -30)
    ContentFrame.Position = UDim2.new(0, 0, 0, 30)
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
    Button.Size = UDim2.new(1, -10, 0, 30)
    Button.Position = UDim2.new(0, 5, 0, #tab:GetChildren() * 35)
    Button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    Button.Text = name
    Button.Parent = tab
    
    Button.MouseButton1Click:Connect(callback)
end

function Library.addSection(tab, name)
    local Section = Instance.new("Frame")
    Section.Size = UDim2.new(1, -10, 0, 50)
    Section.Position = UDim2.new(0, 5, 0, #tab:GetChildren() * 55)
    Section.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    Section.Parent = tab
    
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 0, 20)
    Label.Text = name
    Label.Parent = Section
    
    Library.Sections[name] = Section
    return Section
end

function Library.addTooltip(element, text)
    local Tooltip = Instance.new("TextLabel")
    Tooltip.Size = UDim2.new(0, 150, 0, 25)
    Tooltip.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Tooltip.TextColor3 = Color3.fromRGB(255, 255, 255)
    Tooltip.Text = text
    Tooltip.Visible = false
    Tooltip.Parent = Library.ScreenGui
    
    element.MouseEnter:Connect(function()
        Tooltip.Visible = true
        Tooltip.Position = UDim2.new(0, UIS:GetMouseLocation().X, 0, UIS:GetMouseLocation().Y)
    end)
    element.MouseLeave:Connect(function()
        Tooltip.Visible = false
    end)
end

function Library.addInfoDisplay()
    local Info = Instance.new("Frame")
    Info.Size = UDim2.new(0, 200, 0, 100)
    Info.Position = UDim2.new(1, -210, 0, 10)
    Info.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    Info.Parent = Library.ScreenGui
    
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 1, 0)
    Label.Text = "FPS: 0 | Ping: 0 | Username: " .. game.Players.LocalPlayer.Name
    Label.TextColor3 = Color3.fromRGB(255, 255, 255)
    Label.Parent = Info
    
    Library.InfoDisplays[#Library.InfoDisplays + 1] = Label
    
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
