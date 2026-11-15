--[[
    Isle  -  a dark, Apple-style UI library for Roblox

    local Isle = loadstring(game:HttpGet("YOUR_RAW_URL"))()

    local win  = Isle:CreateWindow({ Title = "Atlas", Subtitle = "v1.0" })   -- alias: MakeWindow
    local tab  = win:CreateTab("Main")                                       -- alias: MakeTab
    local sec  = tab:Section("Movement")
    sec:Toggle({ Name = "Sprint", Flag = "sprint", Callback = function(on) end })
    Isle:Notify({ Title = "Loaded", Content = "Atlas is ready", Type = "Success" })

    See example.lua for every component.
]]

--// services ----------------------------------------------------------------
local cloneref = cloneref or function(o) return o end
local function service(name) return cloneref(game:GetService(name)) end

local Players          = service("Players")
local TweenService     = service("TweenService")
local UserInputService = service("UserInputService")
local RunService       = service("RunService")
local TextService      = service("TextService")
local HttpService      = service("HttpService")
local GuiService       = service("GuiService")
local Stats            = service("Stats")
local CoreGui          = service("CoreGui")

local env = (getgenv and getgenv()) or _G
if env.__ISLE then
    pcall(function() env.__ISLE:Destroy() end)
end

--// theme -------------------------------------------------------------------
-- Neutral graphite, white overlays for depth, one accent. Nothing blue or purple.
local Theme = {
    Base   = Color3.fromRGB(24, 24, 25),
    Accent = Color3.fromRGB(48, 209, 88),
    OnAccent = Color3.fromRGB(14, 14, 14),
    Text   = Color3.fromRGB(245, 245, 247),
    Dim    = Color3.fromRGB(152, 152, 158),
    Faint  = Color3.fromRGB(104, 104, 110),
    Track  = Color3.fromRGB(70, 70, 75),
    Tile   = Color3.fromRGB(50, 50, 54),
    TileOn = Color3.fromRGB(88, 88, 94),
    Types  = {
        Info    = Color3.fromRGB(220, 220, 226),
        Success = Color3.fromRGB(48, 209, 88),
        Warning = Color3.fromRGB(255, 189, 46),
        Error   = Color3.fromRGB(255, 95, 87),
    },
}
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

-- Soft 9-slice drop shadow. If this asset is ever unavailable the shadow
-- simply doesn't render; swap the id here and everything else still works.
local SHADOW_ASSET = "rbxassetid://6014261993"

local FONT_FAMILY = "rbxasset://fonts/families/GothamSSm.json"
local FONT_WEIGHT = {
    Regular  = Enum.FontWeight.Regular,
    Medium   = Enum.FontWeight.Medium,
    SemiBold = Enum.FontWeight.SemiBold,
    Bold     = Enum.FontWeight.Bold,
}
local FONT_FALLBACK = {
    Regular  = Enum.Font.Gotham,
    Medium   = Enum.Font.GothamMedium,
    SemiBold = Enum.Font.GothamSemibold,
    Bold     = Enum.Font.GothamBold,
}

local DOCK_H, TILE, TILE_MAG = 68, 44, 52

--// library table -----------------------------------------------------------
local Isle = {
    Version = "1.0.0",
    Theme = Theme,
    Flags = {},
    Windows = {},
    Visible = true,
    ToggleKey = Enum.KeyCode.RightShift,
    _conns = {},
    _flagged = {},
    _accentHooks = {},
    _z = 10,
}

local Window, Tab, Section = {}, {}, {}
Window.__index, Tab.__index, Section.__index = Window, Tab, Section

--// helpers -----------------------------------------------------------------
local function tween(obj, props, time, style, dir)
    local t = TweenService:Create(obj, TweenInfo.new(time or 0.2, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function setFont(obj, weight)
    weight = weight or "Regular"
    local ok = pcall(function()
        obj.FontFace = Font.new(FONT_FAMILY, FONT_WEIGHT[weight], Enum.FontStyle.Normal)
    end)
    if not ok then obj.Font = FONT_FALLBACK[weight] end
end

local function new(class, props, kids)
    local o = Instance.new(class)
    props = props or {}
    if o:IsA("GuiObject") then
        o.BorderSizePixel = 0
        o.BackgroundTransparency = props.BackgroundColor3 and 0 or 1
    end
    if o:IsA("GuiButton") then o.AutoButtonColor = false end
    local isText = o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox")
    if isText then
        o.Text = ""
        o.TextColor3 = Theme.Text
        o.TextSize = 14
        o.TextXAlignment = Enum.TextXAlignment.Left
    end
    for k, v in pairs(props) do
        if k ~= "Parent" and k ~= "Weight" then o[k] = v end
    end
    if isText then setFont(o, props.Weight) end
    for _, c in ipairs(kids or {}) do c.Parent = o end
    if props.Parent then o.Parent = props.Parent end
    return o
end

local function round(inst, r)
    return new("UICorner", { CornerRadius = UDim.new(0, r), Parent = inst })
end

local function stroke(inst, color, transparency, thickness)
    return new("UIStroke", {
        Color = color or WHITE,
        Transparency = transparency or 0.9,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = inst,
    })
end

local function pad(inst, l, r, t, b)
    return new("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or l or 0),
        PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or t or 0),
        Parent = inst,
    })
end

local function addShadow(parent, strength, spread, dy)
    return new("ImageLabel", {
        Name = "Shadow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, dy or 6),
        Size = UDim2.new(1, spread * 2, 1, spread * 2),
        Image = SHADOW_ASSET,
        ImageColor3 = BLACK,
        ImageTransparency = 1 - strength,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        ZIndex = 0,
        Parent = parent,
    })
end

