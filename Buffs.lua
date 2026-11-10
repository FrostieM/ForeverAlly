-- ForeverAlly: which of your class buffs a player lacks, and the icons for them on nameplates.
--  * Class buffs (Fortitude, Divine Spirit, Mark of the Wild, Arcane Intellect) count from anyone:
--    another priest's Fortitude is as good as yours.
--  * Paladin blessings: one blessing of yours per player, and blessings of different kinds from
--    different paladins stack. With none of yours on a player, the first blessing of the role's
--    order (options) that the player lacks is the one to give.
--  * A buff with less than renewPct of its time left counts as missing (to be renewed).
--  * Forever does not say who cast an aura on another player (sourceUnit is empty), so the
--    blessings you cast with the auto-buff macro are remembered (ns.myBlessings, 5 minutes).
--  * Shown only out of combat; not for dead / offline / unassistable players, nor PvP-flagged ones
--    while you are not flagged (option). Auras that come back secret: no icon rather than a wrong one.
local _, ns = ...
local L, Plain = ns.L, ns.Plain

local MANA_USERS = { DRUID = true, HUNTER = true, MAGE = true, PALADIN = true, PRIEST = true, SHAMAN = true, WARLOCK = true }
ns.MANA_USERS = MANA_USERS

-- names = the spells whose aura counts (every rank shares the name; the group version too); the
-- first one is the spell you must know. manaOnly: only for mana users when that option is on.
-- optional: off until switched on in the options (buffs given when needed, not to everyone).
-- tankOnly: only for rage users (warriors, druids in bear form) while that option is on.
-- When a family has different spell names (Detect Lesser / Detect / Greater Invisibility), the
-- best one comes first: the first one you know is the one cast.
local BUFFS = {
    PRIEST = {
        { names = { 1243, 21562 } },                     -- Power Word: Fortitude / Prayer of Fortitude
        { names = { 14752, 27681 }, manaOnly = true },   -- Divine Spirit / Prayer of Spirit
        { names = { 976, 27683 }, optional = true },     -- Shadow Protection / Prayer of Shadow Protection
    },
    DRUID = {
        { names = { 1126, 21849 } },                     -- Mark of the Wild / Gift of the Wild
        { names = { 467 }, optional = true, tankOnly = true }, -- Thorns
    },
    MAGE = {
        { names = { 1459, 23028 }, manaOnly = true },    -- Arcane Intellect / Arcane Brilliance
    },
    WARLOCK = {
        { names = { 5697 }, optional = true },           -- Unending Breath
        { names = { 11743, 2970, 132 }, optional = true }, -- Detect Greater / Detect / Detect Lesser Invisibility
    },
}
-- Paladin blessings: the ordinary one first (the spell you must know), then the Greater one.
local BLESSINGS = {
    might = { 19740, 25782 }, wisdom = { 19742, 25894 }, kings = { 20217, 25898 },
    salvation = { 1038, 25895 }, light = { 19977, 25890 }, sanctuary = { 20911, 25899 },
}
ns.BLESSING_KEYS = { "might", "wisdom", "kings", "salvation", "light", "sanctuary" }
ns.BLESSING_IDS = BLESSINGS
ns.CLASS_BUFFS = BUFFS

local _, playerClass = UnitClass("player")
ns.playerClass = playerClass
local active = {}        -- class buffs you know: { names, icon, spell, id, key, manaOnly }
local blessings = {}     -- blessings you know: key -> { names, icon, spell, id, key = rank-1 id, kind }
local blessingNames = {} -- every blessing name -> its kind (might, wisdom ...)
ns.active, ns.blessings, ns.blessingNames = active, blessings, blessingNames

local function Known(id)
    local name = C_Spell.GetSpellName(id)
    local info = name and C_Spell.GetSpellInfo(name) -- by name: the highest rank in your spellbook
    return info and C_SpellBook.IsSpellKnown(info.spellID) and info.spellID
end

