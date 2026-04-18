--[[
    ███╗   ██╗███████╗██╗  ██╗██╗   ██╗███████╗    ██╗   ██╗██╗
    ████╗  ██║██╔════╝╚██╗██╔╝██║   ██║██╔════╝    ██║   ██║██║
    ██╔██╗ ██║█████╗   ╚███╔╝ ██║   ██║███████╗    ██║   ██║██║
    ██║╚██╗██║██╔══╝   ██╔██╗ ██║   ██║╚════██║    ██║   ██║██║
    ██║ ╚████║███████╗██╔╝ ██╗╚██████╔╝███████║    ╚██████╔╝██║
    ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝     ╚═════╝ ╚═╝

    NexusUI  ·  A Premium Roblox GUI Library
--]]
-- ─────────────────────────────────────────────────────────────────────────────
--  SERVICES
-- ─────────────────────────────────────────────────────────────────────────────
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")
local LocalPlayer      = Players.LocalPlayer

-- ─────────────────────────────────────────────────────────────────────────────
--  THEME  — single source of truth.  Swap colours here to reskin everything.
-- ─────────────────────────────────────────────────────────────────────────────
local T = {
    Bg       = Color3.fromHex("0d0d12"),   -- page background
    Surface  = Color3.fromHex("13131b"),   -- card / sidebar
    Elevated = Color3.fromHex("1b1b25"),   -- raised element / track
    PopUp    = Color3.fromHex("20202c"),   -- dropdown / modal

    Accent   = Color3.fromHex("00e5c3"),   -- ONE accent, used sparingly
    AccentLo = Color3.fromHex("00b89e"),   -- dimmer variant

    TxtHi  = Color3.fromHex("e8e8f0"),    -- primary text
    TxtMid = Color3.fromHex("7a7a9a"),    -- secondary / label text
    TxtLo  = Color3.fromHex("3a3a52"),    -- disabled / placeholder

    Border = Color3.fromRGB(255, 255, 255), -- used with Transparency ~0.90+

    FontBold = Enum.Font.GothamBold,
    FontReg  = Enum.Font.Gotham,
    FontMono = Enum.Font.Code,

    NotifColors = {
        info    = Color3.fromHex("00e5c3"),
        success = Color3.fromHex("39ff6e"),
        error   = Color3.fromHex("ff4f4f"),
        warning = Color3.fromHex("ffaa00"),
    },
}

-- ─────────────────────────────────────────────────────────────────────────────
--  INTERNAL UTILITIES
-- ─────────────────────────────────────────────────────────────────────────────

local function Tween(obj, props, dur, style, dir)
    TweenService:Create(obj, TweenInfo.new(
        dur or 0.2,
        style or Enum.EasingStyle.Quart,
        dir   or Enum.EasingDirection.Out
    ), props):Play()
end

