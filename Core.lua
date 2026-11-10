-- ForeverAlly: shared core. Settings, the log, secret-value helpers and one nameplate loop that
-- the parts (Allies.lua: the recent-ally icon, Buffs.lua: the missing-buff icons) draw through.
--
-- Facts about the WoW: Forever client this is built on (found in game, see CHANGELOG.md):
--  * C_NamePlate.GetNamePlates() leaves friendly plates out: the nameplate1..60 tokens are walked.
--  * Friendly names, levels and auras can come back as "secret" values in some situations: every
--    read goes through Plain(), and a secret answer means "can't tell" (draw nothing).
local addonName, ns = ...
local L = ns.L

ns.TAG = "|cff7fd4ffForeverAlly:|r "

function ns.Plain(v)
    if v ~= nil and not (issecretvalue and issecretvalue(v)) then return v end
end
local Plain = ns.Plain

function ns.Print(msg) print(ns.TAG .. msg) end

--------------------------------------------------------------------------------
-- Settings (account-wide: ForeverAllyDB)
--------------------------------------------------------------------------------

local DEFAULTS = {
    allies = { enabled = true, size = 14, memory = true, blizzardList = true, tooltip = true },
    grouped = {},                 -- guid -> { name, last time seen in your group }
    buffs = { enabled = true, size = 14, renewPct = 30, skipPvP = true, manaOnly = true, off = {},
        optIn = {},                -- optional buffs switched on (they start off)
        thornsTanksOnly = true },
    blessings = {
        self = { "kings", "might", "wisdom", "salvation", "light", "sanctuary" }, -- on yourself
        mana = { "wisdom", "kings", "salvation", "might", "light", "sanctuary" },
        physical = { "might", "kings", "salvation", "light", "sanctuary", "wisdom" },
        noSalvationForRage = true,
    },
    auto = { enabled = true, self = true, group = true, others = true, ranks = true, message = true, skipSec = 8 },
    debug = false,
    log = {},
}
ns.DEFAULTS = DEFAULTS

local function Fill(db, defaults)
    for k, v in pairs(defaults) do
        if db[k] == nil then
            if type(v) == "table" then
                local copy = {}
                Fill(copy, v)
                db[k] = copy
            else
                db[k] = v
            end
        elseif type(v) == "table" and type(db[k]) == "table" and #v == 0 then
            Fill(db[k], v) -- (a keyed table: fill missing keys; an ordered list is kept as saved)
        end
    end
end