local function measure(str, size, font)
    local ok, v = pcall(function()
        return TextService:GetTextSize(str, size, font or Enum.Font.GothamMedium, Vector2.new(1000, 100)).X
    end)
    return ok and v or (#str * size * 0.55)
end

local function fire(cb, ...)
    if type(cb) ~= "function" then return end
    task.spawn(function(...)
        local ok, err = pcall(cb, ...)
        if not ok then warn("[Isle] callback error: " .. tostring(err)) end
    end, ...)
end

local function isPress(i)
    return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

local function isMove(i)
    return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
end

local function mount(gui)
    if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then gui.Parent = h return end
    end
    local ok = pcall(function() gui.Parent = CoreGui end)
    if ok and gui.Parent == CoreGui then return end
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function Isle:_connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(self._conns, c)
    return c
end

function Isle:_onAccent(fn)
    table.insert(self._accentHooks, fn)
    fn(Theme.Accent)
end

function Isle:SetAccent(color)
    Theme.Accent = color
    for i = #self._accentHooks, 1, -1 do
        local ok, alive = pcall(self._accentHooks[i], color)
        if not ok or alive == false then table.remove(self._accentHooks, i) end
    end
end

--// init --------------------------------------------------------------------
function Isle:_init()
    if self.Gui then return end
    local gui = new("ScreenGui", {
        Name = "Isle",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 999,
    })
    mount(gui)
    self.Gui = gui
    self.Layer = new("Frame", { Name = "Layer", Size = UDim2.fromScale(1, 1), Parent = gui })

    self:_buildIsland()
    self:_buildDock()

    self:_connect(UserInputService.InputBegan, function(i, processed)
        if processed then return end
        if i.KeyCode == self.ToggleKey then self:SetVisible(not self.Visible) end
    end)
end

--// dynamic island ----------------------------------------------------------
function Isle:_buildIsland()
    local root = new("Frame", {
        Name = "Island",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 12),
        Size = UDim2.fromOffset(110, 34),
        ZIndex = 10,
        Parent = self.Gui,
    })
    addShadow(root, 0.5, 16, 4)
    local pill = new("Frame", { Name = "Pill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, ClipsDescendants = true, ZIndex = 2, Parent = root })
    local corner = round(pill, 17)
    stroke(pill, WHITE, 0.9)

    -- idle layer: status dot, title, live stats
    local idle = new("CanvasGroup", { Name = "Idle", Size = UDim2.fromScale(1, 1), Parent = pill })
    local dot = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0),
        Size = UDim2.fromOffset(8, 8), BackgroundColor3 = Theme.Accent, Parent = idle,
    })
    round(dot, 4)
    self:_onAccent(function(c) if dot.Parent then dot.BackgroundColor3 = c else return false end end)
    local title = new("TextLabel", {
        Position = UDim2.fromOffset(30, 0), Size = UDim2.new(0, 160, 1, 0),
        Text = self.IslandTitle or "Isle", TextSize = 13, Weight = "Medium", Parent = idle,
    })
    local statsL = new("TextLabel", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 0), Size = UDim2.new(0, 110, 1, 0),
        Text = "", TextSize = 12, TextColor3 = Theme.Dim, TextXAlignment = Enum.TextXAlignment.Right,
        TextTransparency = 1, Parent = idle,
    })

    -- notification layer
    local note = new("CanvasGroup", { Name = "Note", Size = UDim2.fromScale(1, 1), GroupTransparency = 1, Parent = pill })
    local ring = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 18, 0.5, 0), Size = UDim2.fromOffset(32, 32),
        BackgroundColor3 = Theme.Types.Info, BackgroundTransparency = 0.8, Parent = note,
    })
    round(ring, 16)
    local core = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 10),
        BackgroundColor3 = Theme.Types.Info, Parent = ring,
    })
    round(core, 5)
    local nTitle = new("TextLabel", { Position = UDim2.fromOffset(64, 14), Size = UDim2.new(1, -82, 0, 18), TextSize = 14, Weight = "SemiBold", TextTruncate = Enum.TextTruncate.AtEnd, Parent = note })
    local nBody = new("TextLabel", {
        Position = UDim2.fromOffset(64, 33), Size = UDim2.new(1, -82, 0, 30), TextSize = 12, TextColor3 = Theme.Dim,
        TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.AtEnd, Parent = note,
    })

    local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = pill })

    local state, hover, skip = "idle", false, false
    local fps, ping = 0, 0

    local function layoutIdle()
        local w = math.clamp(measure(title.Text, 13) + 50, 100, 250)
        if hover then w += 118 end
        tween(root, { Size = UDim2.fromOffset(w, 34) }, 0.35)
        tween(corner, { CornerRadius = UDim.new(0, 17) }, 0.35)
        tween(statsL, { TextTransparency = hover and 0 or 1 }, 0.25)
    end

    hit.MouseEnter:Connect(function() hover = true if state == "idle" then layoutIdle() end end)
    hit.MouseLeave:Connect(function() hover = false if state == "idle" then layoutIdle() end end)
    hit.MouseButton1Click:Connect(function()
        if state == "note" then
            skip = true
        else
            hover = not hover
            layoutIdle()
        end
    end)

    -- live stats
    local frames, last = 0, os.clock()
    self:_connect(RunService.Heartbeat, function()
        frames += 1
        local now = os.clock()
        if now - last >= 0.5 then
            fps = math.floor(frames / (now - last) + 0.5)
            frames, last = 0, now
            pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5) end)
            if hover then statsL.Text = string.format("%d fps   %d ms", fps, ping) end
        end
    end)

    local function showNote(n)
        state, skip = "note", false
        local color = Theme.Types[n.Type or "Info"] or Theme.Types.Info
        local body = tostring(n.Content or "")
        local h = body ~= "" and 78 or 56
        ring.BackgroundColor3, core.BackgroundColor3 = color, color
        nTitle.Text = tostring(n.Title or "Notification")
        nBody.Text = body
        nBody.Visible = body ~= ""
        if body ~= "" then
            nTitle.Position, nTitle.Size = UDim2.fromOffset(64, 14), UDim2.new(1, -82, 0, 18)
        else
            nTitle.Position, nTitle.Size = UDim2.fromOffset(64, 0), UDim2.new(1, -82, 1, 0)
        end

        tween(idle, { GroupTransparency = 1 }, 0.12)
        tween(root, { Size = UDim2.fromOffset(344, h) }, 0.55, Enum.EasingStyle.Back)
        tween(corner, { CornerRadius = UDim.new(0, 28) }, 0.45)
        task.wait(0.1)
        tween(note, { GroupTransparency = 0 }, 0.22)

        local t, dur = 0, n.Duration or 4
        while t < dur and not skip and root.Parent do t += task.wait(0.05) end
        tween(note, { GroupTransparency = 1 }, 0.15)
        task.wait(0.16)
    end

    self.Island = {
        SetTitle = function(text)
            title.Text = text
            if state == "idle" then layoutIdle() end
        end,
        Queue = {},
        Busy = false,
        Run = function(isl)
            isl.Busy = true
            task.spawn(function()
                while #isl.Queue > 0 and root.Parent do
                    showNote(table.remove(isl.Queue, 1))
                end
                state = "idle"
                tween(idle, { GroupTransparency = 0 }, 0.25)
                layoutIdle()
                isl.Busy = false
            end)
        end,
    }
    layoutIdle()
