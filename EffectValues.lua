----------------------------------------------------------------------
-- VoidGear EffectValues  (GENERATED -- do not hand-edit)
--
-- Per-spec trinket tiers from Blizzard's own API (2026-10-30): the share of the top
-- Mythic+ players of each spec who wear each trinket. S >= 30%, A >= 15%, B >= 7%, C >= 3%.
-- Read by EffectValuer (VoidGear) and VoidBags' trinket upgrade check.
-- Regenerate: voidscout-data/tools/cmd/stat-pull --effects-out ../../VoidGear/EffectValues.lua
----------------------------------------------------------------------
VoidGear = VoidGear or {}
VoidGear.EffectValues = VoidGear.EffectValues or { bySpec = {} }
VoidGear.EffectValues.source = "Top Mythic+ players' trinkets (Blizzard API), 2026-10-30"

-- Blood Death Knight, 56 players
VoidGear.EffectValues.bySpec[250] = { trinketsByName = {
    ["Voracious Heart of Ula'tek"] = "S",
    ["Zul'jin's Guillotine Technique"] = "S",
    ["Twisted Horror's Tendril"] = "A",
} }

-- Frost Death Knight, 54 players
VoidGear.EffectValues.bySpec[251] = { trinketsByName = {
    ["Voracious Heart of Ula'tek"] = "S",
    ["Twisted Horror's Tendril"] = "S",
    ["Zul'jin's Guillotine Technique"] = "A",
} }

-- Unholy Death Knight, 46 players
VoidGear.EffectValues.bySpec[252] = { trinketsByName = {
    ["Voracious Heart of Ula'tek"] = "S",
    ["Zul'jin's Guillotine Technique"] = "S",
    ["Twisted Horror's Tendril"] = "A",
    ["Keeper's Seething Core"] = "C",
} }

-- Devourer Demon Hunter, 53 players
VoidGear.EffectValues.bySpec[1480] = { trinketsByName = {
    ["Twisted Horror's Tendril"] = "S",
    ["Gebbo's Bottomless Bag"] = "S",
    ["Wavecaller's Seastone"] = "A",
    ["Freightrunner's Flask"] = "C",
} }

-- Havoc Demon Hunter, 51 players
VoidGear.EffectValues.bySpec[577] = { trinketsByName = {
    ["Zul'jin's Guillotine Technique"] = "S",
    ["Twisted Horror's Tendril"] = "S",
    ["Voracious Heart of Ula'tek"] = "A",
    ["Font of Venomous Rage"] = "C",
} }

-- Vengeance Demon Hunter, 47 players
VoidGear.EffectValues.bySpec[581] = { trinketsByName = {
    ["Zul'jin's Guillotine Technique"] = "S",
    ["Twisted Horror's Tendril"] = "S",
    ["Voracious Heart of Ula'tek"] = "A",
    ["First Mate's Shellward"] = "B",
    ["Keeper's Seething Core"] = "B",
    ["Gebbo's Bottomless Bag"] = "B",
    ["Lightbearer's Shield Fragment"] = "C",
} }

-- Balance Druid, 57 players
VoidGear.EffectValues.bySpec[102] = { trinketsByName = {
    ["Twisted Horror's Tendril"] = "S",
    ["Gebbo's Bottomless Bag"] = "S",
    ["Vile Vial of Volatile Venom"] = "A",
    ["Wavecaller's Seastone"] = "A",
    ["Hex Lord's Dooming Idol"] = "B",
    ["Freightrunner's Flask"] = "C",
} }

-- Feral Druid, 51 players
VoidGear.EffectValues.bySpec[103] = { trinketsByName = {
    ["Voracious Heart of Ula'tek"] = "S",
    ["Twisted Horror's Tendril"] = "S",
    ["Gebbo's Bottomless Bag"] = "C",
    ["Zul'jin's Guillotine Technique"] = "C",
} }

-- Guardian Druid, 56 players
VoidGear.EffectValues.bySpec[104] = { trinketsByName = {
    ["Twisted Horror's Tendril"] = "S",
    ["Voracious Heart of Ula'tek"] = "S",
    ["Keeper's Seething Core"] = "S",
    ["Gebbo's Bottomless Bag"] = "B",
} }

