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

--// config + themes ---------------------------------------------------------
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local Config = {
    Animations   = true,
    AnimSpeed    = 1,
    DockAutoHide = true,
    Island       = true,
    IslandStats  = false,
    Radius       = 1,      -- multiplier on every corner radius
    Scale        = 1,      -- whole-interface scale
    Transparency = 0.05,   -- window background transparency
    Font         = "Gotham",
}

local Fonts = {
    ["Gotham"]      = "rbxasset://fonts/families/GothamSSm.json",
    ["Montserrat"]  = "rbxasset://fonts/families/Montserrat.json",
    ["Builder Sans"] = "rbxasset://fonts/families/BuilderSans.json",
    ["Source Sans"] = "rbxasset://fonts/families/SourceSansPro.json",
}
local FONT_WEIGHT = {
    Regular = Enum.FontWeight.Regular, Medium = Enum.FontWeight.Medium,
    SemiBold = Enum.FontWeight.SemiBold, Bold = Enum.FontWeight.Bold,
}
local FONT_FALLBACK = {
    Regular = Enum.Font.Gotham, Medium = Enum.Font.GothamMedium,
    SemiBold = Enum.Font.GothamSemibold, Bold = Enum.Font.GothamBold,
}

-- Neutral palettes only: no blues, no purples, no gradients.
local Themes = {
    Graphite = { Base = rgb(24, 24, 25), Accent = rgb(48, 209, 88), OnAccent = rgb(14, 14, 14), Text = rgb(245, 245, 247), Dim = rgb(152, 152, 158), Faint = rgb(104, 104, 110), Track = rgb(70, 70, 75), Tile = rgb(50, 50, 54), TileOn = rgb(88, 88, 94), Overlay = WHITE, Bar = rgb(32, 32, 34) },
    Obsidian = { Base = rgb(8, 8, 8), Accent = rgb(236, 236, 236), OnAccent = rgb(10, 10, 10), Text = rgb(240, 240, 240), Dim = rgb(140, 140, 140), Faint = rgb(90, 90, 90), Track = rgb(58, 58, 58), Tile = rgb(30, 30, 30), TileOn = rgb(72, 72, 72), Overlay = WHITE, Bar = rgb(18, 18, 18) },
    Ember    = { Base = rgb(28, 24, 21), Accent = rgb(255, 159, 10), OnAccent = rgb(26, 16, 4), Text = rgb(247, 242, 236), Dim = rgb(166, 155, 144), Faint = rgb(114, 104, 94), Track = rgb(78, 70, 62), Tile = rgb(56, 49, 43), TileOn = rgb(96, 85, 74), Overlay = WHITE, Bar = rgb(36, 31, 27) },
    Moss     = { Base = rgb(21, 25, 22), Accent = rgb(150, 200, 140), OnAccent = rgb(14, 22, 14), Text = rgb(238, 244, 238), Dim = rgb(148, 160, 150), Faint = rgb(100, 112, 102), Track = rgb(62, 72, 64), Tile = rgb(44, 52, 46), TileOn = rgb(78, 92, 80), Overlay = WHITE, Bar = rgb(28, 34, 30) },
    Rose     = { Base = rgb(27, 24, 25), Accent = rgb(240, 128, 148), OnAccent = rgb(28, 10, 14), Text = rgb(247, 240, 242), Dim = rgb(164, 150, 154), Faint = rgb(112, 100, 104), Track = rgb(76, 68, 71), Tile = rgb(55, 49, 51), TileOn = rgb(94, 84, 88), Overlay = WHITE, Bar = rgb(35, 30, 32) },
    Paper    = { Base = rgb(246, 246, 248), Accent = rgb(52, 190, 86), OnAccent = rgb(255, 255, 255), Text = rgb(28, 28, 30), Dim = rgb(110, 110, 116), Faint = rgb(160, 160, 166), Track = rgb(200, 200, 206), Tile = rgb(226, 226, 231), TileOn = rgb(206, 206, 212), Overlay = BLACK, Bar = rgb(238, 238, 242) },
}
local ThemeNames = { "Graphite", "Obsidian", "Ember", "Moss", "Rose", "Paper" }

local Theme = { Types = {
    Info = rgb(220, 220, 226), Success = rgb(48, 209, 88), Warning = rgb(255, 189, 46), Error = rgb(255, 95, 87),
} }
for k, v in pairs(Themes.Graphite) do Theme[k] = v end

local ISLAND_TEXT = rgb(245, 245, 247)
local ISLAND_DIM = rgb(160, 160, 166)

-- Soft 9-slice drop shadow. If the asset is ever unavailable the shadow just
-- doesn't render; swap the id here and nothing else breaks.
local SHADOW_ASSET = "rbxassetid://6014261993"

local DOCK_H, TILE, TILE_MAG = 68, 44, 52

--// library table -----------------------------------------------------------
local Isle = {
    Version = "2.0.0",
    Theme = Theme,
    Themes = Themes,
    ThemeNames = ThemeNames,
    ThemeName = "Graphite",
    Config = Config,
    Fonts = Fonts,
    Flags = {},
    Windows = {},
    Visible = true,
    ToggleKey = Enum.KeyCode.RightShift,
    _conns = {},
    _flagged = {},
    _hooks = {},
    _z = 10,
}

local Window, Tab, Section, Tabbox = {}, {}, {}, {}
Window.__index, Tab.__index, Section.__index, Tabbox.__index = Window, Tab, Section, Tabbox

--// registries (live theming) ----------------------------------------------
local registry, fontReg, cornerReg = {}, {}, {}

local function T(token) return { __token = token } end
local OV = T("Overlay")

local function dur(t)
    if not Config.Animations then return 0 end
    return t / math.max(Config.AnimSpeed, 0.1)
end

