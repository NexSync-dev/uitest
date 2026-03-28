-- ██████╗ ██╗███████╗████████╗    ██╗   ██╗██╗
-- ██╔══██╗██║██╔════╝╚══██╔══╝    ██║   ██║██║
-- ██████╔╝██║█████╗     ██║       ██║   ██║██║
-- ██╔══██╗██║██╔══╝     ██║       ██║   ██║██║
-- ██║  ██║██║██║        ██║       ╚██████╔╝██║
-- ╚═╝  ╚═╝╚═╝╚═╝        ╚═╝        ╚═════╝ ╚═╝
-- Rift UI Library — custom, clean, first-person compatible

local Rift = {}
Rift.__index = Rift

-- Services
local Players            = game:GetService("Players")
local UserInputService   = game:GetService("UserInputService")
local RunService         = game:GetService("RunService")
local TweenService       = game:GetService("TweenService")
local CoreGui            = game:GetService("CoreGui")

local lp   = Players.LocalPlayer
local mouse = lp:GetMouse()

-- Theme
local Theme = {
    Background   = Color3.fromRGB(10,  10,  12),
    Surface      = Color3.fromRGB(16,  16,  20),
    SurfaceHover = Color3.fromRGB(22,  22,  28),
    Border       = Color3.fromRGB(35,  35,  45),
    Accent       = Color3.fromRGB(99,  102, 241), -- indigo
    AccentDim    = Color3.fromRGB(55,  57,  140),
    AccentGlow   = Color3.fromRGB(139, 92,  246), -- purple
    Text         = Color3.fromRGB(230, 230, 240),
    TextDim      = Color3.fromRGB(120, 120, 140),
    TextMuted    = Color3.fromRGB(65,  65,  80),
    Success      = Color3.fromRGB(52,  211, 153),
    Warning      = Color3.fromRGB(251, 191, 36),
    Danger       = Color3.fromRGB(239, 68,  68),
    White        = Color3.fromRGB(255, 255, 255),
    Black        = Color3.fromRGB(0,   0,   0),
}

-- Utility
local function tween(obj, props, t, style, dir)
    local ti = TweenInfo.new(t or 0.18, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out)
    local tw = TweenService:Create(obj, ti, props)
    tw:Play()
    return tw
end

local function make(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props) do
        inst[k] = v
    end
    return inst
end

