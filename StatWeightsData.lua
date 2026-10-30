----------------------------------------------------------------------
-- VoidGear StatWeightsData  (GENERATED -- do not hand-edit)
--
-- Per-spec secondary stat weights from Blizzard's own API (2026-10-30): the secondary
-- stats the top Mythic+ players of each spec wear, summed over their equipped gear.
-- The data sets the ORDER; weights are a fixed band by rank (1, 0.9, 0.8, 0.55).
-- Regenerate: voidscout-data/tools/cmd/stat-pull --gear-out ../../VoidGear/StatWeightsData.lua
----------------------------------------------------------------------
VoidGear = VoidGear or {}
VoidGear.StatWeights = VoidGear.StatWeights or {}
VoidGear.StatWeights.generated = "2026-10-30"
VoidGear.StatWeights.presets = {
    ["DEATHKNIGHT_BLOOD"] = { label = "Blood Death Knight (Tank)", primary = "Strength", weights = { Haste = 1, Crit = 0.9, Mastery = 0.8, Versatility = 0.55 } },  -- 56 players
    ["DEATHKNIGHT_FROST"] = { label = "Frost Death Knight (DPS)", primary = "Strength", weights = { Mastery = 1, Crit = 0.9, Haste = 0.8, Versatility = 0.55 } },  -- 54 players
    ["DEATHKNIGHT_UNHOLY"] = { label = "Unholy Death Knight (DPS)", primary = "Strength", weights = { Crit = 1, Mastery = 0.9, Haste = 0.8, Versatility = 0.55 } },  -- 46 players
    ["DEMONHUNTER_DEVOURER"] = { label = "Devourer Demon Hunter (DPS)", primary = "Intellect", weights = { Mastery = 1, Haste = 0.9, Crit = 0.8, Versatility = 0.55 } },  -- 53 players
    ["DEMONHUNTER_HAVOC"] = { label = "Havoc Demon Hunter (DPS)", primary = "Agility", weights = { Mastery = 1, Crit = 0.9, Haste = 0.8, Versatility = 0.55 } },  -- 51 players
    ["DEMONHUNTER_VENGEANCE"] = { label = "Vengeance Demon Hunter (Tank)", primary = "Agility", weights = { Haste = 1, Crit = 0.9, Mastery = 0.8, Versatility = 0.55 } },  -- 47 players
    ["DRUID_BALANCE"] = { label = "Balance Druid (DPS)", primary = "Intellect", weights = { Mastery = 1, Haste = 0.9, Crit = 0.8, Versatility = 0.55 } },  -- 57 players
    ["DRUID_FERAL"] = { label = "Feral Druid (DPS)", primary = "Agility", weights = { Mastery = 1, Haste = 0.9, Crit = 0.8, Versatility = 0.55 } },  -- 51 players
    ["DRUID_GUARDIAN"] = { label = "Guardian Druid (Tank)", primary = "Agility", weights = { Haste = 1, Crit = 0.9, Mastery = 0.8, Versatility = 0.55 } },  -- 56 players
    ["DRUID_RESTORATION"] = { label = "Restoration Druid (Healer)", primary = "Intellect", weights = { Haste = 1, Mastery = 0.9, Versatility = 0.8, Crit = 0.55 } },  -- 55 players
    ["EVOKER_AUGMENTATION"] = { label = "Augmentation Evoker (DPS)", primary = "Intellect", weights = { Mastery = 1, Crit = 0.9, Haste = 0.8, Versatility = 0.55 } },  -- 51 players
    ["EVOKER_DEVASTATION"] = { label = "Devastation Evoker (DPS)", primary = "Intellect", weights = { Crit = 1, Mastery = 0.9, Haste = 0.8, Versatility = 0.55 } },  -- 51 players
    ["EVOKER_PRESERVATION"] = { label = "Preservation Evoker (Healer)", primary = "Intellect", weights = { Haste = 1, Crit = 0.9, Mastery = 0.8, Versatility = 0.55 } },  -- 57 players
    ["HUNTER_BEAST_MASTERY"] = { label = "Beast Mastery Hunter (DPS)", primary = "Agility", weights = { Mastery = 1, Crit = 0.9, Haste = 0.8, Versatility = 0.55 } },  -- 54 players
    ["HUNTER_MARKSMANSHIP"] = { label = "Marksmanship Hunter (DPS)", primary = "Agility", weights = { Crit = 1, Mastery = 0.9, Haste = 0.8, Versatility = 0.55 } },  -- 51 players
    ["HUNTER_SURVIVAL"] = { label = "Survival Hunter (DPS)", primary = "Agility", weights = { Mastery = 1, Crit = 0.9, Haste = 0.8, Versatility = 0.55 } },  -- 53 players
    ["MAGE_ARCANE"] = { label = "Arcane Mage (DPS)", primary = "Intellect", weights = { Haste = 1, Crit = 0.9, Mastery = 0.8, Versatility = 0.55 } },  -- 55 players
    ["MAGE_FIRE"] = { label = "Fire Mage (DPS)", primary = "Intellect", weights = { Haste = 1, Mastery = 0.9, Versatility = 0.8, Crit = 0.55 } },  -- 41 players
    ["MAGE_FROST"] = { label = "Frost Mage (DPS)", primary = "Intellect", weights = { Mastery = 1, Crit = 0.9, Haste = 0.8, Versatility = 0.55 } },  -- 44 players
    ["MONK_BREWMASTER"] = { label = "Brewmaster Monk (Tank)", primary = "Agility", weights = { Crit = 1, Versatility = 0.9, Mastery = 0.8, Haste = 0.55 } },  -- 51 players
    ["MONK_MISTWEAVER"] = { label = "Mistweaver Monk (Healer)", primary = "Intellect", weights = { Haste = 1, Mastery = 0.9, Crit = 0.8, Versatility = 0.55 } },  -- 57 players
    ["MONK_WINDWALKER"] = { label = "Windwalker Monk (DPS)", primary = "Agility", weights = { Mastery = 1, Haste = 0.9, Crit = 0.8, Versatility = 0.55 } },  -- 59 players
    ["PALADIN_HOLY"] = { label = "Holy Paladin (Healer)", primary = "Intellect", weights = { Haste = 1, Crit = 0.9, Versatility = 0.8, Mastery = 0.55 } },  -- 59 players
    ["PALADIN_PROTECTION"] = { label = "Protection Paladin (Tank)", primary = "Strength", weights = { Crit = 1, Haste = 0.9, Mastery = 0.8, Versatility = 0.55 } },  -- 55 players
    ["PALADIN_RETRIBUTION"] = { label = "Retribution Paladin (DPS)", primary = "Strength", weights = { Mastery = 1, Crit = 0.9, Haste = 0.8, Versatility = 0.55 } },  -- 59 players
    ["PRIEST_DISCIPLINE"] = { label = "Discipline Priest (Healer)", primary = "Intellect", weights = { Haste = 1, Mastery = 0.9, Crit = 0.8, Versatility = 0.55 } },  -- 49 players
    ["PRIEST_HOLY"] = { label = "Holy Priest (Healer)", primary = "Intellect", weights = { Haste = 1, Crit = 0.9, Mastery = 0.8, Versatility = 0.55 } },  -- 56 players
    ["PRIEST_SHADOW"] = { label = "Shadow Priest (DPS)", primary = "Intellect", weights = { Mastery = 1, Haste = 0.9, Crit = 0.8, Versatility = 0.55 } },  -- 58 players
    ["ROGUE_ASSASSINATION"] = { label = "Assassination Rogue (DPS)", primary = "Agility", weights = { Mastery = 1, Crit = 0.9, Haste = 0.8, Versatility = 0.55 } },  -- 14 players
    ["ROGUE_OUTLAW"] = { label = "Outlaw Rogue (DPS)", primary = "Agility", weights = { Crit = 1, Haste = 0.9, Versatility = 0.8, Mastery = 0.55 } },  -- 49 players
    ["ROGUE_SUBTLETY"] = { label = "Subtlety Rogue (DPS)", primary = "Agility", weights = { Mastery = 1, Crit = 0.9, Haste = 0.8, Versatility = 0.55 } },  -- 51 players
    ["SHAMAN_ELEMENTAL"] = { label = "Elemental Shaman (DPS)", primary = "Intellect", weights = { Mastery = 1, Crit = 0.9, Haste = 0.8, Versatility = 0.55 } },  -- 59 players
    ["SHAMAN_ENHANCEMENT"] = { label = "Enhancement Shaman (DPS)", primary = "Agility", weights = { Mastery = 1, Haste = 0.9, Crit = 0.8, Versatility = 0.55 } },  -- 55 players
    ["SHAMAN_RESTORATION"] = { label = "Restoration Shaman (Healer)", primary = "Intellect", weights = { Crit = 1, Haste = 0.9, Versatility = 0.8, Mastery = 0.55 } },  -- 58 players
    ["WARLOCK_AFFLICTION"] = { label = "Affliction Warlock (DPS)", primary = "Intellect", weights = { Haste = 1, Crit = 0.9, Mastery = 0.8, Versatility = 0.55 } },  -- 41 players
    ["WARLOCK_DEMONOLOGY"] = { label = "Demonology Warlock (DPS)", primary = "Intellect", weights = { Crit = 1, Haste = 0.9, Mastery = 0.8, Versatility = 0.55 } },  -- 58 players
    ["WARLOCK_DESTRUCTION"] = { label = "Destruction Warlock (DPS)", primary = "Intellect", weights = { Haste = 1, Mastery = 0.9, Crit = 0.8, Versatility = 0.55 } },  -- 38 players
    ["WARRIOR_ARMS"] = { label = "Arms Warrior (DPS)", primary = "Strength", weights = { Crit = 1, Haste = 0.9, Mastery = 0.8, Versatility = 0.55 } },  -- 57 players
    ["WARRIOR_FURY"] = { label = "Fury Warrior (DPS)", primary = "Strength", weights = { Mastery = 1, Haste = 0.9, Crit = 0.8, Versatility = 0.55 } },  -- 38 players
    ["WARRIOR_PROTECTION"] = { label = "Protection Warrior (Tank)", primary = "Strength", weights = { Haste = 1, Crit = 0.9, Mastery = 0.8, Versatility = 0.55 } },  -- 51 players

    -- Fallbacks for an unknown class/spec: the average of every spec in that role.
    ["DEFAULT_DPS"] = { label = "Default DPS (average)", primary = "auto", weights = { Mastery = 1, Crit = 0.9, Haste = 0.8, Versatility = 0.55 } },  -- 27 specs
    ["DEFAULT_TANK"] = { label = "Default Tank (average)", primary = "auto", weights = { Haste = 1, Crit = 0.9, Mastery = 0.8, Versatility = 0.55 } },  -- 6 specs
    ["DEFAULT_HEALER"] = { label = "Default Healer (average)", primary = "auto", weights = { Haste = 1, Crit = 0.9, Mastery = 0.8, Versatility = 0.55 } },  -- 7 specs
}