local function tween(obj, props, time, style, direction)
    local t = TweenService:Create(obj, TweenInfo.new(dur(time or 0.2), style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function fontFace(weight)
    return Font.new(Fonts[Config.Font] or Fonts.Gotham, FONT_WEIGHT[weight] or Enum.FontWeight.Regular, Enum.FontStyle.Normal)
end

local function setFont(obj, weight)
    weight = weight or "Regular"
    table.insert(fontReg, { obj, weight })
    local ok = pcall(function() obj.FontFace = fontFace(weight) end)
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
        o.TextSize = 14
        o.TextXAlignment = Enum.TextXAlignment.Left
        if props.TextColor3 == nil then
            o.TextColor3 = Theme.Text
            table.insert(registry, { o, "TextColor3", "Text" })
        end
    end
    for k, v in pairs(props) do
        if k ~= "Parent" and k ~= "Weight" then
            if type(v) == "table" and v.__token then
                o[k] = Theme[v.__token]
                table.insert(registry, { o, k, v.__token })
            else
                o[k] = v
            end
        end
    end
    if isText then setFont(o, props.Weight) end
    for _, c in ipairs(kids or {}) do c.Parent = o end
    if props.Parent then o.Parent = props.Parent end
    return o
end

local function round(inst, r, fixed)
    local c = new("UICorner", { CornerRadius = UDim.new(0, fixed and r or r * Config.Radius), Parent = inst })
    if not fixed then table.insert(cornerReg, { c, r }) end
    return c
end

local function stroke(inst, color, transparency, thickness)
    return new("UIStroke", {
        Color = color or OV,
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
-- InputObject.Position ignores the top inset; the gui here doesn't, so correct for it.
local function pointer(i)
    if i.UserInputType == Enum.UserInputType.Touch then
        return Vector2.new(i.Position.X, i.Position.Y + GuiService:GetGuiInset().Y)
    end
    return UserInputService:GetMouseLocation()
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

local function pressable(frame, hit, amount)
    local sc = new("UIScale", { Parent = frame })
    hit.MouseButton1Down:Connect(function() tween(sc, { Scale = amount or 0.94 }, 0.08) end)
    local function release() tween(sc, { Scale = 1 }, 0.25, Enum.EasingStyle.Back) end
    hit.MouseButton1Up:Connect(release)
    hit.MouseLeave:Connect(release)
    return sc
end

function Isle:_connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(self._conns, c)
    return c
end

function Isle:_onTheme(fn)
    table.insert(self._hooks, fn)
    fn()
end

--// live customisation ------------------------------------------------------
function Isle:_applyTheme()
    for i = #registry, 1, -1 do
        local r = registry[i]
        if not r[1]:IsDescendantOf(self.Gui) then
            table.remove(registry, i)
        else
            tween(r[1], { [r[2]] = Theme[r[3]] }, 0.3)
        end
    end
    for i = #self._hooks, 1, -1 do
        local ok, alive = pcall(self._hooks[i])
        if not ok or alive == false then table.remove(self._hooks, i) end
    end
end

function Isle:AddTheme(name, tbl)
    local full = {}
    for k, v in pairs(Themes.Graphite) do full[k] = v end
    for k, v in pairs(tbl) do full[k] = v end
    Themes[name] = full
    if not table.find(ThemeNames, name) then table.insert(ThemeNames, name) end
end

function Isle:SetTheme(t)
    local src = type(t) == "string" and Themes[t] or (type(t) == "table" and t)
    if not src then return false end
    self:_init()
    for k, v in pairs(src) do Theme[k] = v end
    if type(t) == "string" then self.ThemeName = t end
    self:_applyTheme()
    return true
end

function Isle:SetAccent(color)
    self:_init()
    Theme.Accent = color
    self:_applyTheme()
end

function Isle:SetColor(token, color)
    self:_init()
    Theme[token] = color
    self:_applyTheme()
end

function Isle:SetFont(name)
    if not Fonts[name] then return false end
    self:_init()
    Config.Font = name
    for i = #fontReg, 1, -1 do
        local r = fontReg[i]
        if not r[1]:IsDescendantOf(self.Gui) then
            table.remove(fontReg, i)
        else
            pcall(function() r[1].FontFace = fontFace(r[2]) end)
        end
    end
    return true
end

function Isle:SetRadius(scale)
    self:_init()
    Config.Radius = scale
    for i = #cornerReg, 1, -1 do
        local r = cornerReg[i]
        if not r[1]:IsDescendantOf(self.Gui) then
            table.remove(cornerReg, i)
        else
            tween(r[1], { CornerRadius = UDim.new(0, r[2] * scale) }, 0.25)
        end
    end
end

function Isle:SetScale(s)
    self:_init()
    Config.Scale = s
    self.LayerScale.Scale = s
    self.Layer.Size = UDim2.fromScale(1 / s, 1 / s)
end

function Isle:SetTransparency(v)
    Config.Transparency = v
    for _, w in ipairs(self.Windows) do
        tween(w.Main, { BackgroundTransparency = v }, 0.25)
    end
end

function Isle:SetIsland(v)
    Config.Island = v
    if self.Island then self.Island.Refresh() end
end

-- Isle:Set("Radius", 1.2) / Isle:Configure({ Radius = 1.2, Theme = "Ember", ... })
function Isle:Set(key, v)
    self:_init()
    if key == "Radius" then self:SetRadius(v)
    elseif key == "Scale" then self:SetScale(v)
    elseif key == "Transparency" then self:SetTransparency(v)
    elseif key == "Font" then self:SetFont(v)
    elseif key == "Theme" then self:SetTheme(v)
    elseif key == "Accent" then self:SetAccent(v)
    elseif key == "Island" then self:SetIsland(v)
    elseif Config[key] ~= nil then Config[key] = v end
end

function Isle:Configure(tbl)
    for k, v in pairs(tbl) do self:Set(k, v) end
end

--// init --------------------------------------------------------------------
function Isle:_init()
    if self.Gui then return end
    local gui = new("ScreenGui", {
        Name = "Isle", ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
    })
    mount(gui)
    self.Gui = gui
    self.Layer = new("Frame", { Name = "Layer", Size = UDim2.fromScale(1 / Config.Scale, 1 / Config.Scale), Parent = gui })
    self.LayerScale = new("UIScale", { Scale = Config.Scale, Parent = self.Layer })

    self:_buildIsland()
    self:_buildDock()

    self:_connect(UserInputService.InputBegan, function(i, processed)
        if processed then return end
        if i.KeyCode == self.ToggleKey then self:SetVisible(not self.Visible) end
    end)
end

--// dynamic island ----------------------------------------------------------
-- A plain black pill. No shadow, no outline.
function Isle:_buildIsland()
    local root = new("Frame", {
        Name = "Island", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10),
        Size = UDim2.fromOffset(100, 30), ZIndex = 10, Visible = Config.Island, Parent = self.Gui,
    })
    local pill = new("Frame", { Name = "Pill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, ClipsDescendants = true, Parent = root })
    local corner = new("UICorner", { CornerRadius = UDim.new(0, 15), Parent = pill })

    local idle = new("CanvasGroup", { Name = "Idle", Size = UDim2.fromScale(1, 1), Parent = pill })
    local dot = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 13, 0.5, 0),
        Size = UDim2.fromOffset(7, 7), BackgroundColor3 = Theme.Accent, Parent = idle,
    })
    round(dot, 4, true)
    self:_onTheme(function()
        if not dot.Parent then return false end
        tween(dot, { BackgroundColor3 = Theme.Accent }, 0.3)
    end)
    local title = new("TextLabel", {
        Position = UDim2.fromOffset(28, 0), Size = UDim2.new(0, 180, 1, 0), Text = self.IslandTitle or "Isle",
        TextSize = 13, TextColor3 = ISLAND_TEXT, Weight = "Medium", Parent = idle,
    })
    local statsL = new("TextLabel", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 0), Size = UDim2.new(0, 104, 1, 0),
        TextSize = 12, TextColor3 = ISLAND_DIM, TextXAlignment = Enum.TextXAlignment.Right, TextTransparency = 1, Parent = idle,
    })

    local note = new("CanvasGroup", { Name = "Note", Size = UDim2.fromScale(1, 1), GroupTransparency = 1, Parent = pill })
    local ring = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 18, 0.5, 0), Size = UDim2.fromOffset(32, 32),
        BackgroundColor3 = Theme.Types.Info, BackgroundTransparency = 0.8, Parent = note,
    })
    round(ring, 16, true)
    local core = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 10),
        BackgroundColor3 = Theme.Types.Info, Parent = ring,
    })
    round(core, 5, true)
    local nTitle = new("TextLabel", { Position = UDim2.fromOffset(64, 14), Size = UDim2.new(1, -82, 0, 18), TextSize = 14, TextColor3 = ISLAND_TEXT, Weight = "SemiBold", TextTruncate = Enum.TextTruncate.AtEnd, Parent = note })
    local nBody = new("TextLabel", {
        Position = UDim2.fromOffset(64, 33), Size = UDim2.new(1, -82, 0, 30), TextSize = 12, TextColor3 = ISLAND_DIM,
        TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.AtEnd, Parent = note,
    })
    local barTrack = new("Frame", { Position = UDim2.new(0, 64, 1, -10), Size = UDim2.new(1, -82, 0, 2), BackgroundColor3 = WHITE, BackgroundTransparency = 0.88, Parent = note })
    round(barTrack, 1, true)
    local barFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Types.Info, Parent = barTrack })
    round(barFill, 1, true)

    local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = pill })

    local state, hover, skip = "idle", false, false
    local fps, ping = 0, 0

    local function layoutIdle()
        local w = math.clamp(measure(title.Text, 13) + 46, 90, 260)
        local showStats = hover and Config.IslandStats
        if showStats then w += 112 end
        tween(root, { Size = UDim2.fromOffset(w, 30) }, 0.4)
        tween(corner, { CornerRadius = UDim.new(0, 15) }, 0.4)
        tween(statsL, { TextTransparency = showStats and 0 or 1 }, 0.25)
    end

    hit.MouseEnter:Connect(function() hover = true if state == "idle" then layoutIdle() end end)
    hit.MouseLeave:Connect(function() hover = false if state == "idle" then layoutIdle() end end)
    hit.MouseButton1Click:Connect(function()
        if state == "note" then skip = true end
    end)

    local frames, last = 0, os.clock()
    self:_connect(RunService.Heartbeat, function()
        frames += 1
        local now = os.clock()
        if now - last >= 0.5 then
            fps = math.floor(frames / (now - last) + 0.5)
            frames, last = 0, now
            if hover and Config.IslandStats then
                pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5) end)
                statsL.Text = string.format("%d fps   %d ms", fps, ping)
            end
        end
    end)

    local function showNote(n)
        state, skip = "note", false
        root.Visible = true
        local color = Theme.Types[n.Type or "Info"] or Theme.Types.Info
        local body = tostring(n.Content or "")
        local h = body ~= "" and 78 or 56
        ring.BackgroundColor3, core.BackgroundColor3, barFill.BackgroundColor3 = color, color, color
        nTitle.Text = tostring(n.Title or "Notification")
        nBody.Text = body
        nBody.Visible = body ~= ""
        if body ~= "" then
            nTitle.Position, nTitle.Size = UDim2.fromOffset(64, 14), UDim2.new(1, -82, 0, 18)
        else
            nTitle.Position, nTitle.Size = UDim2.fromOffset(64, 0), UDim2.new(1, -82, 1, -6)
        end
        local d = n.Duration or 4
        barFill.Size = UDim2.fromScale(1, 1)

        tween(idle, { GroupTransparency = 1 }, 0.12)
        tween(root, { Size = UDim2.fromOffset(330, h) }, 0.5)
        tween(corner, { CornerRadius = UDim.new(0, 26) }, 0.45)
        task.wait(dur(0.1))
        tween(note, { GroupTransparency = 0 }, 0.22)
        TweenService:Create(barFill, TweenInfo.new(d, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) }):Play()

        local t = 0
        while t < d and not skip and root.Parent do t += task.wait(0.05) end
        tween(note, { GroupTransparency = 1 }, 0.15)
        task.wait(dur(0.16))
    end

    self.Island = {
        SetTitle = function(text)
            title.Text = text
            if state == "idle" then layoutIdle() end
        end,
        Refresh = function()
            if state == "idle" then root.Visible = Config.Island end
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
                task.delay(dur(0.45), function()
                    if state == "idle" and root.Parent then root.Visible = Config.Island end
                end)
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
        Name = "Dock", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18),
        Size = UDim2.fromOffset(100, DOCK_H), Visible = false, ZIndex = 100000, Parent = self.Layer,
    })
    addShadow(root, 0.55, 26, 10)
    local bar = new("Frame", { Name = "Bar", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T("Bar"), BackgroundTransparency = 0.1, ZIndex = 2, Parent = root })
    round(bar, 24)
    stroke(bar, OV, 0.88)
    local items = new("Frame", { Name = "Items", Size = UDim2.fromScale(1, 1), Parent = bar })
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8), Parent = items,
    })

    local tip = new("TextLabel", {
        Name = "Tooltip", AnchorPoint = Vector2.new(0.5, 1), AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundColor3 = rgb(14, 14, 15), BackgroundTransparency = 0.1, Text = "", TextSize = 12, TextColor3 = ISLAND_TEXT,
        Weight = "Medium", TextXAlignment = Enum.TextXAlignment.Center, RichText = true, Visible = false,
        ZIndex = 100001, Parent = self.Gui,
    })
    round(tip, 8, true)
    stroke(tip, WHITE, 0.9)
    pad(tip, 10, 10, 6, 6)

    -- thin handle shown while the dock is tucked away (also the tap target on touch)
    local grab = new("TextButton", {
        Name = "Grabber", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2),
        Size = UDim2.fromOffset(140, 22), Visible = false, ZIndex = 100000, Parent = self.Gui,
    })
    local gline = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -5), Size = UDim2.fromOffset(46, 4),
        BackgroundColor3 = WHITE, BackgroundTransparency = 0.6, Parent = grab,
    })
    round(gline, 2, true)
    grab.MouseEnter:Connect(function() tween(gline, { BackgroundTransparency = 0.2, Size = UDim2.fromOffset(64, 4) }, 0.15) end)
    grab.MouseLeave:Connect(function() tween(gline, { BackgroundTransparency = 0.6, Size = UDim2.fromOffset(46, 4) }, 0.2) end)
    grab.MouseButton1Click:Connect(function() self:PeekDock(4) end)

    self.Dock = {
        Root = root, Items = items, Tip = tip, Grab = grab, Tiles = {},
        Shown = true, PeekUntil = os.clock() + 3.5, Width = 100, HasEntries = false,
    }

    self:_onTheme(function()
        if not root.Parent then return false end
        for _, rec in pairs(self.Dock.Tiles) do self:_styleTile(rec) end
    end)

    self:_connect(RunService.Heartbeat, function() self:_updateDock() end)