end

function Isle:Notify(o)
    self:_init()
    if type(o) == "string" then o = { Title = o } end
    local isl = self.Island
    table.insert(isl.Queue, o or {})
    if not isl.Busy then isl:Run() end
end

function Isle:SetIslandTitle(text)
    self:_init()
    self.IslandTitle = text
    self.Island.SetTitle(text)
end

--// dock --------------------------------------------------------------------
function Isle:_buildDock()
    local root = new("Frame", {
        Name = "Dock",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -18),
        Size = UDim2.fromOffset(100, DOCK_H),
        Visible = false,
        ZIndex = 100000,
        Parent = self.Layer,
    })
    addShadow(root, 0.55, 26, 10)
    local bar = new("Frame", { Name = "Bar", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(32, 32, 34), BackgroundTransparency = 0.1, ZIndex = 2, Parent = root })
    round(bar, 24)
    stroke(bar, WHITE, 0.88)
    local items = new("Frame", { Name = "Items", Size = UDim2.fromScale(1, 1), Parent = bar })
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = items,
    })

    local tip = new("TextLabel", {
        Name = "Tooltip",
        AnchorPoint = Vector2.new(0.5, 1),
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundColor3 = Color3.fromRGB(14, 14, 15),
        BackgroundTransparency = 0.12,
        Text = "", TextSize = 12, Weight = "Medium",
        TextXAlignment = Enum.TextXAlignment.Center,
        Visible = false,
        ZIndex = 100001,
        Parent = self.Gui,
    })
    round(tip, 8)
    stroke(tip, WHITE, 0.9)
    pad(tip, 10, 10, 6, 6)

    self.Dock = { Root = root, Items = items, Tip = tip }
end

function Isle:_hideTip()
    if self.Dock then self.Dock.Tip.Visible = false end
end

function Isle:_showTip(tile, text)
    local d = self.Dock
    d.Tip.Text = text
    d.Tip.Visible = true
    local function place()
        if not tile.Parent then return end
        d.Tip.Position = UDim2.fromOffset(tile.AbsolutePosition.X + tile.AbsoluteSize.X / 2, d.Root.AbsolutePosition.Y - 10)
    end
    place()
    task.delay(0.16, function() if d.Tip.Visible then place() end end)
end

function Isle:_makeTile(e, order)
    local items = self.Dock.Items
    if e.Divider then
        new("Frame", { Size = UDim2.fromOffset(1, 26), BackgroundColor3 = WHITE, BackgroundTransparency = 0.85, LayoutOrder = order, Parent = items })
        return
    end
    local tile = new("TextButton", {
        Name = "Tile",
        Size = UDim2.fromOffset(TILE, TILE),
        BackgroundColor3 = e.Active and Theme.TileOn or Theme.Tile,
        LayoutOrder = order,
        Parent = items,
    })
    if e.Dim then tile.BackgroundTransparency = 0.5 end
    round(tile, 12)
    stroke(tile, WHITE, e.Active and 0.78 or 0.92)

    if e.Icon then
        new("ImageLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(24, 24),
            Image = e.Icon, ImageTransparency = e.Dim and 0.5 or 0, Parent = tile,
        })
    else
        new("TextLabel", {
            Size = UDim2.fromScale(1, 1), Text = e.Glyph or string.upper(string.sub(e.Name, 1, 1)),
            TextSize = 18, Weight = "SemiBold", TextXAlignment = Enum.TextXAlignment.Center,
            TextTransparency = e.Dim and 0.5 or 0, Parent = tile,
        })
    end
    if e.Active then
        local dot = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 4), Size = UDim2.fromOffset(4, 4),
            BackgroundColor3 = WHITE, Parent = tile,
        })
        round(dot, 2)
    end

    tile.MouseEnter:Connect(function()
        tween(tile, { Size = UDim2.fromOffset(TILE_MAG, TILE_MAG) }, 0.18, Enum.EasingStyle.Back)
        self:_showTip(tile, e.Name)
    end)
    tile.MouseLeave:Connect(function()
        tween(tile, { Size = UDim2.fromOffset(TILE, TILE) }, 0.2)
        self:_hideTip()
    end)
    tile.MouseButton1Down:Connect(function()
        tween(tile, { Size = UDim2.fromOffset(TILE - 4, TILE - 4) }, 0.08)
    end)
    tile.MouseButton1Click:Connect(function()
        self:_hideTip()
        e.Click()
    end)
end

