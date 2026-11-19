-- ForeverAlly: the recent-ally mark. A player you have been in a group with gets an icon in front
-- of the name on their nameplate and a line in their tooltip. Two sources: the game's own Recent
-- Allies list (C_RecentAllies) and the addon's memory of everyone seen in your group (the game's
-- list leaves some players out, friends among them).
--
-- Anyone can also be added by hand: right-click their unit frame (target, party, raid, focus, a
-- name in chat) > "Add to allies...", with an optional note and an icon of your choice instead of
-- the default one. The note shows in their tooltip, the icon on their nameplate and in the
-- tooltip. /ally add [note] | note <text> | edit | del do the same for your target.
--
-- A memory record: ns.db.grouped[guid] = { name, last time seen in your group (or added),
--   note = text or nil, icon = key in ICONS or nil (the default), manual = true while added by
--   hand and not yet seen in your group }
local _, ns = ...
local L, Plain = ns.L, ns.Plain

local ATLAS = "friendslist-recentallies-yellow"
local marks = {} -- plate -> texture

-- icons to pick from: the default, the raid markers, roles and professions
local RAID = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
local ICON = "Interface\\Icons\\"
local ICONS = {
    { key = "default", atlas = ATLAS },
    { key = "star", file = RAID .. "1" }, { key = "circle", file = RAID .. "2" },
    { key = "diamond", file = RAID .. "3" }, { key = "triangle", file = RAID .. "4" },
    { key = "moon", file = RAID .. "5" }, { key = "square", file = RAID .. "6" },
    { key = "cross", file = RAID .. "7" }, { key = "skull", file = RAID .. "8" },
    { key = "tank", file = ICON .. "Ability_Warrior_DefensiveStance", crop = true },
    { key = "healer", file = ICON .. "Spell_Holy_Heal", crop = true },
    { key = "damage", file = ICON .. "INV_Sword_04", crop = true },
    { key = "helper", file = ICON .. "Spell_Holy_SealOfSacrifice", crop = true },
    { key = "trader", file = ICON .. "INV_Misc_Coin_01", crop = true },
    { key = "note", file = ICON .. "INV_Misc_Note_01", crop = true },
    { key = "bad", file = ICON .. "INV_Misc_Bone_HumanSkull_01", crop = true },
    { key = "fun", file = ICON .. "INV_Misc_Food_15", crop = true },
    { key = "mining", file = ICON .. "Trade_Mining", crop = true },
    { key = "blacksmithing", file = ICON .. "Trade_BlackSmithing", crop = true },
    { key = "alchemy", file = ICON .. "Trade_Alchemy", crop = true },
    { key = "enchanting", file = ICON .. "Trade_Engraving", crop = true },
    { key = "tailoring", file = ICON .. "Trade_Tailoring", crop = true },
    { key = "leatherworking", file = ICON .. "Trade_LeatherWorking", crop = true },
    { key = "engineering", file = ICON .. "Trade_Engineering", crop = true },
    { key = "herbalism", file = ICON .. "Trade_Herbalism", crop = true },
}
local ICON_BY_KEY = {}
for _, def in ipairs(ICONS) do ICON_BY_KEY[def.key] = def end

local function IconDef(rec)
    return (rec and rec.icon and ICON_BY_KEY[rec.icon]) or ICONS[1]
end

local function ApplyIcon(tex, def)
    if def.atlas then
        tex:SetTexCoord(0, 1, 0, 1)
        tex:SetAtlas(def.atlas)
    else
        tex:SetTexture(def.file)
        if def.crop then tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) else tex:SetTexCoord(0, 1, 0, 1) end
    end
end

local function IconMarkup(def, size)
    if def.atlas then return CreateAtlasMarkup(def.atlas, size, size) end
    if def.crop then return ("|T%s:%d:%d:0:0:64:64:5:59:5:59|t"):format(def.file, size, size) end
    return ("|T%s:%d:%d|t"):format(def.file, size, size)
end

local function InGameList(guid)
    if not (ns.db.allies.blizzardList and C_RecentAllies and C_RecentAllies.IsRecentAllyByGUID) then return false end
    local ok, res = pcall(C_RecentAllies.IsRecentAllyByGUID, guid)
    return ok and Plain(res) == true
end