end

function Isle:PeekDock(seconds)
    if self.Dock then self.Dock.PeekUntil = os.clock() + (seconds or 3) end
end

function Isle:_setDockShown(v)
    local d = self.Dock
    d.Shown = v
    tween(d.Root, { Position = v and UDim2.new(0.5, 0, 1, -18) or UDim2.new(0.5, 0, 1, DOCK_H + 40) }, 0.4)
    d.Grab.Visible = (not v) and Config.DockAutoHide and d.HasEntries and self.Visible
    if not v then self:_hideTip() end
end

function Isle:_updateDock()
    local d = self.Dock
    if not d then return end
    if not self.Visible or not d.HasEntries then
        if d.Shown then self:_setDockShown(false) end
        d.Grab.Visible = false
        return
    end
    local want = true
    if Config.DockAutoHide then
        local m = UserInputService:GetMouseLocation()
        local size = self.Gui.AbsoluteSize
        local s = Config.Scale
        local zone = d.Shown and (DOCK_H + 46) * s or 70
        local halfW = math.max(d.Width / 2 * s + 90, 240)
        local near = UserInputService.MouseEnabled and m.Y >= size.Y - zone and math.abs(m.X - size.X / 2) <= halfW
        want = near or d.Hovered ~= nil or os.clock() < d.PeekUntil
    end
    if want then
        d.LeaveAt = nil
        if not d.Shown then self:_setDockShown(true) end
    elseif d.Shown then
        d.LeaveAt = d.LeaveAt or os.clock()
        if os.clock() - d.LeaveAt > 0.55 then self:_setDockShown(false) end
    end
    if d.Shown and d.Grab.Visible then d.Grab.Visible = false end
end

local function escapeRich(s)
    return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

function Isle:_hideTip()
    if self.Dock then self.Dock.Tip.Visible = false end
end

function Isle:_showTip(rec)
    local d = self.Dock
    local e = rec.Entry
    d.Tip.Text = escapeRich(e.Name) .. (e.Hint and (' <font color="#8e8e93" size="11">  ' .. e.Hint .. "</font>") or "")
    d.Tip.Visible = true
    local function place()
        if not rec.Tile.Parent then return end
        d.Tip.Position = UDim2.fromOffset(rec.Tile.AbsolutePosition.X + rec.Tile.AbsoluteSize.X / 2, d.Root.AbsolutePosition.Y - 10)
    end
    place()
    task.delay(0.16, function() if d.Tip.Visible and d.Hovered == rec then place() end end)
end

function Isle:_styleTile(rec)
    local e = rec.Entry
    tween(rec.Tile, { BackgroundColor3 = e.Active and Theme.TileOn or Theme.Tile, BackgroundTransparency = e.Dim and 0.5 or 0 }, 0.2)
    rec.Stroke.Color = Theme.Overlay
    tween(rec.Stroke, { Transparency = e.Active and 0.78 or 0.92 }, 0.2)
    rec.Dot.BackgroundColor3 = Theme.Text
    tween(rec.Dot, { BackgroundTransparency = e.Active and 0 or 1 }, 0.2)
    if rec.Glyph:IsA("TextLabel") then
        tween(rec.Glyph, { TextTransparency = e.Dim and 0.5 or 0 }, 0.2)
    else
        tween(rec.Glyph, { ImageTransparency = e.Dim and 0.5 or 0 }, 0.2)
    end
end

function Isle:_makeTile(e)
    local d = self.Dock
    local tile = new("TextButton", {
        Name = "Tile", Size = UDim2.fromOffset(0, 0), BackgroundColor3 = Theme.Tile, Parent = d.Items,
    })
    round(tile, 12)
    local st = stroke(tile, OV, 0.92)
    local glyph
    if e.Icon then
        glyph = new("ImageLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(24, 24),
            Image = e.Icon, Parent = tile,
        })
    else
        glyph = new("TextLabel", {
            Size = UDim2.fromScale(1, 1), Text = e.Glyph or string.upper(string.sub(e.Name, 1, 1)),
            TextSize = 18, Weight = "SemiBold", TextXAlignment = Enum.TextXAlignment.Center, Parent = tile,
        })
    end
    local dot = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 4), Size = UDim2.fromOffset(4, 4),
        BackgroundColor3 = Theme.Text, BackgroundTransparency = 1, Parent = tile,
    })
    round(dot, 2, true)

    local rec = { Tile = tile, Stroke = st, Dot = dot, Glyph = glyph, Entry = e }
    tile.MouseEnter:Connect(function()
        d.Hovered = rec
        tween(tile, { Size = UDim2.fromOffset(TILE_MAG, TILE_MAG) }, 0.2, Enum.EasingStyle.Back)
        self:_showTip(rec)
    end)
    tile.MouseLeave:Connect(function()
        if d.Hovered == rec then d.Hovered = nil end
        tween(tile, { Size = UDim2.fromOffset(TILE, TILE) }, 0.2)
        self:_hideTip()
    end)
    tile.MouseButton1Down:Connect(function() tween(tile, { Size = UDim2.fromOffset(TILE - 6, TILE - 6) }, 0.08) end)
    tile.MouseButton1Click:Connect(function()
        tween(tile, { Size = UDim2.fromOffset(TILE_MAG, TILE_MAG) }, 0.25, Enum.EasingStyle.Back)
        self:_hideTip()
        if rec.Entry.Click then rec.Entry.Click() end
    end)
    tile.MouseButton2Click:Connect(function()
        if rec.Entry.Context then
            self:_hideTip()
            rec.Entry.Context()
        end
    end)
    return rec
end

function Isle:_renderDock()
    local d = self.Dock
    if not d then return end

    local entries = {}
    local win = self.Focused
    if win then
        for _, tab in ipairs(win.Tabs) do
            table.insert(entries, {
                Key = tab, Name = tab.Name, Icon = tab.Icon, Glyph = tab.Glyph,
                Active = win.ActiveTab == tab,
                Hint = #win.Tabs > 1 and "right-click to pop out" or nil,
                Click = function() self:_focus(tab.Window) tab.Window:SetTab(tab) end,
                Context = function() tab.Window:Detach(tab) end,
            })
        end
    end
    if #self.Windows > 1 or (not win and #self.Windows > 0) then
        if #entries > 0 then table.insert(entries, { Key = "divider", Divider = true }) end
        for _, w in ipairs(self.Windows) do
            table.insert(entries, {
                Key = w, Name = w.Title, Glyph = w.Glyph, Active = (w == win), Dim = w.Minimized,
                Click = function()
                    if w.Minimized then w:Restore()
                    elseif w == self.Focused then w:Minimize()
                    else self:_focus(w) end
                end,
            })
        end
    end

    local seen = {}
    local width = 24 + (TILE_MAG - TILE)
    for idx, e in ipairs(entries) do
        seen[e.Key] = true
        local rec = d.Tiles[e.Key]
        if e.Divider then
            if not rec then
                local line = new("Frame", { Size = UDim2.fromOffset(1, 26), BackgroundColor3 = OV, BackgroundTransparency = 0.85, Parent = d.Items })
                rec = { Tile = line, Divider = true }
                d.Tiles[e.Key] = rec
            end
            rec.Tile.LayoutOrder = idx
            width += 1
        else
            if not rec then
                rec = self:_makeTile(e)
                d.Tiles[e.Key] = rec
                tween(rec.Tile, { Size = UDim2.fromOffset(TILE, TILE) }, 0.35, Enum.EasingStyle.Back)
            end
            rec.Entry = e
            rec.Tile.LayoutOrder = idx
            self:_styleTile(rec)
            width += TILE
        end
        if idx > 1 then width += 8 end
    end
    for key, rec in pairs(d.Tiles) do
        if not seen[key] then
            d.Tiles[key] = nil
            if d.Hovered == rec then d.Hovered = nil end
            local gone = rec.Tile
            tween(gone, { Size = UDim2.fromOffset(0, 0) }, 0.2)
            task.delay(dur(0.22), function() gone:Destroy() end)
        end
    end

    local had = d.HasEntries
    d.Width = width
    d.HasEntries = #entries > 0
    if d.HasEntries and not had then self:PeekDock(3) end
    d.Root.Visible = d.HasEntries
    tween(d.Root, { Size = UDim2.fromOffset(width, DOCK_H) }, 0.3)
    if d.HasEntries and d.Shown == false and not Config.DockAutoHide then self:_setDockShown(true) end