function Isle:_renderDock()
    local d = self.Dock
    if not d then return end
    for _, c in ipairs(d.Items:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
    self:_hideTip()

    local entries = {}
    local win = self.Focused
    if win then
        for _, tab in ipairs(win.Tabs) do
            table.insert(entries, {
                Name = tab.Name, Icon = tab.Icon, Glyph = tab.Glyph,
                Active = win.ActiveTab == tab,
                Click = function() self:_focus(win) win:SetTab(tab) end,
            })
        end
    end
    if #self.Windows > 1 or (not win and #self.Windows > 0) then
        if #entries > 0 then table.insert(entries, { Divider = true }) end
        for _, w in ipairs(self.Windows) do
            table.insert(entries, {
                Name = w.Title, Glyph = w.Glyph,
                Active = (w == win), Dim = w.Minimized,
                Click = function()
                    if w.Minimized then w:Restore()
                    elseif w == self.Focused then w:Minimize()
                    else self:_focus(w) end
                end,
            })
        end
    end

    local width = 24 + (TILE_MAG - TILE)
    for idx, e in ipairs(entries) do
        self:_makeTile(e, idx)
        width += (e.Divider and 1 or TILE) + (idx > 1 and 8 or 0)
    end
    d.Root.Visible = #entries > 0
    tween(d.Root, { Size = UDim2.fromOffset(width, DOCK_H) }, 0.3)
end

--// global visibility / config ----------------------------------------------
function Isle:_focus(win)
    self._z += 1
    win.Holder.ZIndex = self._z
    if self.Focused ~= win then
        self.Focused = win
        self:_renderDock()
    end
end

function Isle:SetVisible(v)
    self.Visible = v
    if not self.Dock then return end
    tween(self.Dock.Root, { Position = v and UDim2.new(0.5, 0, 1, -18) or UDim2.new(0.5, 0, 1, 120) }, 0.35)
    for _, w in ipairs(self.Windows) do
        w:_animate(v and not w.Minimized)
    end
    if not v then self:_hideTip() end
end

function Isle:SaveConfig(name)
    if not (writefile and HttpService) then return false end
    local data = {}
    for flag, el in pairs(self._flagged) do data[flag] = el.Value end
    pcall(function() if makefolder and not (isfolder and isfolder("Isle")) then makefolder("Isle") end end)
    local ok = pcall(writefile, "Isle/" .. name .. ".json", HttpService:JSONEncode(data))
    return ok
end

function Isle:LoadConfig(name)
    if not (readfile and isfile) then return false end
    local path = "Isle/" .. name .. ".json"
    if not isfile(path) then return false end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok then return false end
    for flag, v in pairs(data) do
        local el = self._flagged[flag]
        if el then pcall(el.Set, v) end
    end
    return true
end

function Isle:Destroy()
    for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    for _, w in ipairs(self.Windows) do
        for _, c in ipairs(w._conns) do pcall(function() c:Disconnect() end) end
    end
    if self.Gui then self.Gui:Destroy() end
    env.__ISLE = nil
end

--// window ------------------------------------------------------------------
function Isle:CreateWindow(o)
    self:_init()
    if type(o) == "string" then o = { Title = o } end
    o = o or {}
    if o.Accent then self:SetAccent(o.Accent) end
    if o.ToggleKey then self.ToggleKey = o.ToggleKey end

    local win = setmetatable({
        Library = self,
        Title = o.Title or "Window",
        Glyph = o.Glyph,
        Tabs = {},
        Minimized = false,
        _conns = {},
        _shown = true,
    }, Window)

    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
    local size = o.Size or Vector2.new(580, 400)
    if typeof(size) == "UDim2" then size = Vector2.new(size.X.Offset, size.Y.Offset) end
    size = Vector2.new(math.min(size.X, vp.X - 24), math.min(size.Y, vp.Y - 150))

    local n = #self.Windows
    local holder = new("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = o.Position or UDim2.new(0.5, n * 28, 0.5, -26 + n * 28),
        Size = UDim2.fromOffset(size.X, size.Y),
        Parent = self.Layer,
    })
    local scale = new("UIScale", { Scale = 0.95, Parent = holder })
    local shadow = addShadow(holder, 0.6, 34, 10)
    local main = new("CanvasGroup", {
        Name = "Main", Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Base, BackgroundTransparency = o.Transparency or 0.05,
        GroupTransparency = 1, ZIndex = 2, Parent = holder,
    })
    round(main, 16)
    local rim = new("Frame", { Name = "Rim", Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = holder })
    round(rim, 16)
    local rimStroke = stroke(rim, WHITE, 1)

    win.Holder, win.Main, win.Scale, win.Shadow, win.Rim, win.RimStroke = holder, main, scale, shadow, rim, rimStroke

    -- title bar
    local top = new("Frame", { Name = "Top", Size = UDim2.new(1, 0, 0, 48), Parent = main })
    new("Frame", { Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.93, Parent = top })

    local function light(x, color, fn)
        local b = new("TextButton", { Size = UDim2.fromOffset(12, 12), Position = UDim2.new(0, x, 0.5, -6), BackgroundColor3 = color, Parent = top })
        round(b, 6)
        b.MouseEnter:Connect(function() tween(b, { BackgroundTransparency = 0.3 }, 0.1) end)
        b.MouseLeave:Connect(function() tween(b, { BackgroundTransparency = 0 }, 0.15) end)
        b.MouseButton1Click:Connect(fn)
    end
    light(16, Color3.fromRGB(240, 96, 88), function() win:Destroy() end)
    light(36, Color3.fromRGB(240, 186, 56), function() win:Minimize() end)

    local hasSub = o.Subtitle and o.Subtitle ~= ""
    new("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, hasSub and -8 or 0),
        Size = UDim2.new(1, -180, 0, 18), Text = win.Title, TextSize = 14, Weight = "SemiBold",
        TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, Parent = top,
    })
    if hasSub then
        new("TextLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 9),
            Size = UDim2.new(1, -180, 0, 14), Text = o.Subtitle, TextSize = 11, TextColor3 = Theme.Dim,
            TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, Parent = top,
        })
    end

    win.Pages = new("Frame", { Name = "Pages", Position = UDim2.fromOffset(0, 49), Size = UDim2.new(1, 0, 1, -49), ClipsDescendants = true, Parent = main })

    -- dragging
    local dragging, dragStart, startPos
    top.InputBegan:Connect(function(i)
        if isPress(i) then
            dragging, dragStart, startPos = true, i.Position, holder.Position
            self:_focus(win)
        end
    end)
    win:_connect(UserInputService.InputChanged, function(i)
        if dragging and isMove(i) then
            local d = i.Position - dragStart
            holder.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    win:_connect(UserInputService.InputEnded, function(i)
        if dragging and isPress(i) then dragging = false end
    end)

    -- click anywhere on a window to bring it forward
    win:_connect(UserInputService.InputBegan, function(i)
        if not isPress(i) or not win._shown or self.Focused == win then return end
        local p
        if i.UserInputType == Enum.UserInputType.Touch then
            local inset = GuiService:GetGuiInset()
            p = Vector2.new(i.Position.X, i.Position.Y + inset.Y)
        else
            p = UserInputService:GetMouseLocation()
        end
        local a, s = holder.AbsolutePosition, holder.AbsoluteSize
        if p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y then
            self:_focus(win)
        end
    end)

    table.insert(self.Windows, win)
    if not self._titleSet then
        self._titleSet = true
        self.Island.SetTitle(o.IslandTitle or win.Title)
    end
    self:_focus(win)
    win:_animate(true)
    return win
end
Isle.MakeWindow = Isle.CreateWindow

function Window:_connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(self._conns, c)
    return c
end

function Window:_animate(show)
    self._shown = show
    local h = self.Holder
    if show then
        h.Visible = true
        tween(self.Scale, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)
        tween(self.Main, { GroupTransparency = 0 }, 0.25)
        tween(self.Shadow, { ImageTransparency = 0.4 }, 0.3)
        tween(self.RimStroke, { Transparency = 0.9 }, 0.3)
    else
        tween(self.Scale, { Scale = 0.95 }, 0.22)
        tween(self.Main, { GroupTransparency = 1 }, 0.2)
        tween(self.Shadow, { ImageTransparency = 1 }, 0.2)
        tween(self.RimStroke, { Transparency = 1 }, 0.2)
        task.delay(0.24, function()
            if not self._shown and h.Parent then h.Visible = false end
        end)
    end
end

function Window:Minimize()
    if self.Minimized then return end
    self.Minimized = true
    self:_animate(false)
    local lib = self.Library
    if lib.Focused == self then
        local best
        for _, w in ipairs(lib.Windows) do
            if not w.Minimized and (not best or w.Holder.ZIndex > best.Holder.ZIndex) then best = w end
        end
        lib.Focused = best
    end
    lib:_renderDock()
end

function Window:Restore()
    if not self.Minimized then return end
    self.Minimized = false
    self:_animate(true)
    self.Library.Focused = nil
    self.Library:_focus(self)
end

function Window:Destroy()
    local lib = self.Library
    for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    for i, w in ipairs(lib.Windows) do
        if w == self then table.remove(lib.Windows, i) break end
    end
    if lib.Focused == self then
        lib.Focused = nil
        local best
        for _, w in ipairs(lib.Windows) do
            if not w.Minimized and (not best or w.Holder.ZIndex > best.Holder.ZIndex) then best = w end
        end
        lib.Focused = best
    end
    self.Holder:Destroy()
    lib:_renderDock()
end

function Window:Notify(o) self.Library:Notify(o) end

function Window:SetTab(tab, instant)
    if self.ActiveTab == tab then return end
    local old = self.ActiveTab
    self.ActiveTab = tab
    if old then
        tween(old.Page, { GroupTransparency = 1 }, 0.15)
        task.delay(0.16, function()
            if self.ActiveTab ~= old then old.Page.Visible = false end
        end)
    end
    tab.Page.Visible = true
    tab.Scroll.Position = UDim2.fromOffset(0, instant and 0 or 10)
    tween(tab.Page, { GroupTransparency = 0 }, 0.25)
    tween(tab.Scroll, { Position = UDim2.new() }, 0.32)
    self.Library:_renderDock()
end

function Window:CreateTab(name, o)
    if type(name) == "table" then o = name name = o.Name end
    o = o or {}
    local tab = setmetatable({
        Window = self, Name = name or "Tab", Icon = o.Icon, Glyph = o.Glyph, Order = 0,
    }, Tab)

    local page = new("CanvasGroup", { Name = tab.Name, Size = UDim2.fromScale(1, 1), GroupTransparency = 1, Visible = false, Parent = self.Pages })
    local scroll = new("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3, ScrollBarImageColor3 = WHITE, ScrollBarImageTransparency = 0.75,
        ScrollingDirection = Enum.ScrollingDirection.Y, Parent = page,
    })
    new("UIListLayout", { Padding = UDim.new(0, 18), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
    pad(scroll, 18, 18, 8, 28)
    if o.ShowTitle ~= false then
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 34), Text = o.Title or tab.Name, TextSize = 26, Weight = "SemiBold",
            LayoutOrder = 0, Parent = scroll,
        })
    end
    tab.Page, tab.Scroll = page, scroll

    table.insert(self.Tabs, tab)
    if not self.ActiveTab then self:SetTab(tab, true) else self.Library:_renderDock() end
    return tab