local function PlayerGUID(unit)
    if not unit or not Plain(UnitIsPlayer(unit)) or Plain(UnitIsUnit(unit, "player")) then return end
    return Plain(UnitGUID(unit))
end

-- guid and memory record (nil when only in the game's list) of an ally; nil when not an ally
local function Ally(unit)
    local guid = PlayerGUID(unit)
    if not guid then return end
    local rec = ns.db.allies.memory and ns.db.grouped[guid] or nil
    if rec or InGameList(guid) then return guid, rec end
end

local function IsAlly(unit)
    return Ally(unit) ~= nil
end
ns.IsAlly = IsAlly

local function RememberGroup()
    if not (ns.db.allies.memory and IsInGroup()) then return end
    local grouped, now = ns.db.grouped, time()
    local prefix, count = "party", GetNumSubgroupMembers()
    if IsInRaid() then prefix, count = "raid", GetNumGroupMembers() end
    for i = 1, count do
        local unit = prefix .. i
        local guid = PlayerGUID(unit)
        if guid then
            local name = Plain(GetUnitName(unit, true)) or "?"
            local rec = grouped[guid]
            if rec then
                -- (kept in place: the note and the icon stay)
                if name ~= "?" then rec[1] = name end
                rec[2], rec.manual = now, nil
            else
                grouped[guid] = { name, now }
            end
        end
    end
end

local function Hide(plate)
    if marks[plate] then marks[plate]:Hide() end
end

local function Update(unit, plate)
    local a = ns.db.allies
    if not a.enabled then Hide(plate) return end
    local guid, rec = Ally(unit)
    if not guid then Hide(plate) return end
    local t = marks[plate]
    if not t then
        t = plate:CreateTexture(nil, "OVERLAY", nil, 7)
        marks[plate] = t
    end
    ApplyIcon(t, IconDef(rec)) -- (a plate is reused for other players: set every time)
    t:SetSize(a.size, a.size)
    t:Show()
    local row = { t }
    ns.PlaceRow(plate, row, 1, a.size, "left")
    -- (EllesmereUI re-applies the name font right after the plate appears: measured again then)
    C_Timer.After(0.1, function()
        if marks[plate] == t and t:IsShown() then ns.PlaceRow(plate, row, 1, a.size, "left") end
    end)
end

table.insert(ns.parts, { Update = Update, Hide = Hide })

-- (C_RecentAllies.TryRequestRecentAlliesData is for Blizzard's UI only on Forever: calling it shows
-- the "addon blocked" popup even inside pcall. The game loads the list by itself.)
ns.On("PLAYER_ENTERING_WORLD", function()
    RememberGroup()
    ns.RefreshAll()
end)
ns.On("GROUP_ROSTER_UPDATE", function() RememberGroup(); ns.RefreshAll() end)
pcall(ns.On, "RECENT_ALLIES_CACHE_UPDATE", function() ns.RefreshAll() end)
pcall(ns.On, "RECENT_ALLIES_DATA_READY", function() ns.RefreshAll() end)

-- tooltip: the ally line with their icon and a grey date on the right (last time in your group, or
-- the day you added them), then the note in quotes, indented under the label text
local INDENT = 18 -- the 14 px icon and the space after it
local leftOffsetWorks
local function LeftOffsetWorks()
    -- (does AddLine take a left offset on this client? an indented line on a hidden tooltip of our own)
    if leftOffsetWorks == nil then
        leftOffsetWorks = false
        pcall(function()
            local probe = CreateFrame("GameTooltip", "ForeverAllyTooltipProbe", UIParent, "GameTooltipTemplate")
            probe:SetOwner(UIParent, "ANCHOR_NONE")
            probe:SetPoint("CENTER")
            probe:AddLine("x")
            probe:AddLine("x", 1, 1, 1, false, 20)
            probe:Show()
            local l1, l2 = ForeverAllyTooltipProbeTextLeft1:GetLeft(), ForeverAllyTooltipProbeTextLeft2:GetLeft()
            leftOffsetWorks = (l1 and l2 and l2 - l1 > 10) or false
            probe:Hide()
        end)
    end
    return leftOffsetWorks
end

local NOTE_WIDTH = 240 -- a long note wraps at this width, not at the width of the unit's name
local widened = false

ns.AfterLoad(function()
    if not (TooltipDataProcessor and Enum.TooltipDataType) then return end
    GameTooltip:HookScript("OnTooltipCleared", function(tt)
        if widened then widened = false; tt:SetMinimumWidth(0) end
    end)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt)
        if tt ~= GameTooltip or not tt.GetUnit or not ns.db.allies.tooltip or not ns.db.allies.enabled then return end
        local _, unit = tt:GetUnit()
        unit = Plain(unit)
        if not unit then return end
        local guid, rec = Ally(unit)
        if not guid then return end
        -- (added by hand and never seen in a group: no "grouped with you")
        local label = (rec and rec.manual and not InGameList(guid)) and L["Added to your allies"] or L["Grouped with you before"]
        local left = IconMarkup(IconDef(rec), 14) .. " " .. label
        local when = rec and type(rec[2]) == "number" and rec[2] > 0 and date(L["%m/%d/%Y"], rec[2])
        if when then
            tt:AddDoubleLine(left, when, 1, 0.82, 0, 0.5, 0.5, 0.5)
        else
            tt:AddLine(left, 1, 0.82, 0)
        end
        if rec and rec.note then
            local text = L['"%s"']:format(rec.note)
            if (strlenutf8 and strlenutf8(rec.note) or #rec.note) > 30 and tt.SetMinimumWidth then -- (letters, not bytes)
                widened = true
                tt:SetMinimumWidth(NOTE_WIDTH)
            end
            if LeftOffsetWorks() then
                tt:AddLine(text, 1, 0.82, 0, true, INDENT)
            else
                tt:AddLine("    " .. text, 1, 0.82, 0, true)
            end
        end
    end)
end)