end

--// global visibility / config files ---------------------------------------
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
    for _, w in ipairs(self.Windows) do
        w:_animate(v and not w.Minimized)
    end
    if not v then
        self:_hideTip()
    else
        self:PeekDock(2)
    end
end

local function encodeValue(v)
    if typeof(v) == "Color3" then return { __color = v:ToHex() } end
    return v
end
local function decodeValue(v)
    if type(v) == "table" and v.__color then
        local ok, c = pcall(Color3.fromHex, v.__color)
        if ok then return c end
    end
    return v
end

function Isle:SaveConfig(name)
    if not writefile then return false end
    local data = {}
    for flag, el in pairs(self._flagged) do data[flag] = encodeValue(el.Value) end
    pcall(function() if makefolder and not (isfolder and isfolder("Isle")) then makefolder("Isle") end end)
    return (pcall(writefile, "Isle/" .. name .. ".json", HttpService:JSONEncode(data)))
end

function Isle:LoadConfig(name)
    if not (readfile and isfile) then return false end
    local path = "Isle/" .. name .. ".json"
    if not isfile(path) then return false end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok then return false end
    for flag, v in pairs(data) do
        local el = self._flagged[flag]
        if el then pcall(el.Set, decodeValue(v)) end
    end
    return true
end

function Isle:Destroy()
    for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    for _, w in ipairs(self.Windows) do
        for _, c in ipairs(w._conns) do pcall(function() c:Disconnect() end) end
        for _, t in ipairs(w.Tabs) do
            for _, c in ipairs(t._conns) do pcall(function() c:Disconnect() end) end
        end
    end
    if self.Gui then self.Gui:Destroy() end
    env.__ISLE = nil
end
Isle.Unload = Isle.Destroy