local function stroke(parent, color, thickness, transparency)
    return make("UIStroke", {
        Parent = parent,
        Color = color or Theme.Border,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function corner(parent, radius)
    return make("UICorner", { Parent = parent, CornerRadius = UDim.new(0, radius or 6) })
end

local function padding(parent, top, bottom, left, right)
    return make("UIPadding", {
        Parent = parent,
        PaddingTop    = UDim.new(0, top    or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
        PaddingLeft   = UDim.new(0, left   or 0),
        PaddingRight  = UDim.new(0, right  or 0),
    })
end

local function listLayout(parent, dir, pad, halign, valign)
    return make("UIListLayout", {
        Parent = parent,
        FillDirection = dir or Enum.FillDirection.Vertical,
        Padding = UDim.new(0, pad or 4),
        HorizontalAlignment = halign or Enum.HorizontalAlignment.Left,
        VerticalAlignment   = valign or Enum.VerticalAlignment.Top,
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
end

-- Mouse unlock system for first-person
local CameraMode_backup = nil
local function unlockMouse()
    lp.CameraMode = Enum.CameraMode.Classic
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = true
end

local function lockMouse()
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
end

-- ════════════════════════════════════════════════
-- WINDOW
-- ════════════════════════════════════════════════
function Rift.new(config)
    local self = setmetatable({}, Rift)

    config = config or {}
    self.Title      = config.Title or "Rift"
    self.Subtitle   = config.Subtitle or ""
    self.ToggleKey  = config.ToggleKey or Enum.KeyCode.RightShift
    self.Open       = true
    self.Tabs       = {}
    self.ActiveTab  = nil
    self.Flags      = {}
    self.Connections = {}

    -- Root ScreenGui
    local sg = make("ScreenGui", {
        Name              = "RiftUI_" .. math.random(100000, 999999),
        ResetOnSpawn      = false,
        ZIndexBehavior    = Enum.ZIndexBehavior.Sibling,
        DisplayOrder      = 99999,
        IgnoreGuiInset    = true,
    })

    -- Try safe parent
    pcall(function() sg.Parent = CoreGui end)
    if not sg.Parent then
        pcall(function()
            if syn and syn.protect_gui then syn.protect_gui(sg) end
            sg.Parent = CoreGui
        end)
    end
    if not sg.Parent then sg.Parent = lp:WaitForChild("PlayerGui") end

    self.ScreenGui = sg

    -- Drop shadow container (behind window)
    local shadowHolder = make("Frame", {
        Parent = sg,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 724, 0, 464),
        Position = UDim2.new(0.5, -362, 0.5, -232),
        ZIndex = 1,
    })

    -- Glow shadow
    local shadow = make("ImageLabel", {
        Parent = shadowHolder,
        BackgroundTransparency = 1,
        Image = "rbxassetid://6014261993",
        ImageColor3 = Theme.Accent,
        ImageTransparency = 0.72,
        Size = UDim2.new(1, 60, 1, 60),
        Position = UDim2.new(0, -30, 0, -30),
        ZIndex = 1,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
    })

    -- Main window frame
    local win = make("Frame", {
        Parent = sg,
        BackgroundColor3 = Theme.Background,
        Size = UDim2.new(0, 720, 0, 460),
        Position = UDim2.new(0.5, -360, 0.5, -230),
        BorderSizePixel = 0,
        ZIndex = 2,
        ClipsDescendants = true,
    })
    corner(win, 10)
    stroke(win, Theme.Border, 1)
    self.Window = win

    -- Noise texture overlay for depth
    make("ImageLabel", {
        Parent = win,
        BackgroundTransparency = 1,
        Image = "rbxassetid://9968344807",
        ImageTransparency = 0.94,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 100,
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.new(0, 128, 0, 128),
    })

    -- Accent line top
    local accentLine = make("Frame", {
        Parent = win,
        BackgroundColor3 = Theme.Accent,
        Size = UDim2.new(0, 0, 0, 2),
        Position = UDim2.new(0, 0, 0, 0),
        BorderSizePixel = 0,
        ZIndex = 10,
    })
    tween(accentLine, { Size = UDim2.new(1, 0, 0, 2) }, 0.6, Enum.EasingStyle.Quart)

    -- Gradient top glow
    local topGlow = make("Frame", {
        Parent = win,
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 0.88,
        Size = UDim2.new(1, 0, 0, 60),
        Position = UDim2.new(0, 0, 0, 0),
        BorderSizePixel = 0,
        ZIndex = 3,
    })
    make("UIGradient", {
        Parent = topGlow,
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
    })

    -- ── Titlebar ──────────────────────────────────────
    local titlebar = make("Frame", {
        Parent = win,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 52),
        Position = UDim2.new(0, 0, 0, 2),
        ZIndex = 5,
    })

    -- Logo dot cluster
    local dotFrame = make("Frame", {
        Parent = titlebar,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(0, 16, 0.5, -14),
        ZIndex = 6,
    })
    local dotColors = { Theme.Accent, Theme.AccentGlow, Color3.fromRGB(236, 72, 153) }
    for i, col in ipairs(dotColors) do
        make("Frame", {
            Parent = dotFrame,
            BackgroundColor3 = col,
            Size = UDim2.new(0, 7, 0, 7),
            Position = UDim2.new(0, (i-1)*10, 0, (i==2) and 10 or (i==3) and 5 or 0),
            BorderSizePixel = 0,
            ZIndex = 7,
        })
    end

    -- Title text
    make("TextLabel", {
        Parent = titlebar,
        Text = self.Title,
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 200, 1, 0),
        Position = UDim2.new(0, 52, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6,
    })

    if self.Subtitle ~= "" then
        make("TextLabel", {
            Parent = titlebar,
            Text = "  ·  " .. self.Subtitle,
            TextColor3 = Theme.TextDim,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 300, 1, 0),
            Position = UDim2.new(0, 175, 0, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 6,
        })
    end

    -- Key hint (top right)
    local keyHint = make("TextLabel", {
        Parent = titlebar,
        Text = tostring(self.ToggleKey):gsub("Enum.KeyCode.", "") .. " to toggle",
        TextColor3 = Theme.TextMuted,
        Font = Enum.Font.Gotham,
        TextSize = 10,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 150, 1, 0),
        Position = UDim2.new(1, -166, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 6,
    })

    -- Separator line under titlebar
    make("Frame", {
        Parent = win,
        BackgroundColor3 = Theme.Border,
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 0, 53),
        BorderSizePixel = 0,
        ZIndex = 5,
    })

    -- ── Sidebar (tab buttons) ─────────────────────────
    local sidebar = make("Frame", {
        Parent = win,
        BackgroundColor3 = Theme.Surface,
        Size = UDim2.new(0, 155, 1, -54),
        Position = UDim2.new(0, 0, 0, 54),
        BorderSizePixel = 0,
        ZIndex = 4,
    })

    -- Sidebar right border
    make("Frame", {
        Parent = sidebar,
        BackgroundColor3 = Theme.Border,
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, -1, 0, 0),
        BorderSizePixel = 0,
        ZIndex = 5,
    })

    local tabBtnHolder = make("Frame", {
        Parent = sidebar,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, -12),
        Position = UDim2.new(0, 0, 0, 12),
        ZIndex = 5,
    })
    listLayout(tabBtnHolder, Enum.FillDirection.Vertical, 2)
    padding(tabBtnHolder, 0, 0, 8, 8)
    self.TabBtnHolder = tabBtnHolder

    -- ── Content area ──────────────────────────────────
    local content = make("Frame", {
        Parent = win,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -155, 1, -54),
        Position = UDim2.new(0, 155, 0, 54),
        BorderSizePixel = 0,
        ZIndex = 4,
        ClipsDescendants = true,
    })
    self.Content = content

    -- ── Dragging ──────────────────────────────────────
    local dragging, dragStart, startPos = false, nil, nil
    titlebar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = inp.Position
            startPos  = win.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = inp.Position - dragStart
            win.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
            shadowHolder.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X + 2,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y + 2
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    -- ── Toggle key ────────────────────────────────────
    local conn = UserInputService.InputBegan:Connect(function(inp, gpe)
        if gpe then return end
        if inp.KeyCode == self.ToggleKey then
            self:Toggle()
        end
    end)
    table.insert(self.Connections, conn)

    -- First-person mouse unlock on open
    local fpConn = RunService.RenderStepped:Connect(function()
        if self.Open then
            unlockMouse()
        end
    end)
    table.insert(self.Connections, fpConn)

    -- Open animation
    win.Size = UDim2.new(0, 0, 0, 0)
    win.Position = UDim2.new(0.5, 0, 0.5, 0)
    win.BackgroundTransparency = 1
    tween(win, {
        Size = UDim2.new(0, 720, 0, 460),
        Position = UDim2.new(0.5, -360, 0.5, -230),
        BackgroundTransparency = 0,
    }, 0.35, Enum.EasingStyle.Back)

    return self
end

function Rift:Toggle()
    self.Open = not self.Open
    local win = self.Window
    if self.Open then
        win.Visible = true
        unlockMouse()
        tween(win, { BackgroundTransparency = 0 }, 0.2)
        for _, v in ipairs(win:GetDescendants()) do
            if v:IsA("TextLabel") or v:IsA("TextButton") then
                tween(v, { TextTransparency = 0 }, 0.2)
            elseif v:IsA("Frame") or v:IsA("ScrollingFrame") then
                -- don't blanket fade frames
            end
        end
    else
        tween(win, { BackgroundTransparency = 1 }, 0.18).Completed:Connect(function()
            if not self.Open then win.Visible = false end
        end)
        -- restore mouse lock if in first person
        task.delay(0.2, function()
            if not self.Open then
                lockMouse()
            end
        end)
    end
end