function ns.BuildActive()
    wipe(active)
    for _, buff in ipairs(BUFFS[playerClass] or {}) do
        local icon, knownID
        for _, id in ipairs(buff.names) do
            local known = Known(id)
            if known then icon, knownID = C_Spell.GetSpellTexture(known), known; break end
        end
        if icon then
            local names = {}
            for _, id in ipairs(buff.names) do
                local n = C_Spell.GetSpellName(id)
                if n then names[#names + 1] = n end
            end
            active[#active + 1] = { names = names, icon = icon, spell = C_Spell.GetSpellName(knownID) or names[1],
                id = knownID, key = buff.names[1], manaOnly = buff.manaOnly, optional = buff.optional, tankOnly = buff.tankOnly }
        end
    end
    wipe(blessings)
    wipe(blessingNames)
    if playerClass ~= "PALADIN" then return end
    for kind, ids in pairs(BLESSINGS) do
        local names = {}
        for _, id in ipairs(ids) do
            local n = C_Spell.GetSpellName(id)
            if n then names[#names + 1] = n; blessingNames[n] = kind end
        end
        local known = Known(ids[1])
        if known then
            blessings[kind] = { names = names, icon = C_Spell.GetSpellTexture(known), spell = names[1],
                id = known, key = ids[1], kind = kind }
        end
    end
end

function ns.HasBuffs()
    return #active > 0 or next(blessings) ~= nil
end

-- One pass over the unit's buffs: names on it (anyone's), the ones you cast, the ones running low.
-- nil when anything comes back unreadable.
function ns.Scan(unit)
    local present, mine, low = {}, {}, {}
    local now, renew = GetTime(), (ns.db.buffs.renewPct or 30) / 100
    for i = 1, 80 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
        if not ok then return nil end
        if aura == nil then break end
        if issecretvalue and issecretvalue(aura) then return nil end
        local name = Plain(aura.name)
        if not name then return nil end
        present[name] = true
        local src = Plain(aura.sourceUnit)
        if src and Plain(UnitIsUnit(src, "player")) then mine[name] = true end
        local exp, dur = Plain(aura.expirationTime), Plain(aura.duration)
        if exp and dur and exp > 0 and dur > 0 and (exp - now) / dur < renew then low[name] = true end
    end
    return present, mine, low
end
local Scan = ns.Scan

-- missing: none of these names is on the unit with more than the renew share of its time left
local function Missing(present, names, low)
    for _, n in ipairs(names) do if present[n] and not (low and low[n]) then return false end end
    return true
end

local BLESSING_TIME = 300
ns.myBlessings = {} -- guid -> { name, untilT }
function ns.RememberBlessing(guid, name)
    local now = GetTime()
    for g, r in pairs(ns.myBlessings) do if r.untilT <= now then ns.myBlessings[g] = nil end end
    ns.myBlessings[guid] = { name = name, untilT = now + BLESSING_TIME }
end

local function BestBlessing(unit, present, mine, low)
    local off = ns.db.buffs.off
    -- yours is already on them: nothing, or the same one again when it is running out
    for n in pairs(mine) do
        local kind = blessingNames[n]
        if kind then
            if low[n] and not off[kind] then return blessings[kind] end
            return
        end
    end
    local guid = Plain(UnitGUID(unit))
    local rec = guid and ns.myBlessings[guid]
    if rec and present[rec.name] and (rec.untilT > GetTime() or low[rec.name]) then
        local kind = blessingNames[rec.name]
        if low[rec.name] and kind and not off[kind] then return blessings[kind] end
        return
    end
    local power = Plain(UnitPowerType(unit))
    -- yourself: your own order (a paladin is on mana, but a Retribution one fights like a warrior)
    local order = Plain(UnitIsUnit(unit, "player")) and ns.db.blessings.self
        or (power == 0) and ns.db.blessings.mana or ns.db.blessings.physical
    for _, kind in ipairs(order) do
        local b = blessings[kind]
        local rageSalv = kind == "salvation" and power == 1 and ns.db.blessings.noSalvationForRage
        -- another paladin's blessing that is running out counts as missing too
        if b and not off[kind] and not rageSalv and Missing(present, b.names, low) then return b end
    end
end

-- the buffs this unit lacks: { buff, ... } (class buffs, then the blessing), nil when unreadable
function ns.Needs(unit)
    local present, mine, low = Scan(unit)
    if not present then return end
    local _, class = UnitClass(unit)
    class = Plain(class)
    local list, off, manaOnly = {}, ns.db.buffs.off, ns.db.buffs.manaOnly
    local optIn, tanksOnly = ns.db.buffs.optIn, ns.db.buffs.thornsTanksOnly
    local power
    for _, buff in ipairs(active) do
        local forClass = not (buff.manaOnly and manaOnly) or (class and MANA_USERS[class])
        local wanted = (buff.optional and optIn[buff.key]) or (not buff.optional and not off[buff.key])
        if wanted and buff.tankOnly and tanksOnly then
            power = power or Plain(UnitPowerType(unit))
            wanted = power == 1
        end
        if wanted and forClass and Missing(present, buff.names, low) then list[#list + 1] = buff end
    end
    if next(blessings) then list[#list + 1] = BestBlessing(unit, present, mine, low) end
    return list
end

function ns.Wanted(unit, allowSelf)
    if not Plain(UnitIsPlayer(unit)) then return end
    if Plain(UnitIsUnit(unit, "player")) and not allowSelf then return end
    if not Plain(UnitCanAssist("player", unit)) then return end
    if Plain(UnitIsDeadOrGhost(unit)) or Plain(UnitIsConnected(unit)) == false then return end
    if ns.db.buffs.skipPvP and Plain(UnitIsPVP(unit)) and not Plain(UnitIsPVP("player")) then return end
    return true
end

--------------------------------------------------------------------------------
-- Icons
--------------------------------------------------------------------------------

local rows = {} -- plate -> { textures }

local function Hide(plate)
    local row = rows[plate]
    if row then for _, t in ipairs(row) do t:Hide() end end
end

local function Update(unit, plate)
    local b = ns.db.buffs
    if not b.enabled or not ns.HasBuffs() or InCombatLockdown() or not ns.Wanted(unit) then Hide(plate) return end
    local needs = ns.Needs(unit)
    if not needs then Hide(plate) return end
    local row = rows[plate]
    local count = 0
    for _, need in ipairs(needs) do
        count = count + 1
        if not row then row = {}; rows[plate] = row end
        local t = row[count]
        if not t then
            t = plate:CreateTexture(nil, "OVERLAY", nil, 7)
            t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            row[count] = t
        end
        t:SetSize(b.size, b.size)
        t:SetTexture(need.icon)
        t:Show()
    end
    if row then for i = count + 1, #row do row[i]:Hide() end end
    if count == 0 then return end
    ns.PlaceRow(plate, row, count, b.size, "right")
    C_Timer.After(0.1, function()
        if rows[plate] == row and row[1]:IsShown() then ns.PlaceRow(plate, row, count, b.size, "right") end
    end)
end

table.insert(ns.parts, { Update = Update, Hide = Hide })

ns.On("PLAYER_ENTERING_WORLD", function() ns.BuildActive(); ns.RefreshAll() end)
ns.On("SPELLS_CHANGED", function() ns.BuildActive(); ns.RefreshAll() end)
ns.On("PLAYER_REGEN_DISABLED", function() ns.RefreshAll() end)
ns.On("PLAYER_REGEN_ENABLED", function() ns.RefreshAll() end)
ns.On("UNIT_AURA", function(_, unit)
    if unit and unit ~= "player" and unit:find("^nameplate") then ns.UpdateUnit(unit) end
end)
ns.On("UNIT_FLAGS", function(_, unit)
    if unit == "player" then ns.RefreshAll() elseif unit and unit:find("^nameplate") then ns.UpdateUnit(unit) end
end)

-- buffs run low with time, not only on aura changes: the icons are redrawn every few seconds
local wait = 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    wait = 3
    if ns.db and ns.db.buffs.enabled and ns.HasBuffs() and not InCombatLockdown() then ns.RefreshAll() end
end)
