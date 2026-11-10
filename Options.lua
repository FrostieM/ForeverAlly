-- ForeverAlly: the options page (Esc > Options > AddOns > ForeverAlly, or /fally). Built by hand on
-- the canvas layout, with the widgets ClearLoot uses on this client (checkbuttons, plain sliders,
-- panel buttons). A failure here never touches the nameplate or macro code.
local _, ns = ...
local L = ns.L

local BLESSING_NAMES = {} -- kind -> localized spell name (filled when the page opens)

-- friendly player nameplates: current clients name the setting nameplateShowFriendlyPlayers, older
-- ones nameplateShowFriends (a name the client does not have reads nil). Unknown counts as on.
local VIS_CVARS = { "nameplateShowFriendlyPlayers", "nameplateShowFriends" }
local function FriendlyPlatesOn()
    for _, name in ipairs(VIS_CVARS) do
        local ok, v = pcall(GetCVar, name)
        if ok and v ~= nil then return v == "1" end
    end
    return true
end
local function FriendlyPlatesShow()
    if InCombatLockdown() then return end
    for _, name in ipairs(VIS_CVARS) do pcall(SetCVar, name, "1") end
end

local function Tip(widget, title, text)
    widget:HookScript("OnEnter", function(self)
        if not text then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 0.82, 0)
        GameTooltip:AddLine(text, 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    widget:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local refreshers = {} -- functions that re-read the settings into the widgets

local function Header(parent, y, text)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", 16, y)
    fs:SetText(text)
    return y - 28
end

local function Check(parent, y, label, tooltip, get, set, indent)
    local template = DoesTemplateExist and DoesTemplateExist("InterfaceOptionsCheckButtonTemplate")
        and "InterfaceOptionsCheckButtonTemplate" or "UICheckButtonTemplate"
    local cb = CreateFrame("CheckButton", nil, parent, template)
    cb:SetSize(26, 26)
    cb:SetPoint("TOPLEFT", 16 + (indent or 0), y)
    local text = cb.Text
    if type(text) ~= "table" then text = cb.text end
    if type(text) ~= "table" then
        text = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        cb.Text = text
    end
    -- label: a string, or a function giving it (spell names that load later)
    local function Label() return type(label) == "function" and label() or label end
    text:SetText(Label())
    Tip(cb, Label(), tooltip)
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        ns.RefreshAll()
    end)
    table.insert(refreshers, function()
        cb:SetChecked(get() and true or false)
        if type(label) == "function" then text:SetText(label()) end
    end)
    return y - 28
end

-- A spell's name in the client's language. The game knows the name of a spell the character has
-- not learned only once its data is loaded: it is requested, the page refreshes when it comes
-- (SPELL_DATA_LOAD_RESULT), and meanwhile a translated name stands in.
local FALLBACK_NAMES = {
    [19740] = "Blessing of Might", [19742] = "Blessing of Wisdom", [20217] = "Blessing of Kings",
    [1038] = "Blessing of Salvation", [19977] = "Blessing of Light", [20911] = "Blessing of Sanctuary",
    [1243] = "Power Word: Fortitude", [14752] = "Divine Spirit", [1126] = "Mark of the Wild", [1459] = "Arcane Intellect",
    [976] = "Shadow Protection", [467] = "Thorns", [5697] = "Unending Breath", [11743] = "Detect Invisibility",
}
local function SpellLabel(id)
    local name = C_Spell.GetSpellName(id)
    if name then return name end
    if C_Spell.RequestLoadSpellData then pcall(C_Spell.RequestLoadSpellData, id) end
    return FALLBACK_NAMES[id] and L[FALLBACK_NAMES[id]] or tostring(id)
end

local function Slider(parent, y, label, tooltip, minV, maxV, step, unit, get, set)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 22, y)
    local s = CreateFrame("Slider", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    s:SetSize(220, 16)
    s:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -8)
    s:SetOrientation("HORIZONTAL")
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    if s.SetBackdrop then
        s:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        s:SetBackdropColor(0.08, 0.08, 0.10, 0.85)
        s:SetBackdropBorderColor(0.6, 0.5, 0.3, 0.9)
    end
    local thumb = s:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(14, 20)
    thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    s:SetThumbTexture(thumb)
    local function Show(v) fs:SetText(("%s: |cffffffff%d %s|r"):format(label, v, unit)) end
    s:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / step + 0.5) * step
        Show(v)
        if self.updating then return end
        set(v)
        ns.RefreshAll()
    end)
    Tip(s, label, tooltip)
    table.insert(refreshers, function()
        s.updating = true
        s:SetValue(get())
        s.updating = false
        Show(get())
    end)
    return y - 52
