-- 12.1.5 (and WoW Forever) removed the old global item functions; use C_Item's.
local GetDetailedItemLevelInfo = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
----------------------------------------------------------------------
-- VoidGear EffectValuer  (Tier-2 hybrid)
--
-- Reads an item's Use/Equip effects (from the rendered tooltip, because
-- GetItemSpell misses passive "Equip:" procs), plus sockets and set
-- bonuses, and assigns a score contribution.
--
-- HYBRID by design:
--   * Closed-form where the effect is fully readable
--       - on-use STAT:  stat x (duration/cooldown) x weight
--       - empty SOCKET:  gem stat x best-secondary weight
--   * ESTIMATE (flagged) where value needs Phase-3 log data
--       - passive STAT proc  -> default uptime (no RPPM API)
--       - DAMAGE proc/use    -> ilvl-budget fraction (needs dmg->score model)
--       - OPAQUE proc        -> ilvl-budget fraction (tooltip has no numbers)
--       - SET bonus magnitude -> proportional directional credit
--
-- The *_FRAC / DEFAULT_* / GEM_STAT constants are per-patch tuning knobs.
-- They are refreshed by the weekly pipeline / Phase-3 log corpus; every
-- value they produce is marked estimate=true so the UI can label it.
----------------------------------------------------------------------
VoidGear = VoidGear or {}
VoidGear.EffectValuer = {}
local EV = VoidGear.EffectValuer

-- Tooltip stat words -> our weight keys (match StatWeights/ItemScorer).
-- Ordered longest-first so "Critical Strike" wins before any short word.
local STAT_WORDS = {
    { "Critical Strike", "Crit" },
    { "Intellect",       "Intellect" },
    { "Strength",        "Strength" },
    { "Agility",         "Agility" },
    { "Versatility",     "Versatility" },
    { "Mastery",         "Mastery" },
    { "Haste",           "Haste" },
    { "Leech",           "Leech" },
    { "Avoidance",       "Avoidance" },
    { "Speed",           "Speed" },
}

-- Per-patch tuning knobs (refreshed by weekly pipeline / Phase-3 logs).
EV.DEFAULT_PROC_UPTIME = 0.40   -- passive stat proc, until logs give real rate
EV.DMG_PROC_ILVL_FRAC  = 0.35   -- damage proc placeholder (fraction of ilvl budget)
EV.OPAQUE_ILVL_FRAC    = 0.30   -- fully-opaque proc placeholder
EV.SET_PIECE_ILVL_FRAC = 0.12   -- directional "this is a set piece" credit
EV.GEM_STAT            = 22     -- Midnight Flawless hybrid gem ~14+6 / pure ~20 (deliberately low); was a 200 placeholder
-- Trinket BiS tier -> total-value multiplier vs a stat-stick of equal ilvl.
-- Tier comes from EffectValues (how many top M+ players wear it, Blizzard API).
EV.TIER_MULT = { S = 1.20, A = 1.05, B = 0.92, C = 0.80 }

-- Simple per-link cache, cleared on spec change (see Invalidate()).
EV._cache = {}
EV._byInstance = {}   -- tooltip dataInstanceID -> cache key

-- The game updates a tooltip's data when more of it loads: drop that item's
-- entry so the next score reads the finished tooltip.
local tooltipWatch = CreateFrame("Frame")
tooltipWatch:RegisterEvent("TOOLTIP_DATA_UPDATE")
tooltipWatch:SetScript("OnEvent", function(_, _, dataInstanceID)
    local key = dataInstanceID and EV._byInstance[dataInstanceID]
    if key then
        EV._cache[key] = nil
        EV._byInstance[dataInstanceID] = nil
    end
end)

local function num(s)
    if not s then return nil end
    return tonumber((s:gsub(",", "")))
end