--// window ------------------------------------------------------------------
function Isle:CreateWindow(o)
    self:_init()
    if type(o) == "string" then o = { Title = o } end
    o = o or {}
    if o.Config then self:Configure(o.Config) end
    if o.Theme then self:SetTheme(o.Theme) end
    if o.Accent then self:SetAccent(o.Accent) end
    if o.Transparency then self:SetTransparency(o.Transparency) end
    if o.ToggleKey then self.ToggleKey = o.ToggleKey end

    local win = setmetatable({
        Library = self, Title = o.Title or "Window", Glyph = o.Glyph, Tabs = {}, Minimized = false,
        _conns = {}, _shown = true,
    }, Window)

    local scale = Config.Scale
    local vp = self.Gui.AbsoluteSize / scale
    local size = o.Size or Vector2.new(600, 420)
    if typeof(size) == "UDim2" then size = Vector2.new(size.X.Offset, size.Y.Offset) end
    size = Vector2.new(math.min(size.X, vp.X - 24), math.min(size.Y, vp.Y - 120))
    local minSize = o.MinSize or Vector2.new(380, 260)

    local n = #self.Windows
    local holder = new("Frame", {
        Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = o.Position or UDim2.new(0.5, n * 28, 0.5, -26 + n * 28),
        Size = UDim2.fromOffset(size.X, size.Y), Parent = self.Layer,
    })
    local uiscale = new("UIScale", { Scale = 0.95, Parent = holder })
    local shadow = addShadow(holder, 0.6, 34, 10)
    local main = new("CanvasGroup", {
        Name = "Main", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T("Base"),
        BackgroundTransparency = Config.Transparency, GroupTransparency = 1, ZIndex = 2, Parent = holder,
    })
    round(main, 16)
    local rim = new("Frame", { Name = "Rim", Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = holder })
    round(rim, 16)
    local rimStroke = stroke(rim, OV, 1)

    win.Holder, win.Main, win.Scale, win.Shadow, win.RimStroke = holder, main, uiscale, shadow, rimStroke

    -- title bar -------------------------------------------------------------
    local top = new("Frame", { Name = "Top", Size = UDim2.new(1, 0, 0, 48), Parent = main })
    new("Frame", { Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = OV, BackgroundTransparency = 0.93, Parent = top })

    local function light(x, color, fn)
        local b = new("TextButton", { Size = UDim2.fromOffset(12, 12), Position = UDim2.new(0, x, 0.5, -6), BackgroundColor3 = color, Parent = top })
        round(b, 6, true)
        pressable(b, b, 0.8)
        b.MouseEnter:Connect(function() tween(b, { BackgroundTransparency = 0.3 }, 0.1) end)
        b.MouseLeave:Connect(function() tween(b, { BackgroundTransparency = 0 }, 0.15) end)
        b.MouseButton1Click:Connect(fn)
    end
    light(16, rgb(240, 96, 88), function() win:Close() end)
    light(36, rgb(240, 186, 56), function() win:Minimize() end)
    light(56, rgb(74, 196, 96), function() win:ToggleMaximize() end)

    local hasSub = o.Subtitle and o.Subtitle ~= ""
    win.TitleLabel = new("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, hasSub and -8 or 0),
        Size = UDim2.new(1, -220, 0, 18), Text = win.Title, TextSize = 14, Weight = "SemiBold",
        TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, Parent = top,
    })
    if hasSub then
        new("TextLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 9),
            Size = UDim2.new(1, -220, 0, 14), Text = o.Subtitle, TextSize = 11, TextColor3 = T("Dim"),
            TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, Parent = top,
        })
    end

    win.Pages = new("Frame", { Name = "Pages", Position = UDim2.fromOffset(0, 49), Size = UDim2.new(1, 0, 1, -49), ClipsDescendants = true, Parent = main })

    -- dragging + double-click to maximise -------------------------------------
    local dragging, dragStart, startPos
    top.InputBegan:Connect(function(i)
        if not isPress(i) then return end
        self:_focus(win)
        local now = os.clock()
        if now - (win._lastClick or 0) < 0.35 then
            win._lastClick = 0
            win:ToggleMaximize()
            return
        end
        win._lastClick = now
        if o.Draggable == false or win._max then return end
        dragging, dragStart, startPos = true, i.Position, holder.Position
    end)
    win:_connect(UserInputService.InputChanged, function(i)
        if dragging and isMove(i) then
            local d = (i.Position - dragStart) / Config.Scale
            holder.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    win:_connect(UserInputService.InputEnded, function(i)
        if dragging and isPress(i) then dragging = false end
    end)

    -- resizing: right edge, bottom edge and corner ----------------------------
    if o.Resizable ~= false then
        local grip1 = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -7, 1, -7), Size = UDim2.fromOffset(12, 1.5), Rotation = -45, BackgroundColor3 = OV, BackgroundTransparency = 0.78, ZIndex = 5, Parent = holder })
        local grip2 = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -7, 1, -7), Size = UDim2.fromOffset(6, 1.5), Rotation = -45, BackgroundColor3 = OV, BackgroundTransparency = 0.78, ZIndex = 5, Parent = holder })
        grip1.Position = UDim2.new(1, -5, 1, -9)
        grip2.Position = UDim2.new(1, -5, 1, -6)

        local rs
        local function handle(name, pos, sz, ax, ay)
            local h = new("TextButton", { Name = name, Position = pos, Size = sz, ZIndex = 6, Parent = holder })
            h.InputBegan:Connect(function(i)
                if isPress(i) and not win._max then
                    self:_focus(win)
                    rs = { at = i.Position, size = Vector2.new(holder.Size.X.Offset, holder.Size.Y.Offset), pos = holder.Position, axis = h }
                    tween(grip1, { BackgroundTransparency = 0.3 }, 0.1)
                    tween(grip2, { BackgroundTransparency = 0.3 }, 0.1)
                end
            end)
            h.MouseEnter:Connect(function() if not rs then tween(grip1, { BackgroundTransparency = 0.5 }, 0.12) tween(grip2, { BackgroundTransparency = 0.5 }, 0.12) end end)
            h.MouseLeave:Connect(function() if not rs then tween(grip1, { BackgroundTransparency = 0.78 }, 0.2) tween(grip2, { BackgroundTransparency = 0.78 }, 0.2) end end)
            win:_connect(UserInputService.InputChanged, function(i)
                if rs and h and isMove(i) and rs.axis == h then
                    local d = (i.Position - rs.at) / Config.Scale
                    local maxS = self.Gui.AbsoluteSize / Config.Scale - Vector2.new(16, 16)
                    local nx = ax and math.clamp(rs.size.X + d.X, minSize.X, math.max(minSize.X, o.MaxSize and o.MaxSize.X or maxS.X)) or rs.size.X
                    local ny = ay and math.clamp(rs.size.Y + d.Y, minSize.Y, math.max(minSize.Y, o.MaxSize and o.MaxSize.Y or maxS.Y)) or rs.size.Y
                    holder.Size = UDim2.fromOffset(nx, ny)
                    holder.Position = UDim2.new(rs.pos.X.Scale, rs.pos.X.Offset + (nx - rs.size.X) / 2, rs.pos.Y.Scale, rs.pos.Y.Offset + (ny - rs.size.Y) / 2)
                end
            end)
            return h
        end
        handle("ResizeRight", UDim2.new(1, -4, 0, 28), UDim2.new(0, 10, 1, -52), true, false)
        handle("ResizeBottom", UDim2.new(0, 28, 1, -4), UDim2.new(1, -52, 0, 10), false, true)
        handle("ResizeCorner", UDim2.new(1, -22, 1, -22), UDim2.fromOffset(26, 26), true, true)
        win:_connect(UserInputService.InputEnded, function(i)
            if rs and isPress(i) then
                rs = nil
                tween(grip1, { BackgroundTransparency = 0.78 }, 0.25)
                tween(grip2, { BackgroundTransparency = 0.78 }, 0.25)
            end
        end)
    end

    -- click anywhere on a window to bring it forward
    win:_connect(UserInputService.InputBegan, function(i)
        if not isPress(i) or not win._shown or self.Focused == win then return end
        local p = pointer(i)
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
        tween(self.Scale, { Scale = 1 }, 0.45, Enum.EasingStyle.Back)
        tween(self.Main, { GroupTransparency = 0 }, 0.25)
        tween(self.Shadow, { ImageTransparency = 0.4 }, 0.3)
        tween(self.RimStroke, { Transparency = 0.9 }, 0.3)
    else
        tween(self.Scale, { Scale = 0.94 }, 0.22)
        tween(self.Main, { GroupTransparency = 1 }, 0.2)
        tween(self.Shadow, { ImageTransparency = 1 }, 0.2)
        tween(self.RimStroke, { Transparency = 1 }, 0.2)
        task.delay(dur(0.24), function()
            if not self._shown and h.Parent then h.Visible = false end
        end)
    end
end

function Window:ToggleMaximize()
    local h = self.Holder
    if self._max then
        local p = self._max
        self._max = nil
        tween(h, { Size = p.Size, Position = p.Pos }, 0.4)
    else
        self._max = { Size = h.Size, Pos = h.Position }
        local vp = self.Library.Gui.AbsoluteSize / Config.Scale
        tween(h, { Size = UDim2.fromOffset(vp.X - 24, vp.Y - 120), Position = UDim2.new(0.5, 0, 0.5, -30) }, 0.4)
    end
end

function Window:SetTitle(text)
    self.Title = text
    self.TitleLabel.Text = text
    self.Library:_renderDock()
end

local function topWindow(lib, except)
    local best
    for _, w in ipairs(lib.Windows) do
        if w ~= except and not w.Minimized and (not best or w.Holder.ZIndex > best.Holder.ZIndex) then best = w end
    end
    return best
end

function Window:Minimize()
    if self.Minimized then return end
    self.Minimized = true
    self:_animate(false)
    local lib = self.Library
    if lib.Focused == self then lib.Focused = topWindow(lib, self) end
    lib:_renderDock()
end

function Window:Restore()
    if not self.Minimized then return end
    self.Minimized = false
    self:_animate(true)
    self.Library.Focused = nil
    self.Library:_focus(self)
end

-- moves a tab into this window (used for pop-out and re-docking)
function Window:_adopt(tab)
    tab.Page.Parent = self.Pages
    tab.Window = self
    table.insert(self.Tabs, tab)
    tab.Page.Visible = false
    tab.Page.GroupTransparency = 1
    tab:_hideSections()
end

function Window:Detach(tab)
    local lib = self.Library
    local idx
    for i, t in ipairs(self.Tabs) do if t == tab then idx = i end end
    if not idx then return end
    if #self.Tabs <= 1 then
        lib:Notify({ Title = "Can't pop out", Content = "This is the only tab in its window", Type = "Warning" })
        return
    end
    table.remove(self.Tabs, idx)
    if self.ActiveTab == tab then
        self.ActiveTab = nil
        self:SetTab(self.Tabs[math.max(idx - 1, 1)], true)
    end
    local hs = self.Holder.Size
    local nw = lib:CreateWindow({
        Title = tab.Name, Glyph = tab.Glyph, Size = Vector2.new(hs.X.Offset, hs.Y.Offset),
        Position = self.Holder.Position + UDim2.fromOffset(44, 44),
    })
    nw.Origin = self
    nw:_adopt(tab)
    nw:SetTab(tab, true)
    lib:_renderDock()
end

function Window:Close()
    local lib = self.Library
    local origin = self.Origin
    if origin and table.find(lib.Windows, origin) and #self.Tabs > 0 then
        local moved = {}
        for _, t in ipairs(self.Tabs) do table.insert(moved, t) end
        self.Tabs, self.ActiveTab = {}, nil
        for _, t in ipairs(moved) do origin:_adopt(t) end
        origin:SetTab(moved[#moved])
        lib:_focus(origin)
    end
    self:_animate(false)
    task.delay(dur(0.25), function() self:Destroy() end)
end

function Window:Destroy()
    local lib = self.Library
    for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    for _, t in ipairs(self.Tabs) do
        for _, c in ipairs(t._conns) do pcall(function() c:Disconnect() end) end
    end
    local at = table.find(lib.Windows, self)
    if at then table.remove(lib.Windows, at) end
    if lib.Focused == self then lib.Focused = topWindow(lib, self) end
    self.Holder:Destroy()
    lib:_renderDock()
end

function Window:Notify(o) self.Library:Notify(o) end

function Window:SetTab(tab, instant)
    if not tab or self.ActiveTab == tab then return end
    local old = self.ActiveTab
    self.ActiveTab = tab
    if old then
        tween(old.Page, { GroupTransparency = 1 }, 0.15)
        task.delay(dur(0.17), function()
            if self.ActiveTab ~= old and old.Window == self then
                old.Page.Visible = false
                old:_hideSections()
            end
        end)
    end
    tab.Page.Visible = true
    tab:_hideSections()
    tab.Scroll.CanvasPosition = Vector2.zero
    tween(tab.Page, { GroupTransparency = 0 }, instant and 0.2 or 0.25)
    task.defer(function() tab:_reveal() end)
    self.Library:_renderDock()
end

function Window:CreateTab(name, o)
    if type(name) == "table" then o = name name = o.Name end
    o = o or {}
    local tab = setmetatable({
        Window = self, Name = name or "Tab", Icon = o.Icon, Glyph = o.Glyph,
        Order = { Left = 0, Right = 0 }, Sections = {}, RightCount = 0, Revealed = false, _conns = {},
    }, Tab)

    local page = new("CanvasGroup", { Name = tab.Name, Size = UDim2.fromScale(1, 1), GroupTransparency = 1, Visible = false, Parent = self.Pages })
    local scroll = new("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3, ScrollBarImageColor3 = OV, ScrollBarImageTransparency = 0.75,
        ScrollingDirection = Enum.ScrollingDirection.Y, Parent = page,
    })
    new("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
    pad(scroll, 18, 18, 8, 28)
    if o.ShowTitle ~= false then
        new("TextLabel", { Size = UDim2.new(1, 0, 0, 34), Text = o.Title or tab.Name, TextSize = 26, Weight = "SemiBold", LayoutOrder = 0, Parent = scroll })
    end

    local cols = new("Frame", { Name = "Columns", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = scroll })
    local colList = new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Top, Parent = cols,
    })
    local function column(name, order)
        local c = new("Frame", { Name = name, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = cols })
        new("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = c })
        return c
    end
    tab.Left, tab.Right = column("Left", 1), column("Right", 2)
    tab.Right.Visible = false
    tab.Page, tab.Scroll, tab.Cols, tab.ColList = page, scroll, cols, colList
    scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() tab:_layoutColumns(false) end)

    table.insert(self.Tabs, tab)
    if not self.ActiveTab then self:SetTab(tab, true) else self.Library:_renderDock() end
    return tab
end
Window.MakeTab = Window.CreateTab

--// tab: columns, sections, tabboxes -----------------------------------------
function Tab:_connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(self._conns, c)
    return c
end

function Tab:_layoutColumns(animate)
    local hasRight = self.RightCount > 0
    local width = self.Scroll.AbsoluteSize.X / Config.Scale
    local stacked = hasRight and width < 440
    self.ColList.FillDirection = stacked and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
    self.ColList.Padding = UDim.new(0, stacked and 14 or 12)
    self.Right.Visible = hasRight
    local size = (hasRight and not stacked) and UDim2.new(0.5, -6, 0, 0) or UDim2.new(1, 0, 0, 0)
    if animate then
        tween(self.Left, { Size = size }, 0.35)
        tween(self.Right, { Size = size }, 0.35)
    else
        self.Left.Size, self.Right.Size = size, size
    end
end

function Tab:_hideSections()
    self.Revealed = false
    for _, s in ipairs(self.Sections) do
        s.Wrap.GroupTransparency = 1
        s.Pad.PaddingTop = UDim.new(0, 12)
    end
end

function Tab:_reveal()
    if self.Window.ActiveTab ~= self then return end
    self.Revealed = true
    for idx, s in ipairs(self.Sections) do
        task.delay(dur(math.min((idx - 1) * 0.05, 0.35)), function()
            if not self.Revealed or not s.Wrap.Parent then return end
            tween(s.Wrap, { GroupTransparency = 0 }, 0.3)
            tween(s.Pad, { PaddingTop = UDim.new(0, 0) }, 0.4)
        end)
    end
end

function Tab:_wrap(side)
    side = (type(side) == "string" and side:lower() == "right") and "Right" or "Left"
    self.Order[side] += 1
    local wrap = new("CanvasGroup", {
        Name = "Section", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        GroupTransparency = self.Revealed and 0 or 1, LayoutOrder = self.Order[side], Parent = self[side],
    })
    local padTop = new("UIPadding", { PaddingTop = UDim.new(0, self.Revealed and 0 or 12), Parent = wrap })
    new("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder, Parent = wrap })
    table.insert(self.Sections, { Wrap = wrap, Pad = padTop })
    if side == "Right" then
        self.RightCount += 1
        if self.RightCount == 1 then self:_layoutColumns(true) end
    end
    return wrap
end

function Tab:Section(title, side, opts)
    if type(title) == "table" then opts = title title, side = opts.Name or opts.Title, opts.Side end
    opts = opts or {}
    local lib = self.Window.Library
    local wrap = self:_wrap(side)

    local head = new("TextButton", { Name = "Header", Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 0, Visible = title ~= nil and title ~= "", Parent = wrap })
    new("TextLabel", { Position = UDim2.fromOffset(6, 0), Size = UDim2.new(1, -34, 1, 0), Text = title or "", TextSize = 12, TextColor3 = T("Dim"), Weight = "Medium", Parent = head })
    local chevron
    if opts.Collapsible then
        chevron = new("TextLabel", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(14, 14),
            Text = ">", TextSize = 12, TextColor3 = T("Dim"), TextXAlignment = Enum.TextXAlignment.Center, Rotation = 90, Parent = head,
        })
    end

    local group = new("Frame", {
        Name = "Group", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = OV, BackgroundTransparency = 0.94, ClipsDescendants = true, LayoutOrder = 1, Parent = wrap,
    })
    round(group, 12)
    stroke(group, OV, 0.95)
    local list = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = group })

    local sec = setmetatable({ Tab = self, Lib = lib, Group = group, Count = 0, Wrap = wrap }, Section)

    if opts.Collapsible then
        head.MouseButton1Click:Connect(function()
            sec.Collapsed = not sec.Collapsed
            if sec.Collapsed then
                local h = group.AbsoluteSize.Y / Config.Scale
                group.AutomaticSize = Enum.AutomaticSize.None
                group.Size = UDim2.new(1, 0, 0, h)
                tween(group, { Size = UDim2.new(1, 0, 0, 0) }, 0.3)
                tween(chevron, { Rotation = 0 }, 0.25)
            else
                local target = list.AbsoluteContentSize.Y / Config.Scale
                tween(group, { Size = UDim2.new(1, 0, 0, target) }, 0.3)
                tween(chevron, { Rotation = 90 }, 0.25)
                task.delay(dur(0.32), function()
                    if not sec.Collapsed and group.Parent then
                        group.AutomaticSize = Enum.AutomaticSize.Y
                        group.Size = UDim2.new(1, 0, 0, 0)
                    end
                end)
            end
        end)
        if opts.Collapsed then
            sec.Collapsed = true
            group.AutomaticSize = Enum.AutomaticSize.None
            group.Size = UDim2.new(1, 0, 0, 0)
            chevron.Rotation = 0
        end
    end

    self.Last = sec
    return sec