end
Window.MakeTab = Window.CreateTab

--// tab / section -----------------------------------------------------------
function Tab:Section(title)
    local lib = self.Window.Library
    self.Order += 1
    local wrap = new("Frame", { Name = "Section", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = self.Order, Parent = self.Scroll })
    new("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder, Parent = wrap })
    if title and title ~= "" then
        local h = new("TextLabel", { Size = UDim2.new(1, 0, 0, 16), Text = title, TextSize = 12, TextColor3 = Theme.Dim, Weight = "Medium", LayoutOrder = 0, Parent = wrap })
        pad(h, 6, 0, 0, 0)
    end
    local group = new("Frame", {
        Name = "Group", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = WHITE, BackgroundTransparency = 0.94, ClipsDescendants = true, LayoutOrder = 1, Parent = wrap,
    })
    round(group, 12)
    stroke(group, WHITE, 0.95)
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = group })

    local sec = setmetatable({ Tab = self, Lib = lib, Group = group, Count = 0 }, Section)
    self.Last = sec
    return sec
end

local COMPONENTS = { "Label", "Button", "Toggle", "Slider", "Dropdown", "Input", "Keybind" }
for _, name in ipairs(COMPONENTS) do
    Tab[name] = function(self, ...)
        local sec = self.Last or self:Section()
        return sec[name](sec, ...)
    end
