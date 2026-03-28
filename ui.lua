-- ██████╗ ██╗███████╗████████╗    ██╗   ██╗██╗
-- ██╔══██╗██║██╔════╝╚══██╔══╝    ██║   ██║██║
-- ██████╔╝██║█████╗     ██║       ██║   ██║██║
-- ██╔══██╗██║██╔══╝     ██║       ██║   ██║██║
-- ██║  ██║██║██║        ██║       ╚██████╔╝██║
-- ╚═╝  ╚═╝╚═╝╚═╝        ╚═╝        ╚═════╝ ╚═╝
-- Rift UI Library — v1.1 (shadow fix)

local Rift = {}
Rift.__index = Rift

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local CoreGui          = game:GetService("CoreGui")

local lp = Players.LocalPlayer

local Theme = {
    Background   = Color3.fromRGB(10,  10,  12),
    Surface      = Color3.fromRGB(16,  16,  20),
    SurfaceHover = Color3.fromRGB(22,  22,  28),
    Border       = Color3.fromRGB(35,  35,  45),
    Accent       = Color3.fromRGB(99,  102, 241),
    AccentDim    = Color3.fromRGB(55,  57,  140),
    AccentGlow   = Color3.fromRGB(139, 92,  246),
    Text         = Color3.fromRGB(230, 230, 240),
    TextDim      = Color3.fromRGB(120, 120, 140),
    TextMuted    = Color3.fromRGB(65,  65,  80),
    Success      = Color3.fromRGB(52,  211, 153),
    Warning      = Color3.fromRGB(251, 191, 36),
    Danger       = Color3.fromRGB(239, 68,  68),
    White        = Color3.fromRGB(255, 255, 255),
    Black        = Color3.fromRGB(0,   0,   0),
}

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

    -- Shadow — stored as self._shadowHolder so Toggle() can hide it
    local shadowHolder = make("Frame", {
        Parent = sg,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 724, 0, 464),
        Position = UDim2.new(0.5, -362, 0.5, -232),
        ZIndex = 1,
        Visible = false,   -- starts hidden, shown after open anim
    })
    self._shadowHolder = shadowHolder

    make("ImageLabel", {
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

    make("ImageLabel", {
        Parent = win, BackgroundTransparency = 1,
        Image = "rbxassetid://9968344807", ImageTransparency = 0.94,
        Size = UDim2.new(1, 0, 1, 0), ZIndex = 100,
        ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.new(0, 128, 0, 128),
    })

    local accentLine = make("Frame", {
        Parent = win, BackgroundColor3 = Theme.Accent,
        Size = UDim2.new(0, 0, 0, 2), BorderSizePixel = 0, ZIndex = 10,
    })
    tween(accentLine, { Size = UDim2.new(1, 0, 0, 2) }, 0.6, Enum.EasingStyle.Quart)

    local topGlow = make("Frame", {
        Parent = win, BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 0.88,
        Size = UDim2.new(1, 0, 0, 60), BorderSizePixel = 0, ZIndex = 3,
    })
    make("UIGradient", {
        Parent = topGlow, Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1),
        }),
    })

    local titlebar = make("Frame", {
        Parent = win, BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 52),
        Position = UDim2.new(0, 0, 0, 2), ZIndex = 5,
    })

    local dotFrame = make("Frame", {
        Parent = titlebar, BackgroundTransparency = 1,
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(0, 16, 0.5, -14), ZIndex = 6,
    })
    for i, col in ipairs({ Theme.Accent, Theme.AccentGlow, Color3.fromRGB(236, 72, 153) }) do
        make("Frame", {
            Parent = dotFrame, BackgroundColor3 = col,
            Size = UDim2.new(0, 7, 0, 7),
            Position = UDim2.new(0, (i-1)*10, 0, i==2 and 10 or i==3 and 5 or 0),
            BorderSizePixel = 0, ZIndex = 7,
        })
    end

    make("TextLabel", {
        Parent = titlebar, Text = self.Title,
        TextColor3 = Theme.Text, Font = Enum.Font.GothamBold, TextSize = 15,
        BackgroundTransparency = 1, Size = UDim2.new(0, 200, 1, 0),
        Position = UDim2.new(0, 52, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
    })
    if self.Subtitle ~= "" then
        make("TextLabel", {
            Parent = titlebar, Text = "  ·  " .. self.Subtitle,
            TextColor3 = Theme.TextDim, Font = Enum.Font.Gotham, TextSize = 12,
            BackgroundTransparency = 1, Size = UDim2.new(0, 300, 1, 0),
            Position = UDim2.new(0, 175, 0, 0),
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
        })
    end
    make("TextLabel", {
        Parent = titlebar,
        Text = tostring(self.ToggleKey):gsub("Enum.KeyCode.", "") .. " to toggle",
        TextColor3 = Theme.TextMuted, Font = Enum.Font.Gotham, TextSize = 10,
        BackgroundTransparency = 1, Size = UDim2.new(0, 150, 1, 0),
        Position = UDim2.new(1, -166, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6,
    })
    make("Frame", {
        Parent = win, BackgroundColor3 = Theme.Border,
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 0, 53), BorderSizePixel = 0, ZIndex = 5,
    })

    local sidebar = make("Frame", {
        Parent = win, BackgroundColor3 = Theme.Surface,
        Size = UDim2.new(0, 155, 1, -54),
        Position = UDim2.new(0, 0, 0, 54), BorderSizePixel = 0, ZIndex = 4,
    })
    make("Frame", {
        Parent = sidebar, BackgroundColor3 = Theme.Border,
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, -1, 0, 0), BorderSizePixel = 0, ZIndex = 5,
    })

    local tabBtnHolder = make("Frame", {
        Parent = sidebar, BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, -12),
        Position = UDim2.new(0, 0, 0, 12), ZIndex = 5,
    })
    listLayout(tabBtnHolder, Enum.FillDirection.Vertical, 2)
    padding(tabBtnHolder, 0, 0, 8, 8)
    self.TabBtnHolder = tabBtnHolder

    local content = make("Frame", {
        Parent = win, BackgroundTransparency = 1,
        Size = UDim2.new(1, -155, 1, -54),
        Position = UDim2.new(0, 155, 0, 54),
        BorderSizePixel = 0, ZIndex = 4, ClipsDescendants = true,
    })
    self.Content = content

    -- Dragging
    local dragging, dragStart, startPos = false, nil, nil
    titlebar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = inp.Position; startPos = win.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local d = inp.Position - dragStart
            win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
            shadowHolder.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X+2, startPos.Y.Scale, startPos.Y.Offset+d.Y+2)
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

    -- Open animation — reveal shadow only after window is done
    win.Size = UDim2.new(0, 0, 0, 0)
    win.Position = UDim2.new(0.5, 0, 0.5, 0)
    win.BackgroundTransparency = 1
    tween(win, {
        Size = UDim2.new(0, 720, 0, 460),
        Position = UDim2.new(0.5, -360, 0.5, -230),
        BackgroundTransparency = 0,
    }, 0.35, Enum.EasingStyle.Back).Completed:Connect(function()
        shadowHolder.Visible = true
    end)

    return self
