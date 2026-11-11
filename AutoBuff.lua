-- ForeverAlly: the auto-buff key. Each press buffs the next player who lacks one of your buffs:
-- you, then your group, then the players around you (their nameplates), the first one in range.
--
-- How, and why (each point was found in game on Forever, see CHANGELOG.md):
--  * The game lets an addon cast only from a key press, one spell per press. The key is bound to a
--    secure button (Key Bindings > AddOns > ForeverAlly, or the options) whose macro text the addon
--    rewrites out of combat, a few times a second, only when the pick changes. Before a fight it is
--    emptied (secure attributes can't change in combat). No macro of the player's is used.
--  * Group members are cast on by unit ([@party1]). Anyone else: [@nameplateN] did nothing, so the
--    player is targeted by name and the previous target restored. /targetexact finds a Forever
--    player only by the full "Name Surname"; the bare name may hit an NPC of that name.
--  * The text is kept within 255 bytes, as a macro's (Cyrillic letters take two): the full name
--    always stays in.
--  * Forever does not lower a buff's rank for a low-level target ("target too low level"): the rank
--    is picked by level (the classic rule: spell level at most 10 above the target's), and one rank
--    lower after a "too low level" answer.
--  * The server's answers come after the next press may already have moved on: every answer is tied
--    to its cast (castGUID). A player a cast failed on goes to the back of the queue for a while.
local _, ns = ...
local L, Plain = ns.L, ns.Plain

local button = CreateFrame("Button", "FAllyPress", UIParent) -- the cast text clicks it after its /cast (short: 255 bytes)
button:SetSize(1, 1)
button:Hide()

local function InRange(need, unit)
    local ok, r = pcall(C_Spell.IsSpellInRange, need.id or need.spell, unit)
    r = ok and Plain(r)
    if r == true or r == 1 then return true end
    if r == false or r == 0 then return false end
    local ok2, inRange, checked = pcall(UnitInRange, unit)
    if ok2 and Plain(checked) and Plain(inRange) ~= nil then return Plain(inRange) and true or false end
    local ok3, visible = pcall(UnitIsVisible, unit)
    return not ok3 or Plain(visible) ~= false
end
ns.InRange = InRange

local skipUntil = {}
-- a buff that has just landed: its aura reaches the unit a moment after "cast ok", and until then the
-- player still looks unbuffed. Without this the next press cast the same buff on them again.
local justCast = {} -- guid -> { spell = name, t = GetTime() }
local JUST_CAST_SEC = 3
local lastGUID, lastPress, lastText = nil, 0, nil
local casts, lastCast, lastFailed, lastFailedT = {}, nil, nil, 0
local pressCount, sentSincePress = 0, false
local NOT_A_TARGET_PROBLEM = {}
for _, key in ipairs({ "SPELL_FAILED_NOT_READY", "ERR_ABILITY_COOLDOWN", "ERR_SPELL_COOLDOWN",
    "SPELL_FAILED_SPELL_IN_PROGRESS", "ERR_GENERIC_NO_TARGET", "SPELL_FAILED_NO_POWER", "ERR_OUT_OF_MANA",
    "SPELL_FAILED_MOVING", "SPELL_FAILED_NOT_MOUNTED", "SPELL_FAILED_NOT_SHAPESHIFT" }) do
    if type(_G[key]) == "string" then NOT_A_TARGET_PROBLEM[_G[key]] = true end
end

local stats
local function Pick()
    local a = ns.db.auto
    local seen, now = {}, GetTime()
    stats = { players = 0, need = 0, far = 0, skipped = 0, unreadable = 0, why = {} }
    local laterUnit, laterNeed
    -- (for the log: why a group member got nothing)
    local function note(unit, why)
        if unit == "player" or ns.GroupToken(unit) then
            stats.why[#stats.why + 1] = ("%s %s: %s"):format(unit, Plain((UnitName(unit))) or "?", why)
        end
    end
    local function try(unit)
        local exists = UnitExists(unit)
        if not Plain(exists) and not (ns.GroupToken(unit) and ns.Secret(exists)) then return end
        local guid = ns.UnitKey(unit)
        if not guid then note(unit, ns.Secret(UnitGUID(unit)) and "GUID hidden" or "no GUID") return end
        if seen[guid] then return end
        seen[guid] = true
        local ok, why = ns.Wanted(unit, true)
        if not ok then
            if why == "dead" then ns.ForgetCasts(guid) end -- (their buffs are gone)
            note(unit, why or "?") return
        end
        stats.players = stats.players + 1
        local needs, blind = ns.Needs(unit)
        if not needs then stats.unreadable = stats.unreadable + 1 note(unit, "buffs hidden") return end
        if blind then stats.unreadable = stats.unreadable + 1 end
        local jc = justCast[guid]
        if jc and now - jc.t < JUST_CAST_SEC then
            local rest = {}
            for _, need in ipairs(needs) do if need.spell ~= jc.spell then rest[#rest + 1] = need end end
            needs = rest
        end
        if #needs == 0 then note(unit, blind and "has all (by your casts)" or "has all") return end
        stats.need = stats.need + 1
        local later = (skipUntil[guid] or 0) > now
        local isSelf = Plain(UnitIsUnit(unit, "player"))
        for _, need in ipairs(needs) do
            if isSelf or InRange(need, unit) then
                if not later then return need end
                stats.skipped = stats.skipped + 1
                note(unit, "moved back")
                if not laterUnit then laterUnit, laterNeed = unit, need end
                return
            end
        end
        stats.far = stats.far + 1
        note(unit, "out of range")
    end
    local units = {}
    if a.self then units[#units + 1] = "player" end
    if a.group then
        if IsInRaid() then for i = 1, 40 do units[#units + 1] = "raid" .. i end
        else for i = 1, 4 do units[#units + 1] = "party" .. i end end
    end
    if a.others then for _, unit in ipairs(ns.PlateUnits()) do units[#units + 1] = unit end end
    for _, unit in ipairs(units) do
        -- (a group member reached through a nameplate when "group" is off is still a group member)
        if a.group or not (Plain(UnitInParty(unit)) or Plain(UnitInRaid(unit))) or Plain(UnitIsUnit(unit, "player")) then
            local need = try(unit)
            if need then return unit, need end
        end
    end
    if laterUnit then return laterUnit, laterNeed end
end

--------------------------------------------------------------------------------
-- Ranks
--------------------------------------------------------------------------------

local RANKS = { -- [rank 1 id] = { { id, classic learn level }, ... } lowest first
    [1243]  = { { 1243, 1 }, { 1244, 12 }, { 1245, 24 }, { 2791, 36 }, { 10937, 48 }, { 10938, 60 } },
    [14752] = { { 14752, 30 }, { 14818, 40 }, { 14819, 50 }, { 27841, 60 } },
    [1126]  = { { 1126, 1 }, { 5232, 10 }, { 6756, 20 }, { 5234, 30 }, { 8907, 40 }, { 9884, 50 }, { 9885, 60 } },
    [1459]  = { { 1459, 1 }, { 1460, 14 }, { 1461, 28 }, { 10156, 42 }, { 10157, 56 } },
    [19740] = { { 19740, 4 }, { 19834, 12 }, { 19835, 22 }, { 19836, 32 }, { 19837, 42 }, { 19838, 52 }, { 25291, 60 } },
    [19742] = { { 19742, 14 }, { 19850, 24 }, { 19852, 34 }, { 19853, 44 }, { 19854, 54 }, { 25290, 60 } },
    [19977] = { { 19977, 40 }, { 19978, 50 }, { 19979, 60 } },
    [20911] = { { 20911, 30 }, { 20912, 40 }, { 20913, 50 }, { 20914, 60 } },
    [976]   = { { 976, 30 }, { 10957, 42 }, { 10958, 56 } },                                  -- Shadow Protection
    [467]   = { { 467, 6 }, { 782, 14 }, { 1075, 24 }, { 8914, 34 }, { 9756, 44 }, { 9910, 54 } }, -- Thorns
}
local rankCap = {} -- guid -> { [key] = highest rank index allowed }

local function KnownRank(id)
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    return C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id) or false
end

local function CastText(need, unit, guid)
    local list = ns.db.auto.ranks and need.key and RANKS[need.key]
    if not list then return need.spell end
    local known = {}
    for _, r in ipairs(list) do
        if KnownRank(r[1]) then
            local ok, lvl = pcall(C_Spell.GetSpellLevelLearned or function() end, r[1])
            lvl = ok and Plain(lvl)
            known[#known + 1] = { r[1], (type(lvl) == "number" and lvl > 0) and lvl or r[2] }
        end
    end
    if #known == 0 then return need.spell end
    local target = Plain(UnitLevel(unit))
    local cap = guid and rankCap[guid] and rankCap[guid][need.key]
    local pick = 1
    for i, r in ipairs(known) do
        if (not target or target <= 0 or r[2] - 10 <= target) and (not cap or i <= cap) then pick = i end
    end
    if pick == #known then return need.spell, pick end
    local sub = C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(known[pick][1])
    if sub and sub ~= "" then return need.spell .. "(" .. sub .. ")", pick end
    return need.spell, pick
end

--------------------------------------------------------------------------------
-- The key-binding button
--------------------------------------------------------------------------------

local IDLE_BODY = "/click FAllyPress"
local armed = {}
local lastNobody -- the last "pick nobody" reasons logged (logged again only when they change)

-- Key Bindings > AddOns > ForeverAlly: a secure button that runs macro text (type "macro",
-- macrotext) set by the addon out of combat. Both press and release reach it; the secure gate runs
-- it once (in game: on the key press). (An earlier secure button that cast on [@nameplateN] units
-- never fired; this one targets by name.)
local castButton = CreateFrame("Button", "FAllyCast", UIParent, "SecureActionButtonTemplate")
castButton:SetSize(1, 1)
castButton:SetAlpha(0)
castButton:EnableMouse(false)
castButton:RegisterForClicks("AnyDown", "AnyUp")
castButton:SetAttribute("useOnKeyDown", false)
for _, suffix in ipairs({ "", "1" }) do castButton:SetAttribute("type" .. suffix, "macro") end
castButton:HookScript("PostClick", function(_, mouse, down)
    ns.Log("  key-binding button clicked (%s, down %s)", mouse, down)
end)
BINDING_HEADER_FOREVERALLY = "ForeverAlly"
_G["BINDING_NAME_CLICK FAllyCast:LeftButton"] = L["Buff the next player"]

local function SetBody(body)
    if InCombatLockdown() or armed.body == body then return end
    for _, suffix in ipairs({ "", "1" }) do castButton:SetAttribute("macrotext" .. suffix, body) end
    armed.body = body
    ns.Log("action = %s", (body:gsub("\n", " | ")))
end
SetBody(IDLE_BODY)

local function CastLines(unit, spell, withBare)
    if Plain(UnitIsUnit(unit, "player")) then return "/cast [@player] " .. spell end
    if unit:find("^party") or unit:find("^raid") then return "/cast [@" .. unit .. ",help,nodead] " .. spell end
    local name = Plain((UnitName(unit)))
    local full
    local okU, first, surname = pcall(UnitNameUnmodified or function() end, unit)
    if okU and Plain(first) and Plain(surname) and Plain(surname) ~= "" then full = Plain(first) .. " " .. Plain(surname) end
    if not full then
        local okFull, f = pcall(GetUnitName, unit, true)
        full = okFull and Plain(f) or nil
    end
    full = full or name
    if not full or full == "" then return end
    local lines = { "/cleartarget" }
    -- the bare name first, the full name last (it wins over an NPC of the bare name)
    if withBare and name and name ~= full then lines[#lines + 1] = "/targetexact " .. name end
    lines[#lines + 1] = "/targetexact " .. full
    lines[#lines + 1] = "/cast [@target,help,nodead] " .. spell
    lines[#lines + 1] = "/targetlasttarget"
    return table.concat(lines, "\n")
end

local function Arm()
    if InCombatLockdown() then return end
    if not ns.db.auto.enabled then
        -- switched off: no cast left for a press to fire at a stale target
        armed.unit, armed.guid, armed.text, armed.key, armed.rankIdx, armed.spell = nil, nil, nil, nil, nil, nil
        SetBody(IDLE_BODY)
        return
    end
    local unit, need = Pick()
    local castText, rankIdx
    if unit then castText, rankIdx = CastText(need, unit, Plain(UnitGUID(unit))) end
    armed.key, armed.rankIdx, armed.spell = need and need.key, rankIdx, need and need.spell
    -- kept within 255 bytes, as a macro: the bare name is dropped first when it does not fit
    local body
    for _, withBare in ipairs({ true, false }) do
        local lines = unit and CastLines(unit, castText, withBare)
        body = lines and (lines .. "\n/click FAllyPress")
        if not body or #body <= 255 then break end
    end
    if not body or #body > 255 then unit = nil end
    local guid = unit and ns.UnitKey(unit)
    local s = stats or {}
    if unit then
        lastNobody = nil
        if guid ~= armed.guid or (armed.text and not armed.text:find(castText, 1, true)) then
            ns.Log("pick %s (%s) %s -> %s; players %s need %s far %s later %s unreadable %s; %s",
                unit, Plain(GetUnitName(unit, true)), guid, castText, s.players, s.need, s.far, s.skipped, s.unreadable,
                ns.Describe(unit))
        end
    else
        local why = (s.why and #s.why > 0) and ("; group: " .. table.concat(s.why, ", ")) or ""
        if why ~= lastNobody then
            lastNobody = why
            ns.Log("pick nobody; players %s need %s far %s later %s unreadable %s%s",
                s.players, s.need, s.far, s.skipped, s.unreadable, why)
        end
    end
    armed.unit, armed.guid = unit, guid
    armed.text = unit and ((Plain(UnitName(unit)) or "?") .. ": " .. castText)
    SetBody(unit and body or IDLE_BODY)
end
ns.Arm = Arm

button:SetScript("OnClick", function()
    if InCombatLockdown() then return end
    lastGUID, lastPress, lastText = armed.guid, GetTime(), armed.text
    ns.Log("PRESS %s / %s; target '%s'", armed.text, armed.guid, Plain(UnitName("target")))
    -- a press that sends no cast at all (and shows no error) means the macro's target was wrong:
    -- that player goes to the back of the queue. The global cooldown or a cast under way also send
    -- nothing, so only a press while nothing blocks it counts.
    local pressGUID, pressID = armed.guid, pressCount + 1
    pressCount, sentSincePress = pressID, false
    local start, duration = 0, 0
    local cd = C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(61304)
    if cd then start, duration = Plain(cd.startTime) or 0, Plain(cd.duration) or 0 end
    local blocked = (duration > 0 and start + duration > GetTime()) or UnitCastingInfo("player") ~= nil
    if pressGUID and not blocked then
        C_Timer.After(1, function()
            if pressCount == pressID and not sentSincePress and lastGUID == pressGUID then
                skipUntil[pressGUID] = GetTime() + ns.db.auto.skipSec
                ns.Log("  nothing was cast: %s moved back", armed.text)
                Arm()
            end
        end)
    end
    if ns.db.auto.message then
        local s = stats or {}
        UIErrorsFrame:AddMessage(armed.text or L["Nobody to buff (players %d, need a buff %d, too far %d, moved back %d, unreadable %d)"]:format(
            s.players or 0, s.need or 0, s.far or 0, s.skipped or 0, s.unreadable or 0), 1, 0.82, 0)
    end
    C_Timer.After(0.2, Arm)
end)

-- The auto-buff key: the options key field binds the key-binding button (CLICK FAllyCast:LeftButton,
-- the same entry as Key Bindings > ForeverAlly); a key the old "ForeverAlly" macro had is freed.
local CLICK = "CLICK FAllyCast:LeftButton"
function ns.GetBuffKey()
    return GetBindingKey(CLICK)
end

function ns.SetBuffKey(key)
    if InCombatLockdown() then return end
    for _, k in ipairs({ GetBindingKey(CLICK) }) do SetBinding(k) end
    for _, k in ipairs({ GetBindingKey("MACRO ForeverAlly") }) do SetBinding(k) end
    if key then SetBindingClick(key, "FAllyCast", "LeftButton") end
    SaveBindings(GetCurrentBindingSet())
    return true
end

local wait = 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    wait = 0.3
    if ns.db and ns.HasBuffs() then Arm() end -- (Arm empties the action when the option is off)
end)

ns.On("PLAYER_LOGIN", function()
    C_Timer.After(3, function()
        ns.BuildActive() -- (the spellbook is read here too: this may run before the first refresh)
        if ns.db.auto.enabled and ns.HasBuffs() and not ns.GetBuffKey() then
            ns.Print(L["Set the auto-buff key: /fally, or Key Bindings > ForeverAlly."])
        end
    end)
end)
ns.On("PLAYER_TARGET_CHANGED", function()
    if GetTime() - lastPress < 2 then ns.Log("  target -> '%s'", Plain(UnitName("target"))) end
end)
ns.On("PLAYER_REGEN_DISABLED", function()
    armed.unit, armed.guid, armed.text = nil, nil, nil
    SetBody(IDLE_BODY) -- a target picked before the fight must not be cast on during it
end)
ns.On("UNIT_SPELLCAST_SENT", function(_, _, target, castGUID, spellID)
    sentSincePress = true
    if GetTime() - lastPress < 2 then ns.Log("  cast sent: %s at '%s'", Plain(spellID) and C_Spell.GetSpellName(Plain(spellID)), Plain(target)) end
    castGUID = Plain(castGUID)
    if armed.guid then
        local now = GetTime()
        for k, c in pairs(casts) do if now - c.t > 10 then casts[k] = nil end end
        local rec = { guid = armed.guid, key = armed.key, rank = armed.rankIdx, text = armed.text, spell = armed.spell, t = now }
        if castGUID then casts[castGUID] = rec end
        lastCast = rec
    end
end, "player")
ns.On("UNIT_SPELLCAST_FAILED", function(_, _, castGUID, spellID)
    sentSincePress = true
    if GetTime() - lastPress < 2 then ns.Log("  cast FAILED: %s", Plain(spellID) and C_Spell.GetSpellName(Plain(spellID))) end
    castGUID = Plain(castGUID)
    lastFailed, lastFailedT = castGUID and casts[castGUID] or nil, GetTime()
end, "player")
ns.On("UNIT_SPELLCAST_SUCCEEDED", function(_, _, castGUID, spellID)
    spellID = Plain(spellID)
    local name = spellID and C_Spell.GetSpellName(spellID)
    if GetTime() - lastPress < 2 then ns.Log("  cast ok: %s", name) end
    castGUID = Plain(castGUID)
    local rec = castGUID and casts[castGUID]
    if castGUID then casts[castGUID] = nil end
    if name and rec then
        justCast[rec.guid] = { spell = name, t = GetTime() }
        if ns.blessingNames[name] then ns.RememberBlessing(rec.guid, name) end
        ns.RememberCast(rec.guid, name)
        Arm() -- on to the next player at once, not on the one just buffed
        ns.RefreshAll()
    end
end, "player")
ns.On("UI_ERROR_MESSAGE", function(_, _, message)
    sentSincePress = true
    if GetTime() - lastPress < 2 then ns.Log("  error: %s", message) end
    if NOT_A_TARGET_PROBLEM[message] then return end
    C_Timer.After(0.05, function()
        local now = GetTime()
        local rec = (lastFailed and now - lastFailedT < 0.5 and lastFailed) or (lastCast and now - lastCast.t < 1.5 and lastCast)
        -- refused before anything was sent ("out of range" from the client itself): the pressed player
        if not rec and lastGUID and now - lastPress < 0.6 then rec = { guid = lastGUID, text = lastText } end
        if not rec then return end
        lastFailed, lastCast = nil, nil
        local lowLevel = type(message) == "string" and ((type(SPELL_FAILED_LOWLEVEL) == "string" and message == SPELL_FAILED_LOWLEVEL)
            or message:find("низкого уровня", 1, true) or message:lower():find("too low", 1, true))
        local stronger = type(message) == "string" and ((type(SPELL_FAILED_AURA_BOUNCED) == "string" and message == SPELL_FAILED_AURA_BOUNCED)
            or message:find("более мощное", 1, true) or message:lower():find("more powerful", 1, true))
        if stronger and rec.spell then
            ns.Bounce(rec.guid, rec.spell)
            ns.Log("  %s: someone else's stronger one is on them; not offered for 2 min", rec.text)
        elseif lowLevel and rec.spell and not (rec.key and rec.rank and rec.rank > 1) then
            -- no lower rank to try (Kings has a single one): another buff for them instead
            ns.Bounce(rec.guid, rec.spell, 600)
            ns.Log("  %s: too low level for any rank; not offered for 10 min", rec.text)
        elseif lowLevel and rec.key and rec.rank then
            rankCap[rec.guid] = rankCap[rec.guid] or {}
            rankCap[rec.guid][rec.key] = math.max(1, rec.rank - 1)
            ns.Log("  too low level (%s): next time rank %d", rec.text, math.max(1, rec.rank - 1))
        else
            skipUntil[rec.guid] = now + ns.db.auto.skipSec
            ns.Log("  %s moved back", rec.text)
        end
        if lastGUID == rec.guid then lastGUID = nil end
        Arm()
    end)
end)

-- /fally status: what the addon thinks of your target
function ns.Status()
    local names = {}
    for _, b in ipairs(ns.active) do names[#names + 1] = b.spell end
    for _, b in pairs(ns.blessings) do names[#names + 1] = b.spell end
    ns.Print(L["Your buffs: %s"]:format(#names > 0 and table.concat(names, ", ") or L["none known"]))
    if Plain(UnitExists("target")) then
        local ok, why = ns.Wanted("target", true)
        ns.Print(L["Target: suitable %s"]:format(ok and L["yes"] or (L["no"] .. (why and (" (" .. why .. ")") or ""))))
        local needs = ns.Needs("target")
        if not needs then ns.Print(L["Target's buffs can't be read"])
        elseif #needs == 0 then ns.Print(L["The target needs nothing"])
        else
            for _, need in ipairs(needs) do
                ns.Print(L["Needs %s; in range %s"]:format(need.spell, InRange(need, "target") and L["yes"] or L["no"]))
            end
        end
    end
    local key = ns.GetBuffKey()
    ns.Print(L["Auto-buff key: %s"]:format(key and (GetBindingText and GetBindingText(key) or key) or L["Not set"]))
    ns.Print(L["Next press: %s"]:format(((armed.body or IDLE_BODY):gsub("\n", " || "))))
end
