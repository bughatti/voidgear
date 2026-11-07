----------------------------------------------------------------------
-- VoidGear StatWeights (logic)
-- Per-spec stat priority lookup + user customization.
-- Used by ItemScorer to evaluate gear.
--
-- The preset DATA (per-spec weights) lives in StatWeightsData.lua, which is
-- GENERATED from Blizzard's API (the stats the top Mythic+ players of each spec
-- wear) by voidscout-data/tools/cmd/stat-pull — regenerate after a patch/rework, not on a
-- schedule. Users can still override with /vgear custom or by editing
-- VoidGearCharDB.statWeights.custom.
----------------------------------------------------------------------
VoidGear = VoidGear or {}
local VG = VoidGear

-- `or {}` so load order vs StatWeightsData.lua doesn't matter (whichever
-- loads first creates the table; the other fills in presets / logic).
VG.StatWeights = VG.StatWeights or {}
local SW = VG.StatWeights
SW.presets = SW.presets or {}

----------------------------------------------------------------------
-- Normalize a class+spec into a preset key.
-- Class comes from UnitClass (uppercase, no spaces).
-- Spec comes from GetSpecializationInfo (e.g. "Beast Mastery") — we
-- uppercase + replace spaces with underscores so "Beast Mastery" matches
-- "BEAST_MASTERY".
----------------------------------------------------------------------
local function MakePresetKey(class, specName)
    if not class or class == "" then return nil end
    if not specName or specName == "" then return nil end
    return class .. "_" .. specName:upper():gsub(" ", "_")
end

----------------------------------------------------------------------
-- Get the user's currently active weights (saved per character)
----------------------------------------------------------------------
function SW:GetCurrent()
    VoidGearCharDB = VoidGearCharDB or {}
    VoidGearCharDB.statWeights = VoidGearCharDB.statWeights or {}

    if VoidGearCharDB.statWeights.custom then
        return VoidGearCharDB.statWeights.custom
    end

    local presetKey = VoidGearCharDB.statWeights.preset
    if presetKey and self.presets[presetKey] then
        return self.presets[presetKey]
    end

    -- WoW Forever: no specs -- per-class leveling weights.
    local _, class = UnitClass("player")
    if VG.IS_FOREVER then
        return self.forever[class] or self.forever.WARRIOR
    end

    -- Auto-detect by class + spec
    local specIndex = GetSpecialization and GetSpecialization() or 0
    local specName
    if specIndex and specIndex > 0 then
        specName = select(2, GetSpecializationInfo(specIndex))  -- 2nd return = name
    end
    local key = MakePresetKey(class, specName)
    if key and self.presets[key] then
        return self.presets[key]
    end

    -- Role-aware fallback
    local role = specIndex > 0 and (GetSpecializationRole and GetSpecializationRole(specIndex)) or nil
    if role == "TANK" then return self.presets["DEFAULT_TANK"] end
    if role == "HEALER" then return self.presets["DEFAULT_HEALER"] end
    return self.presets["DEFAULT_DPS"]
end

