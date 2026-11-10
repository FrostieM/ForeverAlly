-- ForeverAlly: the recent-ally mark. A player you have been in a group with gets an icon in front
-- of the name on their nameplate and a line in their tooltip. Two sources: the game's own Recent
-- Allies list (C_RecentAllies) and the addon's memory of everyone seen in your group (the game's
-- list leaves some players out, friends among them). /ally add | del marks or unmarks your target.
local _, ns = ...
local L, Plain = ns.L, ns.Plain

local ATLAS = "friendslist-recentallies-yellow"
local marks = {} -- plate -> texture

local function InGameList(guid)
    if not (ns.db.allies.blizzardList and C_RecentAllies and C_RecentAllies.IsRecentAllyByGUID) then return false end
    local ok, res = pcall(C_RecentAllies.IsRecentAllyByGUID, guid)
    return ok and Plain(res) == true
end

local function PlayerGUID(unit)
    if not unit or not Plain(UnitIsPlayer(unit)) or Plain(UnitIsUnit(unit, "player")) then return end
    return Plain(UnitGUID(unit))
end

local function IsAlly(unit)
    local guid = PlayerGUID(unit)
    if not guid then return false end
    return (ns.db.allies.memory and ns.db.grouped[guid] ~= nil) or InGameList(guid)
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
        if guid then grouped[guid] = { Plain(GetUnitName(unit, true)) or "?", now } end
    end
end

local function Hide(plate)
    if marks[plate] then marks[plate]:Hide() end
end

local function Update(unit, plate)
    local a = ns.db.allies
    if not (a.enabled and IsAlly(unit)) then Hide(plate) return end
    local t = marks[plate]
    if not t then
        t = plate:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetAtlas(ATLAS)
        marks[plate] = t
    end
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

-- tooltip line
ns.AfterLoad(function()
    if not (TooltipDataProcessor and Enum.TooltipDataType) then return end
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt)
        if tt ~= GameTooltip or not tt.GetUnit or not ns.db.allies.tooltip or not ns.db.allies.enabled then return end
        local _, unit = tt:GetUnit()
        unit = Plain(unit)
        if unit and IsAlly(unit) then
            tt:AddLine(CreateAtlasMarkup(ATLAS, 14, 14) .. " " .. L["Grouped with you before"], 1, 0.82, 0)
        end
    end)
end)

function ns.ClearAllies()
    wipe(ns.db.grouped)
    ns.RefreshAll()
end

function ns.AllyCount()
    local n = 0
    for _ in pairs(ns.db.grouped) do n = n + 1 end
    return n
end

SLASH_FOREVERALLYMARK1 = "/ally"
SlashCmdList.FOREVERALLYMARK = function(msg)
    msg = strtrim((msg or ""):lower())
    if msg == "add" or msg == "del" then
        local guid = PlayerGUID("target")
        if not guid then ns.Print(L["Target a player first."]) return end
        local name = Plain(GetUnitName("target", true)) or "?"
        ns.db.grouped[guid] = msg == "add" and { name, time() } or nil
        ns.Print((msg == "add" and L["%s marked as an ally."] or L["%s removed from the ally memory (the game's own list is not changed)."]):format(name))
        ns.RefreshAll()
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
    ns.Print(L["Allies remembered: %d. /ally add - mark your target, /ally del - unmark it."]:format(ns.AllyCount()))
end
