-- ██████╗ ██╗███████╗████████╗    ██╗   ██╗██╗
-- ██╔══██╗██║██╔════╝╚══██╔══╝    ██║   ██║██║
-- ██████╔╝██║█████╗     ██║       ██║   ██║██║
-- ██╔══██╗██║██╔══╝     ██║       ██║   ██║██║
-- ██║  ██║██║██║        ██║       ╚██████╔╝██║
-- ╚═╝  ╚═╝╚═╝╚═╝        ╚═╝        ╚═════╝ ╚═╝
-- Rift UI Library — v1.3 (animated refresh)

local Rift = {}
Rift.__index = Rift

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local CoreGui          = game:GetService("CoreGui")

local lp = Players.LocalPlayer

local Theme = {
    Background   = Color3.fromRGB(11,  11,  14),
    Surface      = Color3.fromRGB(17,  17,  22),
    SurfaceHover = Color3.fromRGB(26,  26,  33),
    Border       = Color3.fromRGB(34,  34,  44),
    Accent       = Color3.fromRGB(56,  189, 248),
    AccentDim    = Color3.fromRGB(14,  116, 174),
    AccentGlow   = Color3.fromRGB(125, 211, 252),
    Text         = Color3.fromRGB(228, 228, 235),
    TextDim      = Color3.fromRGB(110, 110, 130),
    TextMuted    = Color3.fromRGB(55,  55,  70),
    Success      = Color3.fromRGB(52,  211, 153),
    Warning      = Color3.fromRGB(251, 191, 36),
    Danger       = Color3.fromRGB(239, 68,  68),
    White        = Color3.fromRGB(255, 255, 255),
    Black        = Color3.fromRGB(0,   0,   0),
    Orb1         = Color3.fromRGB(56,  189, 248),
    Orb2         = Color3.fromRGB(99,  102, 241),
    Orb3         = Color3.fromRGB(52,  211, 153),
}

-- ════════════════════════════════════════════════
-- HELPERS
-- ════════════════════════════════════════════════
local function tween(obj, props, t, style, dir)
    local ti = TweenInfo.new(t or 0.18, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out)
    local tw = TweenService:Create(obj, ti, props)
    tw:Play()
    return tw
end

local function make(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props) do inst[k] = v end
    return inst
end