----------------------------------------------------------------------
-- Pull the Use:/Equip: effect lines out of a tooltip-line array.
-- WoW Forever: weapon procs read "Chance on hit: ..." (Classic wording).
----------------------------------------------------------------------
function EV:ExtractEffects(lines)
    local out = {}
    for _, ln in ipairs(lines or {}) do
        local kind = ln:match("^(Use):") or ln:match("^(Equip):")
            or (VoidGear.IS_FOREVER and ln:match("^(Chance on hit):"))
        if kind then out[#out + 1] = { kind = kind, text = ln } end
    end
    return out
end

----------------------------------------------------------------------
-- WoW Forever: Classic "Equip:" stat lines are real stats, not procs. Forever audit,
-- 2026-11-09: they all got the same flat "effect" guess (a fishing +5 as much as +2% crit),
-- which VoidBags strips and VoidQuest keeps, so the two disagreed about upgrades.
-- Returns statKey, amount (already scaled for conditions), or nil. statKey "" = a real
-- line worth nothing for gear (a profession skill).
--   "Improves your chance to get a critical strike by 1%."         CritPct
--   "Improves your chance to hit with spells by 1%."                SpellHitPct
--   "+20 Attack Power." / "+36 Attack Power when fighting Undead."  AttackPower (x0.25)
--   "Increases damage and healing done by magical spells and effects by up to 12."  SpellPower
--   "Increases healing done by spells and effects by up to 22."    Healing
--   "Increases damage done by Shadow spells and effects by up to 10."  SchoolPower
--   "Restores 3 mana per 5 sec."  MP5      "Increased Defense +7."  Defense
--   "Increased Daggers +3."  WeaponSkill  "Increased Fishing +5."  ""
----------------------------------------------------------------------
local WEAPON_SKILLS = { "daggers", "swords", "axes", "maces", "fist weapons", "staves", "polearms",
    "bows", "guns", "crossbows", "two%-handed swords", "two%-handed axes", "two%-handed maces" }
local PROF_SKILLS = { "fishing", "mining", "herbalism", "skinning", "cooking", "first aid" }

function EV:ClassicStat(text)
    local t = text:lower():gsub("^equip:%s*", "")
    -- decimals too: Forever's Pyrewood Signet Ring reads "Improves your chance to hit by 0.4%."
    -- (the whole-number pattern missed it, so its hit counted 0; seen 2026-11-15)
    local pct = tonumber(t:match("by (%d+%.?%d*)%%") or "")
    local upTo = tonumber(t:match("up to (%d+)") or "")
    if t:find("critical strike", 1, true) and pct then
        return t:find("spell", 1, true) and "SpellCritPct" or "CritPct", pct
    end
    if (t:find("chance to hit", 1, true) or t:find("hit chance", 1, true)) and pct then
        return t:find("spell", 1, true) and "SpellHitPct" or "HitPct", pct
    end
    if t:find("dodge", 1, true) and pct then return "DodgePct", pct end
    if t:find("parry", 1, true) and pct then return "ParryPct", pct end
    if t:find("block attacks", 1, true) and pct then return "BlockPct", pct end
    local bv = tonumber(t:match("block value of your shield by (%d+)") or "")
    if bv then return "BlockValue", bv end
    local ap = tonumber(t:match("^%+(%d+) ranged attack power") or "")
    if ap then return "RangedAttackPower", ap end
    ap = tonumber(t:match("^%+(%d+) attack power") or "")
    if ap then
        if t:find("when fighting", 1, true) or t:find("in cat", 1, true) or t:find("form", 1, true) then
            return "AttackPower", ap * 0.25   -- only against one creature type / in a form
        end
        return "AttackPower", ap
    end
    if upTo and t:find("damage and healing done by magical spells", 1, true) then return "SpellPower", upTo end
    if upTo and t:find("healing done by spells", 1, true) then return "Healing", upTo end
    if upTo and t:find("damage done by %a+ spells") then return "SchoolPower", upTo end
    local mp5 = tonumber(t:match("restores (%d+) mana per 5") or "")
    if mp5 then return "MP5", mp5 end
    local hp5 = tonumber(t:match("restores (%d+) health every 5") or "") or tonumber(t:match("restores (%d+) health per 5") or "")
    if hp5 then return "HP5", hp5 end
    local def = tonumber(t:match("increased defense %+(%d+)") or "")
    if def then return "Defense", def end
    for _, s in ipairs(PROF_SKILLS) do
        if t:find("increased " .. s .. " %+%d+") then return "", 0 end
    end
    for _, s in ipairs(WEAPON_SKILLS) do
        local n = tonumber(t:match("increased " .. s .. " %+(%d+)") or "")
        if n then return "WeaponSkill", n end
    end
    return nil
end

----------------------------------------------------------------------
-- WoW Forever: "Use:" buffs and "Chance on hit:" procs, as their AVERAGE stats (the user,
-- 2026-11-15: "i dont understand why we cant read the Equip or use on items" / "yes build it").
-- Before, they got a flat guess that VoidBags dropped, so a trinket's +260 attack power counted 0.
--   Use:  a buff of N for D seconds every C seconds = N x D / C on average:
--         "Use: Increases your attack power by 260 for 20 sec. (2 Min Cooldown)"  -> AP 43
--   Chance on hit: Classic weapon procs fire about once a minute (1 PPM):
--         damage "... causing 72 Nature damage" -> 72 / 60 = 1.2 weapon DPS
--         a buff "... increases your attack power by 50 for 10 sec" -> 50 x 10 / 60
--   "Equip: 2% chance on hit to gain 1 extra attack." -> about 2% more swings, worth crit 2%
-- Returns a list { {key, amount}, ... }; an empty list = understood, worth nothing for gear
-- (a stun, a heal, a speed boost); nil = not understood (logged: VoidGearDB.unreadLines).
----------------------------------------------------------------------
local BUFF_STATS = { strength = "Strength", agility = "Agility", stamina = "Stamina",
    intellect = "Intellect", spirit = "Spirit" }
local PROC_PER_MIN = 1

local function seconds(n, unit)
    n = tonumber(n)
    if not n then return nil end
    unit = unit:lower()
    if unit:find("^h") then return n * 3600 end
    if unit:find("^m") then return n * 60 end
    return n
end
-- "(1 Min 30 Sec Cooldown)", "(5 Min Cooldown)", "(30 Sec Cooldown)", "(1 Hour Cooldown)"
local function cooldownOf(t)
    local cd = t:match("%(([^()]-) cooldown%)")
    if not cd then return nil end
    local total = 0
    for n, unit in cd:gmatch("(%d+)%s*(%a+)") do total = total + (seconds(n, unit) or 0) end
    return total > 0 and total or nil
end
local function durationOf(t)
    local n, unit = t:match("for (%d+) (%a+)")
    return n and seconds(n, unit) or nil
end

-- the stat a buff text raises: key, amount (amount per 1 for percent stats)
-- every stat a buff text raises: { {key, amount}, ... } (amount per 1 for percent stats). All of
-- them: "attack speed by 25% and spell casting speed by 33%" is two (Codex review).
local function buffStats(t)
    local out = {}
    local function add(key, n) if key and n then out[#out + 1] = { key, n } end end
    local n = tonumber((t:match("attack power by (%d+)") or ""))
    -- "melee and ranged attack power" (Earthstrike) is attack power; only a ranged-only one is ranged
    -- (Codex release gate: it scored zero for melee)
    local rangedOnly = t:find("ranged attack power", 1, true) and not t:find("melee and ranged", 1, true)
    if n then add(rangedOnly and "RangedAttackPower" or "AttackPower", n) end
    n = tonumber((t:match("damage and healing done by magical spells and effects by up to (%d+)") or ""))
    if n then add("SpellPower", n)
    else
        n = tonumber((t:match("healing done by %a* ?spells and effects by up to (%d+)") or ""))
        if n then add("Healing", n) end
    end
    add("Armor", tonumber((t:match("armor by (%d+)") or "")))
    for word, key in pairs(BUFF_STATS) do add(key, tonumber((t:match(word .. " by (%d+)") or ""))) end
    local p = tonumber((t:match("critical strike[%a ]-by (%d+)%%") or t:match("crit[%a ]-by (%d+)%%") or ""))
    if p then add(t:find("spell", 1, true) and "SpellCritPct" or "CritPct", p) end
    p = tonumber((t:match("chance to hit[%a ]-by (%d+)%%") or ""))
    if p then add(t:find("spell", 1, true) and "SpellHitPct" or "HitPct", p) end
    add("HastePct", tonumber((t:match("attack speed by (%d+)%%") or "")))
    add("SpellHastePct", tonumber((t:match("casting speed by (%d+)%%") or "")))
    return out
end

-- buffs that do nothing for a gear comparison: understood, worth 0
local NOTHING = { "run speed", "movement speed", "swim speed", "stun", "knock", "fear", "slow",
    "heal", "restores", "absorb", "resistance", "immune", "transform", "water breathing", "stealth",
    "threat", "pet", "mount", "fishing", "when struck", "mana cost" }
local function nothing(t)
    for _, w in ipairs(NOTHING) do if t:find(w, 1, true) then return true end end
    return false
end

function EV:ClassicEffect(kind, text)
    local t = text:lower():gsub("%s+", " ")
    -- extra attacks (Hand of Justice style): a share of your swings again, worth that much crit
    local pct, extra = t:match("(%d+)%% chance on hit to gain (%d+) extra attack")
    if pct then return { { "CritPct", tonumber(pct) * tonumber(extra) } } end
    local isProc = kind == "Chance on hit" or t:find("chance on hit", 1, true) or t:find("chance on melee hit", 1, true)
    local stats = buffStats(t)
    if kind == "Use" and not isProc then
        local dur, cd = durationOf(t), cooldownOf(t)
        if #stats > 0 and dur and cd then
            local out = {}
            for _, s in ipairs(stats) do out[#out + 1] = { s[1], s[2] * math.min(1, dur / cd) } end
            return out
        end
        if nothing(t) then return {} end
        return nil
    end
    if isProc then
        -- proc damage: "for 72 Nature damage", "causing 30 to 40 damage", "inflicts 50 damage";
        -- over time: "20 damage every 2 sec for 10 sec" = every tick (Codex review)
        -- the over-time part with its own tick (Codex: an initial hit must not be multiplied)
        local tick, every, over = t:match("(%d+) %a* ?damage every (%d+) sec%a* for (%d+) sec")
        local dot = (tick and tonumber(every) > 0) and tonumber(tick) * math.floor(tonumber(over) / tonumber(every)) or 0
        local rest = tick and t:gsub("%d+ %a* ?damage every %d+ sec%a* for %d+ sec", "") or t
        -- a total over time: "and an additional 60 damage over 6 sec" (Codex release gate: it was lost)
        local total = tonumber((rest:match("(%d+) %a* ?damage over %d+ sec") or ""))
        if total then
            dot = dot + total
            rest = rest:gsub("%d+ %a* ?damage over %d+ sec", "")
        end
        local a, b = rest:match("(%d+) to (%d+) %a* ?damage")
        local dmg = a and (tonumber(a) + tonumber(b)) / 2 or tonumber((rest:match("(%d+) %a* ?damage") or "")) or 0
        dmg = dmg + dot
        local dur = durationOf(t)
        local out = {}
        if dmg and dmg > 0 and #stats == 0 then out[#out + 1] = { "DPS", dmg * PROC_PER_MIN / 60 } end
        if dur then
            for _, s in ipairs(stats) do out[#out + 1] = { s[1], s[2] * math.min(1, dur * PROC_PER_MIN / 60) } end
        end
        if #out > 0 then return out end
        if nothing(t) then return {} end
        return nil
    end
    -- an Equip line that isn't a stat (ClassicStat had it first): thorns, mana cost of one spell...
    if nothing(t) then return {} end
    return nil
end

-- a line nothing could read: kept with how often it was seen, so its wording can be added
function EV:LogUnread(text)
    if not VoidGear.IS_FOREVER or type(text) ~= "string" then return end
    VoidGearDB = VoidGearDB or {}
    VoidGearDB.unreadLines = VoidGearDB.unreadLines or {}
    local u = VoidGearDB.unreadLines
    if u[text] then u[text] = u[text] + 1; return end
    local n = 0
    for _ in pairs(u) do n = n + 1; if n >= 300 then return end end
    u[text] = 1
end

----------------------------------------------------------------------
-- Best secondary-stat weight (what you'd gem into).
----------------------------------------------------------------------
function EV:BestSecondaryWeight(weights)
    local best = 0
    for _, key in ipairs({ "Crit", "Haste", "Mastery", "Versatility" }) do
        local w = weights and weights[key]
        if w and w > best then best = w end
    end
    return best
end

----------------------------------------------------------------------
-- Phase-3 empirical magnitudes for a spec (from the VoidScout log corpus),
-- or nil when none have been generated yet.
----------------------------------------------------------------------
function EV:Empirical(specID)
    local ev = VoidGear.EffectValues
    if not (specID and ev and ev.bySpec) then return nil end
    return ev.bySpec[specID]
end

----------------------------------------------------------------------
-- Classify + value a single effect line.
-- Returns { class, value, estimate, stat, statVal, dmg, dur }
----------------------------------------------------------------------
function EV:ClassifyEffect(eff, weights, primary, ilvl, budgetPerIlvl, spellID)
    local text = eff.text

    -- Look for "<number> <StatWord>" (a stat buff amount).
    local statVal, statKey
    for _, pair in ipairs(STAT_WORDS) do
        local n = text:match("([%d,]+)%s+" .. pair[1])
        if n then statVal, statKey = num(n), pair[2]; break end
    end
    local durSec = tonumber(text:match("for%s+([%d%.]+)%s*sec"))
    local dmg = num(text:match("([%d,]+)%s+%a+%s+damage")) or num(text:match("dealing%s+([%d,]+)"))

    if statKey and statVal then
        local w = (statKey == primary) and 1.0 or (weights and weights[statKey]) or 0
        if eff.kind == "Use" then
            -- On-use: uptime = duration / base cooldown (both readable).
            local cd
            if spellID and GetSpellBaseCooldown then
                local ms = GetSpellBaseCooldown(spellID)
                if ms and ms > 0 then cd = ms / 1000 end
            end
            if not cd then
                local m = text:match("(%d+)%s*min%s*[Cc]ooldown")
                if m then cd = tonumber(m) * 60 else cd = tonumber(text:match("(%d+)%s*sec%s*[Cc]ooldown")) end
            end
            local uptime = (durSec and cd and cd > 0) and math.min(1, durSec / cd) or self.DEFAULT_PROC_UPTIME
            return { class = "onuse_stat", value = statVal * uptime * w,
                     estimate = (cd == nil), stat = statKey, statVal = statVal, dur = durSec }
        else
            -- Passive stat proc: uptime unknown (no RPPM API) -> default.
            return { class = "passive_stat", value = statVal * self.DEFAULT_PROC_UPTIME * w,
                     estimate = true, stat = statKey, statVal = statVal, dur = durSec }
        end
    elseif dmg then
        return { class = "damage", value = ilvl * budgetPerIlvl * self.DMG_PROC_ILVL_FRAC,
                 estimate = true, dmg = dmg }
    else
        return { class = "opaque", value = ilvl * budgetPerIlvl * self.OPAQUE_ILVL_FRAC,
                 estimate = true }
    end
end

----------------------------------------------------------------------
-- Directional set-piece credit (Phase 2). Magnitude + 2pc/4pc threshold
-- awareness comes from Phase-3 log deltas; for now a set piece just gets a
-- proportional bump so tier edges out an equivalent non-set piece.
----------------------------------------------------------------------
function EV:IsSetPiece(itemID, specID)
    if not (itemID and specID and specID > 0 and C_Item.GetSetBonusesForSpecializationByItemID) then
        return false
    end
    local ok, ids = pcall(C_Item.GetSetBonusesForSpecializationByItemID, specID, itemID)
    return ok and type(ids) == "table" and #ids > 0
end

----------------------------------------------------------------------
-- Value an item's non-stat extras: effects + sockets + set.
-- Returns totalExtra, details.  (Every item's tooltip is read once: passive
-- "Equip:" procs on weapons and armor are effects too; the cache keeps it cheap.)
----------------------------------------------------------------------
function EV:ValueExtras(link, weights, primary, budgetPerIlvl, opts)
    if not link then return 0, nil end
    local cacheKey = (type(link) == "string") and link or ("id:" .. tostring(link))
    if not (opts and opts.noCache) and self._cache[cacheKey] then
        local c = self._cache[cacheKey]
        return c.total, c.details
    end

    local ilvl = GetDetailedItemLevelInfo(link) or 0
    local itemID, _, _, equipLoc = C_Item.GetItemInfoInstant(link)
    local details = { effects = {}, empty = 0, socketValue = 0, setValue = 0 }
    local total = 0

    -- Active spec + any Phase-3 empirical magnitudes for it.
    local specIdx = GetSpecialization and GetSpecialization() or 0
    local specID = (specIdx and specIdx > 0) and GetSpecializationInfo(specIdx) or 0
    local emp = self:Empirical(specID)

    -- Effects: any item. GetItemSpell only sees on-use spells, so a passive
    -- "Equip:" proc (an embellishment, a weapon proc) is read from the tooltip.
    local _, spellID = C_Item.GetItemSpell(link)
    local effectSum, incomplete = 0, false
    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local tt = (type(link) == "string") and C_TooltipInfo.GetHyperlink(link)
                   or C_TooltipInfo.GetItemByID(link)
        local lines = {}
        -- Still loading (the item, its spell text, or "Retrieving item information"):
        -- score it, don't cache it. A later change to this tooltip drops the entry too.
        if not (tt and tt.lines and #tt.lines >= 2)
           or (itemID and C_Item.IsItemDataCachedByID and not C_Item.IsItemDataCachedByID(itemID))
           or (spellID and C_Spell.IsSpellDataCached and not C_Spell.IsSpellDataCached(spellID)) then
            incomplete = true
            if itemID then C_Item.RequestLoadItemDataByID(itemID) end
            if spellID and C_Spell.RequestLoadSpellData then C_Spell.RequestLoadSpellData(spellID) end
        end
        if tt and tt.dataInstanceID then self._byInstance[tt.dataInstanceID] = cacheKey end
        if tt and tt.lines then
            for _, line in ipairs(tt.lines) do
                if TooltipUtil and TooltipUtil.SurfaceArgs then TooltipUtil.SurfaceArgs(line) end
                local t = line.leftText
                if t and not (issecretvalue and issecretvalue(t)) then
                    if t == RETRIEVING_ITEM_INFO then incomplete = true end
                    if t ~= "" then lines[#lines + 1] = t end
                end
            end
        end
        for _, eff in ipairs(self:ExtractEffects(lines)) do
            -- WoW Forever: a Classic stat line goes to details.classic (ItemScorer adds it to the
            -- stat score); an Equip line it can't read is worth nothing, never a flat guess
            local key, amt, parts
            if VoidGear.IS_FOREVER and eff.kind == "Equip" then key, amt = self:ClassicStat(eff.text) end
            -- not a plain stat: a Use buff or a proc, as its average (ClassicEffect)
            if VoidGear.IS_FOREVER and not key then parts = self:ClassicEffect(eff.kind, eff.text) end
            if key or parts then
                for _, p in ipairs(parts or { { key, amt } }) do
                    if p[1] ~= "" then
                        details.classic = details.classic or {}
                        details.classic[p[1]] = (details.classic[p[1]] or 0) + p[2]
                    end
                end
            elseif VoidGear.IS_FOREVER then
                -- nothing could read it: worth nothing, and kept so its wording can be added
                details.effects[#details.effects + 1] = { class = "unread", value = 0, estimate = true }
                self:LogUnread(eff.text)
            else
                local r = self:ClassifyEffect(eff, weights, primary, ilvl, budgetPerIlvl or 0, spellID)
                details.effects[#details.effects + 1] = r
                effectSum = effectSum + (r.value or 0)
            end
        end
    end
    -- Tier override: if we have a scraped BiS tier for this trinket (by NAME),
    -- value it as (ilvl budget x tier multiplier) minus its visible-stat score.
    -- That makes an S trinket score above its raw ilvl budget and a C below,
    -- and replaces the placeholder estimate. Falls back to the estimate if the
    -- trinket isn't in the ranking.
    local tier
    if equipLoc == "INVTYPE_TRINKET" and emp and emp.trinketsByName then
        local nm = (type(link) == "string") and link:match("%[(.-)%]") or nil
        if not nm then nm = C_Item.GetItemInfo(link) end
        if nm then tier = emp.trinketsByName[nm] end
    end
    if tier then
        local mult = self.TIER_MULT[tier] or 1.0
        local statScore = 0
        if VoidGear.Scorer and VoidGear.Scorer.ScoreStats then
            local st = C_Item.GetItemStats(link)
            if st then statScore = VoidGear.Scorer:ScoreStats(st, weights, primary) end
        end
        effectSum = math.max(0, ilvl * (budgetPerIlvl or 0) * mult - statScore)
        details.effectSource = "tier"
        details.tier = tier
    elseif emp and emp.trinkets and itemID and emp.trinkets[itemID]
           and equipLoc == "INVTYPE_TRINKET" then
        effectSum = emp.trinkets[itemID].score or effectSum
        details.effectSource = "empirical"
        details.empiricalTrinket = emp.trinkets[itemID]
    elseif #details.effects > 0 then
        details.effectSource = "estimate"
    end
    total = total + effectSum

    -- Sockets (closed-form). Value EVERY socket, filled or empty: GetItemStats
    -- never includes a socketed gem's stats, so counting only empty ones made a
    -- drop with an empty socket outscore the same piece you'd already gemmed.
    local nSock = (C_Item.GetItemNumSockets and C_Item.GetItemNumSockets(link)) or 0
    if nSock > 0 then
        local filled = 0
        for i = 1, nSock do
            local gem = C_Item.GetItemGem and C_Item.GetItemGem(link, i)
            if gem then filled = filled + 1 end
        end
        details.empty = nSock - filled
        details.socketValue = nSock * self.GEM_STAT * self:BestSecondaryWeight(weights)
        total = total + details.socketValue
    end

    -- Set piece: empirical value if the corpus has it, else directional estimate.
    if self:IsSetPiece(itemID, specID) then
        local sv
        if emp and emp.sets then
            local ok, ids = pcall(C_Item.GetSetBonusesForSpecializationByItemID, specID, itemID)
            if ok and type(ids) == "table" then
                for _, sid in ipairs(ids) do
                    if emp.sets[sid] then sv = (sv or 0) + (emp.sets[sid].score or 0) end
                end
            end
        end
        if sv then
            details.setValue = sv
            details.setSource = "empirical"
        else
            details.setValue = ilvl * (budgetPerIlvl or 0) * self.SET_PIECE_ILVL_FRAC
            details.setEstimate = true
        end
        total = total + details.setValue
    end

    if not (opts and opts.noCache) and not incomplete then
        self._cache[cacheKey] = { total = total, details = details }
    end
    return total, details
end

----------------------------------------------------------------------
-- Clear cache (e.g. on spec/weight change).
----------------------------------------------------------------------
function EV:Invalidate()
    wipe(self._cache)
    wipe(self._byInstance)
end