end

-- row plumbing
local function newRow(sec, minH, auto)
    sec.Count += 1
    local r = new("Frame", {
        Name = "Row", Size = UDim2.new(1, 0, 0, minH or 44), BackgroundColor3 = WHITE, BackgroundTransparency = 1,
        LayoutOrder = sec.Count, Parent = sec.Group,
    })
    if auto then r.AutomaticSize = Enum.AutomaticSize.Y end
    if sec.Count > 1 then
        new("Frame", { Name = "Line", Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -14, 0, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.92, Parent = r })
    end
    return r
end

local function textStack(row, o, reserve)
    local stack = new("Frame", {
        Name = "Text", Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -(28 + (reserve or 0)), 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, Parent = row,
    })
    new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = stack })
    pad(stack, 0, 0, 13, 13)
    local nameL = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.Y, Text = o.Name or "", TextWrapped = true,
        Weight = "Medium", LayoutOrder = 1, Parent = stack,
    })
    local descL
    if o.Description and o.Description ~= "" then
        descL = new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 14), AutomaticSize = Enum.AutomaticSize.Y, Text = o.Description, TextSize = 12,
            TextColor3 = Theme.Dim, TextWrapped = true, LayoutOrder = 2, Parent = stack,
        })
    end
    return nameL, descL
end

local function overlay(row)
    local hit = new("TextButton", { Name = "Hit", Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = row })
    hit.MouseEnter:Connect(function() tween(row, { BackgroundTransparency = 0.955 }, 0.12) end)
    hit.MouseLeave:Connect(function() tween(row, { BackgroundTransparency = 1 }, 0.2) end)
    return hit
end

local function bind(lib, o, obj)
    if o.Flag then
        lib._flagged[o.Flag] = obj
        lib.Flags[o.Flag] = obj.Value
    end
end

local function changed(lib, o, obj, ...)
    if o.Flag then lib.Flags[o.Flag] = obj.Value end
    fire(o.Callback, ...)
end

--// components -------------------------------------------------------------
function Section:Label(o)
    if type(o) == "string" then o = { Name = o } end
    local r = newRow(self, 44, true)
    local nameL = textStack(r, o, 0)
    nameL.TextColor3 = Theme.Dim
    return {
        Instance = r,
        Set = function(text) nameL.Text = tostring(text) end,
    }
end

function Section:Button(o)
    if type(o) == "string" then o = { Name = o } end
    o = o or {}
    local lib = self.Lib
    local r = newRow(self, 44, true)
    local label = o.ButtonText or "Run"
    local w = math.max(56, measure(label, 13) + 26)
    textStack(r, o, w + 6)

    local hit = overlay(r)
    local pill = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(w, 28),
        BackgroundColor3 = WHITE, BackgroundTransparency = 0.88, Parent = r,
    })
    round(pill, 8)
    local pl = new("TextLabel", { Size = UDim2.fromScale(1, 1), Text = label, TextSize = 13, Weight = "Medium", TextXAlignment = Enum.TextXAlignment.Center, Parent = pill })

    local function release()
        tween(pill, { BackgroundColor3 = WHITE, BackgroundTransparency = 0.88 }, 0.25)
        tween(pl, { TextColor3 = Theme.Text }, 0.25)
    end
    hit.MouseButton1Down:Connect(function()
        tween(pill, { BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0 }, 0.08)
        tween(pl, { TextColor3 = Theme.OnAccent }, 0.08)
    end)
    hit.MouseButton1Up:Connect(release)
    hit.MouseLeave:Connect(release)
    hit.MouseButton1Click:Connect(function() fire(o.Callback) end)

    return { Instance = r, SetText = function(t) pl.Text = t end }
end

function Section:Toggle(o)
    o = o or {}
    local lib = self.Lib
    local obj = { Value = o.Default == true }
    local r = newRow(self, 44, true)
    textStack(r, o, 56)
    local hit = overlay(r)

    local track = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(46, 28),
        BackgroundColor3 = Theme.Track, Parent = r,
    })
    round(track, 14)
    local knob = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.fromOffset(24, 24),
        BackgroundColor3 = WHITE, Parent = track,
    })
    round(knob, 12)

    local function paint(animate)
        local on = obj.Value
        local t = animate and 0.22 or 0
        tween(track, { BackgroundColor3 = on and Theme.Accent or Theme.Track }, t)
        tween(knob, { Position = on and UDim2.new(1, -26, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) }, t, Enum.EasingStyle.Back)
    end
    function obj.Set(v, silent)
        obj.Value = v == true
        paint(true)
        if not silent then changed(lib, o, obj, obj.Value) end
    end
    function obj.Get() return obj.Value end
    hit.MouseButton1Click:Connect(function() obj.Set(not obj.Value) end)

    lib:_onAccent(function()
        if not track.Parent then return false end
        if obj.Value then track.BackgroundColor3 = Theme.Accent end
    end)
    paint(false)
    bind(lib, o, obj)
    obj.Instance = r
    return obj
end