local function stroke(parent, color, thickness)
    return make("UIStroke", {
        Parent = parent,
        Color = color or Theme.Border,
        Thickness = thickness or 1,
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

-- Ping-pong animation loop between two states
local function loopTween(obj, propsA, propsB, t, style)
    local alive = true
    local function cycle(to, from)
        if not alive then return end
        tween(obj, to, t, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut).Completed:Connect(function()
            if not alive then return end
            tween(obj, from, t, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut).Completed:Connect(function()
                cycle(to, from)
            end)
        end)
    end
    cycle(propsA, propsB)
    return function() alive = false end
end

-- Click ripple that expands and fades from the cursor
local function ripple(parent, relX, relY)
    local r = make("Frame", {
        Parent = parent,
        BackgroundColor3 = Theme.White,
        BackgroundTransparency = 0.82,
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0, relX, 0, relY),
        BorderSizePixel = 0,
        ZIndex = parent.ZIndex + 5,
    })
    corner(r, 9999)
    local sz = math.max(parent.AbsoluteSize.X, parent.AbsoluteSize.Y) * 2.2
    tween(r, {
        Size     = UDim2.new(0, sz, 0, sz),
        Position = UDim2.new(0, relX - sz/2, 0, relY - sz/2),
        BackgroundTransparency = 1,
    }, 0.55, Enum.EasingStyle.Quart).Completed:Connect(function()
        r:Destroy()
    end)
end

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

    self.Title       = config.Title or "Rift"
    self.Subtitle    = config.Subtitle or ""
    self.ToggleKey   = config.ToggleKey or Enum.KeyCode.RightShift
    self.Open        = true
    self.Tabs        = {}
    self.ActiveTab   = nil
    self.Flags       = {}
    self.Connections = {}
    self._loopKills  = {}

    local sg = make("ScreenGui", {
        Name           = "RiftUI_" .. math.random(100000, 999999),
        ResetOnSpawn   = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder   = 99999,
        IgnoreGuiInset = true,
    })
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(sg) end end)
    pcall(function() sg.Parent = CoreGui end)
    if not sg.Parent then sg.Parent = lp:WaitForChild("PlayerGui") end
    self.ScreenGui = sg

    -- ── Shadow ──
    local shadowHolder = make("Frame", {
        Parent = sg, BackgroundTransparency = 1,
        Size = UDim2.new(0, 760, 0, 500),
        Position = UDim2.new(0.5, -380, 0.5, -250),
        ZIndex = 1, Visible = false,
    })
    self._shadowHolder = shadowHolder
    make("ImageLabel", {
        Parent = shadowHolder, BackgroundTransparency = 1,
        Image = "rbxassetid://6014261993",
        ImageColor3 = Theme.Accent, ImageTransparency = 0.75,
        Size = UDim2.new(1, 80, 1, 80), Position = UDim2.new(0, -40, 0, -40),
        ZIndex = 1, ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
    })

    -- ── Main window ──
    local win = make("Frame", {
        Parent = sg, BackgroundColor3 = Theme.Background,
        Size = UDim2.new(0, 720, 0, 460),
        Position = UDim2.new(0.5, -360, 0.5, -230),
        BorderSizePixel = 0, ZIndex = 2, ClipsDescendants = true,
    })
    corner(win, 10)
    stroke(win, Theme.Border, 1)
    self.Window = win

    -- ── Animated ambient orbs (background life) ──
    local orbContainer = make("Frame", {
        Parent = win, BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0), ZIndex = 1,
    })

    local function makeOrb(color, size, x, y, tr)
        local orb = make("Frame", {
            Parent = orbContainer, BackgroundColor3 = color,
            BackgroundTransparency = tr, Size = UDim2.new(0, size, 0, size),
            Position = UDim2.new(0, x, 0, y), BorderSizePixel = 0, ZIndex = 1,
        })
        corner(orb, size)
        return orb
    end

    local orb1 = makeOrb(Theme.Orb1, 320, -60, -80,  0.90)
    local orb2 = makeOrb(Theme.Orb2, 260, 430, 180,  0.92)
    local orb3 = makeOrb(Theme.Orb3, 200, 190, 260,  0.93)

    table.insert(self._loopKills, loopTween(orb1,
        { Position = UDim2.new(0, -40, 0, -55), BackgroundTransparency = 0.88 },
        { Position = UDim2.new(0, -80, 0, -110), BackgroundTransparency = 0.93 }, 6))
    table.insert(self._loopKills, loopTween(orb2,
        { Position = UDim2.new(0, 445, 0, 160), BackgroundTransparency = 0.90 },
        { Position = UDim2.new(0, 405, 0, 215), BackgroundTransparency = 0.94 }, 8))
    table.insert(self._loopKills, loopTween(orb3,
        { Position = UDim2.new(0, 175, 0, 245), BackgroundTransparency = 0.91 },
        { Position = UDim2.new(0, 230, 0, 285), BackgroundTransparency = 0.95 }, 7))

    -- ── Top accent line ──
    local accentLine = make("Frame", {
        Parent = win, BackgroundColor3 = Theme.Accent,
        Size = UDim2.new(0, 0, 0, 1), BorderSizePixel = 0, ZIndex = 10,
    })

    -- ── Title bar ──
    local titlebar = make("Frame", {
        Parent = win, BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 52),
        Position = UDim2.new(0, 0, 0, 1), ZIndex = 5,
    })

    local titleAccentBar = make("Frame", {
        Parent = titlebar, BackgroundColor3 = Theme.Accent,
        Size = UDim2.new(0, 3, 0, 0),
        Position = UDim2.new(0, 16, 0.5, 11),
        BorderSizePixel = 0, ZIndex = 7,
    })
    corner(titleAccentBar, 2)
    -- Subtle color pulse on the bar
    table.insert(self._loopKills, loopTween(titleAccentBar,
        { BackgroundColor3 = Theme.Accent },
        { BackgroundColor3 = Theme.AccentGlow }, 2.5))

    local titleLabel = make("TextLabel", {
        Parent = titlebar, Text = self.Title,
        TextColor3 = Theme.Text, Font = Enum.Font.GothamBold, TextSize = 14,
        BackgroundTransparency = 1, Size = UDim2.new(0, 200, 1, 0),
        Position = UDim2.new(0, 28, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
        TextTransparency = 1,
    })
    local subtitleLabel
    if self.Subtitle ~= "" then
        subtitleLabel = make("TextLabel", {
            Parent = titlebar, Text = "/ " .. self.Subtitle,
            TextColor3 = Theme.TextMuted, Font = Enum.Font.Gotham, TextSize = 12,
            BackgroundTransparency = 1, Size = UDim2.new(0, 280, 1, 0),
            Position = UDim2.new(0, 168, 0, 0),
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
            TextTransparency = 1,
        })
    end
    local toggleHintLabel = make("TextLabel", {
        Parent = titlebar,
        Text = tostring(self.ToggleKey):gsub("Enum.KeyCode.", "") .. " to toggle",
        TextColor3 = Theme.TextMuted, Font = Enum.Font.Gotham, TextSize = 10,
        BackgroundTransparency = 1, Size = UDim2.new(0, 150, 1, 0),
        Position = UDim2.new(1, -166, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6,
        TextTransparency = 1,
    })

    local divider = make("Frame", {
        Parent = win, BackgroundColor3 = Theme.Border,
        Size = UDim2.new(0, 0, 0, 1),
        Position = UDim2.new(0, 0, 0, 53), BorderSizePixel = 0, ZIndex = 5,
    })

    -- ── Sidebar ──
    local sidebar = make("Frame", {
        Parent = win, BackgroundColor3 = Theme.Surface,
        Size = UDim2.new(0, 148, 1, -54),
        Position = UDim2.new(0, 0, 0, 54), BorderSizePixel = 0, ZIndex = 4,
    })
    make("Frame", {
        Parent = sidebar, BackgroundColor3 = Theme.Border,
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, -1, 0, 0), BorderSizePixel = 0, ZIndex = 5,
    })
    -- Sidebar top accent fade
    local sideGrad = make("Frame", {
        Parent = sidebar, BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 0.94,
        Size = UDim2.new(1, 0, 0, 80), BorderSizePixel = 0, ZIndex = 5,
    })
    make("UIGradient", {
        Parent = sideGrad, Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
    })

    local tabBtnHolder = make("Frame", {
        Parent = sidebar, BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, -10),
        Position = UDim2.new(0, 0, 0, 10), ZIndex = 5,
    })
    listLayout(tabBtnHolder, Enum.FillDirection.Vertical, 2)
    padding(tabBtnHolder, 0, 0, 7, 7)
    self.TabBtnHolder = tabBtnHolder

    local content = make("Frame", {
        Parent = win, BackgroundTransparency = 1,
        Size = UDim2.new(1, -148, 1, -54),
        Position = UDim2.new(0, 148, 0, 54),
        BorderSizePixel = 0, ZIndex = 4, ClipsDescendants = true,
    })
    self.Content = content

    -- ── Dragging ──
    local dragging, dragStart, startPos = false, nil, nil
    titlebar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = inp.Position; startPos = win.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local d = inp.Position - dragStart
            win.Position        = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
            shadowHolder.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)

    table.insert(self.Connections, UserInputService.InputBegan:Connect(function(inp, gpe)
        if gpe then return end
        if inp.KeyCode == self.ToggleKey then self:Toggle() end
    end))
    table.insert(self.Connections, RunService.RenderStepped:Connect(function()
        if self.Open then unlockMouse() end
    end))

    -- ── Orchestrated open animation ──
    win.Size = UDim2.new(0, 660, 0, 0)
    win.Position = UDim2.new(0.5, -330, 0.5, 0)
    win.BackgroundTransparency = 1

    tween(win, {
        Size = UDim2.new(0, 720, 0, 460),
        Position = UDim2.new(0.5, -360, 0.5, -230),
        BackgroundTransparency = 0,
    }, 0.4, Enum.EasingStyle.Back).Completed:Connect(function()
        shadowHolder.Visible = true
        -- Accent line draws across
        tween(accentLine, { Size = UDim2.new(1, 0, 0, 1) }, 0.35, Enum.EasingStyle.Quart)
        -- Divider draws across
        tween(divider, { Size = UDim2.new(1, 0, 0, 1) }, 0.3, Enum.EasingStyle.Quart)
        -- Title accent bar slides down
        tween(titleAccentBar, {
            Size = UDim2.new(0, 3, 0, 22),
            Position = UDim2.new(0, 16, 0.5, -11),
        }, 0.3, Enum.EasingStyle.Back)
        -- Text fades in with stagger
        task.delay(0.08, function() tween(titleLabel, { TextTransparency = 0 }, 0.25) end)
        task.delay(0.15, function()
            if subtitleLabel then tween(subtitleLabel, { TextTransparency = 0 }, 0.25) end
        end)
        task.delay(0.22, function() tween(toggleHintLabel, { TextTransparency = 0 }, 0.25) end)
    end)

    return self