function Rift:Notify(config)
    config = config or {}
    local msg   = config.Message or config.Title or "Notification"
    local sub   = config.Subtitle or ""
    local dur   = config.Duration or 3.5
    local col   = config.Color or Theme.Accent

    local sg = self.ScreenGui

    -- Stack offset
    local yOff = 20
    for _, v in ipairs(sg:GetChildren()) do
        if v.Name == "RiftNotif" then
            yOff = yOff + v.AbsoluteSize.Y + 8
        end
    end

    local notif = make("Frame", {
        Parent = sg,
        Name = "RiftNotif",
        BackgroundColor3 = Theme.Surface,
        Size = UDim2.new(0, 280, 0, 56),
        Position = UDim2.new(1, 10, 1, -(yOff + 56)),
        BorderSizePixel = 0,
        ZIndex = 200,
    })
    corner(notif, 8)
    stroke(notif, Theme.Border, 1)

    -- Color bar left
    local bar = make("Frame", {
        Parent = notif,
        BackgroundColor3 = col,
        Size = UDim2.new(0, 3, 1, -12),
        Position = UDim2.new(0, 6, 0, 6),
        BorderSizePixel = 0,
        ZIndex = 201,
    })
    corner(bar, 2)

    make("TextLabel", {
        Parent = notif,
        Text = msg,
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -24, 0, 20),
        Position = UDim2.new(0, 18, 0, 10),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 202,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    if sub ~= "" then
        make("TextLabel", {
            Parent = notif,
            Text = sub,
            TextColor3 = Theme.TextDim,
            Font = Enum.Font.Gotham,
            TextSize = 11,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -24, 0, 16),
            Position = UDim2.new(0, 18, 0, 30),
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 202,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })
    end

    -- Progress bar
    local prog = make("Frame", {
        Parent = notif,
        BackgroundColor3 = col,
        BackgroundTransparency = 0.6,
        Size = UDim2.new(1, -14, 0, 2),
        Position = UDim2.new(0, 7, 1, -4),
        BorderSizePixel = 0,
        ZIndex = 203,
    })
    corner(prog, 1)

    -- Slide in
    tween(notif, { Position = UDim2.new(1, -290, 1, -(yOff + 56)) }, 0.3, Enum.EasingStyle.Back)
    tween(prog, { Size = UDim2.new(0, 0, 0, 2) }, dur - 0.3, Enum.EasingStyle.Linear)

    task.delay(dur, function()
        tween(notif, { Position = UDim2.new(1, 10, 1, -(yOff + 56)) }, 0.25).Completed:Connect(function()
            notif:Destroy()
        end)
    end)
end