-- Restoration Druid, 55 players
VoidGear.EffectValues.bySpec[105] = { trinketsByName = {
    ["Soulcoiler Ritual Vessel"] = "S",
    ["Wavecaller's Seastone"] = "S",
    ["Unstable Felheart Crystal"] = "A",
    ["Gebbo's Bottomless Bag"] = "B",
    ["Sigil of the Impending Eclipse"] = "B",
    ["Hex Lord's Dooming Idol"] = "C",
    ["Twisted Horror's Tendril"] = "C",
} }

-- Augmentation Evoker, 51 players
VoidGear.EffectValues.bySpec[1473] = { trinketsByName = {
    ["Font of Venomous Rage"] = "S",
    ["Twisted Horror's Tendril"] = "S",
    ["Fang of Umbral Malignance"] = "S",
    ["Gebbo's Bottomless Bag"] = "B",
    ["Mindpiercer's Sigil"] = "B",
    ["Wavecaller's Seastone"] = "B",
} }

-- Devastation Evoker, 51 players
VoidGear.EffectValues.bySpec[1467] = { trinketsByName = {
    ["Gebbo's Bottomless Bag"] = "S",
    ["Twisted Horror's Tendril"] = "S",
    ["Wavecaller's Seastone"] = "A",
    ["Vile Vial of Volatile Venom"] = "B",
    ["Font of Venomous Rage"] = "B",
} }

-- Preservation Evoker, 57 players
VoidGear.EffectValues.bySpec[1468] = { trinketsByName = {
    ["Soulcoiler Ritual Vessel"] = "S",
    ["Gebbo's Bottomless Bag"] = "S",
    ["Wavecaller's Seastone"] = "A",
    ["Preternatural Antivenom"] = "B",
    ["Twisted Horror's Tendril"] = "B",
    ["Sigil of the Impending Eclipse"] = "B",
    ["Lightspire Core"] = "C",
    ["Unstable Felheart Crystal"] = "C",
    ["Fang of Umbral Malignance"] = "C",
} }

-- Beast Mastery Hunter, 54 players
VoidGear.EffectValues.bySpec[253] = { trinketsByName = {
    ["Twisted Horror's Tendril"] = "S",
    ["Voracious Heart of Ula'tek"] = "S",
    ["Gebbo's Bottomless Bag"] = "A",
    ["Font of Venomous Rage"] = "B",
    ["Keeper's Seething Core"] = "C",
    ["Zul'jin's Guillotine Technique"] = "C",
} }

-- Marksmanship Hunter, 51 players
VoidGear.EffectValues.bySpec[254] = { trinketsByName = {
    ["Voracious Heart of Ula'tek"] = "S",
    ["Twisted Horror's Tendril"] = "S",
    ["Font of Venomous Rage"] = "A",
    ["Gebbo's Bottomless Bag"] = "C",
    ["Venomous Gladiator's Insignia of Alacrity"] = "C",
    ["Venomous Gladiator's Medallion"] = "C",
} }

-- Survival Hunter, 53 players
VoidGear.EffectValues.bySpec[255] = { trinketsByName = {
    ["Voracious Heart of Ula'tek"] = "S",
    ["Twisted Horror's Tendril"] = "S",
    ["Zul'jin's Guillotine Technique"] = "A",
    ["Keeper's Seething Core"] = "B",
    ["Gebbo's Bottomless Bag"] = "C",
    ["Font of Venomous Rage"] = "C",
} }

-- Arcane Mage, 55 players
VoidGear.EffectValues.bySpec[62] = { trinketsByName = {
    ["Twisted Horror's Tendril"] = "S",
    ["Freightrunner's Flask"] = "S",
    ["Gebbo's Bottomless Bag"] = "S",
    ["Hex Lord's Dooming Idol"] = "A",
    ["Wavecaller's Seastone"] = "B",
} }

-- Fire Mage, 41 players
VoidGear.EffectValues.bySpec[63] = { trinketsByName = {
    ["Vile Vial of Volatile Venom"] = "S",
    ["Gebbo's Bottomless Bag"] = "S",
    ["Wavecaller's Seastone"] = "A",
    ["Hex Lord's Dooming Idol"] = "B",
    ["Twisted Horror's Tendril"] = "B",
    ["Stormbound Emblem of Dazar"] = "C",
} }

-- Frost Mage, 44 players
VoidGear.EffectValues.bySpec[64] = { trinketsByName = {
    ["Gebbo's Bottomless Bag"] = "S",
    ["Twisted Horror's Tendril"] = "S",
    ["Wavecaller's Seastone"] = "A",
    ["Freightrunner's Flask"] = "B",
    ["Mindpiercer's Sigil"] = "C",
    ["Lightspire Core"] = "C",
} }