local function New(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function Rounded(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = parent
    return c
end

local function Stroke(parent, transparency, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color        = color or T.Border
    s.Transparency = transparency or 0.92
    s.Thickness    = thickness or 1
    s.Parent       = parent
    return s
end

local function MakeDraggable(frame, handle)
    local dragging, dragInput, dragStart, startPos
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = i.Position; startPos = frame.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    handle.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement then dragInput = i end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if i == dragInput and dragging then
            local d = i.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)
end

-- ─────────────────────────────────────────────────────────────────────────────
--  NOTIFICATION STACK  (toast messages, bottom-right, stacked)
-- ─────────────────────────────────────────────────────────────────────────────
local NOTIF = { stack = {}, W = 290, H = 68, GAP = 8, RIGHT = 14, BOT = 14 }

local function notifReflow()
    for i, d in ipairs(NOTIF.stack) do
        local bot = NOTIF.BOT + (i - 1) * (NOTIF.H + NOTIF.GAP)
        Tween(d.frame, { Position = UDim2.new(1, -(NOTIF.W + NOTIF.RIGHT), 1, -(bot + NOTIF.H)) }, 0.22)
    end
end

local function notifRemove(frame)
    for i, d in ipairs(NOTIF.stack) do
        if d.frame == frame then table.remove(NOTIF.stack, i); break end
    end
    notifReflow()
end

-- ─────────────────────────────────────────────────────────────────────────────
--  LIBRARY TABLE
-- ─────────────────────────────────────────────────────────────────────────────
local NexusUI = {}
NexusUI.__index = NexusUI

-- ── NexusUI:Notify({ Title, Description, Type, Duration }) ───────────────────
function NexusUI:Notify(cfg)
    cfg = cfg or {}
    local title    = cfg.Title       or "Notification"
    local desc     = cfg.Description or ""
    local duration = cfg.Duration    or 3
    local accent   = T.NotifColors[cfg.Type] or T.Accent

    local gui = New("ScreenGui", {
        Name           = "NexusUI_Notif_" .. tick(),
        ResetOnSpawn   = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent         = LocalPlayer:WaitForChild("PlayerGui"),
    })

    local frame = New("Frame", {
        Size             = UDim2.new(0, NOTIF.W, 0, NOTIF.H),
        Position         = UDim2.new(1, 10, 1, -(NOTIF.H + NOTIF.BOT)),
        BackgroundColor3 = T.Surface,
        BorderSizePixel  = 0,
        Parent           = gui,
    })
    Rounded(frame, 10)
    Stroke(frame, 0.60, accent, 1)

    local bar = New("Frame", {
        Size             = UDim2.new(0, 3, 0.65, 0),
        Position         = UDim2.new(0, 10, 0.175, 0),
        BackgroundColor3 = accent,
        BorderSizePixel  = 0,
        Parent           = frame,
    })
    Rounded(bar, 2)

    New("TextLabel", {
        Size              = UDim2.new(1, -30, 0, 20),
        Position          = UDim2.new(0, 20, 0, 10),
        BackgroundTransparency = 1,
        Text              = title,
        TextColor3        = T.TxtHi,
        Font              = T.FontBold,
        TextSize          = 13,
        TextXAlignment    = Enum.TextXAlignment.Left,
        Parent            = frame,
    })

    New("TextLabel", {
        Size              = UDim2.new(1, -30, 0, 16),
        Position          = UDim2.new(0, 20, 0, 33),
        BackgroundTransparency = 1,
        Text              = desc,
        TextColor3        = T.TxtMid,
        Font              = T.FontReg,
        TextSize          = 11,
        TextXAlignment    = Enum.TextXAlignment.Left,
        TextWrapped       = true,
        Parent            = frame,
    })

    local pTrack = New("Frame", {
        Size             = UDim2.new(1, -20, 0, 2),
        Position         = UDim2.new(0, 10, 1, -6),
        BackgroundColor3 = T.Elevated,
        BorderSizePixel  = 0,
        Parent           = frame,
    })
    Rounded(pTrack, 2)
    local pFill = New("Frame", {
        Size             = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = accent,
        BorderSizePixel  = 0,
        Parent           = pTrack,
    })
    Rounded(pFill, 2)

    table.insert(NOTIF.stack, 1, { frame = frame })
    notifReflow()

    -- Slide in with Back easing
    Tween(frame, {
        Position = UDim2.new(1, -(NOTIF.W + NOTIF.RIGHT), 1, -(NOTIF.H + NOTIF.BOT))
    }, 0.35, Enum.EasingStyle.Back)

    -- Drain progress bar
    Tween(pFill, { Size = UDim2.new(0, 0, 1, 0) }, duration, Enum.EasingStyle.Linear)

    -- Dismiss
    task.delay(duration, function()
        notifRemove(frame)
        Tween(frame, { Position = UDim2.new(1, 10, frame.Position.Y.Scale, frame.Position.Y.Offset) }, 0.22)
        task.wait(0.25)
        gui:Destroy()
    end)
end

-- ── NexusUI:CreateWindow(cfg) ─────────────────────────────────────────────────
function NexusUI:CreateWindow(cfg)
    cfg = cfg or {}
    local title    = cfg.Title    or "NexusUI"
    local fullSize = cfg.Size     or UDim2.new(0, 520, 0, 370)
    local pos      = cfg.Position or UDim2.new(
        0.5, -(fullSize.X.Offset / 2),
        0.5, -(fullSize.Y.Offset / 2)
    )

    -- ── Root ScreenGui ────────────────────────────────────────
    local gui = New("ScreenGui", {
        Name           = "NexusUI_" .. title,
        ResetOnSpawn   = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent         = LocalPlayer:WaitForChild("PlayerGui"),
    })

    -- ── Main frame (starts collapsed, animates open) ──────────
    local main = New("Frame", {
        Name             = "Main",
        Size             = UDim2.new(0, fullSize.X.Offset, 0, 0),
        Position         = pos,
        BackgroundColor3 = T.Bg,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
        Parent           = gui,
    })
    Rounded(main, 12)
    Stroke(main, 0.88)

    -- ── Title bar ─────────────────────────────────────────────
    local titleBar = New("Frame", {
        Size             = UDim2.new(1, 0, 0, 46),
        BackgroundColor3 = T.Surface,
        BorderSizePixel  = 0,
        Parent           = main,
    })
    Rounded(titleBar, 12)
    -- Patch bottom corners so titlebar visually merges into body
    New("Frame", {
        Size             = UDim2.new(1, 0, 0, 12),
        Position         = UDim2.new(0, 0, 1, -12),
        BackgroundColor3 = T.Surface,
        BorderSizePixel  = 0,
        Parent           = titleBar,
    })

    -- Accent top-edge dash (left of title)
    do
        local d = New("Frame", {
            Size             = UDim2.new(0, 52, 0, 2),
            Position         = UDim2.new(0, 14, 0, 0),
            BackgroundColor3 = T.Accent,
            BorderSizePixel  = 0,
            Parent           = titleBar,
        })
        Rounded(d, 2)
    end

    -- Animated live dot
    local dot = New("Frame", {
        Size             = UDim2.new(0, 7, 0, 7),
        Position         = UDim2.new(0, 14, 0.5, -3),
        BackgroundColor3 = T.Accent,
        BorderSizePixel  = 0,
        Parent           = titleBar,
    })
    Rounded(dot, 99)
    task.spawn(function()
        while dot.Parent do
            Tween(dot, {BackgroundTransparency = 0.6}, 0.7, Enum.EasingStyle.Sine)
            task.wait(0.7)
            Tween(dot, {BackgroundTransparency = 0}, 0.7, Enum.EasingStyle.Sine)
            task.wait(0.7)
        end
    end)

    New("TextLabel", {
        Size              = UDim2.new(1, -100, 1, 0),
        Position          = UDim2.new(0, 28, 0, 0),
        BackgroundTransparency = 1,
        Text              = title,
        TextColor3        = T.TxtHi,
        Font              = T.FontBold,
        TextSize          = 13,
        TextXAlignment    = Enum.TextXAlignment.Left,
        Parent            = titleBar,
    })

    -- Small control buttons helper
    local function TitleBtn(offsetX, symbol, bg, hoverColor, textColor)
        local b = New("TextButton", {
            Size             = UDim2.new(0, 26, 0, 26),
            Position         = UDim2.new(1, offsetX, 0.5, -13),
            BackgroundColor3 = bg,
            BorderSizePixel  = 0,
            Text             = symbol,
            TextColor3       = textColor or T.TxtMid,
            Font             = T.FontReg,
            TextSize         = 11,
            Parent           = titleBar,
        })
        Rounded(b, 6)
        b.MouseEnter:Connect(function() Tween(b, {BackgroundColor3 = hoverColor or bg}, 0.14) end)
        b.MouseLeave:Connect(function() Tween(b, {BackgroundColor3 = bg}, 0.14) end)
        return b
    end

    local closeBtn = TitleBtn(-12, "✕", Color3.fromHex("2d1a1a"), Color3.fromHex("ff4f4f"), Color3.fromHex("ff4f4f"))
    local minBtn   = TitleBtn(-42, "–", T.Elevated, T.PopUp)

    local minimized = false
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        Tween(main, {Size = minimized and UDim2.new(0, fullSize.X.Offset, 0, 46) or fullSize}, 0.25, Enum.EasingStyle.Quart)
    end)
    closeBtn.MouseButton1Click:Connect(function()
        Tween(main, {Size = UDim2.new(0, fullSize.X.Offset, 0, 0), BackgroundTransparency = 1}, 0.2)
        task.wait(0.22)
        gui:Destroy()
    end)

    MakeDraggable(main, titleBar)

    -- ── Sidebar ───────────────────────────────────────────────
    local sidebar = New("Frame", {
        Size             = UDim2.new(0, 120, 1, -46),
        Position         = UDim2.new(0, 0, 0, 46),
        BackgroundColor3 = T.Surface,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
        Parent           = main,
    })
    -- Fix top corner bleed from titleBar → sidebar
    New("Frame", {
        Size             = UDim2.new(1, 0, 0, 12),
        BackgroundColor3 = T.Surface,
        BorderSizePixel  = 0,
        Parent           = sidebar,
    })
    do
        local l = Instance.new("UIListLayout")
        l.SortOrder = Enum.SortOrder.LayoutOrder
        l.Padding    = UDim.new(0, 2)
        l.Parent     = sidebar
        local p = Instance.new("UIPadding")
        p.PaddingTop   = UDim.new(0, 12)
        p.PaddingLeft  = UDim.new(0, 8)
        p.PaddingRight = UDim.new(0, 8)
        p.Parent       = sidebar
    end

    -- Hairline divider between sidebar and content
    New("Frame", {
        Size             = UDim2.new(0, 1, 1, -46),
        Position         = UDim2.new(0, 120, 0, 46),
        BackgroundColor3 = T.Border,
        BackgroundTransparency = 0.91,
        BorderSizePixel  = 0,
        Parent           = main,
    })

    -- ── Content area ──────────────────────────────────────────
    local content = New("Frame", {
        Size                 = UDim2.new(1, -121, 1, -46),
        Position             = UDim2.new(0, 121, 0, 46),
        BackgroundTransparency = 1,
        ClipsDescendants     = true,
        Parent               = main,
    })

    -- ── Window object ─────────────────────────────────────────
    local Window = { Tabs = {}, ActiveTab = nil, Gui = gui, Frame = main }

    -- ── Window:AddTab({ Name, Icon }) ─────────────────────────
    function Window:AddTab(tabCfg)
        tabCfg = tabCfg or {}
        local name = tabCfg.Name or ("Tab " .. (#self.Tabs + 1))
        local icon = tabCfg.Icon or ""

        -- Sidebar button
        local tabBtn = New("TextButton", {
            Size                 = UDim2.new(1, 0, 0, 34),
            BackgroundColor3     = T.Elevated,
            BackgroundTransparency = 1,
            BorderSizePixel      = 0,
            Text                 = (icon ~= "" and icon .. "  " or "") .. name,
            TextColor3           = T.TxtMid,
            Font                 = T.FontReg,
            TextSize             = 12,
            TextXAlignment       = Enum.TextXAlignment.Left,
            LayoutOrder          = #self.Tabs + 1,
            Parent               = sidebar,
        })
        Rounded(tabBtn, 7)
        do
            local p = Instance.new("UIPadding")
            p.PaddingLeft = UDim.new(0, 10)
            p.Parent = tabBtn
        end

        -- Left-edge active indicator
        local indicator = New("Frame", {
            Size             = UDim2.new(0, 2, 0.55, 0),
            Position         = UDim2.new(0, -2, 0.225, 0),
            BackgroundColor3 = T.Accent,
            BackgroundTransparency = 1,
            BorderSizePixel  = 0,
            Parent           = tabBtn,
        })
        Rounded(indicator, 2)

        -- Scrollable page
        local page = New("ScrollingFrame", {
            Size                 = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel      = 0,
            ScrollBarThickness   = 3,
            ScrollBarImageColor3 = T.Accent,
            CanvasSize           = UDim2.new(0, 0, 0, 0),
            Visible              = false,
            Parent               = content,
        })
        do
            local l = Instance.new("UIListLayout")
            l.SortOrder = Enum.SortOrder.LayoutOrder
            l.Padding    = UDim.new(0, 6)
            l.Parent     = page
            l:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                page.CanvasSize = UDim2.new(0, 0, 0, l.AbsoluteContentSize.Y + 28)
            end)
            local p = Instance.new("UIPadding")
            p.PaddingTop    = UDim.new(0, 14)
            p.PaddingLeft   = UDim.new(0, 12)
            p.PaddingRight  = UDim.new(0, 12)
            p.PaddingBottom = UDim.new(0, 14)
            p.Parent        = page
        end

        local Tab = { Page = page, Button = tabBtn, Indicator = indicator, Elements = {} }

        local function activate()
            if Window.ActiveTab then
                local prev = Window.ActiveTab
                Tween(prev.Button,    {BackgroundTransparency = 1, TextColor3 = T.TxtMid}, 0.18)
                Tween(prev.Indicator, {BackgroundTransparency = 1}, 0.18)
                prev.Page.Visible = false
            end
            Window.ActiveTab = Tab
            Tween(tabBtn,    {BackgroundTransparency = 0.85, TextColor3 = T.TxtHi}, 0.18)
            Tween(indicator, {BackgroundTransparency = 0}, 0.18)
            page.Visible = true
        end

        tabBtn.MouseButton1Click:Connect(activate)
        tabBtn.MouseEnter:Connect(function()
            if Window.ActiveTab ~= Tab then Tween(tabBtn, {BackgroundTransparency = 0.92}, 0.12) end
        end)
        tabBtn.MouseLeave:Connect(function()
            if Window.ActiveTab ~= Tab then Tween(tabBtn, {BackgroundTransparency = 1}, 0.12) end
        end)

        if #self.Tabs == 0 then task.defer(activate) end
        table.insert(self.Tabs, Tab)

        -- ── Internal helpers ───────────────────────────────────
        local function Card(h)
            local f = New("Frame", {
                Size             = UDim2.new(1, 0, 0, h),
                BackgroundColor3 = T.Surface,
                BorderSizePixel  = 0,
                LayoutOrder      = #Tab.Elements + 1,
                Parent           = page,
            })
            Rounded(f, 8)
            Stroke(f, 0.91)
            table.insert(Tab.Elements, f)
            return f
        end

        local function Overlay(parent)
            return New("TextButton", {
                Size                 = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                BorderSizePixel      = 0,
                Text                 = "",
                Parent               = parent,
            })
        end

        -- ── Tab:AddSection(name) ──────────────────────────────
        function Tab:AddSection(txt)
            local l = New("TextLabel", {
                Size              = UDim2.new(1, 0, 0, 22),
                BackgroundTransparency = 1,
                Text              = string.upper(txt or ""),
                TextColor3        = T.TxtMid,
                Font              = T.FontBold,
                TextSize          = 10,
                TextXAlignment    = Enum.TextXAlignment.Left,
                LayoutOrder       = #Tab.Elements + 1,
                Parent            = page,
            })
            local p = Instance.new("UIPadding"); p.PaddingLeft = UDim.new(0,4); p.Parent = l
            table.insert(Tab.Elements, l)
        end

        -- ── Tab:AddDivider() ──────────────────────────────────
        function Tab:AddDivider()
            local d = New("Frame", {
                Size             = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = T.Border,
                BackgroundTransparency = 0.91,
                BorderSizePixel  = 0,
                LayoutOrder      = #Tab.Elements + 1,
                Parent           = page,
            })
            table.insert(Tab.Elements, d)
        end

        -- ── Tab:AddLabel({ Text, Color? }) → { Set, Get } ─────
        function Tab:AddLabel(cfg)
            cfg = type(cfg) == "string" and {Text = cfg} or cfg or {}
            local l = New("TextLabel", {
                Size              = UDim2.new(1, 0, 0, 24),
                BackgroundTransparency = 1,
                Text              = cfg.Text or "",
                TextColor3        = cfg.Color or T.TxtMid,
                Font              = T.FontReg,
                TextSize          = 12,
                TextXAlignment    = Enum.TextXAlignment.Left,
                TextWrapped       = true,
                LayoutOrder       = #Tab.Elements + 1,
                Parent            = page,
            })
            local p = Instance.new("UIPadding"); p.PaddingLeft = UDim.new(0,4); p.Parent = l
            table.insert(Tab.Elements, l)
            return {
                Set = function(_, v) l.Text = tostring(v) end,
                Get = function(_) return l.Text end,
            }
        end

        -- ── Tab:AddButton({ Label, Description?, Callback }) ──
        function Tab:AddButton(cfg)
            cfg = cfg or {}
            local card = Card(cfg.Description and 52 or 38)
            local btn  = Overlay(card)

            New("TextLabel", {
                Size              = UDim2.new(1, -36, 0, 18),
                Position          = UDim2.new(0, 14, 0, cfg.Description and 8 or 10),
                BackgroundTransparency = 1,
                Text              = cfg.Label or "Button",
                TextColor3        = T.TxtHi,
                Font              = T.FontReg,
                TextSize          = 13,
                TextXAlignment    = Enum.TextXAlignment.Left,
                Parent            = card,
            })

            if cfg.Description then
                New("TextLabel", {
                    Size              = UDim2.new(1, -36, 0, 14),
                    Position          = UDim2.new(0, 14, 0, 29),
                    BackgroundTransparency = 1,
                    Text              = cfg.Description,
                    TextColor3        = T.TxtMid,
                    Font              = T.FontReg,
                    TextSize          = 11,
                    TextXAlignment    = Enum.TextXAlignment.Left,
                    Parent            = card,
                })
            end

            local arrow = New("TextLabel", {
                Size              = UDim2.new(0, 18, 1, 0),
                Position          = UDim2.new(1, -26, 0, 0),
                BackgroundTransparency = 1,
                Text              = "›",
                TextColor3        = T.Accent,
                Font              = T.FontBold,
                TextSize          = 17,
                Parent            = card,
            })

            btn.MouseEnter:Connect(function()
                Tween(card,  {BackgroundColor3 = T.Elevated}, 0.12)
                Tween(arrow, {Position = UDim2.new(1, -22, 0, 0)}, 0.12)
            end)
            btn.MouseLeave:Connect(function()
                Tween(card,  {BackgroundColor3 = T.Surface}, 0.12)
                Tween(arrow, {Position = UDim2.new(1, -26, 0, 0)}, 0.12)
            end)
            btn.MouseButton1Down:Connect(function()
                Tween(card, {BackgroundColor3 = Color3.fromHex("101018")}, 0.08)
            end)
            btn.MouseButton1Up:Connect(function()
                Tween(card, {BackgroundColor3 = T.Elevated}, 0.08)
                if cfg.Callback then cfg.Callback() end
            end)
        end

        -- ── Tab:AddToggle({ Label, Description?, Default, Callback }) → { Set, Get } ──
        function Tab:AddToggle(cfg)
            cfg = cfg or {}
            local state = cfg.Default or false
            local card  = Card(cfg.Description and 52 or 38)
            local btn   = Overlay(card)

            New("TextLabel", {
                Size              = UDim2.new(1, -58, 0, 18),
                Position          = UDim2.new(0, 14, 0, cfg.Description and 8 or 10),
                BackgroundTransparency = 1,
                Text              = cfg.Label or "Toggle",
                TextColor3        = T.TxtHi,
                Font              = T.FontReg,
                TextSize          = 13,
                TextXAlignment    = Enum.TextXAlignment.Left,
                Parent            = card,
            })

            if cfg.Description then
                New("TextLabel", {
                    Size              = UDim2.new(1, -58, 0, 14),
                    Position          = UDim2.new(0, 14, 0, 29),
                    BackgroundTransparency = 1,
                    Text              = cfg.Description,
                    TextColor3        = T.TxtMid,
                    Font              = T.FontReg,
                    TextSize          = 11,
                    TextXAlignment    = Enum.TextXAlignment.Left,
                    Parent            = card,
                })
            end

            local track = New("Frame", {
                Size             = UDim2.new(0, 36, 0, 20),
                Position         = UDim2.new(1, -48, 0.5, -10),
                BackgroundColor3 = T.Elevated,
                BorderSizePixel  = 0,
                Parent           = card,
            })
            Rounded(track, 99)
            local tStroke = Stroke(track, 0.88)

            local knob = New("Frame", {
                Size             = UDim2.new(0, 14, 0, 14),
                Position         = UDim2.new(0, 3, 0.5, -7),
                BackgroundColor3 = T.TxtMid,
                BorderSizePixel  = 0,
                Parent           = track,
            })
            Rounded(knob, 99)

            local function refresh(on, animate)
                local d = animate and 0.18 or 0
                if on then
                    Tween(track,   {BackgroundColor3 = T.Accent}, d)
                    Tween(knob,    {Position = UDim2.new(0,19,0.5,-7), BackgroundColor3 = Color3.new(1,1,1)}, d)
                    Tween(tStroke, {Transparency = 1}, d)
                else
                    Tween(track,   {BackgroundColor3 = T.Elevated}, d)
                    Tween(knob,    {Position = UDim2.new(0,3,0.5,-7), BackgroundColor3 = T.TxtMid}, d)
                    Tween(tStroke, {Transparency = 0.88}, d)
                end
            end
            refresh(state, false)

            btn.MouseButton1Click:Connect(function()
                state = not state
                refresh(state, true)
                if cfg.Callback then cfg.Callback(state) end
            end)
            btn.MouseEnter:Connect(function() Tween(card, {BackgroundColor3 = T.Elevated}, 0.12) end)
            btn.MouseLeave:Connect(function() Tween(card, {BackgroundColor3 = T.Surface }, 0.12) end)

            return {
                Set = function(_, v) state = v; refresh(state, true); if cfg.Callback then cfg.Callback(state) end end,
                Get = function(_) return state end,
            }
        end

        -- ── Tab:AddSlider({ Label, Min, Max, Default, Suffix?, Callback }) → { Set, Get } ──
        function Tab:AddSlider(cfg)
            cfg = cfg or {}
            local min    = cfg.Min    or 0
            local max    = cfg.Max    or 100
            local suffix = cfg.Suffix or ""
            local value  = math.clamp(cfg.Default or min, min, max)
            local card   = Card(60)

            New("TextLabel", {
                Size              = UDim2.new(0.6, 0, 0, 18),
                Position          = UDim2.new(0, 14, 0, 10),
                BackgroundTransparency = 1,
                Text              = cfg.Label or "Slider",
                TextColor3        = T.TxtHi,
                Font              = T.FontReg,
                TextSize          = 13,
                TextXAlignment    = Enum.TextXAlignment.Left,
                Parent            = card,
            })

            local valLbl = New("TextLabel", {
                Size              = UDim2.new(0.4, -14, 0, 18),
                Position          = UDim2.new(0.6, 0, 0, 10),
                BackgroundTransparency = 1,
                Text              = tostring(math.round(value)) .. suffix,
                TextColor3        = T.Accent,
                Font              = T.FontMono,
                TextSize          = 12,
                TextXAlignment    = Enum.TextXAlignment.Right,
                Parent            = card,
            })

            local trackBg = New("Frame", {
                Size             = UDim2.new(1, -28, 0, 4),
                Position         = UDim2.new(0, 14, 0, 42),
                BackgroundColor3 = T.Elevated,
                BorderSizePixel  = 0,
                Parent           = card,
            })
            Rounded(trackBg, 2)

            local fill = New("Frame", {
                Size             = UDim2.new((value-min)/(max-min), 0, 1, 0),
                BackgroundColor3 = T.Accent,
                BorderSizePixel  = 0,
                Parent           = trackBg,
            })
            Rounded(fill, 2)

            local thumb = New("Frame", {
                Size             = UDim2.new(0, 14, 0, 14),
                Position         = UDim2.new((value-min)/(max-min), 0, 0.5, 0),
                AnchorPoint      = Vector2.new(0.5, 0.5),
                BackgroundColor3 = T.Accent,
                BorderSizePixel  = 0,
                ZIndex           = 5,
                Parent           = trackBg,
            })
            Rounded(thumb, 99)

            local sliding = false
            local function update(inputX)
                local rel = math.clamp((inputX - trackBg.AbsolutePosition.X) / trackBg.AbsoluteSize.X, 0, 1)
                value = math.round(min + (max - min) * rel)
                Tween(fill, {Size = UDim2.new(rel, 0, 1, 0)}, 0.05)
                thumb.Position = UDim2.new(rel, 0, 0.5, 0)
                valLbl.Text = tostring(value) .. suffix
                if cfg.Callback then cfg.Callback(value) end
            end

            trackBg.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = true; update(i.Position.X) end
            end)
            thumb.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = true end
            end)
            UserInputService.InputChanged:Connect(function(i)
                if sliding and i.UserInputType == Enum.UserInputType.MouseMovement then update(i.Position.X) end
            end)
            UserInputService.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
            end)
            thumb.MouseEnter:Connect(function() Tween(thumb, {Size=UDim2.new(0,17,0,17)},0.12) end)
            thumb.MouseLeave:Connect(function()
                if not sliding then Tween(thumb, {Size=UDim2.new(0,14,0,14)},0.12) end
            end)

            return {
                Set = function(_, v)
                    value = math.clamp(v, min, max)
                    local rel = (value-min)/(max-min)
                    Tween(fill, {Size=UDim2.new(rel,0,1,0)},0.2)
                    thumb.Position = UDim2.new(rel,0,0.5,0)
                    valLbl.Text = tostring(math.round(value))..suffix
                    if cfg.Callback then cfg.Callback(value) end
                end,
                Get = function(_) return value end,
            }
        end

        -- ── Tab:AddDropdown({ Label, Options, Default?, Callback }) → { Set, Get } ──
        function Tab:AddDropdown(cfg)
            cfg = cfg or {}
            local options  = cfg.Options or {}
            local selected = cfg.Default or options[1]
            local open     = false
            local dropH    = math.min(#options, 6) * 30 + 8

            local card = Card(38)
            card.ClipsDescendants = false
            card.ZIndex = 10

            local btn = Overlay(card); btn.ZIndex = 10

            New("TextLabel", {
                Size              = UDim2.new(0.55, 0, 1, 0),
                Position          = UDim2.new(0, 14, 0, 0),
                BackgroundTransparency = 1,
                Text              = cfg.Label or "Dropdown",
                TextColor3        = T.TxtHi,
                Font              = T.FontReg,
                TextSize          = 13,
                TextXAlignment    = Enum.TextXAlignment.Left,
                ZIndex            = 10,
                Parent            = card,
            })

            local selTxt = New("TextLabel", {
                Size              = UDim2.new(0.4, -28, 1, 0),
                Position          = UDim2.new(0.55, 0, 0, 0),
                BackgroundTransparency = 1,
                Text              = tostring(selected or "—"),
                TextColor3        = T.Accent,
                Font              = T.FontReg,
                TextSize          = 12,
                TextXAlignment    = Enum.TextXAlignment.Right,
                ZIndex            = 10,
                Parent            = card,
            })

            local chevron = New("TextLabel", {
                Size              = UDim2.new(0, 18, 1, 0),
                Position          = UDim2.new(1, -22, 0, 0),
                BackgroundTransparency = 1,
                Text              = "▾",
                TextColor3        = T.TxtMid,
                Font              = T.FontReg,
                TextSize          = 11,
                ZIndex            = 10,
                Parent            = card,
            })

            local list = New("Frame", {
                Size             = UDim2.new(1, 0, 0, 0),
                Position         = UDim2.new(0, 0, 1, 4),
                BackgroundColor3 = T.PopUp,
                BorderSizePixel  = 0,
                ClipsDescendants = true,
                ZIndex           = 20,
                Visible          = false,
                Parent           = card,
            })
            Rounded(list, 8)
            Stroke(list, 0.7, T.Accent, 1)
            do
                local l = Instance.new("UIListLayout")
                l.SortOrder = Enum.SortOrder.LayoutOrder
                l.Parent    = list
                local p = Instance.new("UIPadding")
                p.PaddingTop = UDim.new(0,4); p.PaddingBottom = UDim.new(0,4); p.Parent = list
            end

            for i, opt in ipairs(options) do
                local row = New("TextButton", {
                    Size              = UDim2.new(1, 0, 0, 30),
                    BackgroundColor3  = T.Accent,
                    BackgroundTransparency = 1,
                    BorderSizePixel   = 0,
                    Text              = tostring(opt),
                    TextColor3        = opt == selected and T.Accent or T.TxtHi,
                    Font              = T.FontReg,
                    TextSize          = 12,
                    TextXAlignment    = Enum.TextXAlignment.Left,
                    ZIndex            = 22,
                    LayoutOrder       = i,
                    Parent            = list,
                })
                local p2 = Instance.new("UIPadding"); p2.PaddingLeft = UDim.new(0,14); p2.Parent = row
                row.MouseEnter:Connect(function() Tween(row,{BackgroundTransparency=0.85},0.1) end)
                row.MouseLeave:Connect(function() Tween(row,{BackgroundTransparency=1},0.1) end)
                row.MouseButton1Click:Connect(function()
                    selected    = opt
                    selTxt.Text = tostring(opt)
                    for _, c in ipairs(list:GetChildren()) do
                        if c:IsA("TextButton") then c.TextColor3 = T.TxtHi end
                    end
                    row.TextColor3 = T.Accent
                    if cfg.Callback then cfg.Callback(opt) end
                    open = false
                    Tween(list,    {Size=UDim2.new(1,0,0,0)},0.18)
                    Tween(chevron, {Rotation=0},0.18)
                    task.wait(0.2); list.Visible = false
                end)
            end

            btn.MouseButton1Click:Connect(function()
                open = not open
                if open then
                    list.Visible = true; list.Size = UDim2.new(1,0,0,0)
                    Tween(list,    {Size=UDim2.new(1,0,0,dropH)},0.2,Enum.EasingStyle.Back)
                    Tween(chevron, {Rotation=180},0.18)
                else
                    Tween(list,    {Size=UDim2.new(1,0,0,0)},0.18)
                    Tween(chevron, {Rotation=0},0.18)
                    task.wait(0.2); list.Visible = false
                end
            end)
            btn.MouseEnter:Connect(function() Tween(card,{BackgroundColor3=T.Elevated},0.12) end)
            btn.MouseLeave:Connect(function() Tween(card,{BackgroundColor3=T.Surface },0.12) end)

            return {
                Set = function(_, v) selected=v; selTxt.Text=tostring(v); if cfg.Callback then cfg.Callback(v) end end,
                Get = function(_) return selected end,
            }
        end

        -- ── Tab:AddInput({ Label, Placeholder?, Default?, Callback }) → { Set, Get } ──
        function Tab:AddInput(cfg)
            cfg = cfg or {}
            local card = Card(60)

            New("TextLabel", {
                Size              = UDim2.new(1, -16, 0, 18),
                Position          = UDim2.new(0, 14, 0, 8),
                BackgroundTransparency = 1,
                Text              = cfg.Label or "Input",
                TextColor3        = T.TxtHi,
                Font              = T.FontReg,
                TextSize          = 13,
                TextXAlignment    = Enum.TextXAlignment.Left,
                Parent            = card,
            })

            local box = New("TextBox", {
                Size              = UDim2.new(1, -28, 0, 24),
                Position          = UDim2.new(0, 14, 0, 29),
                BackgroundColor3  = T.Elevated,
                BorderSizePixel   = 0,
                Text              = cfg.Default or "",
                PlaceholderText   = cfg.Placeholder or "Type here...",
                PlaceholderColor3 = T.TxtLo,
                TextColor3        = T.TxtHi,
                Font              = T.FontReg,
                TextSize          = 12,
                TextXAlignment    = Enum.TextXAlignment.Left,
                ClearTextOnFocus  = false,
                Parent            = card,
            })
            Rounded(box, 6)
            local bStroke = Stroke(box, 0.88)
            local p3 = Instance.new("UIPadding"); p3.PaddingLeft = UDim.new(0,8); p3.Parent = box

            box.Focused:Connect(function()
                Tween(bStroke, {Color = T.Accent, Transparency = 0.45}, 0.15)
            end)
            box.FocusLost:Connect(function(enter)
                Tween(bStroke, {Color = T.Border, Transparency = 0.88}, 0.15)
                if enter and cfg.Callback then cfg.Callback(box.Text) end
            end)

            return {
                Get = function(_) return box.Text end,
                Set = function(_, v) box.Text = tostring(v) end,
            }
        end

        return Tab
    end -- :AddTab

    -- Open animation
    main.BackgroundTransparency = 1
    Tween(main, {Size = fullSize, BackgroundTransparency = 0}, 0.32, Enum.EasingStyle.Back)

    return Window
end -- :CreateWindow

return NexusUI