end

function Tab:Tabbox(side)
    local lib = self.Window.Library
    local wrap = self:_wrap(side)
    local box = new("Frame", {
        Name = "Tabbox", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = OV, BackgroundTransparency = 0.94, ClipsDescendants = true, LayoutOrder = 1, Parent = wrap,
    })
    round(box, 12)
    stroke(box, OV, 0.95)
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = box })
    local seg = new("Frame", { Name = "Segments", Size = UDim2.new(1, 0, 0, 42), LayoutOrder = 1, Parent = box })
    local segIn = new("Frame", {
        Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 1, -16), BackgroundColor3 = OV, BackgroundTransparency = 0.92, Parent = seg,
    })
    round(segIn, 8)
    new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Parent = segIn })
    new("Frame", { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = OV, BackgroundTransparency = 0.93, Parent = seg })
    local content = new("Frame", { Name = "Content", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = box })
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = content })

    local tb = setmetatable({ Owner = self, Lib = lib, SegIn = segIn, Content = content, Pages = {}, Wrap = wrap }, Tabbox)
    lib:_onTheme(function()
        if not box.Parent then return false end
        tb:_style(true)
    end)
    return tb
end

function Tabbox:_style(animate)
    for _, p in ipairs(self.Pages) do
        local on = p == self.Current
        tween(p.Button, { BackgroundTransparency = on and 0.86 or 1, TextColor3 = on and Theme.Text or Theme.Dim }, animate and 0.2 or 0)
    end
end

function Tabbox:Select(p)
    if self.Current == p then return end
    self.Current = p
    for _, q in ipairs(self.Pages) do q.Group.Visible = (q == p) end
    p.Group.GroupTransparency = 1
    tween(p.Group, { GroupTransparency = 0 }, 0.25)
    self:_style(true)
end

function Tabbox:Tab(name)
    local p = {}
    p.Group = new("CanvasGroup", {
        Name = name, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false,
        LayoutOrder = #self.Pages + 1, Parent = self.Content,
    })
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = p.Group })
    p.Button = new("TextButton", {
        Text = name, TextSize = 13, Weight = "Medium", TextXAlignment = Enum.TextXAlignment.Center,
        BackgroundColor3 = OV, BackgroundTransparency = 1, TextColor3 = Theme.Dim, LayoutOrder = #self.Pages + 1, Parent = self.SegIn,
    })
    round(p.Button, 6)
    table.insert(self.Pages, p)
    for _, q in ipairs(self.Pages) do q.Button.Size = UDim2.new(1 / #self.Pages, 0, 1, 0) end
    p.Button.MouseButton1Click:Connect(function() self:Select(p) end)
    if #self.Pages == 1 then
        self.Current = p
        p.Group.Visible = true
        self:_style(false)
    end
    p.Section = setmetatable({ Tab = self.Owner, Lib = self.Lib, Group = p.Group, Count = 0, Wrap = self.Wrap }, Section)
    return p.Section
end
Tabbox.AddTab = Tabbox.Tab
Tabbox.Section = Tabbox.Tab

-- Linoria-style aliases
function Tab:AddLeftGroupbox(name) return self:Section(name, "Left") end
function Tab:AddRightGroupbox(name) return self:Section(name, "Right") end
function Tab:AddLeftTabbox() return self:Tabbox("Left") end
function Tab:AddRightTabbox() return self:Tabbox("Right") end

local COMPONENTS = { "Label", "Button", "Toggle", "Slider", "Dropdown", "Input", "Keybind", "ColorPicker" }
for _, name in ipairs(COMPONENTS) do
    Tab[name] = function(self, ...)
        local sec = self.Last or self:Section()
        return sec[name](sec, ...)
    end
end

--// row plumbing ------------------------------------------------------------
local function newRow(sec, minH, auto)
    sec.Count += 1
    local r = new("Frame", {
        Name = "Row", Size = UDim2.new(1, 0, 0, minH or 44), BackgroundColor3 = OV, BackgroundTransparency = 1,
        LayoutOrder = sec.Count, Parent = sec.Group,
    })
    if auto then r.AutomaticSize = Enum.AutomaticSize.Y end
    if sec.Count > 1 then
        new("Frame", { Name = "Line", Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -14, 0, 1), BackgroundColor3 = OV, BackgroundTransparency = 0.92, Parent = r })
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
            TextColor3 = T("Dim"), TextWrapped = true, LayoutOrder = 2, Parent = stack,
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

local function changed(lib, o, obj, ...)
    if o.Flag then lib.Flags[o.Flag] = obj.Value end
    fire(o.Callback, ...)
end

local function finish(lib, o, obj, row)
    obj.Instance = row
    function obj.SetVisible(v) row.Visible = v end
    if o.Flag then
        lib._flagged[o.Flag] = obj
        lib.Flags[o.Flag] = obj.Value
    end
    return obj
end

local function accentOf(o) return o.Color or Theme.Accent end

--// components --------------------------------------------------------------
function Section:Label(o)
    if type(o) == "string" then o = { Name = o } end
    local r = newRow(self, 44, true)
    local nameL = textStack(r, o, 0)
    nameL.TextColor3 = Theme.Dim
    self.Lib:_onTheme(function() if not nameL.Parent then return false end tween(nameL, { TextColor3 = Theme.Dim }, 0.3) end)
    return finish(self.Lib, {}, { Set = function(text) nameL.Text = tostring(text) end }, r)
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
        BackgroundColor3 = OV, BackgroundTransparency = 0.88, Parent = r,
    })
    round(pill, 8)
    local pl = new("TextLabel", { Size = UDim2.fromScale(1, 1), Text = label, TextSize = 13, Weight = "Medium", TextXAlignment = Enum.TextXAlignment.Center, Parent = pill })
    pressable(pill, hit, 0.92)

    local function release()
        tween(pill, { BackgroundColor3 = Theme.Overlay, BackgroundTransparency = 0.88 }, 0.3)
        tween(pl, { TextColor3 = Theme.Text }, 0.3)
    end
    hit.MouseButton1Down:Connect(function()
        tween(pill, { BackgroundColor3 = accentOf(o), BackgroundTransparency = 0 }, 0.08)
        tween(pl, { TextColor3 = Theme.OnAccent }, 0.08)
    end)
    hit.MouseButton1Up:Connect(release)
    hit.MouseLeave:Connect(release)
    hit.MouseButton1Click:Connect(function() fire(o.Callback) end)

    return finish(lib, o, { SetText = function(t) pl.Text = t end }, r)
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
    round(track, 14, true)
    local knob = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.fromOffset(24, 24),
        BackgroundColor3 = WHITE, Parent = track,
    })
    round(knob, 12, true)
    pressable(track, hit, 0.94)

    local function paint(animate)
        local on = obj.Value
        local t = animate and 0.25 or 0
        tween(track, { BackgroundColor3 = on and accentOf(o) or Theme.Track }, t)
        tween(knob, { Position = on and UDim2.new(1, -26, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) }, t, Enum.EasingStyle.Back)
    end
    function obj.Set(v, silent)
        obj.Value = v == true
        paint(true)
        if not silent then changed(lib, o, obj, obj.Value) end
    end
    function obj.Get() return obj.Value end
    hit.MouseButton1Click:Connect(function() obj.Set(not obj.Value) end)

    lib:_onTheme(function()
        if not track.Parent then return false end
        paint(true)
    end)
    return finish(lib, o, obj, r)