--------------------------------------------------------------------------------
-- Adding, editing and removing by hand
--------------------------------------------------------------------------------

local function SaveAlly(guid, name, note, icon)
    local grouped = ns.db.grouped
    local rec = grouped[guid]
    if not rec then
        rec = { name or "?", time(), manual = true }
        grouped[guid] = rec
    elseif name and name ~= "?" then
        rec[1] = name
    end
    if note ~= nil then
        note = strtrim(note)
        rec.note = note ~= "" and note or nil
    end
    if icon ~= nil then rec.icon = icon ~= "default" and ICON_BY_KEY[icon] and icon or nil end
    ns.RefreshAll()
    return rec
end

local function RemoveAlly(guid, name)
    ns.db.grouped[guid] = nil
    ns.Print(L["%s removed from the ally memory (the game's own list is not changed)."]:format(name or "?"))
    ns.RefreshAll()
end

-- the edit window: note and icon
local dialog
local CELL, COLS = 30, 9

local function BuildDialog()
    local d = CreateFrame("Frame", "ForeverAllyEditDialog", UIParent, "BackdropTemplate")
    local rows = math.ceil(#ICONS / COLS)
    local width = math.max(COLS * CELL + 40, 350)
    local left = (width - COLS * CELL) / 2 + 2
    d:SetSize(width, 160 + rows * CELL)
    d:SetPoint("CENTER", 0, 120)
    d:SetFrameStrata("DIALOG")
    d:SetToplevel(true)
    d:SetClampedToScreen(true)
    d:EnableMouse(true)
    d:SetMovable(true)
    d:RegisterForDrag("LeftButton")
    d:SetScript("OnDragStart", d.StartMoving)
    d:SetScript("OnDragStop", d.StopMovingOrSizing)
    d:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    d:Hide()
    tinsert(UISpecialFrames, "ForeverAllyEditDialog") -- (Esc closes it)

    d.title = d:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    d.title:SetPoint("TOP", 0, -20)

    local noteLabel = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    noteLabel:SetPoint("TOPLEFT", 22, -44)
    noteLabel:SetText(L["Note (optional)"])

    local eb = CreateFrame("EditBox", nil, d, "InputBoxTemplate")
    eb:SetPoint("TOPLEFT", 28, -60)
    eb:SetPoint("TOPRIGHT", -24, -60)
    eb:SetHeight(22)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(150)
    eb:SetScript("OnEscapePressed", function() d:Hide() end)
    d.edit = eb

    local iconLabel = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    iconLabel:SetPoint("TOPLEFT", 22, -92)
    iconLabel:SetText(L["Icon on the nameplate and in the tooltip"])

    d.cells = {}
    local function Select(key)
        d.icon = key
        for _, b in ipairs(d.cells) do b.sel:SetShown(b.key == key) end
    end
    d.Select = Select
    for i, def in ipairs(ICONS) do
        local b = CreateFrame("Button", nil, d)
        b:SetSize(CELL - 4, CELL - 4)
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        b:SetPoint("TOPLEFT", left + col * CELL, -108 - row * CELL)
        local tex = b:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        ApplyIcon(tex, def)
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b.sel = b:CreateTexture(nil, "OVERLAY")
        b.sel:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        b.sel:SetBlendMode("ADD")
        b.sel:SetSize((CELL - 4) * 1.9, (CELL - 4) * 1.9)
        b.sel:SetPoint("CENTER")
        b.sel:Hide()
        b.key = def.key
        b:SetScript("OnClick", function() Select(def.key) end)
        d.cells[i] = b
    end

    local function MakeButton(text, w)
        local b = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
        b:SetSize(w, 22)
        b:SetText(text)
        return b
    end
    d.save = MakeButton(SAVE or "Save", 100)
    d.save:SetScript("OnClick", function()
        local isNew = ns.db.grouped[d.guid] == nil
        SaveAlly(d.guid, d.name, d.edit:GetText(), d.icon)
        ns.Print((isNew and L["%s marked as an ally."] or L["%s: ally saved."]):format(d.name or "?"))
        d:Hide()
    end)
    d.cancel = MakeButton(CANCEL or "Cancel", 100)
    d.cancel:SetPoint("BOTTOMRIGHT", -18, 18)
    d.cancel:SetScript("OnClick", function() d:Hide() end)
    d.remove = MakeButton(REMOVE or "Remove", 90)
    d.remove:SetPoint("BOTTOMLEFT", 18, 18)
    d.remove:SetScript("OnClick", function()
        RemoveAlly(d.guid, d.name)
        d:Hide()
    end)
    d.save:SetPoint("RIGHT", d.cancel, "LEFT", -6, 0)
    eb:SetScript("OnEnterPressed", function() d.save:Click() end)
    return d
end

function ns.EditAlly(guid, name)
    if not (guid and ns.db) then return end
    dialog = dialog or BuildDialog()
    local rec = ns.db.grouped[guid]
    dialog.guid, dialog.name = guid, name or (rec and rec[1]) or "?"
    dialog.title:SetText(dialog.name)
    dialog.edit:SetText(rec and rec.note or "")
    dialog.Select(rec and rec.icon or "default")
    dialog.remove:SetShown(rec ~= nil)
    dialog:Show()
    dialog.edit:SetFocus()
    dialog.edit:HighlightText()
end

--------------------------------------------------------------------------------
-- Right-click menus of unit frames and names in chat
--------------------------------------------------------------------------------

-- The menus are Blizzard's (opened securely by the game or a UI suite); entries reach them through
-- Menu.ModifyMenu only and run nothing but this addon's own code, so the menu's own items stay secure.
local MENU_TAGS = {
    "MENU_UNIT_PLAYER", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_RAID", "MENU_UNIT_TARGET",
    "MENU_UNIT_FOCUS", "MENU_UNIT_FRIEND", "MENU_UNIT_ENEMY_PLAYER", "MENU_UNIT_CHAT_ROSTER", "MENU_UNIT_GUILD",
    "MENU_UNIT_COMMUNITIES_GUILD_MEMBER", "MENU_UNIT_COMMUNITIES_WOW_MEMBER",
}

-- guid and name of the player a menu is for; nil for yourself, NPCs and anything unreadable
local function ContextPlayer(cd)
    if type(cd) ~= "table" then return end
    local guid, name
    local unit = Plain(cd.unit)
    if type(unit) == "string" then
        if not Plain(UnitIsPlayer(unit)) or Plain(UnitIsUnit(unit, "player")) then return end
        guid, name = Plain(UnitGUID(unit)), Plain(GetUnitName(unit, true))
    end
    if not guid then guid = Plain(cd.guid) end
    local loc = cd.playerLocation
    if not guid and type(loc) == "table" and loc.GetGUID then
        local ok, g = pcall(loc.GetGUID, loc)
        if ok then guid = Plain(g) end
    end
    if not guid and cd.lineID and C_ChatInfo and C_ChatInfo.GetChatLineSenderGUID then
        local ok, g = pcall(C_ChatInfo.GetChatLineSenderGUID, cd.lineID)
        if ok then guid = Plain(g) end
    end
    if type(guid) ~= "string" or not guid:find("^Player%-") or guid == Plain(UnitGUID("player")) then return end
    if not name then
        name = Plain(cd.name)
        local server = Plain(cd.server)
        if type(name) == "string" and type(server) == "string" and server ~= "" and not name:find("-", 1, true) then
            name = name .. "-" .. server
        end
    end
    local rec = ns.db.grouped[guid]
    if type(name) ~= "string" or name == "" then name = rec and rec[1] or "?" end
    return guid, name
end

local function AddMenuEntries(_, menu, cd)
    if not (ns.db and ns.db.allies.enabled and ns.db.allies.memory) then return end
    local guid, name = ContextPlayer(cd)
    ns.Log("ally menu: which %s, unit %s, line %s, player %s", type(cd) == "table" and cd.which, type(cd) == "table" and cd.unit,
        type(cd) == "table" and cd.lineID, guid and name or "none")
    if not guid then return end
    if menu.CreateDivider then menu:CreateDivider() end
    if menu.CreateTitle then menu:CreateTitle("|cff7fd4ffForever|rAlly") end
    if ns.db.grouped[guid] then
        menu:CreateButton(L["Ally note and icon..."], function() ns.EditAlly(guid, name) end)
        menu:CreateButton(L["Remove from allies"], function() RemoveAlly(guid, name) end)
    else
        menu:CreateButton(L["Add to allies..."], function() ns.EditAlly(guid, name) end)
    end
end

ns.AfterLoad(function()
    if not (Menu and Menu.ModifyMenu) then return end
    for _, tag in ipairs(MENU_TAGS) do pcall(Menu.ModifyMenu, tag, AddMenuEntries) end
end)

--------------------------------------------------------------------------------
-- Clearing, counting, slash commands
--------------------------------------------------------------------------------

-- (players you added by hand or gave a note or an icon are kept: remove them one by one)
function ns.ClearAllies()
    for guid, rec in pairs(ns.db.grouped) do
        if not (type(rec) == "table" and (rec.note or rec.icon or rec.manual)) then ns.db.grouped[guid] = nil end
    end
    ns.RefreshAll()
end

function ns.AllyCount()
    local n = 0
    for _ in pairs(ns.db.grouped) do n = n + 1 end
    return n
end

SLASH_FOREVERALLYMARK1 = "/ally"
SlashCmdList.FOREVERALLYMARK = function(msg)
    local cmd, rest = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if cmd == "add" or cmd == "del" or cmd == "note" or cmd == "edit" then
        local guid = PlayerGUID("target")
        if not guid then ns.Print(L["Target a player first."]) return end
        local name = Plain(GetUnitName("target", true)) or "?"
        if cmd == "edit" then ns.EditAlly(guid, name) return end
        if cmd == "del" then RemoveAlly(guid, name) return end
        local isNew = ns.db.grouped[guid] == nil
        SaveAlly(guid, name, (cmd == "note" or rest ~= "") and rest or nil)
        ns.Print((isNew and L["%s marked as an ally."] or L["%s: ally saved."]):format(name))
        return
    end
    local guid = PlayerGUID("target")
    if guid then
        local okF, friend = pcall(C_FriendList.IsFriend, guid)
        local okB, bnet = pcall(C_BattleNet.GetAccountInfoByGUID, guid)
        local function yn(v) return v and L["yes"] or L["no"] end
        ns.Print(L["%s: in the game's list %s, in memory %s, friend %s, Battle.net friend %s"]:format(
            Plain(GetUnitName("target", true)) or "?", yn(InGameList(guid)), yn(ns.db.grouped[guid] ~= nil),
            yn(okF and Plain(friend) == true), yn(okB and bnet ~= nil)))
    end
    ns.Print(L["Allies remembered: %d. Right-click a player's frame to add an ally with a note and an icon; for your target: /ally add [note], /ally note <text>, /ally edit, /ally del."]:format(ns.AllyCount()))
end
