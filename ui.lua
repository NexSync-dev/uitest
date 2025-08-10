local NotificationLibrary =
    loadstring(game:HttpGet("https://raw.githubusercontent.com/hellohellohell012321/TALENTLESS/main/notif_lib.lua"))(
)

if not pcall(function() getconnections(game.DescendantAdded) end) then
    warn("GETCONNECTIONS NOT SUPPORTED - this script will probably not work with your executor.")
    NotificationLibrary:SendNotification("Error", "GETCONNECTIONS NOT SUPPORTED - this script will probably not work with your executor.", 5)
else
end

loadstring(
    game:HttpGet("https://raw.githubusercontent.com/hellohellohell012321/discordpopup/main/discordpopup.lua", true)
)()

local ScreenGui = Instance.new("ScreenGui")
local Frame = Instance.new("Frame")
local title = Instance.new("TextLabel")
local creds = Instance.new("TextLabel")
local IMG_URL_BOX = Instance.new("TextBox")
local creds_2 = Instance.new("TextLabel")
local gobutton = Instance.new("Frame")
local go = Instance.new("TextButton")
local img = Instance.new("ImageLabel")
local TextButton = Instance.new("TextButton")
local closebutton = Instance.new("TextButton")

--Properties:

ScreenGui.Parent = game:GetService("CoreGui")
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

Frame.Parent = ScreenGui
Frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Frame.BorderColor3 = Color3.fromRGB(0, 0, 0)
Frame.BorderSizePixel = 2
Frame.Position = UDim2.new(0.5, 0, 0.5, 0)
Frame.Size = UDim2.new(0, 425, 0, 219)
Frame.AnchorPoint = Vector2.new(0.5, 0.5)

title.Name = "title"
title.Parent = Frame
title.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
title.BorderColor3 = Color3.fromRGB(0, 0, 0)
title.BorderSizePixel = 2
title.Size = UDim2.new(0, 425, 0, 50)
title.Font = Enum.Font.SourceSans
title.Text = "stupid ass starving artists autodrawer"
title.TextColor3 = Color3.fromRGB(0, 0, 0)
title.TextSize = 29.000

creds.Name = "creds"
creds.Parent = Frame
creds.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
creds.BackgroundTransparency = 1.000
creds.BorderColor3 = Color3.fromRGB(0, 0, 0)
creds.BorderSizePixel = 0
creds.Position = UDim2.new(0, 0, 0.853881299, 0)
creds.Size = UDim2.new(0, 167, 0, 25)
creds.Font = Enum.Font.SourceSans
creds.Text = "made by hellohellohell012321"
creds.TextColor3 = Color3.fromRGB(0, 0, 0)
creds.TextSize = 14.000

IMG_URL_BOX.Name = "IMG_URL_BOX"
IMG_URL_BOX.Parent = Frame
IMG_URL_BOX.BackgroundColor3 = Color3.fromRGB(224, 222, 225)
IMG_URL_BOX.BorderColor3 = Color3.fromRGB(0, 0, 0)
IMG_URL_BOX.BorderSizePixel = 3
IMG_URL_BOX.Position = UDim2.new(0.0894117653, 0, 0.378995448, 0)
IMG_URL_BOX.Size = UDim2.new(0, 349, 0, 32)
IMG_URL_BOX.Font = Enum.Font.SourceSans
IMG_URL_BOX.PlaceholderText = "https://i.imgur.com/wPU8Bq9.jpeg"
IMG_URL_BOX.Text = ""
IMG_URL_BOX.TextColor3 = Color3.fromRGB(0, 0, 0)
IMG_URL_BOX.TextScaled = true
IMG_URL_BOX.TextSize = 14.000
IMG_URL_BOX.TextWrapped = true

creds_2.Name = "creds"
creds_2.Parent = Frame
creds_2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
creds_2.BackgroundTransparency = 1.000
creds_2.BorderColor3 = Color3.fromRGB(0, 0, 0)
creds_2.BorderSizePixel = 0
creds_2.Position = UDim2.new(0.270588249, 0, 0.228310496, 0)
creds_2.Size = UDim2.new(0, 194, 0, 26)
creds_2.Font = Enum.Font.SourceSans
creds_2.Text = "insert image URL/address:"
creds_2.TextColor3 = Color3.fromRGB(0, 0, 0)
creds_2.TextScaled = true
creds_2.TextSize = 14.000
creds_2.TextWrapped = true

gobutton.Name = "gobutton"
gobutton.Parent = Frame
gobutton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
gobutton.BorderColor3 = Color3.fromRGB(0, 0, 0)
gobutton.BorderSizePixel = 3
gobutton.Position = UDim2.new(0.0894117653, 0, 0.602739751, 0)
gobutton.Size = UDim2.new(0, 349, 0, 43)

go.Name = "go"
go.Parent = gobutton
go.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
go.BorderColor3 = Color3.fromRGB(0, 0, 0)
go.BorderSizePixel = 0
go.Position = UDim2.new(-0.00147096475, 0, -0.0367502607, 0)
go.Size = UDim2.new(0, 264, 0, 42)
go.Font = Enum.Font.SourceSans
go.Text = "autodraw that shit"
go.TextColor3 = Color3.fromRGB(0, 0, 0)
go.TextSize = 29.000