end

local function Button(parent, y, label, onClick, x)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetPoint("TOPLEFT", x or 20, y)
    b:SetText(label)
    -- (sized to the text itself: a byte count makes Cyrillic buttons twice too wide)
    local fs = b.GetFontString and b:GetFontString()
    local w = type(fs) == "table" and fs.GetStringWidth and fs:GetStringWidth()
    b:SetSize(math.max(120, (type(w) == "number" and w or 100) + 32), 22)
    b:SetScript("OnClick", onClick)
    return b
end

-- a key-capture field: click it, then press a key (or a mouse button); Esc cancels
local MODIFIER_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true, RMETA = true }
local MOUSE_KEYS = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }
local function KeyField(parent, y, label, get, set)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 22, y - 4)
    fs:SetText(label)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(170, 22)
    b:SetPoint("LEFT", fs, "RIGHT", 10, 0)
    b:RegisterForClicks("AnyUp")
    local listening = false
    local function Show()
        local key = get()
        b:SetText(listening and L["Press a key (Esc - cancel)"] or (key and (GetBindingText and GetBindingText(key) or key) or L["Not set"]))
    end
    local function Stop()
        listening = false
        b:EnableKeyboard(false)
        b:SetScript("OnKeyDown", nil)
        Show()
    end
    local function Take(key)
        local mods = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "")
        set(mods .. key)
        Stop()
    end
    b:SetScript("OnClick", function(self, mouse)
        if listening then
            if MOUSE_KEYS[mouse] then Take(MOUSE_KEYS[mouse]) end
            return
        end
        if InCombatLockdown() then return end
        listening = true
        Show()
        self:EnableKeyboard(true)
        self:SetScript("OnKeyDown", function(_, key)
            if key == "ESCAPE" then Stop() return end
            if MODIFIER_KEYS[key] then return end
            Take(key)
        end)
    end)
    b:HookScript("OnHide", function() if listening then Stop() end end)
    local clear = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    clear:SetSize(110, 22)
    clear:SetPoint("LEFT", b, "RIGHT", 6, 0)
    clear:SetText(L["Clear key"])
    clear:SetScript("OnClick", function() set(nil); Show() end)
    table.insert(refreshers, Show)
    return y - 32
end

local function Note(parent, y, text)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", 22, y)
    fs:SetWidth(560)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return y - math.max(16, (fs:GetStringHeight() or 14) + 6)
end

-- an ordered list of blessings with up / down buttons
local function OrderList(parent, y, label, list)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 22, y)
    fs:SetText(label)
    y = y - 20
    local rows = {}
    for i = 1, #list do
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(300, 20)
        row:SetPoint("TOPLEFT", 30, y - (i - 1) * 21)
        row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.text:SetPoint("LEFT", 44, 0)
        for d, info in ipairs({ { -1, "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up", L["Move up"] },
                               { 1, "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up", L["Move down"] } }) do
            local b = CreateFrame("Button", nil, row)
            b:SetSize(18, 18)
            b:SetPoint("LEFT", (d - 1) * 20, 0)
            b:SetNormalTexture(info[2])
            b:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Highlight", "ADD")
            b:SetScript("OnClick", function()
                local j = i + info[1]
                if j < 1 or j > #list then return end
                list[i], list[j] = list[j], list[i]
                for _, fn in ipairs(refreshers) do fn() end
                ns.RefreshAll()
            end)
            Tip(b, info[3])
        end
        rows[i] = row
    end
    table.insert(refreshers, function()
        for i, row in ipairs(rows) do
            local kind = list[i]
            local known = ns.blessings[kind]
            row.text:SetText(("%d. %s%s"):format(i, BLESSING_NAMES[kind] or kind,
                known and "" or " |cff808080(" .. L["not learned"] .. ")|r"))
        end
    end)
    return y - #list * 21 - 6
end

