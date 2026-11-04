----------------------------------------------------------------------
-- VoidGear Spares -- keep, sell, disenchant or vendor: every spare piece of
-- gear on your characters and in the warband bank, judged against ALL your
-- characters (Roster.lua), not just the one you're on. The user asked
-- (2026-11-03): "a crap ton of gear on all 4 main char and a crap ton in the
-- warband bank ... disenchant or save for any potential char".
--
-- Where the gear is: VoidBags' record of every character's bags, its bank
-- (saved when that character last had the bank open) and the warband bank
-- (optional; without VoidBags, only this character's bags), this
-- character's bags read live.
--
-- Per piece, first match wins:
--   1. older expansion          -> Vendor (its materials don't help Midnight Enchanting)
--   2. an upgrade for one of your characters, or within NEAR of what it wears
--                               -> Keep ("+4% for Vede (Unholy)")
--   3. its look isn't collected -> Keep (wear it once, then disenchant)
--   4. BoE worth more on the AH than disenchanted -> Sell
--   5. a character with Enchanting can take it -> Disenchant (which one, and
--      whether it has to be sent there first)
--   6. else                     -> Vendor (soulbound to a character without Enchanting)
-- Soulbound gear only counts for its owner; warbound / BoE gear and the
-- warband bank's count for everyone. No "maybe someday" pile: new characters
-- out-gear old pieces within a few levels.
----------------------------------------------------------------------
VoidGear = VoidGear or {}
local SP = {}
VoidGear.Spares = SP

local GetDetailedItemLevelInfo = C_Item.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo

local NEAR = 0.97   -- within 3% of what a character wears still counts as worth keeping
local OLD_ILVL = 200   -- below this, older-expansion gear is old (Midnight leveling gear starts above it)

-- Midnight disenchanting by quality (green / blue / epic), lowest rank first.
-- One per piece is an estimate until VoidProf learns real yields.
local DE_MAT = {
    [2] = { 243599, 243600 },   -- Eversinging Dust
    [3] = { 243602, 243603 },   -- Radiant Shard
    [4] = { 243605, 243606 },   -- Dawn Crystal
}
SP.DE_MAT = DE_MAT

local SLOT_OF = {
    INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5,
    INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10,
    INVTYPE_FINGER = 11, INVTYPE_TRINKET = 13, INVTYPE_CLOAK = 15,
    INVTYPE_WEAPON = 16, INVTYPE_2HWEAPON = 16, INVTYPE_WEAPONMAINHAND = 16,
    INVTYPE_RANGED = 16, INVTYPE_RANGEDRIGHT = 16,
    INVTYPE_WEAPONOFFHAND = 17, INVTYPE_SHIELD = 17, INVTYPE_HOLDABLE = 17,
}
-- body armor: only the class's own armor type can wear it
local BODY = { INVTYPE_HEAD = true, INVTYPE_SHOULDER = true, INVTYPE_CHEST = true, INVTYPE_ROBE = true,
    INVTYPE_WAIST = true, INVTYPE_LEGS = true, INVTYPE_FEET = true, INVTYPE_WRIST = true, INVTYPE_HAND = true }
-- slots with a look to collect (not jewelry or trinkets)
local LOOK = { INVTYPE_CLOAK = true, INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true,
    INVTYPE_HOLDABLE = true }
for k in pairs(BODY) do LOOK[k] = true end

local ARMOR = { WARRIOR = 4, PALADIN = 4, DEATHKNIGHT = 4, HUNTER = 3, SHAMAN = 3, EVOKER = 3,
    ROGUE = 2, DRUID = 2, MONK = 2, DEMONHUNTER = 2, PRIEST = 1, MAGE = 1, WARLOCK = 1 }
local SHIELD = { WARRIOR = true, PALADIN = true, SHAMAN = true }
local function set(...) local t = {} for _, v in ipairs({ ... }) do t[v] = true end return t end
-- Weapon subclasses each class can use (Enum.ItemWeaponSubclass numbers).
local WEAPONS = {
    WARRIOR = set(0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 18),
    PALADIN = set(0, 1, 4, 5, 6, 7, 8),
    DEATHKNIGHT = set(0, 1, 4, 5, 6, 7, 8),
    HUNTER = set(0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 18),
    SHAMAN = set(0, 1, 4, 5, 10, 13, 15),
    EVOKER = set(0, 1, 4, 5, 7, 8, 10, 13, 15),
    ROGUE = set(0, 4, 7, 13, 15),
    DRUID = set(4, 5, 6, 10, 13, 15),
    MONK = set(0, 4, 6, 7, 10, 13),
    DEMONHUNTER = set(0, 7, 9, 13, 15),
    PRIEST = set(4, 10, 15, 19),
    MAGE = set(7, 10, 15, 19),
    WARLOCK = set(7, 10, 15, 19),
}
local PRIMARY_KEY = { ITEM_MOD_STRENGTH_SHORT = "Strength", ITEM_MOD_AGILITY_SHORT = "Agility",
    ITEM_MOD_INTELLECT_SHORT = "Intellect" }
-- combined main stats: which mains each one counts as
local MULTI_KEY = {
    ITEM_MOD_AGI_STR_INT_SHORT = { Agility = true, Strength = true, Intellect = true },
    ITEM_MOD_STR_AGI_INT_SHORT = { Agility = true, Strength = true, Intellect = true },
    ITEM_MOD_AGI_STR_SHORT = { Agility = true, Strength = true },
    ITEM_MOD_AGI_INT_SHORT = { Agility = true, Intellect = true },
}

local dupName = {}   -- names you have on more than one realm: shown as Name-Realm
local function shortName(key)
    if not key then return "?" end
    local name = key:match("^([^%-]+)") or key
    return dupName[name] and key or name
end
SP.ShortName = shortName

-- VoidBags' "Name-Realm" as a roster key. Two statements on purpose: an
-- `x and s:match()` keeps only match's first value, which lost the realm.
local function vbKey(c)
    if type(c) ~= "table" or type(c.displayKey) ~= "string" then return nil end
    local name, realm = c.displayKey:match("^([^%-]+)%-(.+)$")
    return name and VoidGear.Roster:Key(name, realm)
end

----------------------------------------------------------------------
-- Where the spare gear is
----------------------------------------------------------------------
-- Can this item go into the warband bank, i.e. to your other characters?
-- (Warbound and unbound BoE yes; soulbound, or warbound-until-equipped that
-- was worn, no.) nil = can't tell.
local function warbandOK(loc)
    if not (loc and C_Bank and C_Bank.IsItemAllowedInBankType and Enum.BankType) then return nil end
    local ok, yes = pcall(C_Bank.IsItemAllowedInBankType, Enum.BankType.Account, loc)
    if ok then return yes and true or false end
    return nil
end

-- { { link, id, owner = "Name-Realm" | "warband", bound = true/false/nil, wb = see warbandOK } }
-- bound: this character's bags are read live (C_Item.IsBound); another
-- character's are unknown (nil), as a BoE it once wore is soulbound now.
local function collect()
    local R = VoidGear.Roster
    local me = R:Key()
    local out = {}
    local function add(link, id, owner, bound, inBank, wb)
        if type(link) == "string" and id then
            out[#out + 1] = { link = link, id = id, owner = owner, bound = bound, bank = inBank, wb = wb }
        end
    end
    local vb = type(_G.VoidBagsDB) == "table" and _G.VoidBagsDB
    if vb and type(vb.characters) == "table" then
        local seen = {}
        for _, c in pairs(vb.characters) do
            local key = vbKey(c)
            if key and not seen[key] then
                seen[key] = true
                -- bags: this character's are read live below
                if key ~= me and type(c.bags) == "table" then
                    for _, it in ipairs(c.bags) do add(it.link, it.id, key, nil, nil, it.wb) end
                end
                -- the character bank, as VoidBags saved it when it was last open
                if type(c.bank) == "table" then
                    for _, it in ipairs(c.bank) do add(it.link, it.id, key, nil, true, it.wb) end
                end
            end
        end
        if type(vb.warband) == "table" and type(vb.warband.items) == "table" then
            for _, it in ipairs(vb.warband.items) do add(it.link, it.id, "warband") end
        end
    end
    -- this character: its bags right now
    for bag = 0, (Enum.BagIndex and Enum.BagIndex.ReagentBag or 5) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and not (issecretvalue and issecretvalue(info.itemID)) then
                local loc = ItemLocation and ItemLocation:CreateFromBagAndSlot(bag, slot)
                local ok, bound = pcall(C_Item.IsBound, loc)
                local before = #out
                add(C_Container.GetContainerItemLink(bag, slot), info.itemID, me, ok and bound or info.isBound)
                if #out > before then   -- no link yet: nothing was added
                    out[#out].loc = loc   -- for the Catalyst check (this character only)
                    out[#out].wb = warbandOK(loc)
                    out[#out].bag, out[#out].slot = bag, slot   -- for the Disenchant / deposit buttons
                end
            end
        end
    end
    return out
end

-- Has Enchanting: the roster knows (characters with this VoidGear), else VoidBags' record.
local function enchanter(key)
    local rec = VoidGear.Roster:All()[key]
    if rec and rec.enchanter ~= nil then return rec.enchanter end
    local vb = type(_G.VoidBagsDB) == "table" and _G.VoidBagsDB
    for _, c in pairs(vb and vb.characters or {}) do
        if vbKey(c) == key then
            return type(c.professions) == "table" and (c.professions.Enchanting or c.professions[333]) and true or false
        end
    end
    return false
end

-- Every character you have that VoidGear or VoidBags knows.
local function everyone()
    local keys, seen = {}, {}
    for key in pairs(VoidGear.Roster:All()) do
        if not seen[key] then seen[key] = true; keys[#keys + 1] = key end
    end
    local vb = type(_G.VoidBagsDB) == "table" and _G.VoidBagsDB
    for _, c in pairs(vb and vb.characters or {}) do
        local key = vbKey(c)
        if key and not seen[key] then seen[key] = true; keys[#keys + 1] = key end
    end
    return keys
end

----------------------------------------------------------------------
-- Would one of your characters wear it?
----------------------------------------------------------------------
local pending       -- item data still loading this pass
local itemPending   -- ... for the item being judged: it waits, no verdict yet

local function stats(link)
    local s = C_Item.GetItemStats(link)
    if not s then
        pending, itemPending = true, true
        local id = C_Item.GetItemInfoInstant(link)
        if id then C_Item.RequestLoadItemDataByID(id) end
    end
    return s
end

-- An item's main stats, as the tooltip lists them: { Agility = 114, Intellect = 114 }.
-- Not from C_Item.GetItemStats: on an item with two or three main stats (leather,
-- mail and plate pieces, many trinkets) it reports only the logged-in class's one,
-- so the same piece scored differently on every character (2026-11-03). The tooltip
-- lists them all (the inactive ones greyed). {} = none; nil = tooltip not loaded yet.
local primCache = {}
local STAT_WORD
local function primariesOf(link)
    if not link then return nil end
    if primCache[link] then return primCache[link] end
    if not STAT_WORD then
        STAT_WORD = {}
        if SPELL_STAT1_NAME then STAT_WORD[SPELL_STAT1_NAME] = "Strength" end
        if SPELL_STAT2_NAME then STAT_WORD[SPELL_STAT2_NAME] = "Agility" end
        if SPELL_STAT4_NAME then STAT_WORD[SPELL_STAT4_NAME] = "Intellect" end
    end
    local tip = C_TooltipInfo and C_TooltipInfo.GetHyperlink and C_TooltipInfo.GetHyperlink(link)
    if not (tip and tip.lines and #tip.lines > 1) then
        pending, itemPending = true, true
        return nil
    end
    local out = {}
    for _, line in ipairs(tip.lines) do
        local t = line.leftText
        if type(t) == "string" and not (issecretvalue and issecretvalue(t)) then
            local n, word = t:match("^%+([%d,%.]+) (.+)$")
            local stat = word and STAT_WORD[word]
            if stat then out[stat] = tonumber((n:gsub("[,%.]", ""))) or 0 end
        end
    end
    primCache[link] = out
    return out
end
-- GetItemStats with the main stat set to `primary` when the item offers it (and
-- dropped when it doesn't): what this item gives THAT character.
local MAIN_KEY = { Strength = "ITEM_MOD_STRENGTH_SHORT", Agility = "ITEM_MOD_AGILITY_SHORT",
    Intellect = "ITEM_MOD_INTELLECT_SHORT" }
local function statsAs(link, primary)
    local raw = C_Item.GetItemStats(link)
    local prim = primariesOf(link)
    if not (raw and prim) then return nil end
    local s = {}
    for k, v in pairs(raw) do
        if not (PRIMARY_KEY[k] or MULTI_KEY[k]) then s[k] = v end
    end
    if primary and prim[primary] and MAIN_KEY[primary] then s[MAIN_KEY[primary]] = prim[primary] end
    return s, raw
end

local classIDs   -- "DRUID" -> 11
local function classIDOf(file)
    if not classIDs then
        classIDs = {}
        for i = 1, (GetNumClasses and GetNumClasses() or 0) do
            local _, f, id = GetClassInfo(i)
            if f then classIDs[f] = id end
        end
    end
    return file and classIDs[file]
end

local function canWear(rec, info, link)
    if info.minLevel and rec.level and info.minLevel > rec.level then return false end
    if info.classID == 4 then
        if BODY[info.equipLoc] and info.subclassID ~= ARMOR[rec.class] then return false end
        if info.equipLoc == "INVTYPE_SHIELD" and not SHIELD[rec.class] then return false end
    elseif info.classID == 2 then
        if not (WEAPONS[rec.class] and WEAPONS[rec.class][info.subclassID]) then return false end
    end
    -- class-only items (tier): asked for THAT character's class and spec
    -- (GetItemSpecInfo answers for the class you're logged in on: Astra, 2026-11-03)
    -- Only trusted for your own class: asked from a Death Knight, it said no druid
    -- spec could use a druid's trinket, which then went to Disenchant (2026-11-03).
    local classID = classIDOf(rec.class)
    if rec.specID and classID and C_Item.DoesItemContainSpec and rec.class == select(2, UnitClass("player")) then
        local ok, fits = pcall(C_Item.DoesItemContainSpec, link, classID, rec.specID)
        if ok and fits == false then return false end
    end
    -- an item with a main stat must have this spec's. From the tooltip, which
    -- lists every main stat it has (a druid's Agi/Int/Str trinket read only
    -- "Strength" through GetItemStats on a Death Knight and went to Disenchant).
    if not stats(link) then return nil end   -- not loaded: unknown, not "can't wear"
    local prim = primariesOf(link)
    if not prim then return nil end
    if not next(prim) then return true end   -- no main stat (rings, necks): anyone
    return prim[rec.primary] ~= nil
end

local scoreMemo
local function score(rec, link)
    if not link then return 0 end
    scoreMemo[rec] = scoreMemo[rec] or {}
    local m = scoreMemo[rec]
    if m[link] == nil then
        if not stats(link) then return nil end
        local Sc = VoidGear.Scorer
        local total = Sc:ScoreLink(link, rec.weights, rec.primary) or 0
        -- swap the stat part for THIS character's main stat (statsAs): the
        -- game's own reading follows the class you're logged in on
        local fixed, raw = statsAs(link, rec.primary)
        if not fixed then return nil end
        if Sc.ScoreStats then
            total = total - (Sc:ScoreStats(raw, rec.weights, rec.primary) or 0)
                + (Sc:ScoreStats(fixed, rec.weights, rec.primary) or 0)
        end
        m[link] = total
    end
    return m[link]
end

local function isTwoHand(link)
    local _, _, _, loc, _, _, sub = C_Item.GetItemInfoInstant(link)
    return loc == "INVTYPE_2HWEAPON" or loc == "INVTYPE_RANGED" or (loc == "INVTYPE_RANGEDRIGHT" and sub ~= 19)
end

-- What it would replace on `rec` and that score (nil = can't tell / doesn't fit).
-- Rings, trinkets: the weaker of the two. Two-handers: both hands. Off hands:
-- nothing next to a two-hander. One-handers: the weaker hand when dual wielding.
-- Every spec of a character's class, each as a rec with that spec's weights
-- (StatWeightsData presets) and specID; the saved spec keeps its own (maybe
-- custom) weights. a druid was saved as Feral while the user plays it
-- Restoration too, which would have thrown out its Intellect gear (2026-11-03).
local specCache
local function specsOf(rec)
    if specCache[rec] then return specCache[rec] end
    local list = { rec }
    local classID
    for i = 1, (GetNumClasses and GetNumClasses() or 0) do
        local _, file, id = GetClassInfo(i)
        if file == rec.class then classID = id end
    end
    local presets = VoidGear.StatWeights and VoidGear.StatWeights.presets or {}
    local n = classID and GetNumSpecializationsForClassID and GetNumSpecializationsForClassID(classID) or 0
    for i = 1, n do
        local id, name = GetSpecializationInfoForClassID(classID, i)
        if id and name and id ~= rec.specID then
            local p = presets[rec.class .. "_" .. (name:upper():gsub(" ", "_"))]
            if p and p.weights and (p.primary == "Strength" or p.primary == "Agility" or p.primary == "Intellect") then
                list[#list + 1] = setmetatable({ specID = id, spec = name, weights = p.weights, primary = p.primary },
                    { __index = rec })
            end
        end
    end
    specCache[rec] = list
    return list
end

-- The item level a character wears in the slot a piece would take (rings and
-- trinkets: the lower one; off hands: nothing next to a two-hander), for off-spec
-- checks. nil = can't tell.
local function wornIlvl(rec, info, link, off)
    local g = rec.gear or {}
    local s = SLOT_OF[info.equipLoc]
    local function il(l) return l and (GetDetailedItemLevelInfo(l) or 0) or 0 end
    if s == 11 or s == 13 then return math.min(il(g[s]), il(g[s + 1])) end
    -- an off-spec shield or off hand next to a worn two-hander: that spec wields
    -- something else, so measure against the main hand (Arms vs Protection)
    if s == 17 and g[16] and isTwoHand(g[16]) then return off and il(g[16]) or nil end
    if s == 16 and isTwoHand(link) and g[17] then return math.min(il(g[16]), il(g[17])) end
    return il(g[s])
end

-- Does what a character wears in that slot carry its spec's main stat? (No main
-- stat at all -- rings, necks -- counts as yes.) If not, its saved spec isn't
-- what it's dressed for, and a stat comparison would be meaningless.
local function wornMatches(rec, info)
    local s = SLOT_OF[info.equipLoc]
    local worn = rec.gear and rec.gear[s]
    local prim = worn and primariesOf(worn)   -- all its main stats, whoever is looking
    if not (prim and next(prim)) then return true end
    return prim[rec.primary] ~= nil
end

-- Same unique-equipped group (only one of them can be worn), as a comparable key.
local function uniqueKey(link)
    if not (link and C_Item.GetItemUniquenessByID) then return nil end
    local ok, isUnique, _, count, catID = pcall(C_Item.GetItemUniquenessByID, link)
    if not ok then return nil end
    if catID and catID > 0 and (count or 0) <= 1 then return catID end
    -- unique by itself (no group): only one of THIS item can be worn
    if isUnique then return "item" .. tostring(C_Item.GetItemInfoInstant(link) or 0) end
    return nil
end

local function current(rec, info, link)
    local g = rec.gear or {}
    local s = SLOT_OF[info.equipLoc]
    if s == 11 or s == 13 then
        -- the same item, or one from its unique-equipped group, has to come off
        local id, key = C_Item.GetItemInfoInstant(link), uniqueKey(link)
        for _, slot in ipairs({ s, s + 1 }) do
            local worn = g[slot]
            if worn and key and (C_Item.GetItemInfoInstant(worn) == id or uniqueKey(worn) == key) then   -- only when unique: two of a plain ring can be worn
                return score(rec, worn)
            end
        end
        local a, b = score(rec, g[s]), score(rec, g[s + 1])
        if a == nil or b == nil then return nil end
        return math.min(a, b)
    end
    if s == 16 or s == 17 then
        local mh, oh = g[16], g[17]
        local smh, soh = score(rec, mh), score(rec, oh)
        if smh == nil or soh == nil then return nil end
        if isTwoHand(link) then
            -- Fury wields two two-handers: a new one replaces the weaker hand
            if rec.titansGrip then return math.min(smh, soh) end
            return smh + soh
        end
        if s == 17 then
            if mh and isTwoHand(mh) and not rec.titansGrip then return nil end
            return soh
        end
        if rec.dualWield and info.equipLoc == "INVTYPE_WEAPON" and not (mh and isTwoHand(mh) and not rec.titansGrip) then
            return math.min(smh, soh)
        end
        return smh
    end
    return score(rec, g[s])
end

-- The Catalyst (this character's bags only: it needs the item's place): it
-- keeps the stats and adds set membership, so a convertible piece whose plain
-- stats beat what you wear in that tier slot becomes a tier upgrade. The first
-- test marked a 292 cloth glove "disenchant" because it lost to the 272 set
-- piece the priest wears, set bonus included (2026-11-03). Returns slot name, worn ilvl.
local TIER_SLOT = { INVTYPE_HEAD = { 1, "helm" }, INVTYPE_SHOULDER = { 3, "shoulders" },
    INVTYPE_CHEST = { 5, "chest" }, INVTYPE_ROBE = { 5, "chest" }, INVTYPE_HAND = { 10, "gloves" },
    INVTYPE_LEGS = { 7, "legs" } }
-- Only the best convertible piece per tier slot, and only if it beats what's
-- worn: a 266 glove was kept next to the 292 one in the first test.
local catalystBest   -- [tier slot] = best plain score among convertible pieces, per Judge()
local function catalystScore(it, equipLoc, rec)
    local ts = TIER_SLOT[equipLoc]
    if not (ts and rec and it.loc and C_Item.IsItemConvertibleAndValidForPlayer) then return nil end
    local ok, conv = pcall(C_Item.IsItemConvertibleAndValidForPlayer, it.loc)
    if not (ok and conv) then return nil end
    return VoidGear.Scorer:CalcStaticScore(it.link, rec.weights, rec.primary) or 0, ts
end
local function catalystFor(it, info, rec)
    local cand, ts = catalystScore(it, info.equipLoc, rec)
    if not cand or cand <= 0 or cand < (catalystBest[ts[1]] or 0) then return nil end
    local worn = rec.gear and rec.gear[ts[1]]
    local mine = worn and VoidGear.Scorer:CalcStaticScore(worn, rec.weights, rec.primary) or 0
    if cand > mine then return ts[2], worn and GetDetailedItemLevelInfo(worn) end
    return nil
end

----------------------------------------------------------------------
-- The verdicts
----------------------------------------------------------------------
local function money(c)
    if VoidUI and VoidUI.FormatMoney then return VoidUI:FormatMoney(math.floor(c + 0.5)) end
    return ("%dg"):format(math.floor(c / 10000 + 0.5))
end
SP.Money = money

local function price(ids)
    if not VoidAH_Price then return nil end
    local best
    for _, id in ipairs(ids) do
        local p = VoidAH_Price(id)
        if p and (not best or p < best) then best = p end
    end
    return best
end

-- { keep = {...}, sell = {...}, de = {...}, vendor = {...}, wait = {...},
--   deByWho = { [key] = n }, deMats = { [quality] = n }, pending = bool, unknown = { [key] = true } }
-- Each entry: { link, owner, verdict, why, quality, who }
-- Pieces never to sell, disenchant or vendor, whatever the scores say (the
-- user, 2026-11-03: "it could disenchant something somebody did not want
-- disenchanted"): marked keep here (right-click a Spares row), protected in
-- VoidBags (middle-click in bags), or in one of this character's equipment sets.
-- By item ID: every copy of it is kept. nil = not protected.
local function equipmentSetItems()
    local out = {}
    local ES = C_EquipmentSet
    if not (ES and ES.GetEquipmentSetIDs and ES.GetItemIDs) then return out end
    for _, setID in ipairs(ES.GetEquipmentSetIDs() or {}) do
        for _, id in pairs(ES.GetItemIDs(setID) or {}) do
            if type(id) == "number" and id > 0 then out[id] = true end
        end
    end
    return out
end
local function protectedWhy(id, setItems)
    if not id then return nil end
    if VoidGearDB and VoidGearDB.neverDE and VoidGearDB.neverDE[id] then
        return "you marked it keep (right-click to undo)"
    end
    local vb = type(_G.VoidBagsDB) == "table" and _G.VoidBagsDB.protected
    if type(vb) == "table" and vb[id] then return "protected in VoidBags" end
    if setItems and setItems[id] then return "in one of your equipment sets" end
    return nil
end
SP.ProtectedWhy = function(id) return protectedWhy(id, equipmentSetItems()) end

-- Only weapons and armor in a combat slot with a combat stat get judged.
-- Anything else (profession equipment, a fishing hat, a toy-like trinket) is
-- kept: its value isn't something VoidGear can score. Stats still loading = kept.
local COMBAT_STAT = { "STRENGTH", "AGILITY", "INTELLECT", "STAMINA", "CRIT", "HASTE", "MASTERY", "VERSATILITY" }
-- a profession stat anywhere = profession gear, even with Stamina on it
local PROF_STAT = { "PERCEPTION", "DEFTNESS", "FINESSE", "MULTICRAFT", "RESOURCEFUL", "INGENUITY", "PROFESSION" }
-- Any profession, primary or secondary, named in the tooltip ("Increases
-- Fishing", "Requires Engineering", a cooking hat): a profession item, never
-- judged (the user, 2026-11-03: "any profession items, primary and secondary").
local PROF_WORDS = { "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Herbalism", "Inscription",
    "Jewelcrafting", "Leatherworking", "Mining", "Skinning", "Tailoring", "Cooking", "Fishing", "Archaeology" }
-- plus the game's own names for them, so other languages match too (Codex Sol)
do
    local seen = {}
    for _, w in ipairs(PROF_WORDS) do seen[w] = true end
    local name = C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName
    for _, line in ipairs({ 171, 164, 333, 202, 182, 773, 755, 165, 186, 393, 197, 185, 356, 794 }) do
        local ok, n = pcall(name or error, line)
        if ok and type(n) == "string" and n ~= "" and not seen[n] then
            seen[n] = true
            PROF_WORDS[#PROF_WORDS + 1] = n
        end
    end
end
local profTip = {}   -- link -> its tooltip names a profession
local function notCombatGear(link, classID, equipLoc)
    if classID ~= 2 and classID ~= 4 then return true end   -- weapon / armor only
    if not SLOT_OF[equipLoc or ""] then return true end      -- profession tool / gear slots, tabards, shirts
    local stats = C_Item.GetItemStats(link) or {}
    local combat = false
    for k in pairs(stats) do
        for _, s in ipairs(PROF_STAT) do
            if k:find(s, 1, true) then return true end
        end
        for _, s in ipairs(COMBAT_STAT) do
            if k:find(s, 1, true) then combat = true end
        end
    end
    if not combat then return true end
    -- profession gear says so in its tooltip; the name alone isn't reliable.
    -- Read once per item.
    if profTip[link] == nil then
        local tip = C_TooltipInfo and C_TooltipInfo.GetHyperlink and C_TooltipInfo.GetHyperlink(link)
        -- not loaded yet: kept for now (judged on a later redraw), and no "no" remembered
        if not (tip and tip.lines and #tip.lines > 1) then return true end
        profTip[link] = false
        for _, line in ipairs(tip.lines) do
            local t = line.leftText
            if type(t) == "string" and not (issecretvalue and issecretvalue(t)) then
                for _, w in ipairs(PROF_WORDS) do
                    if t:find(w, 1, true) then profTip[link] = true break end
                end
            end
            if profTip[link] then break end
        end
    end
    return profTip[link]
end
SP.NotCombatGear = notCombatGear

-- Right-click a Spares row: never sell, disenchant or vendor it (again: undo).
function SP:ToggleKeep(id)
    if not id then return end
    VoidGearDB = VoidGearDB or {}
    VoidGearDB.neverDE = VoidGearDB.neverDE or {}
    local now = not VoidGearDB.neverDE[id] or nil
    VoidGearDB.neverDE[id] = now
    return now
end

function SP:Judge()
    local setItems = equipmentSetItems()
    local R = VoidGear.Roster
    local roster = R:All()
    local me = R:Key()
    pending, scoreMemo, specCache = false, {}, {}
    local res = { keep = {}, check = {}, sell = {}, de = {}, vendor = {}, wait = {}, deByWho = {}, deMats = {}, unknown = {} }
    local current_expac = LE_EXPANSION_LEVEL_CURRENT or (GetServerExpansionLevel and GetServerExpansionLevel()) or 11
    local enchanters = {}
    for _, key in ipairs(everyone()) do
        if enchanter(key) then enchanters[#enchanters + 1] = key end
    end
    table.sort(enchanters, function(a, b)
        if (a == me) ~= (b == me) then return a == me end
        return a < b
    end)
    local seenName = {}
    dupName = {}
    for _, key in ipairs(everyone()) do
        local name = key:match("^([^%-]+)") or key
        if seenName[name] then dupName[name] = true end
        seenName[name] = true
    end
    -- Your max-level characters VoidGear hasn't seen yet. Their gear isn't
    -- known, so nothing that might suit them gets a sell / disenchant verdict:
    -- the first test called a druid's brand-new vault pick "disenchant"
    -- before that druid had logged in (2026-11-03).
    local strangers = {}   -- { key, class, level }
    local vb = type(_G.VoidBagsDB) == "table" and _G.VoidBagsDB
    local seenVB = {}
    for _, c in pairs(vb and vb.characters or {}) do
        local key = vbKey(c)
        if key and not seenVB[key] and not roster[key] and (tonumber(c.level) or 0) >= 80 then
            seenVB[key] = true
            strangers[#strangers + 1] = { key = key, class = c.class, level = tonumber(c.level) }
        end
    end
    -- could a stranger wear it, going by class alone (its spec isn't known)?
    local function strangerFor(info, owner, tradable)
        for _, s in ipairs(strangers) do
            if (tradable or s.key == owner) and s.class then
                local fits = not (info.minLevel and s.level and info.minLevel > s.level)
                if fits and info.classID == 4 then
                    if BODY[info.equipLoc] and info.subclassID ~= ARMOR[s.class] then fits = false end
                    if info.equipLoc == "INVTYPE_SHIELD" and not SHIELD[s.class] then fits = false end
                elseif fits and info.classID == 2 then
                    fits = WEAPONS[s.class] and WEAPONS[s.class][info.subclassID] or false
                end
                if fits then return s.key end
            end
        end
    end

    local items = collect()
    catalystBest = {}
    for _, it in ipairs(items) do
        local cand, ts = catalystScore(it, select(4, C_Item.GetItemInfoInstant(it.link)), roster[me])
        if cand and cand > (catalystBest[ts[1]] or 0) then catalystBest[ts[1]] = cand end
    end

    for _, it in ipairs(items) do
        local _, _, _, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(it.link)
        if (classID == 2 or classID == 4) and SLOT_OF[equipLoc] and not (classID == 4 and subclassID == 5) then
            local name, _, quality, _, minLevel, _, _, _, _, _, _, _, _, bindType, expacID = C_Item.GetItemInfo(it.link)
            local e = { link = it.link, owner = it.owner, bank = it.bank, bag = it.bag, slot = it.slot, bound = it.bound,
                quality = quality, ilvl = GetDetailedItemLevelInfo(it.link) }
            if not name then
                pending = true
                C_Item.RequestLoadItemDataByID(it.id)
                e.verdict, e.why = "wait", "loading…"
            elseif expacID == current_expac and (e.ilvl or 0) > 0 and e.ilvl < 100 then
                -- a current-expansion piece at item level 1 (Shield of the Blood Knight
                -- Matriarch, 2026-11-03) is cosmetic, not gear to judge
            elseif notCombatGear(it.link, classID, equipLoc) then
                -- profession tools and gear, fishing hats, fun items: no combat
                -- stats, so every character scores them as worthless. VoidGear
                -- doesn't judge them at all (a fishing hat was disenchanted, 2026-11-03).
                e.verdict, e.who = "keep", it.owner
                e.why = "not combat gear (profession, fishing or fun item): left alone"
            elseif protectedWhy(it.id, setItems) then
                -- yours to keep, whatever the scores say: disenchanting can't be undone
                e.verdict, e.who = "keep", it.owner
                e.why = protectedWhy(it.id, setItems)
            elseif quality and quality >= 2 and quality <= 4 then
                local info = { classID = classID, subclassID = subclassID, equipLoc = equipLoc, minLevel = minLevel }
                -- Can it go to another of your characters? The warband bank's can.
                -- Otherwise: whether the item fits in the warband bank -- read
                -- live for your bags, as VoidBags recorded it for another
                -- character's. Not recorded (an older VoidBags save): a BoE or
                -- warbound-until-equipped piece may have been worn and be
                -- soulbound now, so it stays with its owner (Astra, 2026-11-03).
                local tradable
                if it.owner == "warband" then
                    tradable = true
                elseif it.wb ~= nil then
                    tradable = it.wb
                elseif it.owner == me then
                    tradable = (bindType == 2 or bindType == 3) and it.bound == false
                else
                    tradable = false
                end
                -- sellable on the AH: unbound BoE / BoU only (warbound never is)
                local sellable = (bindType == 2 or bindType == 3) and (it.owner == "warband" or it.bound == false)
                itemPending = false
                -- Old = an older expansion's AND an old item level: this season's
                -- legacy-dungeon loot (Algeth'ar Puzzle Box 298) carries its old
                -- expansion but is current gear (2026-11-03).
                if (expacID or current_expac) < current_expac and (e.ilvl or 0) < OLD_ILVL then
                    e.verdict, e.why = "vendor", "older expansion: its materials don't help Midnight Enchanting"
                else
                    -- 2: worth keeping for one of your characters?
                    local who = {}
                    if tradable then
                        for key in pairs(roster) do who[#who + 1] = key end
                    elseif roster[it.owner] then
                        who[1] = it.owner
                    end   -- an owner not seen yet: strangerFor below holds its gear back
                    local bestRatio, bestKey, bestPct
                    local wearers = {}
                    -- The spec each character was saved in: scored against what it
                    -- wears. Its other specs: what it wears is that spec's gear, so
                    -- scoring it with an off-spec's weights made everything look
                    -- like +500% (2026-11-03): off-specs compare item levels instead.
                    local bestSpec, offKey, offSpec, offIlvl, offWorn
                    local noIlvl   -- a character that can wear it, but the item-level test couldn't run
                    local weapon = SLOT_OF[equipLoc] == 16 or SLOT_OF[equipLoc] == 17
                    -- Trinkets: item levels, for every character. Their worth is mostly
                    -- the effect, which is only scored on the character itself, so the
                    -- same trinket read "+17.6%, keep" on its owner and "disenchant"
                    -- on another character (2026-11-03). Item levels read the same everywhere.
                    local trinket = SLOT_OF[equipLoc] == 13
                    local myIlvl = e.ilvl or 0
                    for _, key in ipairs(who) do
                        local rec, worn = roster[key], false
                        for _, srec in ipairs(specsOf(rec)) do
                            local cw = canWear(srec, info, it.link)
                            if cw == nil then noIlvl = noIlvl or key end   -- can't tell: never Disenchant
                            if cw then
                                if not worn then wearers[#wearers + 1] = key; worn = true end
                                if not trinket and (srec == rec or (srec.primary == rec.primary and not weapon)) and wornMatches(rec, info) then   -- same main stat (Unholy vs Frost): stats compare; another spec's weapon setup is not what is worn
                                    local cand, cur = score(srec, it.link), current(srec, info, it.link)
                                    if cand and cur then
                                        local ratio = cur > 0 and cand / cur or math.huge
                                        if not bestRatio or ratio > bestRatio then
                                            bestRatio, bestKey, bestSpec = ratio, key, srec.spec
                                            bestPct = cur > 0 and (cand - cur) / cur * 100 or nil
                                        end
                                    end
                                end
                                -- Item levels, always, for every spec that can wear it: a
                                -- second, independent test. Disenchant needs BOTH to say
                                -- it's worse; either one saying "as good" keeps it. One
                                -- wrong score must never send a piece to be disenchanted
                                -- (the trinkets, 2026-11-03: "we have to be really careful
                                -- ... your algos being wrong").
                                local w = wornIlvl(rec, info, it.link, srec ~= rec)
                                if not w then noIlvl = noIlvl or key end
                                if w and myIlvl >= w and (not offIlvl or myIlvl - w > offIlvl - offWorn) then
                                    offKey, offSpec, offIlvl, offWorn = key, srec.spec, myIlvl, w
                                end
                            end
                        end
                    end
                    local looked = LOOK[equipLoc] and C_TransmogCollection and C_TransmogCollection.PlayerHasTransmogByItemInfo
                    local lookNew = looked and not C_TransmogCollection.PlayerHasTransmogByItemInfo(it.link)
                    if itemPending and not (bestRatio and bestRatio >= NEAR) then
                        -- a comparison is still loading: no sell / disenchant verdict yet
                        e.verdict, e.why = "wait", "loading…"
                    elseif bestRatio and bestRatio >= NEAR then
                        local spec = bestSpec and (" (" .. bestSpec .. ")") or ""
                        e.verdict = "keep"
                        if not bestPct then
                            e.why = ("empty slot for %s%s"):format(shortName(bestKey), spec)
                        elseif bestPct >= 0 then
                            e.why = ("+%.1f%% for %s%s"):format(bestPct, shortName(bestKey), spec)
                        else
                            e.why = ("within %.1f%% of what %s%s wears"):format(-bestPct, shortName(bestKey), spec)
                        end
                        e.who = bestKey
                    elseif offKey then
                        e.verdict, e.who = "keep", offKey
                        e.why = ("for %s (%s): item level %d vs %d worn"):format(shortName(offKey), offSpec or "?",
                            offIlvl, offWorn)
                    elseif catalystFor(it, info, roster[me]) then
                        local what, mine = catalystFor(it, info, roster[me])
                        e.verdict, e.who = "keep", me
                        e.why = ("Catalyst it: your tier %s at %d (you wear %d)"):format(what, e.ilvl or 0, mine or 0)
                    elseif lookNew and #wearers > 0 then
                        -- Wearing it binds it there, so an enchanter who can wear it
                        -- comes first (it can disenchant it after); then whoever holds
                        -- it, then you, then anyone (Astra, 2026-11-03).
                        local w, best = wearers[1], -1
                        for _, k in ipairs(wearers) do
                            local rank = (enchanter(k) and 4 or 0) + (k == it.owner and 2 or 0) + (k == me and 1 or 0)
                            if rank > best then w, best = k, rank end
                        end
                        e.verdict, e.who = "keep", w
                        if enchanter(w) then
                            e.why = ("look not collected: wear it once on %s, then disenchant it there"):format(shortName(w))
                        else
                            e.why = ("look not collected: wear it once on %s (it binds there; then vendor it)"):format(shortName(w))
                        end
                    elseif strangerFor(info, it.owner, tradable) then
                        local s = strangerFor(info, it.owner, tradable)
                        e.verdict, e.who = "check", s
                        res.unknown[s] = true
                        e.why = s == it.owner and ("log in on %s once to check it against its gear"):format(shortName(s))
                            or ("could suit %s: log in on %s once to check"):format(shortName(s), shortName(s))
                    elseif noIlvl then
                        -- one of the two tests couldn't run (an off-hand for a character
                        -- holding a two-hander, 2026-11-03): never Disenchant on one test alone
                        e.verdict, e.who = "check", it.owner
                        e.why = ("can't compare it with what %s wears: you decide (right-click to always keep)"):format(shortName(noIlvl))
                    elseif trinket and #wearers > 0 then
                        -- below what's worn, but a trinket's effect isn't scored: a
                        -- weaker-looking one can still be the better one. Never on the
                        -- disenchant list; you decide (Codex Sol, 2026-11-03).
                        e.verdict, e.who = "check", it.owner
                        e.why = "trinket below what's worn: its effect isn't scored, so you decide (right-click to always keep)"
                    else
                        -- why it got this far (read with /run, for checking verdicts)
                        e.dbg = ("who=%d wearers=%d trinket=%s noIlvl=%s off=%s ratio=%s"):format(#who, #wearers,
                            tostring(trinket), tostring(noIlvl), tostring(offKey), tostring(bestRatio))
                        local deValue = (price(DE_MAT[quality]) or 0)
                        local ahPrice = sellable and VoidAH_Price and VoidAH_Price(it.id)
                        local deBy
                        -- the holder disenchants its own pieces when it can; only
                        -- otherwise does a warbound piece travel (first: you, if
                        -- you enchant). Before, a piece in Murrath's bags read
                        -- "send it to Vede" when viewed on Vede (2026-11-03).
                        if enchanter(it.owner) then
                            deBy = it.owner
                        elseif tradable then
                            deBy = enchanters[1]
                        end
                        if ahPrice and ahPrice > deValue * 1.2 and ahPrice > 0 then
                            -- a gear price is one listing for that item at any level: a
                            -- hint, not a quote (one showed 217,712g, 2026-11-03)
                            e.verdict, e.why = "sell", ("BoE: listed at %s on your AH (check it before you post)"):format(money(ahPrice))
                        elseif deBy then
                            e.verdict, e.who = "de", deBy
                            if deBy == it.owner then
                                e.why = ("disenchant on %s%s"):format(shortName(deBy), it.bank and " (take it from the bank)" or "")
                            elseif it.owner == "warband" then
                                e.why = ("disenchant on %s (take it from the warband bank)"):format(shortName(deBy))
                            else
                                e.why = ("disenchant on %s (send it from %s)"):format(shortName(deBy), shortName(it.owner))
                            end
                            res.deByWho[deBy] = (res.deByWho[deBy] or 0) + 1
                            res.deMats[quality] = (res.deMats[quality] or 0) + 1
                        else
                            e.verdict = "vendor"
                            e.why = tradable and "no character of yours has Enchanting"
                                or ("soulbound to %s, which has no Enchanting"):format(shortName(it.owner))
                        end
                    end
                end
            end
            if e.verdict then table.insert(res[e.verdict], e) end
        end
    end
    res.pending = pending
    res.enchanters = enchanters
    return res
end