local function OrderComplete(list, defaults)
    -- a saved blessing order missing a kind (an older save) gets it appended
    local seen = {}
    for _, k in ipairs(list) do seen[k] = true end
    for _, k in ipairs(defaults) do if not seen[k] then list[#list + 1] = k end end
end

local function LoadDB()
    if type(ForeverAllyDB) ~= "table" then ForeverAllyDB = {} end
    local db = ForeverAllyDB
    Fill(db, DEFAULTS)
    OrderComplete(db.blessings.self, DEFAULTS.blessings.self)
    OrderComplete(db.blessings.mana, DEFAULTS.blessings.mana)
    OrderComplete(db.blessings.physical, DEFAULTS.blessings.physical)
    -- the two addons this one replaces: their ally memory comes along
    local old = _G.ForeverRecentAllyMarkDB
    if type(old) == "table" and type(old.grouped) == "table" and not db.importedRecentAllyMark then
        for guid, rec in pairs(old.grouped) do
            if db.grouped[guid] == nil then db.grouped[guid] = rec end
        end
        db.importedRecentAllyMark = true
    end
    ns.db = db
end

--------------------------------------------------------------------------------
-- Log (off unless switched on: /fally log on, or the options)
--------------------------------------------------------------------------------

local LOG_MAX = 400
function ns.Log(fmt, ...)
    local db = ns.db
    if not (db and db.debug) then return end
    local args = { ... }
    for i = 1, 12 do -- (a trailing call that returns nothing passes fewer values than the %s slots)
        local v = args[i]
        args[i] = (issecretvalue and issecretvalue(v)) and "<secret>" or tostring(v)
    end
    local ok, msg = pcall(string.format, fmt, unpack(args, 1, 12))
    local log = db.log
    log[#log + 1] = date("%m-%d %H:%M:%S") .. " " .. (ok and msg or fmt)
    while #log > LOG_MAX do table.remove(log, 1) end
end

--------------------------------------------------------------------------------
-- Nameplates
--------------------------------------------------------------------------------

function ns.GetPlate(unit)
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok and plate and not (plate.IsForbidden and plate:IsForbidden()) then return plate end
end

function ns.PlateUnits()
    local out = {}
    for i = 1, 60 do
        local unit = "nameplate" .. i
        if Plain(UnitExists(unit)) then out[#out + 1] = unit end
    end
    return out
end

-- Places `count` textures of `size` beside the name text on a plate: side "left" grows leftwards
-- from the start of the name, "right" rightwards from its end. Without a visible name (another
-- nameplate addon), above the plate.
function ns.PlaceRow(plate, row, count, size, side)
    local GAP = 2
    local uf = plate.UnitFrame
    if type(uf) ~= "table" then uf = nil end
    local name = uf and uf.name
    if type(name) ~= "table" then name = nil end
    local useName = name and uf:IsShown() and name:IsShown()
    local w = useName and Plain(name:GetStringWidth())
    local dir = side == "left" and -1 or 1
    for i = 1, count do
        local t = row[i]
        t:ClearAllPoints()
        local step = (i - 1) * (size + GAP)
        if useName and w and w > 0 then
            -- (the name string may be wider than its text: measured from the centre)
            t:SetPoint("CENTER", name, "CENTER", dir * (w / 2 + GAP + size / 2 + step), 0)
        elseif useName then
            if side == "left" then t:SetPoint("RIGHT", name, "LEFT", -(GAP + step), 0)
            else t:SetPoint("LEFT", name, "RIGHT", GAP + step, 0) end
        else
            t:SetPoint("BOTTOM", plate, "TOP", dir * (size / 2 + step), 2)
        end
    end
end

ns.parts = {} -- { Update(unit, plate), Hide(plate) }

function ns.UpdateUnit(unit)
    if not ns.db then return end
    local plate = ns.GetPlate(unit)
    if not plate then return end
    for _, part in ipairs(ns.parts) do part.Update(unit, plate) end
end

function ns.RefreshAll()
    if not ns.db then return end
    for _, unit in ipairs(ns.PlateUnits()) do ns.UpdateUnit(unit) end
end

local events = CreateFrame("Frame")
ns.events = events
local handlers = {}
function ns.On(event, fn, unitFilter)
    if not handlers[event] then
        handlers[event] = {}
        if unitFilter then events:RegisterUnitEvent(event, unitFilter) else events:RegisterEvent(event) end
    end
    table.insert(handlers[event], fn)
end
events:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event] or {}) do fn(event, ...) end
end)

ns.On("ADDON_LOADED", function(_, name)
    if name ~= addonName then return end
    LoadDB()
    if ns.OnLoad then for _, fn in ipairs(ns.OnLoad) do fn() end end
end)
ns.On("NAME_PLATE_UNIT_ADDED", function(_, unit) ns.UpdateUnit(unit) end)
ns.On("NAME_PLATE_UNIT_REMOVED", function(_, unit)
    if not ns.db then return end
    local plate = ns.GetPlate(unit)
    if plate then for _, part in ipairs(ns.parts) do part.Hide(plate) end end
end)

function ns.AfterLoad(fn)
    ns.OnLoad = ns.OnLoad or {}
    table.insert(ns.OnLoad, fn)
end

--------------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------------

SLASH_FOREVERALLY1 = "/fally"
SLASH_FOREVERALLY2 = "/foreverally"
SlashCmdList.FOREVERALLY = function(msg)
    msg = strtrim((msg or ""):lower())
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    if cmd == "" then
        if ns.OpenOptions then ns.OpenOptions() end
    elseif cmd == "log" then
        if arg == "on" then ns.db.debug = true; ns.Print(L["Log is on."])
        elseif arg == "off" then ns.db.debug = false; ns.Print(L["Log is off."])
        elseif arg == "clear" then ns.db.log = {}; ns.Print(L["Log cleared."])
        else
            local log = ns.db.log
            for i = math.max(1, #log - 15), #log do print(log[i]) end
        end
    elseif cmd == "status" then
        if ns.Status then ns.Status() end
    else
        ns.Print(L["Commands: /fally - options, /fally status - about your target, /fally log on|off|show|clear, /ally add|del"])
    end
end
