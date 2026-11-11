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
--    outside your group while you are not flagged (option). Auras that come back secret: no icon rather than a wrong one.
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

-- "A more powerful spell is already active": someone else's stronger rank of that buff is on the
-- player (running low, so it looked missing). It can't be overwritten: for a while that buff is
-- not offered to them, and a blessing moves on to the next kind in the order.
local BOUNCE_TIME = 120
ns.bounced = {} -- guid -> { [spell name] = untilT }
function ns.Bounce(guid, spell, secs)
    local now = GetTime()
    for g, t in pairs(ns.bounced) do
        local any
        for n, u in pairs(t) do if u <= now then t[n] = nil else any = true end end
        if not any then ns.bounced[g] = nil end
    end
    ns.bounced[guid] = ns.bounced[guid] or {}
    ns.bounced[guid][spell] = now + (secs or BOUNCE_TIME)
end
local function Bounced(guid, spell)
    local t = guid and ns.bounced[guid]
    return t and spell and (t[spell] or 0) > GetTime() or false
end
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
    local guid = ns.UnitKey(unit)
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
        if b and not off[kind] and not rageSalv and not Bounced(guid, b.spell) and Missing(present, b.names, low) then return b end
    end
end

-- Blind mode. In a battleground the client hides every player's buffs from addons (yours too), so
-- for you and your group the addon goes by its own casts instead: what it cast on whom and when
-- (any cast that landed). A buff is given again when, by that clock, it is running low (renewPct),
-- or once the player was seen dead. Someone else's buff on them is not known: a cast that bounces
-- ("a more powerful spell") moves on as usual.
local BLIND_TIME = { -- seconds a buff lasts, by its key (rank 1 id); blessings: BLESSING_TIME
    [1243] = 1800, [14752] = 1800, [976] = 600, [1126] = 1800, [467] = 600, [1459] = 1800,
    [5697] = 600, [11743] = 600,
}
ns.casts = {} -- key (GUID, or "unit:raidN" when hidden) -> { [spell name] = time cast }
function ns.RememberCast(key, name)
    if not (key and name) then return end
    ns.casts[key] = ns.casts[key] or {}
    ns.casts[key][name] = GetTime()
end
-- dead (buffs gone), or the group changed (a hidden-GUID key is a raid slot, which may now be someone else)
function ns.ForgetCasts(key)
    if key then ns.casts[key] = nil; ns.myBlessings[key] = nil end
end
function ns.ForgetSlotCasts()
    for key in pairs(ns.casts) do if key:find("^unit:") then ns.casts[key] = nil end end
    for key in pairs(ns.myBlessings) do if key:find("^unit:") then ns.myBlessings[key] = nil end end
end
local function BlindLow(key, name, dur)
    local t = ns.casts[key] and ns.casts[key][name]
    if not t then return true end
    return GetTime() - t > dur * (1 - (ns.db.buffs.renewPct or 30) / 100)
end

