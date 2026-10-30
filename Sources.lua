----------------------------------------------------------------------
-- VoidGear Sources — "where does this item come from"
--
-- Game data only:
--   1. The Encounter Journal loot scan (/vgear scan, LootDB): raid boss,
--      dungeon or world boss.
--   2. Crafted gear: the item has a crafted quality.
--   2b. Tier set pieces: they drop as tokens (or come from the Catalyst).
--   3. Otherwise "Source unknown".
----------------------------------------------------------------------

VoidGear = VoidGear or {}

local index, indexedAt   -- itemID -> scanned loot entry, rebuilt after each scan

local TIER_LOCS = { INVTYPE_HEAD = true, INVTYPE_SHOULDER = true, INVTYPE_CHEST = true,
    INVTYPE_ROBE = true, INVTYPE_HAND = true, INVTYPE_LEGS = true }

local function Lookup(itemID)
    local cache = VoidGearDB and VoidGearDB.lootCache
    if not cache then return nil end
    if indexedAt ~= cache.scannedAt then
        index, indexedAt = {}, cache.scannedAt
        for _, bucket in ipairs({ cache.raid, cache.mplus, cache.worldBoss }) do
            for _, it in ipairs(bucket or {}) do
                if it.id and not index[it.id] then index[it.id] = it end
            end
        end
    end
    return index[itemID]
end

function VoidGear:GetItemSource(itemID)
    if not itemID or itemID <= 0 then return nil end

    local it = Lookup(itemID)
    if it then
        local where = it.instance or "Instance"
        if it.encounterName then where = where .. " — " .. it.encounterName end
        local kind = (it.contentType == "mplus" and "Dungeon")
            or (it.contentType == "worldBoss" and "World boss") or "Raid"
        return { kind = kind, text = where }
    end

    local fn = C_TradeSkillUI and C_TradeSkillUI.GetItemCraftedQualityByItemInfo
    local ok, q = pcall(fn or function() end, itemID)
    if ok and q then
        return { kind = "Crafted", text = "made by a crafter (crafting orders / Auction House)" }
    end

    -- Tier pieces drop as tokens, so the Adventure Guide never lists the piece itself.
    -- An item set alone isn't enough (other sets exist): tier is the five slots
    -- the Catalyst makes.
    local equipLoc = select(9, C_Item.GetItemInfo(itemID))
    local setID = select(16, C_Item.GetItemInfo(itemID))
    if setID and setID > 0 and TIER_LOCS[equipLoc] then
        return { kind = "Tier set", text = "raid token or the Catalyst" }
    end

    if not (VoidGearDB and VoidGearDB.lootCache) then
        return { kind = "Unknown", text = "click Scan Loot to read the Adventure Guide" }
    end
    return { kind = "Unknown", text = "not in the Adventure Guide: crafted, world drop or vendor" }
end