-- ════════════════════════════════════════════════
-- TAB
-- ════════════════════════════════════════════════
function Rift:Tab(config)
    config = config or {}
    local tabName = config.Name or config.name or "Tab"
    local tabIcon = config.Icon or config.icon or "☰"

    local tab = {}
    tab.Sections = {}

    -- Tab button
    local btn = make("TextButton", {
        Parent = self.TabBtnHolder,
        Text = "",
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 36),
        BorderSizePixel = 0,
        ZIndex = 6,
        AutoButtonColor = false,
    })
    corner(btn, 6)

    local indicator = make("Frame", {
        Parent = btn,
        BackgroundColor3 = Theme.Accent,
        Size = UDim2.new(0, 3, 0, 18),
        Position = UDim2.new(0, -3, 0.5, -9),
        BorderSizePixel = 0,
        ZIndex = 7,
    })
    corner(indicator, 2)

    make("TextLabel", {
        Parent = btn,
        Text = tabIcon .. "  " .. tabName,
        TextColor3 = Theme.TextDim,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -12, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
        Name = "Label",
    })

    -- Tab page (scrollable)
    local page = make("ScrollingFrame", {
        Parent = self.Content,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BorderSizePixel = 0,
        ZIndex = 5,
        Visible = false,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Accent,
        ScrollBarImageTransparency = 0.4,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
    })

    -- Two-column layout inside page
    local cols = make("Frame", {
        Parent = page,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        ZIndex = 5,
    })
    padding(cols, 14, 14, 14, 14)
    make("UIListLayout", {
        Parent = cols,
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 10),
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    tab._page = page
    tab._cols = cols
    tab._btn  = btn
    tab._lib  = self

    -- Activate tab
    local function activate()
        -- Deactivate current
        if self.ActiveTab and self.ActiveTab ~= tab then
            local prev = self.ActiveTab
            prev._page.Visible = false
            tween(prev._btn, { BackgroundTransparency = 1 }, 0.15)
            tween(prev._btn:FindFirstChild("Label"), { TextColor3 = Theme.TextDim }, 0.15)
            tween(prev._btn:FindFirstChild("Indicator") or indicator, { BackgroundTransparency = 1 }, 0.15)
        end
        self.ActiveTab = tab
        page.Visible = true
        tween(btn, { BackgroundTransparency = 0.85 }, 0.15)
        tween(btn:FindFirstChild("Label"), { TextColor3 = Theme.Text }, 0.15)
        tween(indicator, { BackgroundTransparency = 0 }, 0.15)
    end
    indicator.Name = "Indicator"
    indicator.BackgroundTransparency = 1

    btn.MouseButton1Click:Connect(activate)
    btn.MouseEnter:Connect(function()
        if self.ActiveTab ~= tab then
            tween(btn, { BackgroundTransparency = 0.92 }, 0.1)
            tween(btn.Label, { TextColor3 = Theme.Text }, 0.1)
        end
    end)
    btn.MouseLeave:Connect(function()
        if self.ActiveTab ~= tab then
            tween(btn, { BackgroundTransparency = 1 }, 0.1)
            tween(btn.Label, { TextColor3 = Theme.TextDim }, 0.1)
        end
    end)

    -- Auto-select first tab
    if #self.Tabs == 0 then
        activate()
    end
    table.insert(self.Tabs, tab)

    -- Section method on tab
    function tab:Section(cfg)
        cfg = cfg or {}
        local secName = cfg.Name or cfg.name or "Section"
        local side    = cfg.Side or cfg.side or "left"

        -- Find or create column frame
        local colIdx = (side == "right") and 2 or 1
        local colFrame = self._cols:FindFirstChild("Col" .. colIdx)
        if not colFrame then
            colFrame = make("Frame", {
                Parent = self._cols,
                Name = "Col" .. colIdx,
                BackgroundTransparency = 1,
                Size = UDim2.new(0.5, -5, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BorderSizePixel = 0,
                ZIndex = 5,
                LayoutOrder = colIdx,
            })
            listLayout(colFrame, Enum.FillDirection.Vertical, 8)
        end

        local sec = {}
        sec._lib = self._lib

        -- Section container
        local container = make("Frame", {
            Parent = colFrame,
            BackgroundColor3 = Theme.Surface,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BorderSizePixel = 0,
            ZIndex = 6,
        })
        corner(container, 8)
        stroke(container, Theme.Border, 1)

        -- Section header
        local header = make("Frame", {
            Parent = container,
            BackgroundColor3 = Theme.Background,
            Size = UDim2.new(1, 0, 0, 32),
            BorderSizePixel = 0,
            ZIndex = 7,
        })
        make("UICorner", { Parent = header, CornerRadius = UDim.new(0, 7) })

        -- Fix bottom corners of header
        make("Frame", {
            Parent = header,
            BackgroundColor3 = Theme.Background,
            Size = UDim2.new(1, 0, 0, 8),
            Position = UDim2.new(0, 0, 1, -8),
            BorderSizePixel = 0,
            ZIndex = 7,
        })

        make("TextLabel", {
            Parent = header,
            Text = secName:upper(),
            TextColor3 = Theme.Accent,
            Font = Enum.Font.GothamBold,
            TextSize = 10,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -14, 1, 0),
            Position = UDim2.new(0, 14, 0, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 8,
        })

        -- Accent header line
        make("Frame", {
            Parent = header,
            BackgroundColor3 = Theme.Accent,
            Size = UDim2.new(0, 30, 0, 2),
            Position = UDim2.new(0, 14, 1, -2),
            BorderSizePixel = 0,
            ZIndex = 8,
        })

        -- Elements holder
        local elemHolder = make("Frame", {
            Parent = container,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            Position = UDim2.new(0, 0, 0, 32),
            AutomaticSize = Enum.AutomaticSize.Y,
            BorderSizePixel = 0,
            ZIndex = 7,
        })
        listLayout(elemHolder, Enum.FillDirection.Vertical, 0)
        padding(elemHolder, 6, 10, 10, 10)
        sec._elemHolder = elemHolder

        -- ── ELEMENTS ────────────────────────────────────

        -- Toggle
        function sec:Toggle(opts)
            opts = opts or {}
            local name    = opts.Name or opts.name or "Toggle"
            local flag    = opts.Flag or opts.flag or name
            local default = opts.Default or opts.default or false
            local cb      = opts.Callback or opts.callback or function() end

            local val = default
            self._lib.Flags[flag] = val

            local row = make("TextButton", {
                Parent = self._elemHolder,
                Text = "",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 32),
                BorderSizePixel = 0,
                ZIndex = 8,
                AutoButtonColor = false,
            })

            -- Hover bg
            local hover = make("Frame", {
                Parent = row,
                BackgroundColor3 = Theme.SurfaceHover,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                BorderSizePixel = 0,
                ZIndex = 8,
            })
            corner(hover, 5)

            make("TextLabel", {
                Parent = row,
                Text = name,
                TextColor3 = Theme.Text,
                Font = Enum.Font.Gotham,
                TextSize = 13,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -52, 1, 0),
                Position = UDim2.new(0, 8, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 9,
            })

            -- Toggle pill
            local pillBg = make("Frame", {
                Parent = row,
                BackgroundColor3 = Theme.Border,
                Size = UDim2.new(0, 36, 0, 18),
                Position = UDim2.new(1, -44, 0.5, -9),
                BorderSizePixel = 0,
                ZIndex = 9,
            })
            corner(pillBg, 9)

            local pillDot = make("Frame", {
                Parent = pillBg,
                BackgroundColor3 = Theme.TextMuted,
                Size = UDim2.new(0, 12, 0, 12),
                Position = UDim2.new(0, 3, 0.5, -6),
                BorderSizePixel = 0,
                ZIndex = 10,
            })
            corner(pillDot, 6)

            local function setState(v)
                val = v
                self._lib.Flags[flag] = val
                if val then
                    tween(pillBg,  { BackgroundColor3 = Theme.Accent }, 0.18)
                    tween(pillDot, { Position = UDim2.new(0, 21, 0.5, -6), BackgroundColor3 = Theme.White }, 0.18)
                else
                    tween(pillBg,  { BackgroundColor3 = Theme.Border }, 0.18)
                    tween(pillDot, { Position = UDim2.new(0, 3, 0.5, -6), BackgroundColor3 = Theme.TextMuted }, 0.18)
                end
                cb(val)
            end

            setState(default)

            row.MouseButton1Click:Connect(function() setState(not val) end)
            row.MouseEnter:Connect(function() tween(hover, { BackgroundTransparency = 0.85 }, 0.1) end)
            row.MouseLeave:Connect(function() tween(hover, { BackgroundTransparency = 1 }, 0.1) end)

            local ctrl = { Set = setState, Get = function() return val end }
            return ctrl
        end

        -- Slider
        function sec:Slider(opts)
            opts = opts or {}
            local name    = opts.Name or opts.name or "Slider"
            local flag    = opts.Flag or opts.flag or name
            local min     = opts.Min or opts.min or 0
            local max     = opts.Max or opts.max or 100
            local default = opts.Default or opts.default or min
            local suffix  = opts.Suffix or opts.suffix or ""
            local cb      = opts.Callback or opts.callback or function() end
            local decimals= opts.Decimals or opts.decimals or 0

            local val = default
            self._lib.Flags[flag] = val

            local wrap = make("Frame", {
                Parent = self._elemHolder,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 42),
                BorderSizePixel = 0,
                ZIndex = 8,
            })

            local hover = make("Frame", {
                Parent = wrap,
                BackgroundColor3 = Theme.SurfaceHover,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                BorderSizePixel = 0,
                ZIndex = 8,
            })
            corner(hover, 5)

            local nameLabel = make("TextLabel", {
                Parent = wrap,
                Text = name,
                TextColor3 = Theme.Text,
                Font = Enum.Font.Gotham,
                TextSize = 13,
                BackgroundTransparency = 1,
                Size = UDim2.new(0.7, 0, 0, 20),
                Position = UDim2.new(0, 8, 0, 4),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 9,
            })

            local valLabel = make("TextLabel", {
                Parent = wrap,
                Text = tostring(val) .. suffix,
                TextColor3 = Theme.Accent,
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                BackgroundTransparency = 1,
                Size = UDim2.new(0.3, -8, 0, 20),
                Position = UDim2.new(0.7, 0, 0, 4),
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 9,
            })

            -- Track
            local trackBg = make("Frame", {
                Parent = wrap,
                BackgroundColor3 = Theme.Border,
                Size = UDim2.new(1, -16, 0, 4),
                Position = UDim2.new(0, 8, 0, 30),
                BorderSizePixel = 0,
                ZIndex = 9,
            })
            corner(trackBg, 2)

            local trackFill = make("Frame", {
                Parent = trackBg,
                BackgroundColor3 = Theme.Accent,
                Size = UDim2.new((val - min)/(max - min), 0, 1, 0),
                BorderSizePixel = 0,
                ZIndex = 10,
            })
            corner(trackFill, 2)

            -- Handle
            local handle = make("Frame", {
                Parent = trackBg,
                BackgroundColor3 = Theme.White,
                Size = UDim2.new(0, 12, 0, 12),
                Position = UDim2.new((val - min)/(max - min), -6, 0.5, -6),
                BorderSizePixel = 0,
                ZIndex = 11,
            })
            corner(handle, 6)
            stroke(handle, Theme.Accent, 2)

            local dragging = false

            local function updateSlider(x)
                local abs = trackBg.AbsolutePosition.X
                local sz  = trackBg.AbsoluteSize.X
                local pct = math.clamp((x - abs) / sz, 0, 1)
                local raw = min + (max - min) * pct
                local mult = 10^decimals
                val = math.floor(raw * mult + 0.5) / mult
                self._lib.Flags[flag] = val
                local displayVal = decimals == 0 and tostring(math.floor(val)) or string.format("%." .. decimals .. "f", val)
                valLabel.Text = displayVal .. suffix
                trackFill.Size = UDim2.new(pct, 0, 1, 0)
                handle.Position = UDim2.new(pct, -6, 0.5, -6)
                cb(val)
            end

            local btn = make("TextButton", {
                Parent = trackBg,
                Text = "",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 16),
                Position = UDim2.new(0, 0, 0, -8),
                BorderSizePixel = 0,
                ZIndex = 12,
                AutoButtonColor = false,
            })

            btn.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = true
                    updateSlider(inp.Position.X)
                end
            end)
            UserInputService.InputChanged:Connect(function(inp)
                if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
                    updateSlider(inp.Position.X)
                end
            end)
            UserInputService.InputEnded:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
            end)
            wrap.MouseEnter:Connect(function() tween(hover, { BackgroundTransparency = 0.85 }, 0.1) end)
            wrap.MouseLeave:Connect(function() tween(hover, { BackgroundTransparency = 1 }, 0.1) end)

            local ctrl = {
                Set = function(v)
                    val = math.clamp(v, min, max)
                    local pct = (val - min)/(max - min)
                    trackFill.Size = UDim2.new(pct, 0, 1, 0)
                    handle.Position = UDim2.new(pct, -6, 0.5, -6)
                    valLabel.Text = tostring(val) .. suffix
                    self._lib.Flags[flag] = val
                    cb(val)
                end,
                Get = function() return val end,
            }
            return ctrl
        end

        -- Dropdown
        function sec:Dropdown(opts)
            opts = opts or {}
            local name    = opts.Name or opts.name or "Dropdown"
            local flag    = opts.Flag or opts.flag or name
            local items   = opts.Items or opts.items or {}
            local default = opts.Default or opts.default or (items[1] or "None")
            local multi   = opts.Multi or opts.multi or false
            local cb      = opts.Callback or opts.callback or function() end

            local selected = multi and {} or default
            self._lib.Flags[flag] = selected

            local isOpen = false

            local wrap = make("Frame", {
                Parent = self._elemHolder,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 44),
                BorderSizePixel = 0,
                ZIndex = 8,
                ClipsDescendants = false,
            })

            make("TextLabel", {
                Parent = wrap,
                Text = name,
                TextColor3 = Theme.TextDim,
                Font = Enum.Font.Gotham,
                TextSize = 11,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 14),
                Position = UDim2.new(0, 8, 0, 2),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 9,
            })

            local btn = make("TextButton", {
                Parent = wrap,
                Text = "",
                BackgroundColor3 = Theme.Background,
                Size = UDim2.new(1, 0, 0, 26),
                Position = UDim2.new(0, 0, 0, 18),
                BorderSizePixel = 0,
                ZIndex = 9,
                AutoButtonColor = false,
            })
            corner(btn, 6)
            stroke(btn, Theme.Border, 1)

            local selLabel = make("TextLabel", {
                Parent = btn,
                Text = multi and "None" or tostring(default),
                TextColor3 = Theme.Text,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -28, 1, 0),
                Position = UDim2.new(0, 8, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 10,
                TextTruncate = Enum.TextTruncate.AtEnd,
            })

            -- Arrow
            local arrow = make("TextLabel", {
                Parent = btn,
                Text = "⌄",
                TextColor3 = Theme.TextDim,
                Font = Enum.Font.GothamBold,
                TextSize = 14,
                BackgroundTransparency = 1,
                Size = UDim2.new(0, 20, 1, 0),
                Position = UDim2.new(1, -24, 0, 0),
                ZIndex = 10,
            })

            -- Dropdown panel (appears over everything)
            local panel = make("Frame", {
                Parent = self._lib.ScreenGui,
                BackgroundColor3 = Theme.Surface,
                Size = UDim2.new(0, 0, 0, 0),
                BorderSizePixel = 0,
                ZIndex = 500,
                Visible = false,
                ClipsDescendants = true,
            })
            corner(panel, 6)
            stroke(panel, Theme.Accent, 1)

            local panelList = make("Frame", {
                Parent = panel,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BorderSizePixel = 0,
                ZIndex = 501,
            })
            listLayout(panelList, Enum.FillDirection.Vertical, 2)
            padding(panelList, 4, 4, 4, 4)

            local optBtns = {}
            local function refreshDisplay()
                if multi then
                    local joined = table.concat(selected, ", ")
                    selLabel.Text = joined == "" and "None" or joined
                else
                    selLabel.Text = tostring(selected)
                end
            end

            local function buildOptions()
                for _, ob in ipairs(optBtns) do ob:Destroy() end
                optBtns = {}
                for _, item in ipairs(items) do
                    local ob = make("TextButton", {
                        Parent = panelList,
                        Text = "  " .. tostring(item),
                        TextColor3 = Theme.Text,
                        Font = Enum.Font.Gotham,
                        TextSize = 12,
                        BackgroundColor3 = Theme.Background,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 26),
                        BorderSizePixel = 0,
                        ZIndex = 502,
                        AutoButtonColor = false,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    })
                    corner(ob, 4)
                    table.insert(optBtns, ob)

                    ob.MouseEnter:Connect(function() tween(ob, { BackgroundTransparency = 0.8 }, 0.1) end)
                    ob.MouseLeave:Connect(function() tween(ob, { BackgroundTransparency = 1 }, 0.1) end)

                    ob.MouseButton1Click:Connect(function()
                        if multi then
                            local found = false
                            for i, v in ipairs(selected) do
                                if v == item then found = i break end
                            end
                            if found then table.remove(selected, found)
                            else table.insert(selected, item) end
                            self._lib.Flags[flag] = selected
                            cb(selected)
                            refreshDisplay()
                        else
                            selected = item
                            self._lib.Flags[flag] = selected
                            cb(selected)
                            refreshDisplay()
                            isOpen = false
                            tween(panel, { Size = UDim2.new(0, panel.Size.X.Offset, 0, 0) }, 0.15).Completed:Connect(function()
                                panel.Visible = false
                            end)
                            tween(arrow, { Rotation = 0 }, 0.15)
                        end
                    end)
                end
            end

            buildOptions()

            local function openDropdown()
                local abs = btn.AbsolutePosition
                local sz  = btn.AbsoluteSize
                local targetH = math.min(#items * 30 + 8, 180)
                panel.Size = UDim2.new(0, sz.X, 0, 0)
                panel.Position = UDim2.new(0, abs.X, 0, abs.Y + sz.Y + 4)
                panel.Visible = true
                tween(panel, { Size = UDim2.new(0, sz.X, 0, targetH) }, 0.2, Enum.EasingStyle.Back)
                tween(arrow, { Rotation = 180 }, 0.15)
            end

            local function closeDropdown()
                tween(panel, { Size = UDim2.new(0, panel.Size.X.Offset, 0, 0) }, 0.15).Completed:Connect(function()
                    panel.Visible = false
                end)
                tween(arrow, { Rotation = 0 }, 0.15)
            end

            btn.MouseButton1Click:Connect(function()
                isOpen = not isOpen
                if isOpen then openDropdown() else closeDropdown() end
            end)

            UserInputService.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    if isOpen then
                        local mx, my = inp.Position.X, inp.Position.Y
                        local pa = panel.AbsolutePosition
                        local ps = panel.AbsoluteSize
                        if mx < pa.X or mx > pa.X + ps.X or my < pa.Y or my > pa.Y + ps.Y then
                            isOpen = false
                            closeDropdown()
                        end
                    end
                end
            end)

            refreshDisplay()

            local ctrl = {
                Set = function(v)
                    if multi then selected = type(v) == "table" and v or {v}
                    else selected = v end
                    self._lib.Flags[flag] = selected
                    refreshDisplay()
                    cb(selected)
                end,
                SetItems = function(newItems)
                    items = newItems
                    buildOptions()
                end,
                Get = function() return selected end,
            }
            return ctrl
        end

        -- Button
        function sec:Button(opts)
            opts = opts or {}
            local name = opts.Name or opts.name or "Button"
            local cb   = opts.Callback or opts.callback or function() end

            local btn = make("TextButton", {
                Parent = self._elemHolder,
                Text = "",
                BackgroundColor3 = Theme.AccentDim,
                Size = UDim2.new(1, 0, 0, 30),
                BorderSizePixel = 0,
                ZIndex = 8,
                AutoButtonColor = false,
            })
            corner(btn, 6)

            make("UIGradient", {
                Parent = btn,
                Rotation = 90,
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Theme.Accent),
                    ColorSequenceKeypoint.new(1, Theme.AccentDim),
                }),
            })

            make("TextLabel", {
                Parent = btn,
                Text = name,
                TextColor3 = Theme.White,
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                ZIndex = 9,
            })

            btn.MouseEnter:Connect(function() tween(btn, { BackgroundColor3 = Theme.Accent }, 0.1) end)
            btn.MouseLeave:Connect(function() tween(btn, { BackgroundColor3 = Theme.AccentDim }, 0.1) end)
            btn.MouseButton1Down:Connect(function() tween(btn, { BackgroundColor3 = Theme.AccentGlow }, 0.08) end)
            btn.MouseButton1Up:Connect(function() tween(btn, { BackgroundColor3 = Theme.Accent }, 0.08) end)
            btn.MouseButton1Click:Connect(function() cb() end)
        end

        -- Keybind
        function sec:Keybind(opts)
            opts = opts or {}
            local name    = opts.Name or opts.name or "Keybind"
            local flag    = opts.Flag or opts.flag or name
            local default = opts.Default or opts.default or Enum.KeyCode.Unknown
            local mode    = opts.Mode or opts.mode or "Toggle" -- "Toggle", "Hold", "Always"
            local cb      = opts.Callback or opts.callback or function() end

            local boundKey = default
            local active   = false
            local binding  = false

            self._lib.Flags[flag] = { Key = boundKey, Active = active, Mode = mode }

            local row = make("Frame", {
                Parent = self._elemHolder,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 32),
                BorderSizePixel = 0,
                ZIndex = 8,
            })

            local hover = make("Frame", {
                Parent = row,
                BackgroundColor3 = Theme.SurfaceHover,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                BorderSizePixel = 0,
                ZIndex = 8,
            })
            corner(hover, 5)

            make("TextLabel", {
                Parent = row,
                Text = name,
                TextColor3 = Theme.Text,
                Font = Enum.Font.Gotham,
                TextSize = 13,
                BackgroundTransparency = 1,
                Size = UDim2.new(0.6, 0, 1, 0),
                Position = UDim2.new(0, 8, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 9,
            })

            local keyBtn = make("TextButton", {
                Parent = row,
                BackgroundColor3 = Theme.Background,
                Size = UDim2.new(0, 72, 0, 20),
                Position = UDim2.new(1, -80, 0.5, -10),
                BorderSizePixel = 0,
                ZIndex = 9,
                AutoButtonColor = false,
            })
            corner(keyBtn, 4)
            stroke(keyBtn, Theme.Border, 1)

            local keyLabel = make("TextLabel", {
                Parent = keyBtn,
                Text = tostring(boundKey):gsub("Enum.KeyCode.", ""),
                TextColor3 = Theme.Accent,
                Font = Enum.Font.GothamBold,
                TextSize = 11,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                ZIndex = 10,
            })

            -- Mode selector (right-click cycles mode)
            local modeLabel = make("TextLabel", {
                Parent = row,
                Text = mode,
                TextColor3 = Theme.TextMuted,
                Font = Enum.Font.Gotham,
                TextSize = 9,
                BackgroundTransparency = 1,
                Size = UDim2.new(0, 72, 0, 10),
                Position = UDim2.new(1, -80, 1, -10),
                ZIndex = 9,
            })

            local modes = {"Toggle", "Hold", "Always"}
            local modeIdx = 1
            for i, m in ipairs(modes) do if m == mode then modeIdx = i end end

            keyBtn.MouseButton2Click:Connect(function()
                modeIdx = (modeIdx % #modes) + 1
                mode = modes[modeIdx]
                modeLabel.Text = mode
                self._lib.Flags[flag].Mode = mode
                if mode == "Always" then
                    active = true
                    cb(true)
                else
                    active = false
                    cb(false)
                end
            end)

            keyBtn.MouseButton1Click:Connect(function()
                binding = true
                keyLabel.Text = "..."
                tween(keyBtn, { BackgroundColor3 = Theme.AccentDim }, 0.1)
            end)

            UserInputService.InputBegan:Connect(function(inp, gpe)
                if binding then
                    if inp.KeyCode ~= Enum.KeyCode.Unknown then
                        boundKey = inp.KeyCode
                    elseif inp.UserInputType ~= Enum.UserInputType.MouseButton1 then
                        boundKey = inp.UserInputType
                    else
                        binding = false
                        keyLabel.Text = tostring(boundKey):gsub("Enum.KeyCode.", "")
                        tween(keyBtn, { BackgroundColor3 = Theme.Background }, 0.1)
                        return
                    end
                    binding = false
                    keyLabel.Text = tostring(boundKey):gsub("Enum.KeyCode.", ""):gsub("Enum.UserInputType.", "")
                    tween(keyBtn, { BackgroundColor3 = Theme.Background }, 0.1)
                    self._lib.Flags[flag].Key = boundKey
                    return
                end

                if gpe then return end

                local k = inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode or inp.UserInputType
                if k == boundKey then
                    if mode == "Toggle" then
                        active = not active
                        cb(active)
                        self._lib.Flags[flag].Active = active
                        tween(keyBtn, { BackgroundColor3 = active and Theme.AccentDim or Theme.Background }, 0.1)
                        tween(keyLabel, { TextColor3 = active and Theme.White or Theme.Accent }, 0.1)
                    elseif mode == "Hold" then
                        active = true
                        cb(true)
                        self._lib.Flags[flag].Active = true
                        tween(keyBtn, { BackgroundColor3 = Theme.AccentDim }, 0.1)
                    end
                end
            end)

            UserInputService.InputEnded:Connect(function(inp)
                if mode == "Hold" then
                    local k = inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode or inp.UserInputType
                    if k == boundKey then
                        active = false
                        cb(false)
                        self._lib.Flags[flag].Active = false
                        tween(keyBtn, { BackgroundColor3 = Theme.Background }, 0.1)
                    end
                end
            end)

            row.MouseEnter:Connect(function() tween(hover, { BackgroundTransparency = 0.85 }, 0.1) end)
            row.MouseLeave:Connect(function() tween(hover, { BackgroundTransparency = 1 }, 0.1) end)

            if mode == "Always" then
                active = true
                cb(true)
                tween(keyBtn, { BackgroundColor3 = Theme.AccentDim }, 0.1)
            end

            local ctrl = {
                Get = function() return active end,
                GetKey = function() return boundKey end,
            }
            return ctrl
        end

        -- Textbox
        function sec:Textbox(opts)
            opts = opts or {}
            local name   = opts.Name or opts.name or "Input"
            local flag   = opts.Flag or opts.flag or name
            local ph     = opts.Placeholder or opts.placeholder or "Type here..."
            local cb     = opts.Callback or opts.callback or function() end
            local numOnly= opts.NumberOnly or opts.numberOnly or false

            self._lib.Flags[flag] = opts.Default or opts.default or ""

            local wrap = make("Frame", {
                Parent = self._elemHolder,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 44),
                BorderSizePixel = 0,
                ZIndex = 8,
            })

            make("TextLabel", {
                Parent = wrap,
                Text = name,
                TextColor3 = Theme.TextDim,
                Font = Enum.Font.Gotham,
                TextSize = 11,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 14),
                Position = UDim2.new(0, 8, 0, 2),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 9,
            })

            local box = make("TextBox", {
                Parent = wrap,
                Text = opts.Default or opts.default or "",
                PlaceholderText = ph,
                TextColor3 = Theme.Text,
                PlaceholderColor3 = Theme.TextMuted,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                BackgroundColor3 = Theme.Background,
                Size = UDim2.new(1, 0, 0, 26),
                Position = UDim2.new(0, 0, 0, 18),
                BorderSizePixel = 0,
                ZIndex = 9,
                ClearTextOnFocus = false,
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            corner(box, 6)
            stroke(box, Theme.Border, 1)
            padding(box, 0, 0, 8, 8)

            box.Focused:Connect(function()
                tween(box, { BackgroundColor3 = Theme.SurfaceHover }, 0.1)
                stroke(box, Theme.Accent, 1)
            end)
            box.FocusLost:Connect(function(enter)
                tween(box, { BackgroundColor3 = Theme.Background }, 0.1)
                stroke(box, Theme.Border, 1)
                if enter then
                    local t = numOnly and (tonumber(box.Text) or 0) or box.Text
                    self._lib.Flags[flag] = t
                    cb(t)
                end
            end)

            local ctrl = {
                Set = function(v)
                    box.Text = tostring(v)
                    self._lib.Flags[flag] = v
                    cb(v)
                end,
                Get = function() return self._lib.Flags[flag] end,
            }
            return ctrl
        end

        -- Label
        function sec:Label(opts)
            opts = opts or {}
            local text  = opts.Text or opts.text or opts.Name or opts.name or ""
            local color = opts.Color or opts.color or Theme.TextDim

            local lbl = make("TextLabel", {
                Parent = self._elemHolder,
                Text = text,
                TextColor3 = color,
                Font = Enum.Font.Gotham,
                TextSize = 11,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 20),
                Position = UDim2.new(0, 8, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 8,
                TextWrapped = true,
            })

            local ctrl = {
                Set = function(v) lbl.Text = v end,
                SetColor = function(v) lbl.TextColor3 = v end,
            }
            return ctrl
        end

        -- Separator
        function sec:Separator()
            make("Frame", {
                Parent = self._elemHolder,
                BackgroundColor3 = Theme.Border,
                Size = UDim2.new(1, -16, 0, 1),
                Position = UDim2.new(0, 8, 0, 0),
                BorderSizePixel = 0,
                ZIndex = 8,
            })
        end

        table.insert(tab.Sections, sec)
        return sec
    end

    return tab
end

-- ════════════════════════════════════════════════
-- DESTROY
-- ════════════════════════════════════════════════
function Rift:Destroy()
    for _, c in ipairs(self.Connections) do
        pcall(function() c:Disconnect() end)
    end
    self.ScreenGui:Destroy()
    lockMouse()
end

return Rift

-- ════════════════════════════════════════════════════════════════
-- USAGE EXAMPLE (paste below in your executor script):
-- ════════════════════════════════════════════════════════════════
--[[

local Rift = loadstring(game:HttpGet("YOUR_RAW_URL_HERE"))()

local win = Rift.new({
    Title     = "My Script",
    Subtitle  = "v1.0",
    ToggleKey = Enum.KeyCode.RightShift,
})

-- ── Combat Tab ────────────────────────────────────
local combatTab = win:Tab({ Name = "⚔  Combat", Icon = "" })

local aimSection = combatTab:Section({ Name = "Aimbot", Side = "left" })

local aimbotToggle = aimSection:Toggle({
    Name    = "Enable Aimbot",
    Flag    = "aimbot_on",
    Default = false,
    Callback = function(val)
        print("Aimbot:", val)
    end,
})

local fovSlider = aimSection:Slider({
    Name     = "FOV",
    Flag     = "aimbot_fov",
    Min      = 1,
    Max      = 360,
    Default  = 90,
    Suffix   = "°",
    Callback = function(val)
        print("FOV:", val)
    end,
})

local hitpartDrop = aimSection:Dropdown({
    Name    = "Hitpart",
    Flag    = "aimbot_hitpart",
    Items   = { "Head", "Torso", "Left Arm", "Right Arm" },
    Default = "Head",
    Callback = function(val)
        print("Hitpart:", val)
    end,
})

local aimbotKey = aimSection:Keybind({
    Name    = "Aimbot Key",
    Flag    = "aimbot_key",
    Default = Enum.KeyCode.E,
    Mode    = "Hold",
    Callback = function(active)
        print("Aimbot held:", active)
    end,
})

-- Right column
local silentSection = combatTab:Section({ Name = "Silent Aim", Side = "right" })

silentSection:Toggle({
    Name     = "Enable",
    Flag     = "silent_on",
    Default  = false,
    Callback = function(v) print("Silent:", v) end,
})

silentSection:Slider({
    Name     = "Hit Chance",
    Flag     = "silent_chance",
    Min      = 0,
    Max      = 100,
    Default  = 75,
    Suffix   = "%",
    Callback = function(v) print("Chance:", v) end,
})

-- ── Visuals Tab ───────────────────────────────────
local visualTab = win:Tab({ Name = "👁  Visuals", Icon = "" })
local espSection = visualTab:Section({ Name = "ESP", Side = "left" })

espSection:Toggle({ Name = "Box ESP",     Flag = "esp_box",     Default = false })
espSection:Toggle({ Name = "Name ESP",    Flag = "esp_name",    Default = false })
espSection:Toggle({ Name = "Health Bar",  Flag = "esp_health",  Default = false })
espSection:Separator()
espSection:Slider({ Name = "ESP Range", Flag = "esp_range", Min = 50, Max = 2000, Default = 500, Suffix = "m" })

-- ── Misc Tab ──────────────────────────────────────
local miscTab = win:Tab({ Name = "⚙  Misc", Icon = "" })
local miscSection = miscTab:Section({ Name = "Utilities", Side = "left" })

miscSection:Button({
    Name = "Send Test Notification",
    Callback = function()
        win:Notify({
            Message  = "Hello from Rift!",
            Subtitle = "Notification system works",
            Duration = 3,
            Color    = Color3.fromRGB(99, 102, 241),
        })
    end,
})

miscSection:Textbox({
    Name        = "Target Player",
    Flag        = "target_name",
    Placeholder = "Username...",
    Callback    = function(v) print("Target:", v) end,
})

miscSection:Keybind({
    Name     = "Menu Toggle",
    Flag     = "menu_key",
    Default  = Enum.KeyCode.RightShift,
    Mode     = "Toggle",
    Callback = function(active)
        -- already handled by win.ToggleKey, this is just for display
    end,
})

-- Read any flag value at any time:
-- print(win.Flags["aimbot_fov"])
-- print(win.Flags["aimbot_key"].Active)

]]