local function BlindNeeds(unit, key)
    local _, class = UnitClass(unit)
    class = Plain(class)
    local power = Plain(UnitPowerType(unit))
    local list, off, manaOnly = {}, ns.db.buffs.off, ns.db.buffs.manaOnly
    local optIn, tanksOnly = ns.db.buffs.optIn, ns.db.buffs.thornsTanksOnly
    for _, buff in ipairs(active) do
        local forClass = not (buff.manaOnly and manaOnly) or (class and MANA_USERS[class]) or (not class and power == 0)
        local wanted = (buff.optional and optIn[buff.key]) or (not buff.optional and not off[buff.key])
        if wanted and buff.tankOnly and tanksOnly then wanted = power == 1 end
        if wanted and forClass and not Bounced(key, buff.spell) and BlindLow(key, buff.spell, BLIND_TIME[buff.key] or 1800) then
            list[#list + 1] = buff
        end
    end
    if next(blessings) then
        local rec = ns.myBlessings[key]
        local kind = rec and rec.untilT > GetTime() and blessingNames[rec.name]
        if kind then
            -- ours is on them: the same one again when it is running low
            if not off[kind] and blessings[kind] and not Bounced(key, rec.name)
                and BlindLow(key, rec.name, BLESSING_TIME) then list[#list + 1] = blessings[kind] end
        else
            local order = Plain(UnitIsUnit(unit, "player")) and ns.db.blessings.self
                or (power == 0) and ns.db.blessings.mana or ns.db.blessings.physical
            for _, k in ipairs(order) do
                local b = blessings[k]
                local rageSalv = k == "salvation" and power == 1 and ns.db.blessings.noSalvationForRage
                if b and not off[k] and not rageSalv and not Bounced(key, b.spell) then list[#list + 1] = b break end
            end
        end
    end
    return list
end

-- the buffs this unit lacks: { buff, ... } (class buffs, then the blessing), nil when unreadable;
-- for you and your group, when unreadable, by the addon's own casts (blind: second value true)
function ns.Needs(unit)
    local present, mine, low = Scan(unit)
    if not present then
        if unit ~= "player" and not ns.GroupToken(unit) then return end
        local key = ns.UnitKey(unit)
        if not key then return end
        return BlindNeeds(unit, key), true
    end
    local _, class = UnitClass(unit)
    class = Plain(class)
    local list, off, manaOnly = {}, ns.db.buffs.off, ns.db.buffs.manaOnly
    local optIn, tanksOnly = ns.db.buffs.optIn, ns.db.buffs.thornsTanksOnly
    local power
    local guid = ns.UnitKey(unit)
    for _, buff in ipairs(active) do
        local forClass = not (buff.manaOnly and manaOnly) or (class and MANA_USERS[class])
        local wanted = (buff.optional and optIn[buff.key]) or (not buff.optional and not off[buff.key])
        if wanted and buff.tankOnly and tanksOnly then
            power = power or Plain(UnitPowerType(unit))
            wanted = power == 1
        end
        if wanted and forClass and not Bounced(guid, buff.spell) and Missing(present, buff.names, low) then list[#list + 1] = buff end
    end
    if next(blessings) then list[#list + 1] = BestBlessing(unit, present, mine, low) end
    return list
end

-- for the debug log: why this buff: class, which blessing order, and the buffs of yours (any caster)
-- already on the player ("low" = under the renew share, counts as missing)
function ns.Describe(unit)
    local _, class = UnitClass(unit)
    local power = Plain(UnitPowerType(unit))
    local order = Plain(UnitIsUnit(unit, "player")) and "self" or (power == 0) and "mana" or "physical"
    local ours = {}
    for _, b in ipairs(active) do for _, n in ipairs(b.names) do ours[n] = true end end
    local present, _, low = Scan(unit)
    local has = {}
    if present then
        for n in pairs(present) do
            if ours[n] or blessingNames[n] then has[#has + 1] = n .. (low[n] and " (low)" or "") end
        end
        table.sort(has)
    end
    local guid = ns.UnitKey(unit)
    local rec = guid and ns.myBlessings[guid]
    local extra = (rec and rec.untilT > GetTime()) and ("; mine: " .. rec.name) or ""
    local b = guid and ns.bounced[guid]
    if b then
        local now, list = GetTime(), {}
        for n, u in pairs(b) do if u > now then list[#list + 1] = n end end
        if #list > 0 then extra = extra .. "; stronger on them: " .. table.concat(list, ", ") end
    end
    if not present and guid and ns.casts[guid] then
        local now, list = GetTime(), {}
        for n, t in pairs(ns.casts[guid]) do list[#list + 1] = ("%s %ds ago"):format(n, math.floor(now - t)) end
        table.sort(list)
        extra = extra .. "; cast by you: " .. table.concat(list, ", ")
    end
    return ("%s, %s order; has: %s%s"):format(Plain(class) or "?", order,
        present and (#has > 0 and table.concat(has, ", ") or "none") or "hidden (blind: by your casts)", extra)
end

-- a value the client hides from addons (battlegrounds and other restricted places)
local function Secret(v) return v ~= nil and issecretvalue and issecretvalue(v) or false end
ns.Secret = Secret
local function GroupToken(unit) return unit:find("^party%d") or unit:find("^raid%d") end
ns.GroupToken = GroupToken

-- the key a player is remembered by: the GUID, or for a group member whose GUID is hidden, the unit
function ns.UnitKey(unit)
    local guid = Plain(UnitGUID(unit))
    if guid then return guid end
    if GroupToken(unit) then return "unit:" .. unit end
end

-- true, or nil and why not. A party / raid member is not ruled out by a check the client answers
-- with a hidden value (the cast itself carries help,nodead).
function ns.Wanted(unit, allowSelf)
    local group = GroupToken(unit)
    local isPlayer = UnitIsPlayer(unit)
    if not Plain(isPlayer) and not (group and Secret(isPlayer)) then
        return nil, Secret(isPlayer) and "player? hidden" or "not a player"
    end
    if Plain(UnitIsUnit(unit, "player")) and not allowSelf then return nil, "you" end
    local assist = UnitCanAssist("player", unit)
    if not Plain(assist) and not (group and Secret(assist)) then
        return nil, Secret(assist) and "can assist? hidden" or "can't assist"
    end
    if Plain(UnitIsDeadOrGhost(unit)) then return nil, "dead" end
    if Plain(UnitIsConnected(unit)) == false then return nil, "offline" end
    -- (your group is buffed anyway: you are with them, and it is what you want)
    if ns.db.buffs.skipPvP and Plain(UnitIsPVP(unit)) and not Plain(UnitIsPVP("player"))
        and not (group or Plain(UnitInParty(unit)) or Plain(UnitInRaid(unit))) then return nil, "PvP-flagged" end
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

ns.On("PLAYER_ENTERING_WORLD", function() ns.ForgetSlotCasts(); ns.BuildActive(); ns.RefreshAll() end)
ns.On("GROUP_ROSTER_UPDATE", function() ns.ForgetSlotCasts() end)
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
