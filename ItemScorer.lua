-- 12.1.5 (and WoW Forever) removed the old global item functions; use C_Item's.
local GetDetailedItemLevelInfo = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
----------------------------------------------------------------------
-- VoidGear ItemScorer
-- Apply stat weights to an item to produce a numeric score.
-- Higher score = better item for the active spec.
----------------------------------------------------------------------

VoidGear = VoidGear or {}
VoidGear.Scorer = {}
local Sc = VoidGear.Scorer

----------------------------------------------------------------------
-- Map WoW stat keys (returned by C_Item.GetItemStats) to our short names
-- (which match StatWeights.lua preset keys).
----------------------------------------------------------------------
local STAT_KEY_MAP = {
    -- Primary stats
    ITEM_MOD_STRENGTH_SHORT   = "Strength",
    ITEM_MOD_AGILITY_SHORT    = "Agility",
    ITEM_MOD_INTELLECT_SHORT  = "Intellect",
    ITEM_MOD_STAMINA_SHORT    = "Stamina",
    -- Secondaries
    ITEM_MOD_CRIT_RATING_SHORT      = "Crit",
    ITEM_MOD_HASTE_RATING_SHORT     = "Haste",
    ITEM_MOD_MASTERY_RATING_SHORT   = "Mastery",
    ITEM_MOD_VERSATILITY            = "Versatility",
    -- Tertiaries
    ITEM_MOD_CR_LIFESTEAL_SHORT     = "Leech",
    ITEM_MOD_CR_SPEED_SHORT         = "Speed",
    ITEM_MOD_CR_AVOIDANCE_SHORT     = "Avoidance",
    ITEM_MOD_CR_STURDINESS_SHORT    = "Indestructible",
    -- Classic-style stats (WoW Forever items; probed 2026-10-20)
    ITEM_MOD_SPIRIT_SHORT           = "Spirit",
    ITEM_MOD_SPELL_POWER_SHORT      = "SpellPower",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "DPS",
    RESISTANCE0_NAME                = "Armor",
    -- Combined
    ITEM_MOD_AGI_STR_INT_SHORT = "AgiStrInt",  -- all-3 prismatic
    ITEM_MOD_AGI_STR_SHORT     = "AgiStr",
    ITEM_MOD_AGI_INT_SHORT     = "AgiInt",
    ITEM_MOD_STR_AGI_INT_SHORT = "AgiStrInt",
}

-- Default weights for stats not in the preset
local DEFAULT_WEIGHTS = {
    Stamina         = 0.0,
    Leech           = 0.10,
    Speed           = 0.05,
    Avoidance       = 0.05,
    Indestructible  = 0.0,
}

----------------------------------------------------------------------
-- Resolve the weight for a stat given the active weights table.
-- Primary stat gets a high baseline (1.0 effective).
----------------------------------------------------------------------
local function GetWeight(statName, weights, primaryStat)
    -- Primary stat handling
    if statName == primaryStat then return 1.0 end
    -- An explicit weight wins (Forever presets value off-primaries, e.g. Agility
    -- for a Warrior; retail presets only list secondaries, so this is a no-op there).
    if weights and weights[statName] then return weights[statName] end
    if statName == "Strength" or statName == "Agility" or statName == "Intellect" then
        -- Wrong primary for the spec — worth a small amount only (vendor / scrap)
        return 0.0
    end
    -- Combined primaries — if any matches player's primary, count it
    if statName == "AgiStrInt"
        or (statName == "AgiStr" and (primaryStat == "Agility" or primaryStat == "Strength"))
        or (statName == "AgiInt" and (primaryStat == "Agility" or primaryStat == "Intellect")) then
        return 1.0
    end
    -- Secondary or tertiary from weights table
    if weights and weights[statName] then return weights[statName] end
    -- Default for stats not in preset
    return DEFAULT_WEIGHTS[statName] or 0.0
end

----------------------------------------------------------------------
-- Score raw stat table.
-- statsTable: { ITEM_MOD_STRENGTH_SHORT = 124, ITEM_MOD_CRIT_RATING_SHORT = 89, ... }
-- weights:    { Mastery = 1.0, Crit = 0.95, ... } (the .weights subtable from a preset)
-- primaryStat: "Strength" / "Agility" / "Intellect"
----------------------------------------------------------------------
function Sc:ScoreStats(statsTable, weights, primaryStat)
    if not statsTable then return 0 end
    local score = 0
    local breakdown = {}
    for wowKey, value in pairs(statsTable) do
        local statName = STAT_KEY_MAP[wowKey]
        if statName and value and value > 0 then
            local w = GetWeight(statName, weights, primaryStat)
            local contribution = value * w
            score = score + contribution
            if contribution ~= 0 then
                breakdown[statName] = (breakdown[statName] or 0) + contribution
            end
        end
    end
    return score, breakdown
end