end

function Section:Slider(o)
    o = o or {}
    local lib = self.Lib
    local min, max = o.Min or 0, o.Max or 100
    local inc = o.Increment or 1
    local suffix = o.Suffix or ""
    local obj = { Value = math.clamp(o.Default or min, min, max) }
    local hasDesc = o.Description and o.Description ~= ""
    local H = hasDesc and 78 or 62
    local r = newRow(self, H)

    new("TextLabel", { Position = UDim2.fromOffset(14, 11), Size = UDim2.new(1, -110, 0, 18), Text = o.Name or "", Weight = "Medium", Parent = r })
    if hasDesc then
        new("TextLabel", { Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -28, 0, 14), Text = o.Description, TextSize = 12, TextColor3 = T("Dim"), Parent = r })
    end
    local valueL = new("TextLabel", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 11), Size = UDim2.fromOffset(90, 18),
        TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = T("Dim"), TextSize = 13, Parent = r,
    })
    local trackY = H - 20
    local track = new("Frame", {
        Position = UDim2.fromOffset(14, trackY), Size = UDim2.new(1, -28, 0, 6),
        BackgroundColor3 = OV, BackgroundTransparency = 0.86, Parent = r,
    })
    round(track, 3, true)
    local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = accentOf(o), Parent = track })
    round(fill, 3, true)
    local knob = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(18, 18),
        BackgroundColor3 = WHITE, ZIndex = 2, Parent = track,
    })
    round(knob, 9, true)
    stroke(knob, BLACK, 0.8)
    local hit = new("TextButton", { Position = UDim2.fromOffset(8, trackY - 13), Size = UDim2.new(1, -16, 0, 32), ZIndex = 3, Parent = r })

    local function snap(v)
        v = math.clamp(v, min, max)
        v = math.floor((v - min) / inc + 0.5) * inc + min
        return math.clamp(tonumber(string.format("%.6f", v)), min, max)
    end
    local function paint(animate)
        local a = max == min and 0 or (obj.Value - min) / (max - min)
        local t = animate and 0.08 or 0
        tween(fill, { Size = UDim2.fromScale(a, 1) }, t)
        tween(knob, { Position = UDim2.fromScale(a, 0.5) }, t)
        valueL.Text = string.format("%g", obj.Value) .. suffix
    end
    function obj.Set(v, silent)
        v = snap(tonumber(v) or min)
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
            tween(knob, { Size = UDim2.fromOffset(23, 23) }, 0.15, Enum.EasingStyle.Back)
            fromX(i.Position.X)
        end
    end)
    self.Tab:_connect(UserInputService.InputChanged, function(i)
        if dragging and isMove(i) then fromX(i.Position.X) end
    end)
    self.Tab:_connect(UserInputService.InputEnded, function(i)
        if dragging and isPress(i) then
            dragging = false
            self.Tab.Scroll.ScrollingEnabled = true
            tween(knob, { Size = UDim2.fromOffset(18, 18) }, 0.2, Enum.EasingStyle.Back)
        end
    end)

    lib:_onTheme(function()
        if not fill.Parent then return false end
        tween(fill, { BackgroundColor3 = accentOf(o) }, 0.3)
    end)
    paint(false)
    return finish(lib, o, obj, r)
end

function Section:Dropdown(o)
    o = o or {}
    local lib = self.Lib
    local options = o.Options or {}
    local multi = o.Multi == true
    local obj = { Value = multi and {} or nil }
    local r = newRow(self, 44)
    r.ClipsDescendants = true

    local head = new("Frame", { Name = "Head", Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = OV, BackgroundTransparency = 1, Parent = r })
    new("TextLabel", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -200, 1, 0), Text = o.Name or "", Weight = "Medium", Parent = head })
    local arrow = new("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -22, 0.5, 0), Size = UDim2.fromOffset(14, 14),
        Text = ">", TextSize = 14, Weight = "SemiBold", TextColor3 = T("Dim"), TextXAlignment = Enum.TextXAlignment.Center, Parent = head,
    })
    local valueL = new("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -40, 0.5, 0), Size = UDim2.fromOffset(160, 20),
        TextSize = 13, TextColor3 = T("Dim"), TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, Parent = head,
    })
    local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = head })
    hit.MouseEnter:Connect(function() tween(head, { BackgroundTransparency = 0.955 }, 0.12) end)
    hit.MouseLeave:Connect(function() tween(head, { BackgroundTransparency = 1 }, 0.2) end)

    local sep = new("Frame", { Position = UDim2.fromOffset(14, 44), Size = UDim2.new(1, -14, 0, 1), BackgroundColor3 = OV, BackgroundTransparency = 0.92, Visible = false, Parent = r })
    local list = new("ScrollingFrame", {
        Position = UDim2.fromOffset(0, 45), Size = UDim2.new(1, 0, 0, 0), CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, ScrollBarImageColor3 = OV,
        ScrollBarImageTransparency = 0.7, Parent = r,
    })
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

    local buttons, ordered = {}, {}
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
            b.Label.TextColor3 = on and accentOf(o) or Theme.Text
            b.Dot.BackgroundColor3 = accentOf(o)
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
        tween(list, { Size = UDim2.new(1, 0, 0, h) }, 0.32)
        tween(r, { Size = UDim2.new(1, 0, 0, 44 + (v and h + 1 or 0)) }, 0.32)
        tween(arrow, { Rotation = v and 90 or 0 }, 0.25, Enum.EasingStyle.Back)
        if v then
            for idx, b in ipairs(ordered) do
                b.Label.TextTransparency = 1
                task.delay(dur(0.04 + idx * 0.025), function()
                    if b.Label.Parent then tween(b.Label, { TextTransparency = 0 }, 0.2) end
                end)
            end
        end
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
        buttons, ordered = {}, {}
        for idx, opt in ipairs(options) do
            local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = OV, BackgroundTransparency = 1, LayoutOrder = idx, Parent = list })
            local lbl = new("TextLabel", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -44, 1, 0), Text = tostring(opt), TextSize = 13, TextColor3 = Theme.Text, Parent = b })
            local dot = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.5, 0), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = accentOf(o), Visible = false, Parent = b })
            round(dot, 3, true)
            local rec = { Label = lbl, Dot = dot }
            buttons[opt] = rec
            table.insert(ordered, rec)
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

    lib:_onTheme(function()
        if not r.Parent then return false end
        refresh()
    end)
    build()
    if o.Default ~= nil then obj.Set(o.Default, true) end
    return finish(lib, o, obj, r)
end

function Section:Input(o)
    o = o or {}
    local lib = self.Lib
    local obj = { Value = o.Default or "" }
    local r = newRow(self, 44, true)
    textStack(r, o, 166)

    local box = new("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(150, 28),
        BackgroundColor3 = OV, BackgroundTransparency = 0.9, Text = obj.Value, PlaceholderText = o.Placeholder or "Type here",
        PlaceholderColor3 = T("Faint"), ClearTextOnFocus = false, TextSize = 13, ClipsDescendants = true, Parent = r,
    })
    round(box, 8)
    pad(box, 9, 9, 0, 0)
    local ring = stroke(box, accentOf(o), 1)

    box.Focused:Connect(function()
        tween(ring, { Transparency = 0.15 }, 0.15)
        tween(box, { BackgroundTransparency = 0.84 }, 0.15)
    end)
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
        tween(box, { BackgroundTransparency = 0.9 }, 0.2)
        obj.Value = box.Text
        if o.Flag then lib.Flags[o.Flag] = obj.Value end
        fire(o.Callback, obj.Value, enter)
    end)

    lib:_onTheme(function()
        if not ring.Parent then return false end
        ring.Color = accentOf(o)
    end)
    return finish(lib, o, obj, r)
end
Section.Textbox = Section.Input

function Section:Keybind(o)
    o = o or {}
    local lib = self.Lib
    local key = o.Default
    local obj = { Value = key and key.Name or "None" }
    local r = newRow(self, 44, true)
    textStack(r, o, 90)
    local hit = overlay(r)

    local pill = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(72, 28),
        BackgroundColor3 = OV, BackgroundTransparency = 0.88, Parent = r,
    })
    round(pill, 8)
    local pl = new("TextLabel", { Size = UDim2.fromScale(1, 1), TextSize = 12, Weight = "Medium", TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, Parent = pill })
    pressable(pill, hit, 0.93)

    local listening = false
    local function paint()
        pl.Text = listening and "..." or (key and key.Name or "None")
        local w = math.clamp(measure(pl.Text, 12) + 22, 56, 120)
        tween(pill, { Size = UDim2.fromOffset(w, 28), BackgroundColor3 = listening and accentOf(o) or Theme.Overlay, BackgroundTransparency = listening and 0 or 0.88 }, 0.2)
        tween(pl, { TextColor3 = listening and Theme.OnAccent or Theme.Text }, 0.2)
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
    self.Tab:_connect(UserInputService.InputBegan, function(i, processed)
        if listening and i.UserInputType == Enum.UserInputType.Keyboard then
            listening = false
            if i.KeyCode == Enum.KeyCode.Escape then paint()
            elseif i.KeyCode == Enum.KeyCode.Backspace then obj.Set(nil)
            else obj.Set(i.KeyCode) end
            return
        end
        if not processed and key and i.KeyCode == key then fire(o.Callback, key) end
    end)

    lib:_onTheme(function()
        if not pill.Parent then return false end
        paint()
    end)
    return finish(lib, o, obj, r)
