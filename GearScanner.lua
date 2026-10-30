-- 12.1.5 (and WoW Forever) removed the old global item functions; use C_Item's.
local GetDetailedItemLevelInfo = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
----------------------------------------------------------------------
-- VoidGear GearScanner
-- Reads player's currently-equipped gear and returns rich data for
-- each slot — link, ilvl, stats, gems, enchant, computed score.
----------------------------------------------------------------------

VoidGear = VoidGear or {}
VoidGear.Scanner = {}
local S = VoidGear.Scanner

-- Cached stats tables to avoid re-parsing every refresh
local statsCache = setmetatable({}, { __mode = "k" })

----------------------------------------------------------------------
-- Get raw stats table for an item link (or itemID).
-- Returns: { ITEM_MOD_STRENGTH_SHORT = 124, ITEM_MOD_CRIT_RATING_SHORT = 89, ... }
----------------------------------------------------------------------
function S:GetStatsFromLink(link)
    if not link then return nil end
    if statsCache[link] then return statsCache[link] end
    local stats = C_Item.GetItemStats(link)
    statsCache[link] = stats
    return stats
end

----------------------------------------------------------------------
-- Extract gem IDs and enchant from an item link.
-- WoW item link format:
--   |Hitem:itemID:enchantID:gem1:gem2:gem3:gem4:suffix:uniqueID:linkLevel:
--     specID:upgradeID:contextID:bonusCount:bonusIDs:...|h[name]|h
----------------------------------------------------------------------
function S:ParseLink(link)
    if not link then return nil end
    local out = { id = nil, enchant = nil, gems = {}, bonuses = {} }
    local parts = {}
    for p in link:gmatch("item:([^|]+)") do
        for chunk in (p .. ":"):gmatch("([^:]*):") do
            table.insert(parts, chunk)
        end
        break
    end
    out.id      = tonumber(parts[1])
    out.enchant = tonumber(parts[2])
    for i = 3, 6 do
        local g = tonumber(parts[i])
        if g and g > 0 then table.insert(out.gems, g) end
    end
    -- Bonus IDs encode upgrade track, difficulty, etc.
    local bonusCount = tonumber(parts[13]) or 0
    for i = 1, bonusCount do
        local b = tonumber(parts[13 + i])
        if b then table.insert(out.bonuses, b) end
    end
    return out
end

----------------------------------------------------------------------
-- Scan one equipped slot.
-- Returns nil if slot empty.
----------------------------------------------------------------------
function S:GetEquipped(slotID)
    local link = GetInventoryItemLink("player", slotID)
    if not link then return nil end

    local ilvl  = GetDetailedItemLevelInfo(link)
    local name  = link:match("%[(.-)%]") or "?"
    local stats = self:GetStatsFromLink(link)
    local meta  = self:ParseLink(link)
    -- Right after a /reload the game may not have the item's details yet
    -- (level and stats come back nil). Ask for them; callers wait (AnyPending).
    local pending = not ilvl or not stats
    if pending and meta and meta.id then C_Item.RequestLoadItemDataByID(meta.id) end

    return {
        slotID  = slotID,
        link    = link,
        id      = meta and meta.id,
        name    = name,
        ilvl    = ilvl or 0,
        pending = pending,
        stats   = stats or {},
        gems    = (meta and meta.gems) or {},
        enchant = meta and meta.enchant,
        bonuses = (meta and meta.bonuses) or {},
    }
end

----------------------------------------------------------------------
-- Scan all gear slots — returns slotID -> data
----------------------------------------------------------------------
function S:GetAll()
    local out = {}
    for _, slotID in ipairs(VoidGear.PLAN_SLOTS) do
        local data = self:GetEquipped(slotID)
        if data then out[slotID] = data end
    end
    return out
end

-- Is any equipped item still missing its details? (see GetEquipped)
function S:AnyPending()
    for _, slotID in ipairs(VoidGear.PLAN_SLOTS) do
        local d = self:GetEquipped(slotID)
        if d and d.pending then return true end
    end
    return false
end

----------------------------------------------------------------------
-- Get the player's current primary stat (Strength/Agility/Intellect)
-- Based on class — most reliable than spec lookup.
----------------------------------------------------------------------
local PRIMARY_BY_CLASS = {
    DEATHKNIGHT = "Strength",
    DEMONHUNTER = "Agility",
    DRUID       = "auto",   -- depends on spec
    EVOKER      = "Intellect",
    HUNTER      = "Agility",
    MAGE        = "Intellect",
    MONK        = "auto",
    PALADIN     = "auto",
    PRIEST      = "Intellect",
    ROGUE       = "Agility",
    SHAMAN      = "auto",
    WARLOCK     = "Intellect",
    WARRIOR     = "Strength",
}

function S:GetPrimaryStat()
    local _, class = UnitClass("player")
    local primary = PRIMARY_BY_CLASS[class] or "auto"
    if primary ~= "auto" then return primary end
    -- For hybrid classes — the spec's own primary stat (6th return of
    -- GetSpecializationInfo, LE_UNIT_STAT_*). Matching on role skipped tanks,
    -- so Guardian and Brewmaster were scored as Strength (Astra, 2026-10-30).
    local specID = GetSpecialization and GetSpecialization()
    if not specID then return "Strength" end
    local stat = select(6, GetSpecializationInfo(specID))
    if stat == (LE_UNIT_STAT_STRENGTH or 1) then return "Strength"
    elseif stat == (LE_UNIT_STAT_AGILITY or 2) then return "Agility"
    elseif stat == (LE_UNIT_STAT_INTELLECT or 4) then return "Intellect" end
    -- no stat from the game: guess from the spec's name
    local role = GetSpecializationRole and GetSpecializationRole(specID)
    if role == "HEALER" or role == "DAMAGER" then
        -- Roughly: druids/monks/paladins/shamans pick based on spec
        local specName = select(2, GetSpecializationInfo(specID)) or ""
        local s = specName:lower()
        if s:find("balance") or s:find("resto") or s:find("holy") or s:find("disc")
            or s:find("mistweaver") or s:find("elemental") or s:find("enhancement") == nil
            and (s:find("priest") or s:find("shaman")) then
            return "Intellect"
        end
        if s:find("retribution") or s:find("protection paladin") then return "Strength" end
        if s:find("feral") or s:find("guardian") or s:find("brewmaster")
            or s:find("windwalker") or s:find("enhancement") then
            return "Agility"
        end
    end
    return "Strength"
end