-- Brewmaster Monk, 51 players
VoidGear.EffectValues.bySpec[268] = { trinketsByName = {
    ["Twisted Horror's Tendril"] = "S",
    ["Voracious Heart of Ula'tek"] = "S",
    ["Gebbo's Bottomless Bag"] = "S",
    ["Tumor of the Swarm"] = "A",
    ["Zul'jin's Guillotine Technique"] = "B",
    ["First Mate's Shellward"] = "C",
} }

-- Mistweaver Monk, 57 players
VoidGear.EffectValues.bySpec[270] = { trinketsByName = {
    ["Soulcoiler Ritual Vessel"] = "S",
    ["Wavecaller's Seastone"] = "S",
    ["Twisted Horror's Tendril"] = "A",
    ["Unstable Felheart Crystal"] = "B",
    ["Preternatural Antivenom"] = "B",
    ["Sigil of the Impending Eclipse"] = "C",
} }

-- Windwalker Monk, 59 players
VoidGear.EffectValues.bySpec[269] = { trinketsByName = {
    ["Voracious Heart of Ula'tek"] = "S",
    ["Twisted Horror's Tendril"] = "S",
    ["Zul'jin's Guillotine Technique"] = "B",
} }

-- Holy Paladin, 59 players
VoidGear.EffectValues.bySpec[65] = { trinketsByName = {
    ["Soulcoiler Ritual Vessel"] = "S",
    ["Gebbo's Bottomless Bag"] = "S",
    ["Preternatural Antivenom"] = "A",
    ["Twisted Horror's Tendril"] = "A",
    ["Wavecaller's Seastone"] = "B",
} }

-- Protection Paladin, 55 players
VoidGear.EffectValues.bySpec[66] = { trinketsByName = {
    ["Zul'jin's Guillotine Technique"] = "S",
    ["Voracious Heart of Ula'tek"] = "S",
    ["Twisted Horror's Tendril"] = "A",
    ["Gebbo's Bottomless Bag"] = "B",
    ["Resonant Bellowstone"] = "B",
    ["Keeper's Seething Core"] = "B",
    ["First Mate's Shellward"] = "C",
    ["Vile Vial of Volatile Venom"] = "C",
} }

-- Retribution Paladin, 59 players
VoidGear.EffectValues.bySpec[70] = { trinketsByName = {
    ["Voracious Heart of Ula'tek"] = "S",
    ["Zul'jin's Guillotine Technique"] = "S",
    ["Twisted Horror's Tendril"] = "C",
} }

-- Discipline Priest, 49 players
VoidGear.EffectValues.bySpec[256] = { trinketsByName = {
    ["Soulcoiler Ritual Vessel"] = "S",
    ["Wavecaller's Seastone"] = "S",
    ["Twisted Horror's Tendril"] = "A",
    ["Gebbo's Bottomless Bag"] = "B",
    ["Preternatural Antivenom"] = "C",
    ["Sigil of the Impending Eclipse"] = "C",
    ["Hex Lord's Dooming Idol"] = "C",
} }

-- Holy Priest, 56 players
VoidGear.EffectValues.bySpec[257] = { trinketsByName = {
    ["Soulcoiler Ritual Vessel"] = "S",
    ["Gebbo's Bottomless Bag"] = "S",
    ["Wavecaller's Seastone"] = "A",
    ["Unstable Felheart Crystal"] = "B",
    ["Preternatural Antivenom"] = "C",
    ["Twisted Horror's Tendril"] = "C",
} }

-- Shadow Priest, 58 players
VoidGear.EffectValues.bySpec[258] = { trinketsByName = {
    ["Twisted Horror's Tendril"] = "S",
    ["Hex Lord's Dooming Idol"] = "S",
    ["Gebbo's Bottomless Bag"] = "A",
    ["Freightrunner's Flask"] = "A",
    ["Wavecaller's Seastone"] = "A",
    ["Vile Vial of Volatile Venom"] = "B",
} }

-- Assassination Rogue, 14 players
VoidGear.EffectValues.bySpec[259] = { trinketsByName = {
    ["Twisted Horror's Tendril"] = "S",
    ["Voracious Heart of Ula'tek"] = "S",
} }