function Section:Slider(o)
    o = o or {}
    local lib, win = self.Lib, self.Tab.Window
    local min, max = o.Min or 0, o.Max or 100
    local inc = o.Increment or 1
    local suffix = o.Suffix or ""
    local obj = { Value = math.clamp(o.Default or min, min, max) }
    local hasDesc = o.Description and o.Description ~= ""
    local H = hasDesc and 78 or 62
    local r = newRow(self, H)

    new("TextLabel", { Position = UDim2.fromOffset(14, 11), Size = UDim2.new(1, -110, 0, 18), Text = o.Name or "", Weight = "Medium", Parent = r })
    if hasDesc then
        new("TextLabel", { Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -28, 0, 14), Text = o.Description, TextSize = 12, TextColor3 = Theme.Dim, Parent = r })
    end
    local valueL = new("TextLabel", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 11), Size = UDim2.fromOffset(90, 18),
        TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Theme.Dim, TextSize = 13, Parent = r,
    })
    local trackY = H - 20
    local track = new("Frame", {
        Position = UDim2.fromOffset(14, trackY), Size = UDim2.new(1, -28, 0, 6),
        BackgroundColor3 = WHITE, BackgroundTransparency = 0.86, Parent = r,
    })
    round(track, 3)
    local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Accent, Parent = track })
    round(fill, 3)
    local knob = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(18, 18),
        BackgroundColor3 = WHITE, ZIndex = 2, Parent = track,
    })
    round(knob, 9)
    stroke(knob, BLACK, 0.8)
    local hit = new("TextButton", { Position = UDim2.fromOffset(8, trackY - 13), Size = UDim2.new(1, -16, 0, 32), ZIndex = 3, Parent = r })

    local function snap(v)
        v = math.clamp(v, min, max)
        v = math.floor((v - min) / inc + 0.5) * inc + min
        return math.clamp(tonumber(string.format("%.6f", v)), min, max)
    end
    local function paint(animate)
        local a = max == min and 0 or (obj.Value - min) / (max - min)
        local t = animate and 0.07 or 0
        tween(fill, { Size = UDim2.fromScale(a, 1) }, t)
        tween(knob, { Position = UDim2.fromScale(a, 0.5) }, t)
        valueL.Text = string.format("%g", obj.Value) .. suffix
    end
    function obj.Set(v, silent)
        v = snap(tonumber(v) or min)
        if v == obj.Value and silent then return end
        local same = v == obj.Value
        obj.Value = v
        paint(true)
        if not silent and not same then changed(lib, o, obj, v) end
    end
    function obj.Get() return obj.Value end

    local dragging = false
    local function fromX(x)
        local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        obj.Set(min + a * (max - min))
    end
    hit.InputBegan:Connect(function(i)
        if isPress(i) then
            dragging = true
            self.Tab.Scroll.ScrollingEnabled = false
            tween(knob, { Size = UDim2.fromOffset(22, 22) }, 0.12)
            fromX(i.Position.X)
        end
    end)
    win:_connect(UserInputService.InputChanged, function(i)
        if dragging and isMove(i) then fromX(i.Position.X) end
    end)
    win:_connect(UserInputService.InputEnded, function(i)
        if dragging and isPress(i) then
            dragging = false
            self.Tab.Scroll.ScrollingEnabled = true
            tween(knob, { Size = UDim2.fromOffset(18, 18) }, 0.15)
        end
    end)

    lib:_onAccent(function(c) if fill.Parent then fill.BackgroundColor3 = c else return false end end)
    paint(false)
    bind(lib, o, obj)
    obj.Instance = r
    return obj
end