end

function Section:ColorPicker(o)
    o = o or {}
    local lib = self.Lib
    local color = o.Default or Color3.fromRGB(255, 255, 255)
    local h, s, v = color:ToHSV()
    local obj = { Value = color }
    local PANEL = 146
    local r = newRow(self, 44)
    r.ClipsDescendants = true

    local head = new("Frame", { Name = "Head", Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = OV, BackgroundTransparency = 1, Parent = r })
    new("TextLabel", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -90, 1, 0), Text = o.Name or "", Weight = "Medium", Parent = head })
    local swatch = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(40, 22), BackgroundColor3 = color, Parent = head,
    })
    round(swatch, 7)
    stroke(swatch, OV, 0.8)
    local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = head })
    hit.MouseEnter:Connect(function() tween(head, { BackgroundTransparency = 0.955 }, 0.12) end)
    hit.MouseLeave:Connect(function() tween(head, { BackgroundTransparency = 1 }, 0.2) end)
    pressable(swatch, hit, 0.92)

    local panel = new("Frame", { Position = UDim2.fromOffset(14, 52), Size = UDim2.new(1, -28, 0, PANEL), Parent = r })
    local sv = new("Frame", { Size = UDim2.new(1, -30, 0, 104), BackgroundColor3 = Color3.fromHSV(h, 1, 1), ClipsDescendants = true, Parent = panel })
    round(sv, 8)
    local whiteL = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = sv })
    new("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = whiteL })
    local blackL = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, Parent = sv })
    new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = blackL })
    local svCur = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = WHITE, ZIndex = 3, Parent = sv })
    round(svCur, 6, true)
    stroke(svCur, BLACK, 0.4)
    local svHit = new("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = sv })

    local hue = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(20, 104), BackgroundColor3 = WHITE, Parent = panel })
    round(hue, 8)
    local keys = {}
    for k = 0, 6 do table.insert(keys, ColorSequenceKeypoint.new(k / 6, Color3.fromHSV(k / 6 == 1 and 0 or k / 6, 1, 1))) end
    new("UIGradient", { Rotation = 90, Color = ColorSequence.new(keys), Parent = hue })
    local hueCur = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 6, 0, 5), BackgroundColor3 = WHITE, ZIndex = 3, Parent = hue })
    round(hueCur, 2, true)
    stroke(hueCur, BLACK, 0.4)
    local hueHit = new("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = hue })

    local hex = new("TextBox", {
        Position = UDim2.fromOffset(0, 114), Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = OV, BackgroundTransparency = 0.9,
        PlaceholderText = "#RRGGBB", PlaceholderColor3 = T("Faint"), ClearTextOnFocus = false, TextSize = 13, Parent = panel,
    })
    round(hex, 8)
    pad(hex, 9, 9, 0, 0)

    local function apply(silent, animate)
        color = Color3.fromHSV(h, s, v)
        obj.Value = color
        sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        tween(swatch, { BackgroundColor3 = color }, animate and 0.15 or 0)
        svCur.Position = UDim2.fromScale(s, 1 - v)
        hueCur.Position = UDim2.fromScale(0.5, h)
        hex.Text = "#" .. color:ToHex():upper()
        if not silent then changed(lib, o, obj, color) end
    end
    function obj.Set(c, silent)
        if type(c) == "string" then
            local ok, parsed = pcall(Color3.fromHex, c)
            if not ok then return end
            c = parsed
        end
        if typeof(c) ~= "Color3" then return end
        h, s, v = c:ToHSV()
        apply(silent, true)
    end
    function obj.Get() return obj.Value end

    local mode
    svHit.InputBegan:Connect(function(i) if isPress(i) then mode = "sv" self.Tab.Scroll.ScrollingEnabled = false end end)
    hueHit.InputBegan:Connect(function(i) if isPress(i) then mode = "hue" self.Tab.Scroll.ScrollingEnabled = false end end)
    local function drag(i)
        local p = pointer(i)
        if mode == "sv" then
            s = math.clamp((p.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
            v = 1 - math.clamp((p.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
            apply(false)
        elseif mode == "hue" then
            h = math.clamp((p.Y - hue.AbsolutePosition.Y) / math.max(hue.AbsoluteSize.Y, 1), 0, 1)
            apply(false)
        end
    end
    svHit.InputBegan:Connect(function(i) if isPress(i) then drag(i) end end)
    hueHit.InputBegan:Connect(function(i) if isPress(i) then drag(i) end end)
    self.Tab:_connect(UserInputService.InputChanged, function(i) if mode and isMove(i) then drag(i) end end)
    self.Tab:_connect(UserInputService.InputEnded, function(i)
        if mode and isPress(i) then
            mode = nil
            self.Tab.Scroll.ScrollingEnabled = true
        end
    end)
    hex.FocusLost:Connect(function() obj.Set(hex.Text) end)

    local open = false
    hit.MouseButton1Click:Connect(function()
        open = not open
        tween(r, { Size = UDim2.new(1, 0, 0, open and (44 + 8 + PANEL + 10) or 44) }, 0.32)
    end)

    apply(true)
    return finish(lib, o, obj, r)
end
Section.Colorpicker = Section.ColorPicker

--// ready-made settings tab -------------------------------------------------
function Window:CreateSettings(name)
    local lib = self.Library
    local tab = self:CreateTab(name or "Settings")

    local look = tab:Section("Theme", "Left")
    local accent, base, text
    look:Dropdown({
        Name = "Preset", Options = ThemeNames, Default = lib.ThemeName,
        Callback = function(v)
            lib:SetTheme(v)
            accent.Set(Theme.Accent, true)
            base.Set(Theme.Base, true)
            text.Set(Theme.Text, true)
        end,
    })
    accent = look:ColorPicker({ Name = "Accent", Default = Theme.Accent, Flag = "ui_accent", Callback = function(c) lib:SetAccent(c) end })
    base = look:ColorPicker({ Name = "Background", Default = Theme.Base, Flag = "ui_base", Callback = function(c) lib:SetColor("Base", c) end })
    text = look:ColorPicker({ Name = "Text", Default = Theme.Text, Flag = "ui_text", Callback = function(c) lib:SetColor("Text", c) end })

    local shape = tab:Section("Shape and type", "Left")
    shape:Slider({ Name = "Window opacity", Min = 40, Max = 100, Default = math.floor((1 - Config.Transparency) * 100 + 0.5), Suffix = "%", Flag = "ui_opacity", Callback = function(v) lib:SetTransparency(1 - v / 100) end })
    shape:Slider({ Name = "Corner roundness", Min = 0, Max = 160, Default = math.floor(Config.Radius * 100 + 0.5), Increment = 5, Suffix = "%", Flag = "ui_radius", Callback = function(v) lib:SetRadius(v / 100) end })
    shape:Slider({ Name = "Interface size", Min = 70, Max = 130, Default = math.floor(Config.Scale * 100 + 0.5), Increment = 5, Suffix = "%", Flag = "ui_scale", Callback = function(v) lib:SetScale(v / 100) end })
    local fonts = {}
    for fname in pairs(Fonts) do table.insert(fonts, fname) end
    table.sort(fonts)
    shape:Dropdown({ Name = "Font", Options = fonts, Default = Config.Font, Flag = "ui_font", Callback = function(v) lib:SetFont(v) end })

    local behave = tab:Section("Behaviour", "Right")
    behave:Toggle({ Name = "Animations", Default = Config.Animations, Flag = "ui_anim", Callback = function(v) Config.Animations = v end })
    behave:Slider({ Name = "Animation speed", Min = 50, Max = 200, Default = math.floor(Config.AnimSpeed * 100 + 0.5), Increment = 10, Suffix = "%", Flag = "ui_animspeed", Callback = function(v) Config.AnimSpeed = v / 100 end })
    behave:Toggle({ Name = "Auto-hide dock", Description = "Slides away until the cursor reaches the bottom edge", Default = Config.DockAutoHide, Flag = "ui_autohide", Callback = function(v) Config.DockAutoHide = v lib:PeekDock(1.5) end })
    behave:Toggle({ Name = "Dynamic island", Default = Config.Island, Flag = "ui_island", Callback = function(v) lib:SetIsland(v) end })
    behave:Toggle({ Name = "Island stats on hover", Default = Config.IslandStats, Flag = "ui_islandstats", Callback = function(v) Config.IslandStats = v end })
    behave:Keybind({ Name = "Hide interface", Default = lib.ToggleKey, Changed = function(k) if k then lib.ToggleKey = k end end })

    local files = tab:Section("Configuration", "Right")
    local cfgName = files:Input({ Name = "Config name", Default = "default", Placeholder = "name" })
    files:Button({ Name = "Save", ButtonText = "Save", Callback = function()
        lib:Notify({ Title = lib:SaveConfig(cfgName.Get()) and "Config saved" or "Could not save", Type = "Info" })
    end })
    files:Button({ Name = "Load", ButtonText = "Load", Callback = function()
        lib:Notify({ Title = lib:LoadConfig(cfgName.Get()) and "Config loaded" or "No config found", Type = "Info" })
    end })
    files:Button({ Name = "Unload", Description = "Removes the interface completely", ButtonText = "Unload", Callback = function() lib:Destroy() end })
    return tab
end

env.__ISLE = Isle
Isle:_init()
return Isle