end

-- ════════════════════════════════════════════════
-- TOGGLE  ← shadow fix: hide/show shadowHolder
-- ════════════════════════════════════════════════
function Rift:Toggle()
    self.Open = not self.Open
    local win = self.Window
    local sh  = self._shadowHolder

    if self.Open then
        win.Visible = true
        sh.Visible  = true
        unlockMouse()
        tween(win, { BackgroundTransparency = 0 }, 0.2)
    else
        sh.Visible = false   -- ← gone immediately, no leftover glow
        tween(win, { BackgroundTransparency = 1 }, 0.18).Completed:Connect(function()
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

    local yOff = 20
    for _, v in ipairs(sg:GetChildren()) do
        if v.Name == "RiftNotif" then yOff = yOff + v.AbsoluteSize.Y + 8 end
    end

    local notif = make("Frame", {
        Parent = sg, Name = "RiftNotif",
        BackgroundColor3 = Theme.Surface,
        Size = UDim2.new(0, 280, 0, sub ~= "" and 56 or 42),
        Position = UDim2.new(1, 10, 1, -(yOff + 56)),
        BorderSizePixel = 0, ZIndex = 200,
    })
    corner(notif, 8); stroke(notif, Theme.Border, 1)

    local bar = make("Frame", {
        Parent = notif, BackgroundColor3 = col,
        Size = UDim2.new(0, 3, 1, -12),
        Position = UDim2.new(0, 6, 0, 6),
        BorderSizePixel = 0, ZIndex = 201,
    })
    corner(bar, 2)

    make("TextLabel", {
        Parent = notif, Text = msg,
        TextColor3 = Theme.Text, Font = Enum.Font.GothamBold, TextSize = 13,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -24, 0, 20), Position = UDim2.new(0, 18, 0, 10),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 202, TextTruncate = Enum.TextTruncate.AtEnd,
    })
    if sub ~= "" then
        make("TextLabel", {
            Parent = notif, Text = sub,
            TextColor3 = Theme.TextDim, Font = Enum.Font.Gotham, TextSize = 11,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -24, 0, 16), Position = UDim2.new(0, 18, 0, 30),
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 202, TextTruncate = Enum.TextTruncate.AtEnd,
        })
    end

    local prog = make("Frame", {
        Parent = notif, BackgroundColor3 = col, BackgroundTransparency = 0.6,
        Size = UDim2.new(1, -14, 0, 2), Position = UDim2.new(0, 7, 1, -4),
        BorderSizePixel = 0, ZIndex = 203,
    })
    corner(prog, 1)

    tween(notif, { Position = UDim2.new(1, -290, 1, -(yOff+56)) }, 0.3, Enum.EasingStyle.Back)
    tween(prog, { Size = UDim2.new(0, 0, 0, 2) }, dur - 0.3, Enum.EasingStyle.Linear)
    task.delay(dur, function()
        tween(notif, { Position = UDim2.new(1, 10, 1, -(yOff+56)) }, 0.25).Completed:Connect(function()
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
    local tab = { Sections = {}, _lib = self }

    local btn = make("TextButton", {
        Parent = self.TabBtnHolder, Text = "",
        BackgroundColor3 = Theme.Background, BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 36), BorderSizePixel = 0, ZIndex = 6, AutoButtonColor = false,
    })
    corner(btn, 6)

    local indicator = make("Frame", {
        Parent = btn, Name = "Indicator",
        BackgroundColor3 = Theme.Accent, BackgroundTransparency = 1,
        Size = UDim2.new(0, 3, 0, 18), Position = UDim2.new(0, -3, 0.5, -9),
        BorderSizePixel = 0, ZIndex = 7,
    })
    corner(indicator, 2)

    local btnLabel = make("TextLabel", {
        Parent = btn, Name = "Label", Text = tabName,
        TextColor3 = Theme.TextDim, Font = Enum.Font.GothamMedium, TextSize = 13,
        BackgroundTransparency = 1, Size = UDim2.new(1, -12, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7,
    })

    local page = make("ScrollingFrame", {
        Parent = self.Content, BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0), BorderSizePixel = 0, ZIndex = 5, Visible = false,
        ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Accent,
        ScrollBarImageTransparency = 0.4,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
    })

    local cols = make("Frame", {
        Parent = page, BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0, ZIndex = 5,
    })
    padding(cols, 14, 14, 14, 14)
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
            tween(prev._btn.Indicator, { BackgroundTransparency = 1 }, 0.15)
        end
        self.ActiveTab = tab; page.Visible = true
        tween(btn, { BackgroundTransparency = 0.85 }, 0.15)
        tween(btnLabel, { TextColor3 = Theme.Text }, 0.15)
        tween(indicator, { BackgroundTransparency = 0 }, 0.15)
    end

    btn.MouseButton1Click:Connect(activate)
    btn.MouseEnter:Connect(function()
        if self.ActiveTab ~= tab then
            tween(btn, { BackgroundTransparency = 0.92 }, 0.1)
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
        corner(container, 8); stroke(container, Theme.Border, 1)

        local header = make("Frame", {
            Parent = container, BackgroundColor3 = Theme.Background,
            Size = UDim2.new(1, 0, 0, 32), BorderSizePixel = 0, ZIndex = 7,
        })
        make("UICorner", { Parent = header, CornerRadius = UDim.new(0, 7) })
        make("Frame", {   -- covers bottom rounded corners of header
            Parent = header, BackgroundColor3 = Theme.Background,
            Size = UDim2.new(1, 0, 0, 8), Position = UDim2.new(0, 0, 1, -8),
            BorderSizePixel = 0, ZIndex = 7,
        })
        make("TextLabel", {
            Parent = header, Text = secName:upper(),
            TextColor3 = Theme.Accent, Font = Enum.Font.GothamBold, TextSize = 10,
            BackgroundTransparency = 1, Size = UDim2.new(1, -14, 1, 0),
            Position = UDim2.new(0, 14, 0, 0),
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8,
        })
        make("Frame", {
            Parent = header, BackgroundColor3 = Theme.Accent,
            Size = UDim2.new(0, 30, 0, 2), Position = UDim2.new(0, 14, 1, -2),
            BorderSizePixel = 0, ZIndex = 8,
        })

        local elemHolder = make("Frame", {
            Parent = container, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 0, 32),
            AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, ZIndex = 7,
        })
        listLayout(elemHolder, Enum.FillDirection.Vertical, 0)
        padding(elemHolder, 6, 10, 10, 10)
        sec._elemHolder = elemHolder

        -- TOGGLE
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
                Size = UDim2.new(1, 0, 0, 32), BorderSizePixel = 0, ZIndex = 8, AutoButtonColor = false,
            })
            local hover = make("Frame", {
                Parent = row, BackgroundColor3 = Theme.SurfaceHover, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0), BorderSizePixel = 0, ZIndex = 8,
            })
            corner(hover, 5)
            make("TextLabel", {
                Parent = row, Text = name, TextColor3 = Theme.Text,
                Font = Enum.Font.Gotham, TextSize = 13, BackgroundTransparency = 1,
                Size = UDim2.new(1, -52, 1, 0), Position = UDim2.new(0, 8, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9,
            })
            local pillBg = make("Frame", {
                Parent = row, BackgroundColor3 = Theme.Border,
                Size = UDim2.new(0, 36, 0, 18), Position = UDim2.new(1, -44, 0.5, -9),
                BorderSizePixel = 0, ZIndex = 9,
            })
            corner(pillBg, 9)
            local pillDot = make("Frame", {
                Parent = pillBg, BackgroundColor3 = Theme.TextMuted,
                Size = UDim2.new(0, 12, 0, 12), Position = UDim2.new(0, 3, 0.5, -6),
                BorderSizePixel = 0, ZIndex = 10,
            })
            corner(pillDot, 6)

            local function setState(v)
                val = v; self._lib.Flags[flag] = val
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

            return { Set = setState, Get = function() return val end }
        end

        -- SLIDER
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
                Size = UDim2.new(1, 0, 0, 42), BorderSizePixel = 0, ZIndex = 8,
            })
            local hover = make("Frame", {
                Parent = wrap, BackgroundColor3 = Theme.SurfaceHover, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0), BorderSizePixel = 0, ZIndex = 8,
            })
            corner(hover, 5)
            make("TextLabel", {
                Parent = wrap, Text = name, TextColor3 = Theme.Text,
                Font = Enum.Font.Gotham, TextSize = 13, BackgroundTransparency = 1,
                Size = UDim2.new(0.7, 0, 0, 20), Position = UDim2.new(0, 8, 0, 4),
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9,
            })
            local valLabel = make("TextLabel", {
                Parent = wrap, Text = tostring(val)..suffix,
                TextColor3 = Theme.Accent, Font = Enum.Font.GothamBold, TextSize = 12,
                BackgroundTransparency = 1,
                Size = UDim2.new(0.3, -8, 0, 20), Position = UDim2.new(0.7, 0, 0, 4),
                TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 9,
            })
            local trackBg = make("Frame", {
                Parent = wrap, BackgroundColor3 = Theme.Border,
                Size = UDim2.new(1, -16, 0, 4), Position = UDim2.new(0, 8, 0, 30),
                BorderSizePixel = 0, ZIndex = 9,
            })
            corner(trackBg, 2)
            local trackFill = make("Frame", {
                Parent = trackBg, BackgroundColor3 = Theme.Accent,
                Size = UDim2.new((val-min)/(max-min), 0, 1, 0),
                BorderSizePixel = 0, ZIndex = 10,
            })
            corner(trackFill, 2)
            local handle = make("Frame", {
                Parent = trackBg, BackgroundColor3 = Theme.White,
                Size = UDim2.new(0, 12, 0, 12),
                Position = UDim2.new((val-min)/(max-min), -6, 0.5, -6),
                BorderSizePixel = 0, ZIndex = 11,
            })
            corner(handle, 6); stroke(handle, Theme.Accent, 2)

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
                handle.Position = UDim2.new(pct, -6, 0.5, -6)
                cb(val)
            end
            local sliderBtn = make("TextButton", {
                Parent = trackBg, Text = "", BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 16), Position = UDim2.new(0, 0, 0, -8),
                BorderSizePixel = 0, ZIndex = 12, AutoButtonColor = false,
            })
            sliderBtn.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = true; updateSlider(inp.Position.X)
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

        -- DROPDOWN
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
                Font = Enum.Font.Gotham, TextSize = 11, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 8, 0, 2),
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9,
            })
            local btn = make("TextButton", {
                Parent = wrap, Text = "", BackgroundColor3 = Theme.Background,
                Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 0, 18),
                BorderSizePixel = 0, ZIndex = 9, AutoButtonColor = false,
            })
            corner(btn, 6); stroke(btn, Theme.Border, 1)
            local selLabel = make("TextLabel", {
                Parent = btn, Text = multi and "None" or tostring(default),
                TextColor3 = Theme.Text, Font = Enum.Font.Gotham, TextSize = 12,
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
                    })
                    corner(ob, 4); table.insert(optBtns, ob)
                    ob.MouseEnter:Connect(function() tween(ob, { BackgroundTransparency = 0.8 }, 0.1) end)
                    ob.MouseLeave:Connect(function() tween(ob, { BackgroundTransparency = 1 }, 0.1) end)
                    ob.MouseButton1Click:Connect(function()
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
                tween(panel, { Size = UDim2.new(0, sz.X, 0, targetH) }, 0.2, Enum.EasingStyle.Back)
                tween(arrow, { Rotation = 180 }, 0.15)
            end
            btn.MouseButton1Click:Connect(function()
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

        -- BUTTON
        function sec:Button(opts)
            opts = opts or {}
            local name = opts.Name or opts.name or "Button"
            local cb   = opts.Callback or opts.callback or function() end
            local btn = make("TextButton", {
                Parent = self._elemHolder, Text = "", BackgroundColor3 = Theme.AccentDim,
                Size = UDim2.new(1, 0, 0, 30), BorderSizePixel = 0, ZIndex = 8, AutoButtonColor = false,
            })
            corner(btn, 6)
            make("UIGradient", {
                Parent = btn, Rotation = 90,
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Theme.Accent),
                    ColorSequenceKeypoint.new(1, Theme.AccentDim),
                }),
            })
            make("TextLabel", {
                Parent = btn, Text = name, TextColor3 = Theme.White,
                Font = Enum.Font.GothamBold, TextSize = 12,
                BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), ZIndex = 9,
            })
            btn.MouseEnter:Connect(function() tween(btn, { BackgroundColor3 = Theme.Accent }, 0.1) end)
            btn.MouseLeave:Connect(function() tween(btn, { BackgroundColor3 = Theme.AccentDim }, 0.1) end)
            btn.MouseButton1Down:Connect(function() tween(btn, { BackgroundColor3 = Theme.AccentGlow }, 0.08) end)
            btn.MouseButton1Up:Connect(function() tween(btn, { BackgroundColor3 = Theme.Accent }, 0.08) end)
            btn.MouseButton1Click:Connect(cb)
        end

        -- KEYBIND
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
            corner(hover, 5)
            make("TextLabel", {
                Parent = row, Text = name, TextColor3 = Theme.Text,
                Font = Enum.Font.Gotham, TextSize = 13, BackgroundTransparency = 1,
                Size = UDim2.new(0.6, 0, 1, 0), Position = UDim2.new(0, 8, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9,
            })
            local keyBtn = make("TextButton", {
                Parent = row, BackgroundColor3 = Theme.Background,
                Size = UDim2.new(0, 72, 0, 20), Position = UDim2.new(1, -80, 0.5, -10),
                BorderSizePixel = 0, ZIndex = 9, AutoButtonColor = false,
            })
            corner(keyBtn, 4); stroke(keyBtn, Theme.Border, 1)
            local keyLabel = make("TextLabel", {
                Parent = keyBtn,
                Text = tostring(boundKey):gsub("Enum.KeyCode.", ""),
                TextColor3 = Theme.Accent, Font = Enum.Font.GothamBold, TextSize = 11,
                BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), ZIndex = 10,
            })
            local modeLabel = make("TextLabel", {
                Parent = row, Text = mode, TextColor3 = Theme.TextMuted,
                Font = Enum.Font.Gotham, TextSize = 9, BackgroundTransparency = 1,
                Size = UDim2.new(0, 72, 0, 10), Position = UDim2.new(1, -80, 1, -10), ZIndex = 9,
            })
            local modes = {"Toggle","Hold","Always"}; local modeIdx = 1
            for i, m in ipairs(modes) do if m == mode then modeIdx = i end end

            keyBtn.MouseButton2Click:Connect(function()
                modeIdx = modeIdx % #modes + 1; mode = modes[modeIdx]; modeLabel.Text = mode
                self._lib.Flags[flag].Mode = mode
                if mode == "Always" then active = true; cb(true) else active = false; cb(false) end
            end)
            keyBtn.MouseButton1Click:Connect(function()
                binding = true; keyLabel.Text = "..."
                tween(keyBtn, { BackgroundColor3 = Theme.AccentDim }, 0.1)
            end)
            UserInputService.InputBegan:Connect(function(inp, gpe)
                if binding then
                    if inp.KeyCode ~= Enum.KeyCode.Unknown then boundKey = inp.KeyCode
                    elseif inp.UserInputType ~= Enum.UserInputType.MouseButton1 then boundKey = inp.UserInputType
                    end
                    binding = false
                    keyLabel.Text = tostring(boundKey):gsub("Enum.KeyCode.",""):gsub("Enum.UserInputType.","")
                    tween(keyBtn, { BackgroundColor3 = Theme.Background }, 0.1)
                    self._lib.Flags[flag].Key = boundKey; return
                end
                if gpe then return end
                local k = inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode or inp.UserInputType
                if k == boundKey then
                    if mode == "Toggle" then
                        active = not active; cb(active)
                        self._lib.Flags[flag].Active = active
                        tween(keyBtn, { BackgroundColor3 = active and Theme.AccentDim or Theme.Background }, 0.1)
                        tween(keyLabel, { TextColor3 = active and Theme.White or Theme.Accent }, 0.1)
                    elseif mode == "Hold" then
                        active = true; cb(true)
                        self._lib.Flags[flag].Active = true
                        tween(keyBtn, { BackgroundColor3 = Theme.AccentDim }, 0.1)
                    end
                end
            end)
            UserInputService.InputEnded:Connect(function(inp)
                if mode == "Hold" then
                    local k = inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode or inp.UserInputType
                    if k == boundKey then
                        active = false; cb(false); self._lib.Flags[flag].Active = false
                        tween(keyBtn, { BackgroundColor3 = Theme.Background }, 0.1)
                    end
                end
            end)
            row.MouseEnter:Connect(function() tween(hover, { BackgroundTransparency = 0.85 }, 0.1) end)
            row.MouseLeave:Connect(function() tween(hover, { BackgroundTransparency = 1 }, 0.1) end)
            if mode == "Always" then active = true; cb(true) end
            return { Get = function() return active end, GetKey = function() return boundKey end }
        end

        -- LABEL
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

        -- SEPARATOR
        function sec:Separator()
            make("Frame", {
                Parent = self._elemHolder, BackgroundColor3 = Theme.Border,
                Size = UDim2.new(1, -16, 0, 1), BorderSizePixel = 0, ZIndex = 8,
            })
        end

        table.insert(tab.Sections, sec)
        return sec
    end

    return tab
end

function Rift:Destroy()
    for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
    self.ScreenGui:Destroy()
    lockMouse()
end

return Rift