function Section:Dropdown(o)
    o = o or {}
    local lib = self.Lib
    local options = o.Options or {}
    local multi = o.Multi == true
    local obj = { Value = multi and {} or nil }
    local r = newRow(self, 44)
    r.ClipsDescendants = true

    local head = new("Frame", { Name = "Head", Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = WHITE, BackgroundTransparency = 1, Parent = r })
    new("TextLabel", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -200, 1, 0), Text = o.Name or "", Weight = "Medium", Parent = head })
    local arrow = new("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -22, 0.5, 0), Size = UDim2.fromOffset(14, 14),
        Text = ">", TextSize = 14, Weight = "SemiBold", TextColor3 = Theme.Dim, TextXAlignment = Enum.TextXAlignment.Center, Parent = head,
    })
    local valueL = new("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -40, 0.5, 0), Size = UDim2.fromOffset(160, 20),
        TextSize = 13, TextColor3 = Theme.Dim, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, Parent = head,
    })
    local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = head })
    hit.MouseEnter:Connect(function() tween(head, { BackgroundTransparency = 0.955 }, 0.12) end)
    hit.MouseLeave:Connect(function() tween(head, { BackgroundTransparency = 1 }, 0.2) end)

    local sep = new("Frame", { Position = UDim2.fromOffset(14, 44), Size = UDim2.new(1, -14, 0, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.92, Visible = false, Parent = r })
    local list = new("ScrollingFrame", {
        Position = UDim2.fromOffset(0, 45), Size = UDim2.new(1, 0, 0, 0), CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ScrollBarImageColor3 = WHITE,
        ScrollBarImageTransparency = 0.7, Parent = r,
    })
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

    local buttons = {}
    local open = false
    local function height() return math.min(#options, 6) * 32 + 6 end

    local function selected(opt)
        if multi then
            for _, v in ipairs(obj.Value) do if v == opt then return true end end
            return false
        end
        return obj.Value == opt
    end
    local function refresh()
        for opt, b in pairs(buttons) do
            local on = selected(opt)
            b.Label.TextColor3 = on and Theme.Accent or Theme.Text
            b.Dot.Visible = on
        end
        if multi then
            valueL.Text = #obj.Value == 0 and "None" or table.concat(obj.Value, ", ")
        else
            valueL.Text = obj.Value ~= nil and tostring(obj.Value) or "None"
        end
    end
    local function setOpen(v)
        open = v
        sep.Visible = v
        local h = v and height() or 0
        tween(list, { Size = UDim2.new(1, 0, 0, h) }, 0.3)
        tween(r, { Size = UDim2.new(1, 0, 0, 44 + (v and h + 1 or 0)) }, 0.3)
        tween(arrow, { Rotation = v and 90 or 0 }, 0.25)
    end
    hit.MouseButton1Click:Connect(function() setOpen(not open) end)

    function obj.Set(v, silent)
        if multi then
            local pick = {}
            if type(v) == "table" then for _, x in ipairs(v) do pick[x] = true end end
            local out = {}
            for _, opt in ipairs(options) do if pick[opt] then table.insert(out, opt) end end
            obj.Value = out
        else
            obj.Value = nil
            for _, opt in ipairs(options) do if opt == v then obj.Value = v end end
        end
        refresh()
        if not silent then changed(lib, o, obj, obj.Value) end
    end
    function obj.Get() return obj.Value end

    local function build()
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end
        buttons = {}
        for idx, opt in ipairs(options) do
            local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = WHITE, BackgroundTransparency = 1, LayoutOrder = idx, Parent = list })
            local lbl = new("TextLabel", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -44, 1, 0), Text = tostring(opt), TextSize = 13, Parent = b })
            local dot = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.5, 0), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = Theme.Accent, Visible = false, Parent = b })
            round(dot, 3)
            buttons[opt] = { Label = lbl, Dot = dot }
            b.MouseEnter:Connect(function() tween(b, { BackgroundTransparency = 0.95 }, 0.1) end)
            b.MouseLeave:Connect(function() tween(b, { BackgroundTransparency = 1 }, 0.15) end)
            b.MouseButton1Click:Connect(function()
                if multi then
                    local cur = {}
                    for _, v in ipairs(obj.Value) do cur[#cur + 1] = v end
                    local found
                    for k, v in ipairs(cur) do if v == opt then found = k end end
                    if found then table.remove(cur, found) else table.insert(cur, opt) end
                    obj.Set(cur)
                else
                    obj.Set(opt)
                    setOpen(false)
                end
            end)
        end
        refresh()
    end
    function obj.SetOptions(newOptions)
        options = newOptions
        build()
        obj.Set(obj.Value, true)
        if open then setOpen(true) end
    end

    lib:_onAccent(function()
        if not r.Parent then return false end
        refresh()
        for _, b in pairs(buttons) do b.Dot.BackgroundColor3 = Theme.Accent end
    end)
    build()
    if o.Default ~= nil then obj.Set(o.Default, true) end
    bind(lib, o, obj)
    obj.Instance = r
    return obj
end

function Section:Input(o)
    o = o or {}
    local lib = self.Lib
    local obj = { Value = o.Default or "" }
    local r = newRow(self, 44, true)
    textStack(r, o, 166)

    local box = new("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(150, 28),
        BackgroundColor3 = WHITE, BackgroundTransparency = 0.9, Text = obj.Value, PlaceholderText = o.Placeholder or "Type here",
        PlaceholderColor3 = Theme.Faint, ClearTextOnFocus = false, TextSize = 13, ClipsDescendants = true, Parent = r,
    })
    round(box, 8)
    pad(box, 9, 9, 0, 0)
    local ring = stroke(box, Theme.Accent, 1)

    box.Focused:Connect(function() tween(ring, { Transparency = 0.2 }, 0.15) end)
    if o.Numeric then
        box:GetPropertyChangedSignal("Text"):Connect(function()
            local clean = box.Text:gsub("[^%d%.%-]", "")
            if clean ~= box.Text then box.Text = clean end
        end)
    end
    function obj.Set(v, silent)
        obj.Value = tostring(v)
        box.Text = obj.Value
        if not silent then changed(lib, o, obj, obj.Value) end
    end
    function obj.Get() return obj.Value end
    box.FocusLost:Connect(function(enter)
        tween(ring, { Transparency = 1 }, 0.2)
        obj.Value = box.Text
        if o.Flag then lib.Flags[o.Flag] = obj.Value end
        fire(o.Callback, obj.Value, enter)
    end)

    lib:_onAccent(function(c) if ring.Parent then ring.Color = c else return false end end)
    bind(lib, o, obj)
    obj.Instance = r
    return obj
end
Section.Textbox = Section.Input

function Section:Keybind(o)
    o = o or {}
    local lib, win = self.Lib, self.Tab.Window
    local key = o.Default
    local obj = { Value = key and key.Name or "None" }
    local r = newRow(self, 44, true)
    textStack(r, o, 90)
    local hit = overlay(r)

    local pill = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(72, 28),
        BackgroundColor3 = WHITE, BackgroundTransparency = 0.88, Parent = r,
    })
    round(pill, 8)
    local pl = new("TextLabel", { Size = UDim2.fromScale(1, 1), TextSize = 12, Weight = "Medium", TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, Parent = pill })

    local listening = false
    local function paint()
        pl.Text = listening and "..." or (key and key.Name or "None")
        local w = math.clamp(measure(pl.Text, 12) + 22, 56, 120)
        tween(pill, { Size = UDim2.fromOffset(w, 28), BackgroundColor3 = listening and Theme.Accent or WHITE, BackgroundTransparency = listening and 0 or 0.88 }, 0.15)
        tween(pl, { TextColor3 = listening and Theme.OnAccent or Theme.Text }, 0.15)
    end
    function obj.Set(v, silent)
        if typeof(v) == "EnumItem" then key = v
        elseif type(v) == "string" and Enum.KeyCode[v] then key = Enum.KeyCode[v]
        else key = nil end
        obj.Value = key and key.Name or "None"
        paint()
        if not silent then
            if o.Flag then lib.Flags[o.Flag] = obj.Value end
            fire(o.Changed, key)
        end
    end
    function obj.Get() return key end

    hit.MouseButton1Click:Connect(function()
        listening = true
        paint()
    end)
    win:_connect(UserInputService.InputBegan, function(i, processed)
        if listening and i.UserInputType == Enum.UserInputType.Keyboard then
            listening = false
            if i.KeyCode == Enum.KeyCode.Escape then paint()
            elseif i.KeyCode == Enum.KeyCode.Backspace then obj.Set(nil)
            else obj.Set(i.KeyCode) end
            return
        end
        if not processed and key and i.KeyCode == key then fire(o.Callback, key) end
    end)

    paint()
    bind(lib, o, obj)
    obj.Instance = r
    return obj
end

env.__ISLE = Isle
Isle:_init()
return Isle