end

-- ════════════════════════════════════════════════
-- TOGGLE
-- ════════════════════════════════════════════════
function Rift:Toggle()
    self.Open = not self.Open
    local win = self.Window
    local sh  = self._shadowHolder

    -- Kill any stray dropdown panels
    for _, obj in ipairs(self.ScreenGui:GetChildren()) do
        if obj ~= win and obj ~= sh and obj.Name ~= "RiftNotif" then
            if obj:IsA("Frame") then obj.Visible = false end
        end
    end

    if self.Open then
        win.Visible = true
        sh.Visible  = true
        win.BackgroundTransparency = 1
        tween(win, {
            BackgroundTransparency = 0,
            Size = UDim2.new(0, 720, 0, 460),
        }, 0.25, Enum.EasingStyle.Back)
        unlockMouse()
    else
        sh.Visible = false
        tween(win, {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 690, 0, 440),
        }, 0.2, Enum.EasingStyle.Quart).Completed:Connect(function()
            if not self.Open then win.Visible = false end
        end)
        task.delay(0.2, function()
            if not self.Open then lockMouse() end
        end)
    end
end

-- ════════════════════════════════════════════════
-- NOTIFY
-- ════════════════════════════════════════════════
function Rift:Notify(config)
    config = config or {}
    local msg = config.Message or config.Title or "Notification"
    local sub = config.Subtitle or ""
    local dur = config.Duration or 3.5
    local col = config.Color or Theme.Accent
    local sg  = self.ScreenGui

    local notifH = sub ~= "" and 58 or 44
    local yOff = 20
    for _, v in ipairs(sg:GetChildren()) do
        if v.Name == "RiftNotif" then yOff = yOff + v.AbsoluteSize.Y + 8 end
    end

    local notif = make("Frame", {
        Parent = sg, Name = "RiftNotif",
        BackgroundColor3 = Theme.Surface,
        Size = UDim2.new(0, 280, 0, notifH),
        Position = UDim2.new(1, 20, 1, -(yOff + notifH)),
        BorderSizePixel = 0, ZIndex = 200,
        BackgroundTransparency = 0.08,
    })
    corner(notif, 8)
    local notifStroke = stroke(notif, col, 1)

    make("Frame", {
        Parent = notif, BackgroundColor3 = col,
        Size = UDim2.new(0, 2, 1, -14),
        Position = UDim2.new(0, 7, 0, 7),
        BorderSizePixel = 0, ZIndex = 201,
    })
    make("TextLabel", {
        Parent = notif, Text = msg,
        TextColor3 = Theme.Text, Font = Enum.Font.GothamBold, TextSize = 13,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -24, 0, 20), Position = UDim2.new(0, 18, 0, 12),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 202, TextTruncate = Enum.TextTruncate.AtEnd,
    })
    if sub ~= "" then
        make("TextLabel", {
            Parent = notif, Text = sub,
            TextColor3 = Theme.TextDim, Font = Enum.Font.Gotham, TextSize = 11,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -24, 0, 16), Position = UDim2.new(0, 18, 0, 32),
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 202, TextTruncate = Enum.TextTruncate.AtEnd,
        })
    end

    local prog = make("Frame", {
        Parent = notif, BackgroundColor3 = col, BackgroundTransparency = 0.55,
        Size = UDim2.new(1, -16, 0, 2), Position = UDim2.new(0, 8, 1, -5),
        BorderSizePixel = 0, ZIndex = 203,
    })
    corner(prog, 1)

    tween(notif, { Position = UDim2.new(1, -294, 1, -(yOff + notifH)) }, 0.35, Enum.EasingStyle.Back)
    tween(prog, { Size = UDim2.new(0, 0, 0, 2) }, dur - 0.35, Enum.EasingStyle.Linear)

    -- Border pulse on arrival
    task.delay(0.35, function()
        tween(notifStroke, { Transparency = 0.5 }, 0.25)
        task.delay(0.25, function() tween(notifStroke, { Transparency = 0 }, 0.25) end)
    end)

    task.delay(dur, function()
        tween(notif, {
            Position = UDim2.new(1, 20, 1, -(yOff + notifH)),
            BackgroundTransparency = 1,
        }, 0.25).Completed:Connect(function() notif:Destroy() end)
    end)
end