-- Outlaw Rogue, 49 players
VoidGear.EffectValues.bySpec[260] = { trinketsByName = {
    ["Zul'jin's Guillotine Technique"] = "S",
    ["Twisted Horror's Tendril"] = "S",
    ["Voracious Heart of Ula'tek"] = "S",
} }

-- Subtlety Rogue, 51 players
VoidGear.EffectValues.bySpec[261] = { trinketsByName = {
    ["Voracious Heart of Ula'tek"] = "S",
    ["Twisted Horror's Tendril"] = "S",
} }

-- Elemental Shaman, 59 players
VoidGear.EffectValues.bySpec[262] = { trinketsByName = {
    ["Twisted Horror's Tendril"] = "S",
    ["Gebbo's Bottomless Bag"] = "S",
    ["Vile Vial of Volatile Venom"] = "S",
    ["Wavecaller's Seastone"] = "C",
} }

-- Enhancement Shaman, 55 players
VoidGear.EffectValues.bySpec[263] = { trinketsByName = {
    ["Voracious Heart of Ula'tek"] = "S",
    ["Twisted Horror's Tendril"] = "S",
    ["Zul'jin's Guillotine Technique"] = "A",
    ["Vile Vial of Volatile Venom"] = "B",
    ["Gebbo's Bottomless Bag"] = "C",
} }

-- Restoration Shaman, 58 players
VoidGear.EffectValues.bySpec[264] = { trinketsByName = {
    ["Soulcoiler Ritual Vessel"] = "S",
    ["Unstable Felheart Crystal"] = "S",
    ["Twisted Horror's Tendril"] = "A",
    ["Gebbo's Bottomless Bag"] = "A",
    ["Preternatural Antivenom"] = "C",
    ["Venomous Gladiator's Insignia of Alacrity"] = "C",
    ["Venomous Gladiator's Medallion"] = "C",
} }

-- Affliction Warlock, 41 players
VoidGear.EffectValues.bySpec[265] = { trinketsByName = {
    ["Gebbo's Bottomless Bag"] = "S",
    ["Twisted Horror's Tendril"] = "S",
    ["Vile Vial of Volatile Venom"] = "A",
    ["Wavecaller's Seastone"] = "A",
    ["Hex Lord's Dooming Idol"] = "B",
    ["Stormbound Emblem of Dazar"] = "B",
} }

-- Demonology Warlock, 58 players
VoidGear.EffectValues.bySpec[266] = { trinketsByName = {
    ["Twisted Horror's Tendril"] = "S",
    ["Hex Lord's Dooming Idol"] = "S",
    ["Gebbo's Bottomless Bag"] = "S",
    ["Vile Vial of Volatile Venom"] = "A",
    ["Freightrunner's Flask"] = "C",
    ["Wavecaller's Seastone"] = "C",
} }

-- Destruction Warlock, 38 players
VoidGear.EffectValues.bySpec[267] = { trinketsByName = {
    ["Gebbo's Bottomless Bag"] = "S",
    ["Twisted Horror's Tendril"] = "S",
    ["Freightrunner's Flask"] = "S",
    ["Wavecaller's Seastone"] = "A",
    ["Font of Venomous Rage"] = "C",
} }

-- Arms Warrior, 57 players
VoidGear.EffectValues.bySpec[71] = { trinketsByName = {
    ["Zul'jin's Guillotine Technique"] = "S",
    ["Twisted Horror's Tendril"] = "S",
    ["Voracious Heart of Ula'tek"] = "S",
    ["Keeper's Seething Core"] = "B",
} }

-- Fury Warrior, 38 players
VoidGear.EffectValues.bySpec[72] = { trinketsByName = {
    ["Zul'jin's Guillotine Technique"] = "S",
    ["Voracious Heart of Ula'tek"] = "S",
    ["Twisted Horror's Tendril"] = "S",
    ["Keeper's Seething Core"] = "B",
} }

-- Protection Warrior, 51 players
VoidGear.EffectValues.bySpec[73] = { trinketsByName = {
    ["Zul'jin's Guillotine Technique"] = "S",
    ["Voracious Heart of Ula'tek"] = "S",
    ["Twisted Horror's Tendril"] = "S",
    ["Keeper's Seething Core"] = "A",
    ["Gebbo's Bottomless Bag"] = "B",
    ["First Mate's Shellward"] = "C",
} }
