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
----------------------------------------------------------------------
function EV:ExtractEffects(lines)
    local out = {}
    for _, ln in ipairs(lines or {}) do
        local kind = ln:match("^(Use):") or ln:match("^(Equip):")
        if kind then out[#out + 1] = { kind = kind, text = ln } end
    end
    return out
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
            local r = self:ClassifyEffect(eff, weights, primary, ilvl, budgetPerIlvl or 0, spellID)
            details.effects[#details.effects + 1] = r
            effectSum = effectSum + (r.value or 0)
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