-- ════════════════════════════════════════════════
-- TAB
-- ════════════════════════════════════════════════
function Rift:Tab(config)
    config = config or {}
    local tabName = config.Name or config.name or "Tab"
    local tab = { Sections = {}, _lib = self }

    local btn = make("TextButton", {
        Parent = self.TabBtnHolder, Text = "",
        BackgroundColor3 = Theme.SurfaceHover, BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 34), BorderSizePixel = 0, ZIndex = 6,
        AutoButtonColor = false, ClipsDescendants = true,
    })
    corner(btn, 5)

    local indicator = make("Frame", {
        Parent = btn, Name = "Indicator",
        BackgroundColor3 = Theme.Accent, BackgroundTransparency = 1,
        Size = UDim2.new(0, 2, 0, 0),
        Position = UDim2.new(0, 0, 0.5, 8),
        BorderSizePixel = 0, ZIndex = 7,
    })
    corner(indicator, 1)

    local btnLabel = make("TextLabel", {
        Parent = btn, Name = "Label", Text = tabName,
        TextColor3 = Theme.TextDim, Font = Enum.Font.GothamMedium, TextSize = 12,
        BackgroundTransparency = 1, Size = UDim2.new(1, -12, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7,
    })

    local page = make("ScrollingFrame", {
        Parent = self.Content, BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0), BorderSizePixel = 0, ZIndex = 5, Visible = false,
        ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.Accent,
        ScrollBarImageTransparency = 0.5,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
    })

    local cols = make("Frame", {
        Parent = page, BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0, ZIndex = 5,
    })
    padding(cols, 12, 12, 12, 12)
    make("UIListLayout", {
        Parent = cols, FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 10),
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    tab._page = page; tab._cols = cols; tab._btn = btn

    local function activate()
        if self.ActiveTab and self.ActiveTab ~= tab then
            local prev = self.ActiveTab
            prev._page.Visible = false
            tween(prev._btn, { BackgroundTransparency = 1 }, 0.15)
            tween(prev._btn.Label, { TextColor3 = Theme.TextDim }, 0.15)
            tween(prev._btn.Indicator, {
                BackgroundTransparency = 1,
                Size = UDim2.new(0, 2, 0, 0),
                Position = UDim2.new(0, 0, 0.5, 8),
            }, 0.2)
        end
        self.ActiveTab = tab
        page.Visible = true

        -- Staggered section card reveal
        local delay = 0
        for _, col in ipairs(cols:GetChildren()) do
            if col:IsA("Frame") then
                for _, sec in ipairs(col:GetChildren()) do
                    if sec:IsA("Frame") then
                        sec.BackgroundTransparency = 1
                        local d = delay
                        task.delay(d, function()
                            tween(sec, { BackgroundTransparency = 0 }, 0.22, Enum.EasingStyle.Quart)
                        end)
                        delay = delay + 0.05
                    end
                end
            end
        end

        tween(btn, { BackgroundTransparency = 0.88 }, 0.15)
        tween(btnLabel, { TextColor3 = Theme.Text }, 0.15)
        tween(indicator, {
            BackgroundTransparency = 0,
            Size = UDim2.new(0, 2, 0, 16),
            Position = UDim2.new(0, 0, 0.5, -8),
        }, 0.25, Enum.EasingStyle.Back)
    end

    btn.MouseButton1Click:Connect(function()
        local mp = UserInputService:GetMouseLocation()
        local bp = btn.AbsolutePosition
        ripple(btn, mp.X - bp.X, mp.Y - bp.Y)
        activate()
    end)
    btn.MouseEnter:Connect(function()
        if self.ActiveTab ~= tab then
            tween(btn, { BackgroundTransparency = 0.93 }, 0.1)
            tween(btnLabel, { TextColor3 = Theme.Text }, 0.1)
        end
    end)
    btn.MouseLeave:Connect(function()
        if self.ActiveTab ~= tab then
            tween(btn, { BackgroundTransparency = 1 }, 0.1)
            tween(btnLabel, { TextColor3 = Theme.TextDim }, 0.1)
        end
    end)

    if #self.Tabs == 0 then activate() end
    table.insert(self.Tabs, tab)

    -- ── SECTION ──────────────────────────────────────────
    function tab:Section(cfg)
        cfg = cfg or {}
        local secName = cfg.Name or cfg.name or "Section"
        local side    = cfg.Side or cfg.side or "left"
        local colIdx  = side == "right" and 2 or 1

        local colFrame = self._cols:FindFirstChild("Col"..colIdx)
        if not colFrame then
            colFrame = make("Frame", {
                Parent = self._cols, Name = "Col"..colIdx,
                BackgroundTransparency = 1,
                Size = UDim2.new(0.5, -5, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BorderSizePixel = 0, ZIndex = 5, LayoutOrder = colIdx,
            })
            listLayout(colFrame, Enum.FillDirection.Vertical, 8)
        end

        local sec = { _lib = self._lib }

        local container = make("Frame", {
            Parent = colFrame, BackgroundColor3 = Theme.Surface,
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BorderSizePixel = 0, ZIndex = 6,
        })
        corner(container, 7)
        local secStroke = stroke(container, Theme.Border, 1)

        -- Section border brightens on hover
        container.MouseEnter:Connect(function()
            tween(secStroke, { Color = Theme.AccentDim }, 0.2)
        end)
        container.MouseLeave:Connect(function()
            tween(secStroke, { Color = Theme.Border }, 0.25)
        end)

        local header = make("Frame", {
            Parent = container, BackgroundColor3 = Theme.Background,
            Size = UDim2.new(1, 0, 0, 30), BorderSizePixel = 0, ZIndex = 7,
        })
        make("UICorner", { Parent = header, CornerRadius = UDim.new(0, 6) })
        make("Frame", {
            Parent = header, BackgroundColor3 = Theme.Background,
            Size = UDim2.new(1, 0, 0, 7), Position = UDim2.new(0, 0, 1, -7),
            BorderSizePixel = 0, ZIndex = 7,
        })
        local headerDot = make("Frame", {
            Parent = header, BackgroundColor3 = Theme.Accent,
            Size = UDim2.new(0, 4, 0, 4),
            Position = UDim2.new(0, 12, 0.5, -2),
            BorderSizePixel = 0, ZIndex = 8,
        })
        corner(headerDot, 4)
        make("TextLabel", {
            Parent = header, Text = secName,
            TextColor3 = Theme.TextDim, Font = Enum.Font.GothamMedium, TextSize = 11,
            BackgroundTransparency = 1, Size = UDim2.new(1, -26, 1, 0),
            Position = UDim2.new(0, 22, 0, 0),
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8,
        })

        local elemHolder = make("Frame", {
            Parent = container, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 0, 30),
            AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, ZIndex = 7,
        })
        listLayout(elemHolder, Enum.FillDirection.Vertical, 0)
        padding(elemHolder, 5, 9, 9, 9)
        sec._elemHolder = elemHolder

        -- ── TOGGLE ───────────────────────────────────────
        function sec:Toggle(opts)
            opts = opts or {}
            local name    = opts.Name or opts.name or "Toggle"
            local flag    = opts.Flag or opts.flag or name
            local default = opts.Default ~= nil and opts.Default or (opts.default ~= nil and opts.default or false)
            local cb      = opts.Callback or opts.callback or function() end
            local val     = default
            self._lib.Flags[flag] = val

            local row = make("TextButton", {
                Parent = self._elemHolder, Text = "", BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 32), BorderSizePixel = 0, ZIndex = 8,
                AutoButtonColor = false, ClipsDescendants = true,
            })
            local hover = make("Frame", {
                Parent = row, BackgroundColor3 = Theme.SurfaceHover, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0), BorderSizePixel = 0, ZIndex = 8,
            })
            corner(hover, 4)
            make("TextLabel", {
                Parent = row, Text = name, TextColor3 = Theme.Text,
                Font = Enum.Font.Gotham, TextSize = 12, BackgroundTransparency = 1,
                Size = UDim2.new(1, -52, 1, 0), Position = UDim2.new(0, 8, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9,
            })
            -- Glow halo behind pill
            local pillGlow = make("Frame", {
                Parent = row, BackgroundColor3 = Theme.Accent,
                BackgroundTransparency = 1,
                Size = UDim2.new(0, 42, 0, 25), Position = UDim2.new(1, -46, 0.5, -12),
                BorderSizePixel = 0, ZIndex = 8,
            })
            corner(pillGlow, 13)
            local pillBg = make("Frame", {
                Parent = row, BackgroundColor3 = Theme.Border,
                Size = UDim2.new(0, 34, 0, 17), Position = UDim2.new(1, -42, 0.5, -8),
                BorderSizePixel = 0, ZIndex = 9,
            })
            corner(pillBg, 9)
            local pillDot = make("Frame", {
                Parent = pillBg, BackgroundColor3 = Theme.TextMuted,
                Size = UDim2.new(0, 11, 0, 11), Position = UDim2.new(0, 3, 0.5, -5),
                BorderSizePixel = 0, ZIndex = 10,
            })
            corner(pillDot, 6)

            local function setState(v, instant)
                val = v; self._lib.Flags[flag] = val
                if val then
                    if instant then
                        pillBg.BackgroundColor3   = Theme.Accent
                        pillDot.Position          = UDim2.new(0, 20, 0.5, -5)
                        pillDot.BackgroundColor3  = Theme.White
                        pillDot.Size              = UDim2.new(0, 13, 0, 13)
                        pillGlow.BackgroundTransparency = 0.82
                    else
                        tween(pillBg,   { BackgroundColor3 = Theme.Accent }, 0.2)
                        tween(pillDot,  { Position = UDim2.new(0, 20, 0.5, -6), BackgroundColor3 = Theme.White, Size = UDim2.new(0, 13, 0, 13) }, 0.2, Enum.EasingStyle.Back)
                        tween(pillGlow, { BackgroundTransparency = 0.82 }, 0.2)
                    end
                else
                    if instant then
                        pillBg.BackgroundColor3   = Theme.Border
                        pillDot.Position          = UDim2.new(0, 3, 0.5, -5)
                        pillDot.BackgroundColor3  = Theme.TextMuted
                        pillDot.Size              = UDim2.new(0, 11, 0, 11)
                        pillGlow.BackgroundTransparency = 1
                    else
                        tween(pillBg,   { BackgroundColor3 = Theme.Border }, 0.2)
                        tween(pillDot,  { Position = UDim2.new(0, 3, 0.5, -5), BackgroundColor3 = Theme.TextMuted, Size = UDim2.new(0, 11, 0, 11) }, 0.18)
                        tween(pillGlow, { BackgroundTransparency = 1 }, 0.2)
                    end
                end
                cb(val)
            end
            setState(default, true)

            row.MouseButton1Click:Connect(function()
                local mp = UserInputService:GetMouseLocation()
                local rp = row.AbsolutePosition
                ripple(row, mp.X - rp.X, mp.Y - rp.Y)
                setState(not val)
            end)
            row.MouseEnter:Connect(function() tween(hover, { BackgroundTransparency = 0.85 }, 0.1) end)
            row.MouseLeave:Connect(function() tween(hover, { BackgroundTransparency = 1 }, 0.1) end)

            return { Set = function(v) setState(v) end, Get = function() return val end }
        end

        -- ── SLIDER ───────────────────────────────────────
        function sec:Slider(opts)
            opts = opts or {}
            local name     = opts.Name or opts.name or "Slider"
            local flag     = opts.Flag or opts.flag or name
            local min      = opts.Min or opts.min or 0
            local max      = opts.Max or opts.max or 100
            local default  = opts.Default or opts.default or min
            local suffix   = opts.Suffix or opts.suffix or ""
            local decimals = opts.Decimals or opts.decimals or 0
            local cb       = opts.Callback or opts.callback or function() end
            local val      = default
            self._lib.Flags[flag] = val

            local wrap = make("Frame", {
                Parent = self._elemHolder, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 44), BorderSizePixel = 0, ZIndex = 8,
            })
            local hover = make("Frame", {
                Parent = wrap, BackgroundColor3 = Theme.SurfaceHover, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0), BorderSizePixel = 0, ZIndex = 8,
            })
            corner(hover, 4)
            make("TextLabel", {
                Parent = wrap, Text = name, TextColor3 = Theme.Text,
                Font = Enum.Font.Gotham, TextSize = 12, BackgroundTransparency = 1,
                Size = UDim2.new(0.7, 0, 0, 20), Position = UDim2.new(0, 8, 0, 4),
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9,
            })
            local valLabel = make("TextLabel", {
                Parent = wrap, Text = tostring(val)..suffix,
                TextColor3 = Theme.Accent, Font = Enum.Font.GothamBold, TextSize = 11,
                BackgroundTransparency = 1,
                Size = UDim2.new(0.3, -8, 0, 20), Position = UDim2.new(0.7, 0, 0, 4),
                TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 9,
            })
            local trackBg = make("Frame", {
                Parent = wrap, BackgroundColor3 = Theme.Border,
                Size = UDim2.new(1, -16, 0, 3), Position = UDim2.new(0, 8, 0, 32),
                BorderSizePixel = 0, ZIndex = 9,
            })
            corner(trackBg, 2)
            local trackFill = make("Frame", {
                Parent = trackBg, BackgroundColor3 = Theme.Accent,
                Size = UDim2.new((val-min)/(max-min), 0, 1, 0),
                BorderSizePixel = 0, ZIndex = 10,
            })
            corner(trackFill, 2)
            -- Gradient glow on fill
            make("UIGradient", {
                Parent = trackFill,
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Theme.AccentDim),
                    ColorSequenceKeypoint.new(1, Theme.AccentGlow),
                }),
            })
            local handle = make("Frame", {
                Parent = trackBg, BackgroundColor3 = Theme.White,
                Size = UDim2.new(0, 12, 0, 12),
                Position = UDim2.new((val-min)/(max-min), -6, 0.5, -6),
                BorderSizePixel = 0, ZIndex = 11,
            })
            corner(handle, 6)
            local handleStroke = stroke(handle, Theme.Accent, 1)

            local dragging = false
            local function updateSlider(x)
                local pct = math.clamp((x - trackBg.AbsolutePosition.X) / trackBg.AbsoluteSize.X, 0, 1)
                local raw = min + (max - min) * pct
                local mult = 10^decimals
                val = math.floor(raw * mult + 0.5) / mult
                self._lib.Flags[flag] = val
                local dv = decimals == 0 and tostring(math.floor(val)) or string.format("%."..decimals.."f", val)
                valLabel.Text = dv..suffix
                trackFill.Size = UDim2.new(pct, 0, 1, 0)
                handle.Position = UDim2.new(pct, dragging and -8 or -6, 0.5, dragging and -8 or -6)
                cb(val)
            end
            local sliderBtn = make("TextButton", {
                Parent = trackBg, Text = "", BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 18), Position = UDim2.new(0, 0, 0, -9),
                BorderSizePixel = 0, ZIndex = 12, AutoButtonColor = false,
            })
            sliderBtn.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = true
                    updateSlider(inp.Position.X)
                    -- Handle grows on grab
                    tween(handle, { Size = UDim2.new(0, 16, 0, 16) }, 0.14, Enum.EasingStyle.Back)
                    tween(handleStroke, { Color = Theme.AccentGlow, Thickness = 2 }, 0.12)
                end
            end)
            UserInputService.InputChanged:Connect(function(inp)
                if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
                    updateSlider(inp.Position.X)
                end
            end)
            UserInputService.InputEnded:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
                    dragging = false
                    local pct = (val-min)/(max-min)
                    handle.Position = UDim2.new(pct, -6, 0.5, -6)
                    tween(handle, { Size = UDim2.new(0, 12, 0, 12) }, 0.15)
                    tween(handleStroke, { Color = Theme.Accent, Thickness = 1 }, 0.15)
                end
            end)
            wrap.MouseEnter:Connect(function()
                tween(hover, { BackgroundTransparency = 0.85 }, 0.1)
                tween(handleStroke, { Color = Theme.AccentGlow }, 0.15)
            end)
            wrap.MouseLeave:Connect(function()
                if not dragging then
                    tween(hover, { BackgroundTransparency = 1 }, 0.1)
                    tween(handleStroke, { Color = Theme.Accent }, 0.15)
                end
            end)

            return {
                Set = function(v)
                    val = math.clamp(v, min, max)
                    local pct = (val-min)/(max-min)
                    trackFill.Size = UDim2.new(pct, 0, 1, 0)
                    handle.Position = UDim2.new(pct, -6, 0.5, -6)
                    valLabel.Text = tostring(val)..suffix
                    self._lib.Flags[flag] = val; cb(val)
                end,
                Get = function() return val end,
            }
        end

        -- ── DROPDOWN ─────────────────────────────────────
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
                Parent = self._elemHolder, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 44), BorderSizePixel = 0, ZIndex = 8,
            })
            make("TextLabel", {
                Parent = wrap, Text = name, TextColor3 = Theme.TextDim,
                Font = Enum.Font.Gotham, TextSize = 10, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 8, 0, 2),
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9,
            })
            local btn = make("TextButton", {
                Parent = wrap, Text = "", BackgroundColor3 = Theme.Background,
                Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 0, 18),
                BorderSizePixel = 0, ZIndex = 9, AutoButtonColor = false,
                ClipsDescendants = true,
            })
            corner(btn, 5)
            local btnStroke = stroke(btn, Theme.Border, 1)
            local selLabel = make("TextLabel", {
                Parent = btn, Text = multi and "None" or tostring(default),
                TextColor3 = Theme.Text, Font = Enum.Font.Gotham, TextSize = 11,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -28, 1, 0), Position = UDim2.new(0, 8, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 10, TextTruncate = Enum.TextTruncate.AtEnd,
            })
            local arrow = make("TextLabel", {
                Parent = btn, Text = "⌄", TextColor3 = Theme.TextDim,
                Font = Enum.Font.GothamBold, TextSize = 14, BackgroundTransparency = 1,
                Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(1, -24, 0, 0), ZIndex = 10,
            })

            local panel = make("Frame", {
                Parent = self._lib.ScreenGui, BackgroundColor3 = Theme.Surface,
                Size = UDim2.new(0, 0, 0, 0), BorderSizePixel = 0, ZIndex = 500, Visible = false,
                ClipsDescendants = true,
            })
            corner(panel, 6); stroke(panel, Theme.Accent, 1)
            local panelList = make("Frame", {
                Parent = panel, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BorderSizePixel = 0, ZIndex = 501,
            })
            listLayout(panelList, Enum.FillDirection.Vertical, 2)
            padding(panelList, 4, 4, 4, 4)

            local optBtns = {}
            local function refreshDisplay()
                if multi then
                    local j = table.concat(selected, ", ")
                    selLabel.Text = j == "" and "None" or j
                else selLabel.Text = tostring(selected) end
            end
            local function closeDropdown()
                isOpen = false
                tween(panel, { Size = UDim2.new(0, panel.Size.X.Offset, 0, 0) }, 0.15).Completed:Connect(function()
                    panel.Visible = false
                end)
                tween(arrow, { Rotation = 0 }, 0.15)
                tween(btnStroke, { Color = Theme.Border }, 0.15)
            end
            local function buildOptions()
                for _, ob in ipairs(optBtns) do ob:Destroy() end
                optBtns = {}
                for _, item in ipairs(items) do
                    local ob = make("TextButton", {
                        Parent = panelList, Text = "  "..tostring(item),
                        TextColor3 = Theme.Text, Font = Enum.Font.Gotham, TextSize = 12,
                        BackgroundColor3 = Theme.Background, BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 26), BorderSizePixel = 0,
                        ZIndex = 502, AutoButtonColor = false,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ClipsDescendants = true,
                    })
                    corner(ob, 4); table.insert(optBtns, ob)
                    ob.MouseEnter:Connect(function() tween(ob, { BackgroundTransparency = 0.8 }, 0.1) end)
                    ob.MouseLeave:Connect(function() tween(ob, { BackgroundTransparency = 1 }, 0.1) end)
                    ob.MouseButton1Click:Connect(function()
                        local mp = UserInputService:GetMouseLocation()
                        local op = ob.AbsolutePosition
                        ripple(ob, mp.X - op.X, mp.Y - op.Y)
                        if multi then
                            local found = false
                            for i, v in ipairs(selected) do if v == item then found = i break end end
                            if found then table.remove(selected, found) else table.insert(selected, item) end
                            self._lib.Flags[flag] = selected; cb(selected); refreshDisplay()
                        else
                            selected = item; self._lib.Flags[flag] = selected; cb(selected)
                            refreshDisplay(); closeDropdown()
                        end
                    end)
                end
            end
            buildOptions()
            local function openDropdown()
                local abs = btn.AbsolutePosition; local sz = btn.AbsoluteSize
                local targetH = math.min(#items * 30 + 8, 180)
                panel.Size = UDim2.new(0, sz.X, 0, 0)
                panel.Position = UDim2.new(0, abs.X, 0, abs.Y + sz.Y + 4)
                panel.Visible = true; isOpen = true
                tween(panel, { Size = UDim2.new(0, sz.X, 0, targetH) }, 0.22, Enum.EasingStyle.Back)
                tween(arrow, { Rotation = 180 }, 0.15)
                tween(btnStroke, { Color = Theme.Accent }, 0.15)
            end
            btn.MouseButton1Click:Connect(function()
                local mp = UserInputService:GetMouseLocation()
                local bp = btn.AbsolutePosition
                ripple(btn, mp.X - bp.X, mp.Y - bp.Y)
                if isOpen then closeDropdown() else openDropdown() end
            end)
            UserInputService.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 and isOpen then
                    local mx, my = inp.Position.X, inp.Position.Y
                    local pa, ps = panel.AbsolutePosition, panel.AbsoluteSize
                    if mx < pa.X or mx > pa.X+ps.X or my < pa.Y or my > pa.Y+ps.Y then
                        closeDropdown()
                    end
                end
            end)
            refreshDisplay()

            return {
                Set = function(v)
                    selected = multi and (type(v)=="table" and v or {v}) or v
                    self._lib.Flags[flag] = selected; refreshDisplay(); cb(selected)
                end,
                SetItems = function(newItems)
                    items = newItems; buildOptions()
                    if #items > 0 and not multi then selected = items[1]; refreshDisplay() end
                end,
                Get = function() return selected end,
            }
        end

        -- ── BUTTON ───────────────────────────────────────
        function sec:Button(opts)
            opts = opts or {}
            local name = opts.Name or opts.name or "Button"
            local cb   = opts.Callback or opts.callback or function() end
            local btn = make("TextButton", {
                Parent = self._elemHolder, Text = "", BackgroundColor3 = Theme.AccentDim,
                Size = UDim2.new(1, 0, 0, 30), BorderSizePixel = 0, ZIndex = 8,
                AutoButtonColor = false, ClipsDescendants = true,
            })
            corner(btn, 5)
            make("UIGradient", {
                Parent = btn, Rotation = 90,
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Theme.Accent),
                    ColorSequenceKeypoint.new(1, Theme.AccentDim),
                }),
            })
            make("TextLabel", {
                Parent = btn, Text = name, TextColor3 = Theme.White,
                Font = Enum.Font.GothamBold, TextSize = 11,
                BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), ZIndex = 9,
            })
            btn.MouseEnter:Connect(function()
                tween(btn, { BackgroundColor3 = Theme.Accent }, 0.1)
            end)
            btn.MouseLeave:Connect(function()
                tween(btn, { BackgroundColor3 = Theme.AccentDim }, 0.12)
            end)
            btn.MouseButton1Down:Connect(function()
                -- Squish down
                tween(btn, { BackgroundColor3 = Theme.AccentGlow, Size = UDim2.new(1, -4, 0, 27) }, 0.07)
            end)
            btn.MouseButton1Up:Connect(function()
                -- Spring back
                tween(btn, { BackgroundColor3 = Theme.Accent, Size = UDim2.new(1, 0, 0, 30) }, 0.18, Enum.EasingStyle.Back)
            end)
            btn.MouseButton1Click:Connect(function()
                local mp = UserInputService:GetMouseLocation()
                local bp = btn.AbsolutePosition
                ripple(btn, mp.X - bp.X, mp.Y - bp.Y)
                cb()
            end)
        end

        -- ── KEYBIND ──────────────────────────────────────
        function sec:Keybind(opts)
            opts = opts or {}
            local name    = opts.Name or opts.name or "Keybind"
            local flag    = opts.Flag or opts.flag or name
            local default = opts.Default or opts.default or Enum.KeyCode.Unknown
            local mode    = opts.Mode or opts.mode or "Toggle"
            local cb      = opts.Callback or opts.callback or function() end
            local boundKey = default; local active = false; local binding = false
            self._lib.Flags[flag] = { Key = boundKey, Active = active, Mode = mode }

            local row = make("Frame", {
                Parent = self._elemHolder, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 32), BorderSizePixel = 0, ZIndex = 8,
            })
            local hover = make("Frame", {
                Parent = row, BackgroundColor3 = Theme.SurfaceHover, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0), BorderSizePixel = 0, ZIndex = 8,
            })
            corner(hover, 4)
            make("TextLabel", {
                Parent = row, Text = name, TextColor3 = Theme.Text,
                Font = Enum.Font.Gotham, TextSize = 12, BackgroundTransparency = 1,
                Size = UDim2.new(0.6, 0, 1, 0), Position = UDim2.new(0, 8, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9,
            })
            local keyBtn = make("TextButton", {
                Parent = row, BackgroundColor3 = Theme.Background,
                Size = UDim2.new(0, 68, 0, 20), Position = UDim2.new(1, -76, 0.5, -10),
                BorderSizePixel = 0, ZIndex = 9, AutoButtonColor = false,
                ClipsDescendants = true,
            })
            corner(keyBtn, 4)
            local keyStroke = stroke(keyBtn, Theme.Border, 1)
            local keyLabel = make("TextLabel", {
                Parent = keyBtn,
                Text = tostring(boundKey):gsub("Enum.KeyCode.", ""),
                TextColor3 = Theme.Accent, Font = Enum.Font.GothamBold, TextSize = 10,
                BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), ZIndex = 10,
            })
            local modeLabel = make("TextLabel", {
                Parent = row, Text = mode, TextColor3 = Theme.TextMuted,
                Font = Enum.Font.Gotham, TextSize = 9, BackgroundTransparency = 1,
                Size = UDim2.new(0, 68, 0, 10), Position = UDim2.new(1, -76, 1, -10), ZIndex = 9,
            })
            local modes = {"Toggle","Hold","Always"}; local modeIdx = 1
            for i, m in ipairs(modes) do if m == mode then modeIdx = i end end

            keyBtn.MouseButton2Click:Connect(function()
                modeIdx = modeIdx % #modes + 1; mode = modes[modeIdx]; modeLabel.Text = mode
                tween(keyStroke, { Color = Theme.Accent }, 0.1)
                task.delay(0.2, function() tween(keyStroke, { Color = Theme.Border }, 0.15) end)
                self._lib.Flags[flag].Mode = mode
                if mode == "Always" then active = true; cb(true) else active = false; cb(false) end
            end)
            keyBtn.MouseButton1Click:Connect(function()
                binding = true; keyLabel.Text = "..."
                tween(keyBtn, { BackgroundColor3 = Theme.AccentDim }, 0.1)
                tween(keyStroke, { Color = Theme.Accent }, 0.1)
            end)
            UserInputService.InputBegan:Connect(function(inp, gpe)
                if binding then
                    if inp.KeyCode ~= Enum.KeyCode.Unknown then boundKey = inp.KeyCode
                    elseif inp.UserInputType ~= Enum.UserInputType.MouseButton1 then boundKey = inp.UserInputType
                    end
                    binding = false
                    keyLabel.Text = tostring(boundKey):gsub("Enum.KeyCode.",""):gsub("Enum.UserInputType.","")
                    tween(keyBtn, { BackgroundColor3 = Theme.Background }, 0.1)
                    tween(keyStroke, { Color = Theme.Border }, 0.15)
                    self._lib.Flags[flag].Key = boundKey; return
                end
                if gpe then return end
                local k = inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode or inp.UserInputType
                if k == boundKey then
                    if mode == "Toggle" then
                        active = not active; cb(active)
                        self._lib.Flags[flag].Active = active
                        tween(keyBtn, { BackgroundColor3 = active and Theme.AccentDim or Theme.Background }, 0.12)
                        tween(keyLabel, { TextColor3 = active and Theme.White or Theme.Accent }, 0.12)
                        tween(keyStroke, { Color = active and Theme.Accent or Theme.Border }, 0.12)
                        if active then
                            local mp = UserInputService:GetMouseLocation()
                            local kp = keyBtn.AbsolutePosition
                            ripple(keyBtn, mp.X - kp.X, mp.Y - kp.Y)
                        end
                    elseif mode == "Hold" then
                        active = true; cb(true); self._lib.Flags[flag].Active = true
                        tween(keyBtn, { BackgroundColor3 = Theme.AccentDim }, 0.1)
                        tween(keyStroke, { Color = Theme.Accent }, 0.1)
                    end
                end
            end)
            UserInputService.InputEnded:Connect(function(inp)
                if mode == "Hold" then
                    local k = inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode or inp.UserInputType
                    if k == boundKey then
                        active = false; cb(false); self._lib.Flags[flag].Active = false
                        tween(keyBtn, { BackgroundColor3 = Theme.Background }, 0.1)
                        tween(keyStroke, { Color = Theme.Border }, 0.15)
                    end
                end
            end)
            row.MouseEnter:Connect(function() tween(hover, { BackgroundTransparency = 0.85 }, 0.1) end)
            row.MouseLeave:Connect(function() tween(hover, { BackgroundTransparency = 1 }, 0.1) end)
            if mode == "Always" then active = true; cb(true) end
            return { Get = function() return active end, GetKey = function() return boundKey end }
        end

        -- ── LABEL ────────────────────────────────────────
        function sec:Label(opts)
            opts = opts or {}
            local text  = opts.Text or opts.text or opts.Name or opts.name or ""
            local color = opts.Color or opts.color or Theme.TextDim
            local lbl = make("TextLabel", {
                Parent = self._elemHolder, Text = text, TextColor3 = color,
                Font = Enum.Font.Gotham, TextSize = 11, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 8, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, TextWrapped = true,
            })
            return { Set = function(v) lbl.Text = v end, SetColor = function(v) lbl.TextColor3 = v end }
        end

        -- ── SEPARATOR ────────────────────────────────────
        function sec:Separator()
            local sep = make("Frame", {
                Parent = self._elemHolder, BackgroundColor3 = Theme.Border,
                Size = UDim2.new(0, 0, 0, 1), BorderSizePixel = 0, ZIndex = 8,
            })
            task.delay(0.05, function()
                tween(sep, { Size = UDim2.new(1, -16, 0, 1) }, 0.3, Enum.EasingStyle.Quart)
            end)
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
    for _, kill in ipairs(self._loopKills) do pcall(kill) end
    for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
    self.ScreenGui:Destroy()
    lockMouse()
end

return Rift