local function Build(panel)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", -30, 8)
    local c = CreateFrame("Frame", nil, scroll)
    c:SetSize(600, 1600)
    scroll:SetScrollChild(c)

    local db = ns.db
    local y = -8
    local title = c:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", 16, y)
    title:SetText("|cff7fd4ffForever|rAlly  |cff808080" .. (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("ForeverAlly", "Version") or "") .. "|r")
    y = y - 34

    -- friendly nameplates: everything here draws on them
    local npNote = c:CreateFontString(nil, "ARTWORK", "GameFontRedSmall")
    npNote:SetPoint("TOPLEFT", 22, y)
    npNote:SetWidth(420)
    npNote:SetJustifyH("LEFT")
    npNote:SetText(L["Friendly player nameplates are off: the icons and buffing players around you need them."])
    local npButton = Button(c, y - 2, L["Turn them on"], function()
        FriendlyPlatesShow()
        for _, fn in ipairs(refreshers) do fn() end
    end, 450)
    table.insert(refreshers, function()
        local on = FriendlyPlatesOn()
        npNote:SetShown(not on)
        npButton:SetShown(not on)
    end)
    y = y - 32

    y = Header(c, y, L["Recent allies"])
    y = Check(c, y, L["Mark players you were grouped with"], L["An icon in front of the name on their nameplate."],
        function() return db.allies.enabled end, function(v) db.allies.enabled = v end)
    y = Check(c, y, L["Remember everyone you group with"],
        L["The game's own Recent Allies list leaves some players out (friends, for one); the addon keeps its own list too."],
        function() return db.allies.memory end, function(v) db.allies.memory = v end, 20)
    y = Check(c, y, L["Use the game's Recent Allies list"], nil,
        function() return db.allies.blizzardList end, function(v) db.allies.blizzardList = v end, 20)
    y = Check(c, y, L["Line in the tooltip"], nil,
        function() return db.allies.tooltip end, function(v) db.allies.tooltip = v end, 20)
    y = Slider(c, y, L["Ally icon size"], nil, 10, 28, 1, L["px"],
        function() return db.allies.size end, function(v) db.allies.size = v end)
    local clear = Button(c, y, L["Clear the remembered allies"], function() ns.ClearAllies(); for _, fn in ipairs(refreshers) do fn() end end)
    local count = c:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    count:SetPoint("LEFT", clear, "RIGHT", 10, 0)
    table.insert(refreshers, function() count:SetText(("(%d)"):format(ns.AllyCount())) end)
    y = y - 36

    y = Header(c, y, L["Missing buffs"])
    y = Check(c, y, L["Show icons of the buffs a player lacks"],
        L["Out of combat, next to the name on a friendly player's nameplate: each of your class buffs they lack."],
        function() return db.buffs.enabled end, function(v) db.buffs.enabled = v end)
    y = Slider(c, y, L["Buff icon size"], nil, 10, 28, 1, L["px"],
        function() return db.buffs.size end, function(v) db.buffs.size = v end)
    y = Slider(c, y, L["Renew when less than this is left"], L["A buff with less than this share of its time left counts as missing."],
        0, 60, 5, "%", function() return db.buffs.renewPct end, function(v) db.buffs.renewPct = v end)
    y = Check(c, y, L["Skip PvP-flagged players while you are not flagged"], L["Buffing them would flag you for PvP."],
        function() return db.buffs.skipPvP end, function(v) db.buffs.skipPvP = v end)
    y = Check(c, y, L["Intellect and Spirit only for mana users"], nil,
        function() return db.buffs.manaOnly end, function(v) db.buffs.manaOnly = v end)

    -- the buffs of your class (paladins: the blessings)
    local fs = c:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 22, y)
    fs:SetText(L["Buffs to check"])
    y = y - 22
    local ids = {}
    for _, buff in ipairs(ns.CLASS_BUFFS[ns.playerClass] or {}) do
        ids[#ids + 1] = { key = buff.names[1], id = buff.names[1], optional = buff.optional, tankOnly = buff.tankOnly }
    end
    if ns.playerClass == "PALADIN" then
        for _, kind in ipairs(ns.BLESSING_KEYS) do ids[#ids + 1] = { key = kind, id = ns.BLESSING_IDS[kind][1] } end
    end
    for _, e in ipairs(ids) do
        local label = function()
            local known = (ns.blessings[e.key] ~= nil)
            for _, b in ipairs(ns.active) do if b.key == e.key then known = true end end
            return SpellLabel(e.id) .. (known and "" or " |cff808080(" .. L["not learned"] .. ")|r")
        end
        if e.optional then
            -- off until switched on: given when needed, not to everyone
            y = Check(c, y, label, L["Off by default: switch it on if you give this buff to everyone."],
                function() return db.buffs.optIn[e.key] end, function(v) db.buffs.optIn[e.key] = v or nil end, 20)
        else
            y = Check(c, y, label, nil, function() return not db.buffs.off[e.key] end,
                function(v) db.buffs.off[e.key] = (not v) or nil end, 20)
        end
        if e.tankOnly then
            y = Check(c, y, L["Only for tanks (rage users: warriors, druids in bear form)"], nil,
                function() return db.buffs.thornsTanksOnly end, function(v) db.buffs.thornsTanksOnly = v end, 40)
        end
    end

    if ns.playerClass == "PALADIN" then
        y = y - 6
        y = Header(c, y, L["Paladin blessings"])
        y = Note(c, y, L["Each paladin keeps one blessing of their own on a player: the first one in the list that the player lacks is given."])
        y = OrderList(c, y, L["Blessing order for mana users"], db.blessings.mana)
        y = OrderList(c, y, L["Blessing order for rage and energy users"], db.blessings.physical)
        y = Check(c, y, L["No Salvation for rage users (tanks)"], nil,
            function() return db.blessings.noSalvationForRage end, function(v) db.blessings.noSalvationForRage = v end)
    end

    y = y - 6
    y = Header(c, y, L["Auto buff"])
    if not ns.HasBuffs() then
        y = Note(c, y, L["Your class has no buffs for other players: the buff icons and the auto buff stay idle."])
    end
    y = KeyField(c, y, L["Auto-buff key"], ns.GetBuffKey, function(key) ns.SetBuffKey(key) end)
    y = Check(c, y, L["Turn on the auto buff"],
        L["Each press of the auto-buff key buffs the next player who needs it. The key can also be set in Key Bindings > ForeverAlly."],
        function() return db.auto.enabled end, function(v) db.auto.enabled = v end)
    y = Check(c, y, L["Buff yourself"], nil, function() return db.auto.self end, function(v) db.auto.self = v end, 20)
    y = Check(c, y, L["Buff your group"], nil, function() return db.auto.group end, function(v) db.auto.group = v end, 20)
    y = Check(c, y, L["Buff everyone around you"], nil, function() return db.auto.others end, function(v) db.auto.others = v end, 20)
    y = Check(c, y, L["Pick the rank by the target's level"], L["Forever does not lower a buff's rank for a low-level player by itself."],
        function() return db.auto.ranks end, function(v) db.auto.ranks = v end, 20)
    y = Check(c, y, L["Message on each press"], nil, function() return db.auto.message end, function(v) db.auto.message = v end, 20)
    y = Slider(c, y, L["After a failed cast, try others first for"], nil, 0, 30, 1, L["sec"],
        function() return db.auto.skipSec end, function(v) db.auto.skipSec = v end)

    y = Header(c, y, L["Troubleshooting"])
    y = Check(c, y, L["Keep a log"], L["Written to the SavedVariables file on /reload or logout; /fally log show prints the last lines."],
        function() return db.debug end, function(v) db.debug = v end)
    y = Note(c, y, L["Commands: /fally - options, /fally status - about your target, /fally log on|off|show|clear, /ally add|del"])

    c:SetHeight(-y + 20)
    panel:SetScript("OnShow", function()
        for _, kind in ipairs(ns.BLESSING_KEYS) do BLESSING_NAMES[kind] = SpellLabel(ns.BLESSING_IDS[kind][1]) end
        for _, fn in ipairs(refreshers) do fn() end
    end)
end

local category
ns.AfterLoad(function()
    local panel = CreateFrame("Frame", "ForeverAllyOptions", UIParent)
    panel.name = "ForeverAlly"
    panel:Hide()
    local built = false
    panel:HookScript("OnShow", function(self)
        if built then return end
        built = true
        local ok, err = pcall(Build, self)
        if not ok then ns.Print("options: " .. tostring(err)) return end
        self:GetScript("OnShow")(self)
    end)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local ok, cat = pcall(Settings.RegisterCanvasLayoutCategory, panel, panel.name)
        if ok and cat then
            pcall(Settings.RegisterAddOnCategory, cat)
            category = cat
        end
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
    ns.optionsPanel = panel
end)

function ns.OpenOptions()
    if Settings and Settings.OpenToCategory and category then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory and ns.optionsPanel then
        InterfaceOptionsFrame_OpenToCategory(ns.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(ns.optionsPanel)
    end
end

-- friendly nameplates off: say so once a session (everything here needs them)
ns.On("PLAYER_LOGIN", function()
    C_Timer.After(5, function()
        if not FriendlyPlatesOn() then
            ns.Print(L["Friendly player nameplates are off: the icons and buffing players around you need them."] .. " /fally")
        end
    end)
end)

-- spell names of unlearned spells arrive later: the open page re-reads them
local reloadPending = false
pcall(ns.On, "SPELL_DATA_LOAD_RESULT", function()
    local panel = ns.optionsPanel
    if reloadPending or not (panel and panel:IsShown() and panel:GetScript("OnShow")) then return end
    reloadPending = true
    C_Timer.After(0.2, function()
        reloadPending = false
        if panel:IsShown() then panel:GetScript("OnShow")(panel) end
    end)
end)