----------------------------------------------------------------------
-- Weapon DPS estimation (C_Item.GetItemStats doesn't include weapon damage)
-- Linear approximation: each ilvl point = ~0.55 DPS for 2H, 0.40 for 1H.
-- Weighted at 2.5x primary stat because melee abilities scale ~2x off wDPS.
----------------------------------------------------------------------
local WEAPON_EQUIP_LOCS = {
    INVTYPE_WEAPON = 0.40, INVTYPE_2HWEAPON = 0.55,
    INVTYPE_WEAPONMAINHAND = 0.40, INVTYPE_WEAPONOFFHAND = 0.40,
    INVTYPE_RANGED = 0.55, INVTYPE_RANGEDRIGHT = 0.55,
}
local WEAPON_DPS_WEIGHT = 2.5

local function WeaponDpsBonus(link, weights, primaryStat)
    -- Forever items report their real DPS as a stat (scored via the "DPS" weight).
    if VoidGear.IS_FOREVER then return 0 end
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(link)
    local dpsPerIlvl = equipLoc and WEAPON_EQUIP_LOCS[equipLoc]
    if not dpsPerIlvl then return 0 end
    -- casters don't hit with their weapon: its Intellect is already in the stats
    if primaryStat == "Intellect" then return 0 end
    local ilvl = GetDetailedItemLevelInfo(link) or 0
    local primaryWeight = (weights and weights[primaryStat]) or 1.0
    if primaryStat == "Strength" or primaryStat == "Agility" then
        primaryWeight = 1.0  -- primary stat always weighted at 1.0
    end
    return ilvl * dpsPerIlvl * WEAPON_DPS_WEIGHT * primaryWeight
end

----------------------------------------------------------------------
-- Detect if an item has a proc/use/equip effect (any GetItemSpell hit)
----------------------------------------------------------------------
function Sc:HasProc(link)
    if not link then return false end
    local _, spellID = C_Item.GetItemSpell(link)
    if spellID ~= nil and spellID > 0 then return true end
    -- GetItemSpell misses passive "Equip:" procs: read the tooltip for those
    local tt = C_TooltipInfo and C_TooltipInfo.GetHyperlink and C_TooltipInfo.GetHyperlink(link)
    for _, line in ipairs(tt and tt.lines or {}) do
        local t = line.leftText
        if t and not (issecretvalue and issecretvalue(t)) and (t:find("^Equip:") or t:find("^Use:")) then
            return true
        end
    end
    return false
end

----------------------------------------------------------------------
-- Trinket budget calibration — learns expected score-per-ilvl for THIS spec
-- by inspecting your equipped gear. Recalculated when gear changes.
--
-- Strategy:
--   1. If you have an equipped stat-stick trinket (no proc) — use score/ilvl directly
--   2. Otherwise use neck+rings average × 1.12 adjustment (jewelry has similar budget)
--   3. Hardcoded 0.50 fallback if neither available
----------------------------------------------------------------------
Sc.trinketBudgetPerIlvl = 0
local TRINKET_BUDGET_ADJUST = 1.12

function Sc:CalcStaticScore(link, weights, primaryStat)
    -- Stats + weapon DPS (no proc value) — used for budget calibration
    if not link then return 0 end
    local stats = C_Item.GetItemStats(link)
    if not stats then return 0 end
    local score = self:ScoreStats(stats, weights, primaryStat)
    score = score + WeaponDpsBonus(link, weights, primaryStat)
    return score
end

-- Are the trinkets / jewelry the calibration reads still loading? (Right after
-- login their stats can be missing, which would leave the fallback in place.)
function Sc:CalibrationPending()
    for _, slotID in ipairs({ 2, 11, 12, 13, 14 }) do
        local link = GetInventoryItemLink("player", slotID)
        local id = GetInventoryItemID("player", slotID)
        if id and not link then return true end   -- worn, link not ready yet
        if link then
            local _, spellID = C_Item.GetItemSpell(link)
            local cached = (not C_Item.IsItemDataCachedByID or C_Item.IsItemDataCachedByID(id))
                and (not spellID or not C_Spell.IsSpellDataCached or C_Spell.IsSpellDataCached(spellID))
            -- stats, plus the item + spell text HasProc reads for "Equip:"/"Use:"
            if not (C_Item.GetItemStats(link) and cached) then
                C_Item.RequestLoadItemDataByID(id)
                if spellID and C_Spell.RequestLoadSpellData then C_Spell.RequestLoadSpellData(spellID) end
                return true
            end
            -- a passive "Equip:" has no spell ID to wait on: the tooltip itself must be done
            local tt = C_TooltipInfo and C_TooltipInfo.GetHyperlink and C_TooltipInfo.GetHyperlink(link)
            if not (tt and tt.lines and #tt.lines >= 2) then return true end
            for _, line in ipairs(tt.lines) do
                if line.leftText == RETRIEVING_ITEM_INFO then return true end
            end
        end
    end
    return false
end

function Sc:RecalcTrinketBudget()
    local weights, primary = self:GetActiveContext()

    -- Priority 1: Equipped stat-stick trinket (no proc) — perfect calibration
    for _, slotID in ipairs({ 13, 14 }) do
        local link = GetInventoryItemLink("player", slotID)
        if link and not self:HasProc(link) then
            local score = self:CalcStaticScore(link, weights, primary)
            local ilvl = GetDetailedItemLevelInfo(link) or 0
            if score > 0 and ilvl > 0 then
                self.trinketBudgetPerIlvl = score / ilvl
                return self.trinketBudgetPerIlvl
            end
        end
    end

    -- Priority 2: Jewelry reference (neck + rings) with adjustment factor
    local total, count = 0, 0
    for _, slotID in ipairs({ 2, 11, 12 }) do
        local link = GetInventoryItemLink("player", slotID)
        if link then
            local score = self:CalcStaticScore(link, weights, primary)
            local ilvl = GetDetailedItemLevelInfo(link) or 0
            if score > 0 and ilvl > 0 then
                total = total + (score / ilvl)
                count = count + 1
            end
        end
    end
    if count > 0 then
        self.trinketBudgetPerIlvl = (total / count) * TRINKET_BUDGET_ADJUST
        return self.trinketBudgetPerIlvl
    end

    -- Priority 3: Hardcoded fallback
    self.trinketBudgetPerIlvl = 0.50
    return self.trinketBudgetPerIlvl
end

----------------------------------------------------------------------
-- Estimate trinket proc value via budget gap.
-- For a trinket with a proc/use effect, any ilvl budget NOT spent on visible
-- stats is attributed to the proc effect — that's its score contribution.
----------------------------------------------------------------------
function Sc:CalcProcValue(link, weights, primaryStat)
    if not link then return 0 end
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(link)
    if equipLoc ~= "INVTYPE_TRINKET" then return 0 end
    if not self:HasProc(link) then return 0 end

    local staticScore = self:CalcStaticScore(link, weights, primaryStat)
    local ilvl = GetDetailedItemLevelInfo(link) or 0
    if ilvl <= 0 or self.trinketBudgetPerIlvl <= 0 then return 0 end

    local expected = ilvl * self.trinketBudgetPerIlvl
    return math.max(0, expected - staticScore)
end

----------------------------------------------------------------------
-- Score an item by link — INCLUDES weapon DPS bonus AND trinket proc value.
-- This is the score function callers should use for upgrade comparisons.
-- Returns: score, breakdown, stats
----------------------------------------------------------------------
function Sc:ScoreLink(link, weights, primaryStat)
    if not link then return 0, {}, nil end
    local stats = C_Item.GetItemStats(link)
    if not stats then return 0, {}, nil end
    local statScore, breakdown = self:ScoreStats(stats, weights, primaryStat)
    local weaponBonus = WeaponDpsBonus(link, weights, primaryStat)

    -- Tier-2: read Use/Equip effects, sockets and set membership and value
    -- them (hybrid closed-form + flagged estimates). Falls back to the old
    -- budget-gap only if EffectValuer isn't loaded.
    local extra, extraDetails
    if VoidGear.EffectValuer then
        extra, extraDetails = VoidGear.EffectValuer:ValueExtras(
            link, weights, primaryStat, self.trinketBudgetPerIlvl)
    else
        extra = self:CalcProcValue(link, weights, primaryStat)
    end
    extra = extra or 0

    if weaponBonus > 0 then breakdown["WeaponDPS"] = weaponBonus end
    if extra > 0       then breakdown["Effects"]   = extra end
    return statScore + weaponBonus + extra, breakdown, stats, extraDetails
end

----------------------------------------------------------------------
-- Initialize — registers event to recalc trinket budget on gear change.
-- Called from PLAYER_LOGIN (Core.lua), so it calibrates now too: waiting for
-- PLAYER_LOGIN here never fired, and the gear isn't loaded yet at login.
----------------------------------------------------------------------
function Sc:Init()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    local debounce
    local function recalc(tries)
        -- gear still loading: calibrate once it has (a few tries, 1s apart)
        if VoidGear.Scorer:CalibrationPending() and tries < 10 then
            debounce = C_Timer.NewTimer(1, function() recalc(tries + 1) end)
            return
        end
        VoidGear.Scorer:RecalcTrinketBudget()
        if VoidGear.EffectValuer then VoidGear.EffectValuer:Invalidate() end
        -- an open panel was drawn with the old budget
        if _G.VoidGear_Panel and _G.VoidGear_Panel:IsShown() then VoidGear.UI:Refresh() end
    end
    local function schedule()
        if debounce then debounce:Cancel() end
        debounce = C_Timer.NewTimer(0.5, function() recalc(0) end)
    end
    f:SetScript("OnEvent", schedule)
    schedule()
end

----------------------------------------------------------------------
-- Compute upgrade percentage given current and candidate scores.
-- Returns delta (signed) and pct change.
----------------------------------------------------------------------
function Sc:Delta(currentScore, candidateScore)
    local d = candidateScore - currentScore
    local pct = 0
    if currentScore > 0 then pct = (d / currentScore) * 100 end
    return d, pct
end

----------------------------------------------------------------------
-- Convenience: get the active weights + primary stat in one call
----------------------------------------------------------------------
function Sc:GetActiveContext()
    local preset = VoidGear.StatWeights:GetCurrent()
    local primary = preset.primary
    if not primary or primary == "auto" then
        primary = VoidGear.Scanner:GetPrimaryStat()
    end
    return preset.weights, primary, preset
end