----------------------------------------------------------------------
-- WoW Forever leveling weights (classic stats, no specs). Primary = 1.0.
-- Leveling-oriented: weapon DPS is huge for melee (white hits are most of
-- your damage), Stamina keeps you alive solo, Spirit = less downtime for
-- casters. Armor is per point (a piece has ~50-100), so it's a tiebreaker.
-- Approximate by design -- the goal is "is this drop better", not a sim.
----------------------------------------------------------------------
-- Attack power: Classic-style, 1 strength (or a rogue's agility) is worth about 2 attack
-- power to these classes, so AP weighs about half the primary. Plain "+attack power" raises
-- melee AND ranged attack power, so hunters weigh it like ranged AP (Codex review).
SW.forever = {
    WARRIOR = { label = "Warrior (leveling)", primary = "Strength",
        weights = { Agility = 0.5, Stamina = 0.35, AttackPower = 0.5, DPS = 3.0, Armor = 0.02 } },
    PALADIN = { label = "Paladin (leveling)", primary = "Strength",
        weights = { Intellect = 0.35, Stamina = 0.35, Agility = 0.25, Spirit = 0.15, SpellPower = 0.3, AttackPower = 0.5, DPS = 3.0, Armor = 0.02 } },
    HUNTER  = { label = "Hunter (leveling)", primary = "Agility",
        weights = { Intellect = 0.3, Stamina = 0.35, Spirit = 0.1, RangedAttackPower = 0.5, AttackPower = 0.5, DPS = 2.0, Armor = 0.02 } },
    ROGUE   = { label = "Rogue (leveling)", primary = "Agility",
        weights = { Strength = 0.5, Stamina = 0.35, AttackPower = 0.5, DPS = 3.0, Armor = 0.02 } },
    SHAMAN  = { label = "Shaman (leveling)", primary = "Strength",
        weights = { Agility = 0.4, Intellect = 0.5, Stamina = 0.35, Spirit = 0.2, SpellPower = 0.4, AttackPower = 0.4, DPS = 3.0, Armor = 0.02 } },
    DRUID   = { label = "Druid (leveling)", primary = "Agility",
        weights = { Strength = 0.8, Intellect = 0.5, Stamina = 0.35, Spirit = 0.3, SpellPower = 0.4, AttackPower = 0.5, Armor = 0.02 } },
    MAGE    = { label = "Mage (leveling)", primary = "Intellect",
        weights = { Spirit = 0.5, Stamina = 0.4, SpellPower = 0.9, Armor = 0.01 } },
    PRIEST  = { label = "Priest (leveling)", primary = "Intellect",
        weights = { Spirit = 0.7, Stamina = 0.4, SpellPower = 0.9, Armor = 0.01 } },
    WARLOCK = { label = "Warlock (leveling)", primary = "Intellect",
        weights = { Stamina = 0.6, Spirit = 0.3, SpellPower = 0.9, Armor = 0.01 } },
}

----------------------------------------------------------------------
-- Set the active preset by key
----------------------------------------------------------------------
function SW:SetPreset(key)
    VoidGearCharDB = VoidGearCharDB or {}
    VoidGearCharDB.statWeights = VoidGearCharDB.statWeights or {}
    VoidGearCharDB.statWeights.preset = key
    VoidGearCharDB.statWeights.custom = nil
    -- the trinket budget and cached effect values were worked out with the old
    -- weights: redo them, or scores mix the two
    if VoidGear.Scorer and VoidGear.Scorer.RecalcTrinketBudget then VoidGear.Scorer:RecalcTrinketBudget() end
    if VoidGear.EffectValuer then VoidGear.EffectValuer:Invalidate() end
end

----------------------------------------------------------------------
-- List all available presets (sorted by label) — flat list
----------------------------------------------------------------------
function SW:ListPresets()
    local result = {}
    for key, p in pairs(self.presets) do
        table.insert(result, { key = key, label = p.label, note = p.note })
    end
    table.sort(result, function(a, b) return a.label < b.label end)
    return result
end

----------------------------------------------------------------------
-- Class display names (uppercase classFile → user-facing)
----------------------------------------------------------------------
SW.CLASS_DISPLAY = {
    WARRIOR     = "Warrior",
    PALADIN     = "Paladin",
    HUNTER      = "Hunter",
    ROGUE       = "Rogue",
    PRIEST      = "Priest",
    DEATHKNIGHT = "Death Knight",
    SHAMAN      = "Shaman",
    MAGE        = "Mage",
    WARLOCK     = "Warlock",
    MONK        = "Monk",
    DRUID       = "Druid",
    DEMONHUNTER = "Demon Hunter",
    EVOKER      = "Evoker",
}

-- Sort order so the menu lists classes alphabetically by display name
local CLASS_ORDER = {
    "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER",
    "MAGE", "MONK", "PALADIN", "PRIEST", "ROGUE", "SHAMAN",
    "WARLOCK", "WARRIOR",
}

----------------------------------------------------------------------
-- Strip the class name out of a preset label to make a short submenu
-- entry. "Blood DK (Tank)" → "Blood (Tank)". Falls back to raw label.
----------------------------------------------------------------------
local CLASS_LABEL_FRAGMENTS = {
    "DK", "DH", "Druid", "Evoker", "Hunter", "Mage", "Monk",
    "Paladin", "Priest", "Rogue", "Shaman", "Warlock", "Warrior",
}

local function ShortenLabel(label)
    if not label then return "?" end
    local short = label
    for _, frag in ipairs(CLASS_LABEL_FRAGMENTS) do
        -- Remove " <frag> " or " <frag>$" with surrounding spaces
        short = short:gsub("%s+" .. frag .. "%s+", " ")
        short = short:gsub("%s+" .. frag .. "$", "")
    end
    -- Collapse repeated spaces
    short = short:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return short
end

----------------------------------------------------------------------
-- List presets grouped by class. Returns:
--   {
--     { class = "DEATHKNIGHT", display = "Death Knight",
--       presets = { {key, label, specLabel, note}, ... } },
--     ...
--     { class = "_DEFAULTS", display = "Defaults",
--       presets = { ... } },
--   }
----------------------------------------------------------------------
function SW:ListPresetsByClass()
    local byClass = {}
    local defaults = {}

    for key, p in pairs(self.presets) do
        local class = key:match("^([^_]+)_")
        if class == "DEFAULT" then
            table.insert(defaults, {
                key = key, label = p.label, specLabel = p.label, note = p.note,
            })
        elseif self.CLASS_DISPLAY[class] then
            byClass[class] = byClass[class] or {}
            table.insert(byClass[class], {
                key       = key,
                label     = p.label,
                specLabel = ShortenLabel(p.label),
                note      = p.note,
            })
        end
    end

    -- Sort presets within each class by their short label
    for _, list in pairs(byClass) do
        table.sort(list, function(a, b) return a.specLabel < b.specLabel end)
    end
    table.sort(defaults, function(a, b) return a.label < b.label end)

    local result = {}
    for _, class in ipairs(CLASS_ORDER) do
        if byClass[class] then
            table.insert(result, {
                class   = class,
                display = self.CLASS_DISPLAY[class],
                presets = byClass[class],
            })
        end
    end
    if #defaults > 0 then
        table.insert(result, {
            class   = "_DEFAULTS",
            display = "Defaults",
            presets = defaults,
        })
    end
    return result
end