img.Name = "img"
img.Parent = gobutton
img.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
img.BorderColor3 = Color3.fromRGB(0, 0, 0)
img.BorderSizePixel = 0
img.Position = UDim2.new(0.783333242, 0, -0.0232558139, 0)
img.Size = UDim2.new(0, 68, 0, 43)
img.Image = "rbxassetid://9468220156"

TextButton.Parent = Frame
TextButton.BackgroundColor3 = Color3.fromRGB(156, 155, 157)
TextButton.BackgroundTransparency = 0.500
TextButton.BorderColor3 = Color3.fromRGB(0, 0, 0)
TextButton.BorderSizePixel = 0
TextButton.Position = UDim2.new(0.562352955, 0, 0.867579937, 0)
TextButton.Size = UDim2.new(0, 169, 0, 18)
TextButton.Font = Enum.Font.SourceSans
TextButton.Text = "click me for help!"
TextButton.TextColor3 = Color3.fromRGB(0, 0, 0)
TextButton.TextScaled = true
TextButton.TextSize = 14.000
TextButton.TextWrapped = true

closebutton.Name = "closebutton"
closebutton.Parent = Frame
closebutton.BackgroundColor3 = Color3.fromRGB(255, 110, 93)
closebutton.BorderColor3 = Color3.fromRGB(0, 0, 0)
closebutton.BorderSizePixel = 2
closebutton.Position = UDim2.new(0.94588238, 0, -0.0502283089, 0)
closebutton.Size = UDim2.new(0, 41, 0, 37)
closebutton.Font = Enum.Font.SourceSansBold
closebutton.Text = "X"
closebutton.TextColor3 = Color3.fromRGB(255, 255, 255)
closebutton.TextScaled = true
closebutton.TextSize = 14.000
closebutton.TextWrapped = true

local function playSound(soundId, loudness)
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://" .. soundId
    sound.Parent = game.Players.LocalPlayer.Character or game.Players.LocalPlayer
    sound.Volume = loudness or 1
    sound:Play()
end

local function changeColor(hex)
    local player = game:GetService("Players").LocalPlayer
    local textBox = player.PlayerGui.MainGui.PaintFrame.ColorFrame.HexCode.TextBox

    textBox.Text = hex  -- fixed typo

    for _, connection in ipairs(getconnections(textBox.FocusLost)) do
        connection:Fire(true)
    end
end

local function goToStool()
    local playerName = game.Players.LocalPlayer.Name
    local stool = game.Workspace.Plots:FindFirstChild(playerName) and game.Workspace.Plots[playerName].Stool
    stool:Sit(game.Players.LocalPlayer.Character.Humanoid)
end

local function auto(imgur)
    local HttpService = game:GetService("HttpService")
    local httprequest = request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)

    local url = "https://starving-artists-api.vercel.app/api/pixelart"
    
    print("request starting")

    local response = httprequest({
        Url = url,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = HttpService:JSONEncode({ imageUrl = imgur })
    })

    print("request sent")
    print(HttpService:JSONEncode({ imageUrl = imgur }))

    if response and response.StatusCode == 200 then
        local data = HttpService:JSONDecode(response.Body)
        local pixelsTable = data.pixels

        print("request successful")
        print("Pixels count:", #pixelsTable)

 for i = 1, #pixelsTable do
    local player = game:GetService("Players").LocalPlayer
    local location = player.PlayerGui.MainGui.PaintFrame.GridHolder.Grid:FindFirstChild(tostring(i))

    if location then
        print("Changing pixel", i, "to color", pixelsTable[i])
        changeColor(pixelsTable[i])
        wait(0.05)  -- let the color update

        location:Activate()
        wait(0.1)   -- delay between pixel draws

        if i % 10 == 0 then
            wait(0.5)  -- extra pause every 10 pixels to avoid freezing
        end
    else
        print("Pixel button", i, "not found")
    end
end


        spawn(function()
            playSound("6493287948", 0.1)
            NotificationLibrary:SendNotification("Success", "autodraw finished. wait 3-5 minutes before uploading so you don't get banned.", 5)
        end)
    else
        warn("Request failed:", response and response.StatusCode)
        warn("Response body:", response and response.Body)
        playSound("6493287948", 0.1)
        NotificationLibrary:SendNotification("Error", "Request failed: " .. tostring(response and response.StatusCode), 10)
        NotificationLibrary:SendNotification("Error", "Response body: " .. tostring(response and HttpService:JSONEncode(response.Body)), 10)
    end
end


-- drag script (not mince)

local UserInputService = game:GetService("UserInputService")

local gui = Frame

local dragging
local dragInput
local dragStart
local startPos

local function update(input)
    local delta = input.Position - dragStart
    gui.Position =
        UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

gui.InputBegan:Connect(
    function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = gui.Position

            input.Changed:Connect(
                function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end
            )
        end
    end
)

gui.InputChanged:Connect(
    function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end
)

UserInputService.InputChanged:Connect(
    function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end
)

go.MouseButton1Click:Connect(function()

    goToStool()
    wait(0.5)

    local imgurle = IMG_URL_BOX.Text

    if imgurle == "" then
        NotificationLibrary:SendNotification("Error", "put a valid image url!", 5)
    else
        auto(imgurle)
    end
end)

closebutton.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)
