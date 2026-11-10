-- 12.1.5 (and WoW Forever) removed the old global item functions; use C_Item's.
local GetDetailedItemLevelInfo = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
----------------------------------------------------------------------
-- VoidGear LootDB
-- Provides loot lists for each gear-source tab (Raid / M+ / World).
--
-- Approach: hybrid runtime EJ scan + curated overrides.
-- Cache lives in VoidGearDB.lootCache and refreshes via /vgear scan.
----------------------------------------------------------------------

VoidGear = VoidGear or {}
VoidGear.LootDB = {}
local DB = VoidGear.LootDB

----------------------------------------------------------------------
-- INVTYPE → slot mapping (reliable, returned by C_Item.GetItemInfoInstant).
-- This is the AUTHORITATIVE map. EJ slot strings (below) are a fallback only.
----------------------------------------------------------------------
local INVTYPE_SLOT = {
    INVTYPE_HEAD          = 1,
    INVTYPE_NECK          = 2,
    INVTYPE_SHOULDER      = 3,
    INVTYPE_BODY          = 4,   -- shirt (not planned but included for safety)
    INVTYPE_CHEST         = 5,
    INVTYPE_ROBE          = 5,
    INVTYPE_WAIST         = 6,
    INVTYPE_LEGS          = 7,
    INVTYPE_FEET          = 8,
    INVTYPE_WRIST         = 9,
    INVTYPE_HAND          = 10,
    INVTYPE_FINGER        = 11,  -- compare against worst of slot 11/12
    INVTYPE_TRINKET       = 13,  -- compare against worst of slot 13/14
    INVTYPE_CLOAK         = 15,
    INVTYPE_WEAPON        = 16,
    INVTYPE_WEAPONMAINHAND= 16,
    INVTYPE_2HWEAPON      = 16,
    INVTYPE_RANGED        = 16,
    INVTYPE_RANGEDRIGHT   = 16,
    INVTYPE_THROWN        = 16,
    INVTYPE_WEAPONOFFHAND = 17,
    INVTYPE_HOLDABLE      = 17,
    INVTYPE_SHIELD        = 17,
}

-- Fallback for EJ slot strings (used only if INVTYPE lookup fails)
local EJ_SLOT_NAME = {
    ["Head"] = 1, ["Neck"] = 2, ["Shoulder"] = 3, ["Shoulders"] = 3,
    ["Chest"] = 5, ["Robe"] = 5, ["Waist"] = 6, ["Legs"] = 7, ["Feet"] = 8,
    ["Wrist"] = 9, ["Hands"] = 10, ["Finger"] = 11, ["Trinket"] = 13,
    ["Back"] = 15, ["Cloak"] = 15,
    ["Main Hand"] = 16, ["One-Hand"] = 16, ["Two-Hand"] = 16,
    ["Off Hand"] = 17, ["Held In Off-hand"] = 17, ["Ranged"] = 16, ["Shield"] = 17,
    -- weapon-type strings EJ sometimes returns
    ["Sword"] = 16, ["Axe"] = 16, ["Mace"] = 16, ["Dagger"] = 16,
    ["Polearm"] = 16, ["Staff"] = 16, ["Bow"] = 16, ["Gun"] = 16,
    ["Crossbow"] = 16, ["Wand"] = 16, ["Fist Weapon"] = 16, ["Warglaive"] = 16,
}

function DB:SlotFromItem(itemID, slotStr)
    -- Try INVTYPE first (authoritative)
    if itemID and C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemID)
        if equipLoc and INVTYPE_SLOT[equipLoc] then
            return INVTYPE_SLOT[equipLoc]
        end
    end
    -- Fallback to EJ slot string
    return EJ_SLOT_NAME[slotStr or ""]
end

----------------------------------------------------------------------
-- The current season. Read from the game where the game says it:
--   M+ dungeons: C_ChallengeMode.GetMapTable() = this season's keystone
--   dungeons (old-expansion ones included), so it follows each new season.
--   Raids: the game has no "this season's raid" call, so SEASON_RAIDS lists
--   them by Encounter Journal instance ID -- UPDATE THIS EACH SEASON.
--   Season 2 (12.1): The Venomous Abyss.
----------------------------------------------------------------------
DB.SEASON_RAIDS = { [1320] = "The Venomous Abyss" }

-- Names of this season's keystone dungeons (the Encounter Journal lists
-- dungeons by name, not challenge map ID). Empty between seasons.
function DB:SeasonDungeons()
    local names = {}
    if not (C_ChallengeMode and C_ChallengeMode.GetMapTable) then return names end
    for _, mapID in ipairs(C_ChallengeMode.GetMapTable() or {}) do
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        if name then names[name] = true end
    end
    return names
end

-- Is this journal dungeon in the season? Keystone wings ("Operation: Mechagon -
-- Workshop") are named "<journal instance> - <wing>", so a prefix counts too.
function DB:IsSeasonDungeon(instName, seasonDungeons)
    if not instName then return false end
    if seasonDungeons[instName] then return true end
    local prefix = instName .. " - "
    for name in pairs(seasonDungeons) do
        if name:sub(1, #prefix) == prefix then return true end
    end
    return false
end

-- One string per season (its dungeons + raids), stored with a scan so a scan
-- from an older season counts as "not scanned".
function DB:SeasonKey()
    local parts = {}
    for name in pairs(self:SeasonDungeons()) do parts[#parts + 1] = name end
    for id in pairs(self.SEASON_RAIDS) do parts[#parts + 1] = tostring(id) end
    table.sort(parts)
    return table.concat(parts, "|")
end

----------------------------------------------------------------------
-- Curated world / prey / delve drops where EJ data doesn't cover well
----------------------------------------------------------------------
DB.CURATED_WORLD = {
    -- format: { id=, ilvl=, slot=, source=, name= }
    -- Prey hunt rewards (Nightmare tier)
    -- Note: Prey hunt drops vary by hunt; below are common ones.
    -- Voidcore-related currencies aren't items.
    -- TODO: populate once specific drops are confirmed.

    -- World boss / world quest gear (Midnight Eversong, Quel'Thalas)
    -- TODO: populate

    -- Delve gear (bountiful key vault rewards)
    -- TODO: populate

    -- Voidforge upgrades (294 cap items)
    -- These are TIER UPGRADES of player's own gear, not drops. Handled separately.
}

----------------------------------------------------------------------
-- Scan this season's loot from the Encounter Journal (raids at Mythic).
-- Saves to VoidGearDB.lootCache, tagged with the season (SeasonKey).
--
-- Only this season: the raid(s) in SEASON_RAIDS, world bosses of the
-- newest expansion, and the keystone dungeons the game lists for this
-- season -- those come from several expansions, so every tier is walked.
----------------------------------------------------------------------
function DB:Scan(onComplete, attempt)
    self.scanning = true   -- until the last retry is done (FillMissing waits for it)
    VoidGearDB = VoidGearDB or {}
    VoidGearDB.lootCache = {
        raid        = {},
        mplus       = {},
        worldBoss   = {},
        scannedAt   = time(),
        instances   = {},
        seasonKey   = self:SeasonKey(),
    }

    if not EJ_GetCurrentTier or not EJ_GetInstanceByIndex then
        VoidGear:Warn("Encounter Journal not available")
        self.scanning = false
        if onComplete then onComplete() end
        return
    end

    -- make sure the season's keystone dungeon list is loaded
    if C_MythicPlus and C_MythicPlus.RequestMapInfo then C_MythicPlus.RequestMapInfo() end
    -- Only loot for your class and spec (what the journal shows you by default);
    -- the journal's own filter goes back to how it was afterwards.
    local oldClass, oldSpec
    if EJ_GetLootFilter then oldClass, oldSpec = EJ_GetLootFilter() end
    local specID = self:CurrentSpecID()
    if EJ_SetLootFilter and specID then EJ_SetLootFilter(select(3, UnitClass("player")), specID) end
    -- and every slot: a journal left on "Trinkets" would cache trinkets only
    local EJ = C_EncounterJournal
    local oldSlot = EJ and EJ.GetSlotFilter and EJ.GetSlotFilter()
    if oldSlot and EJ.ResetSlotFilter then EJ.ResetSlotFilter() end
    VoidGearDB.lootCache.specID = specID
    local savedTier = EJ_GetCurrentTier()
    local numTiers = (EJ_GetNumTiers and EJ_GetNumTiers()) or savedTier
    local raidsScanned, dungeonsScanned, worldBossesScanned = 0, 0, 0

    -- World boss detection: EJ instances with exactly 1 encounter and instanceType==3
    -- (Enum.EJInstanceType.WorldBoss = 3 in modern WoW)
    local WORLD_BOSS_TYPE = Enum and Enum.EJInstanceType and Enum.EJInstanceType.WorldBoss or 3

    local function classifyInstance(instID)
        -- Try modern API: C_EncounterJournal.GetInstanceForGameMap or similar
        -- Simplest: scan number of encounters; 1-encounter raid = world boss candidate
        local numEnc = 0
        if EJ_SelectInstance then
            EJ_SelectInstance(instID)
            local i = 1
            while true do
                local _, _, encID = EJ_GetEncounterInfoByIndex(i)
                if not encID then break end
                numEnc = numEnc + 1
                i = i + 1
            end
        end
        return numEnc
    end

    -- Scan RAIDS across ALL tiers — 1-encounter raids become world bosses.
    -- An instance can be listed under more than one tier; scan it once.
    local seenInst = {}
    for tier = 1, numTiers do
        if EJ_SelectTier then EJ_SelectTier(tier) end
        local idx = 1
        while true do
            local instID, instName = EJ_GetInstanceByIndex(idx, true)
            if not instID then break end
            local dup = seenInst[instID]   -- already scanned under another tier
            local numEnc = dup and 0 or classifyInstance(instID)
            local isWorldBoss = (numEnc == 1)
            local isNewestTier = (tier == numTiers)

            -- Only scan: this season's raid(s) + the newest expansion's world bosses
            if not dup and ((not isWorldBoss and self.SEASON_RAIDS[instID]) or (isWorldBoss and isNewestTier)) then
                seenInst[instID] = true
                local items = self:ScanInstance(instID, true)
                if #items > 0 then
                    local bucket = isWorldBoss and VoidGearDB.lootCache.worldBoss or VoidGearDB.lootCache.raid
                    for _, it in ipairs(items) do
                        it.instance = instName
                        it.contentType = isWorldBoss and "worldBoss" or "raid"
                        it.tier = tier
                        table.insert(bucket, it)
                    end
                    VoidGearDB.lootCache.instances[instID] = {
                        name = instName,
                        type = isWorldBoss and "worldBoss" or "raid",
                        count = #items, tier = tier,
                    }
                    if isWorldBoss then worldBossesScanned = worldBossesScanned + 1
                    else raidsScanned = raidsScanned + 1 end
                end
            end
            idx = idx + 1
        end
    end

    -- Scan this season's keystone DUNGEONS (any expansion; each name once), with
    -- the journal previewing loot at the player's key level (PreviewKeyLevel).
    local keyLevel = self:PreviewKeyLevel()
    if C_EncounterJournal and C_EncounterJournal.SetPreviewMythicPlusLevel then
        pcall(C_EncounterJournal.SetPreviewMythicPlusLevel, keyLevel)
    end
    VoidGearDB.lootCache.mplusKeyLevel = keyLevel
    local seasonDungeons, done = self:SeasonDungeons(), {}
    if not next(seasonDungeons) then
        VoidGear:Warn("The game lists no Mythic+ dungeons right now (between seasons?) -- M+ loot skipped.")
    end
    for tier = 1, numTiers do
        if EJ_SelectTier then EJ_SelectTier(tier) end
        local di = 1
        while true do
            local instID, instName = EJ_GetInstanceByIndex(di, false)
            if not instID then break end
            local items = {}
            if self:IsSeasonDungeon(instName, seasonDungeons) and not done[instName] then
                done[instName] = true
                items = self:ScanInstance(instID, false)
            end
            if #items > 0 then
                for _, it in ipairs(items) do
                    it.instance = instName
                    it.contentType = "mplus"
                    it.tier = tier
                    table.insert(VoidGearDB.lootCache.mplus, it)
                end
                VoidGearDB.lootCache.instances[instID] = { name = instName, type = "dungeon", count = #items, tier = tier }
                dungeonsScanned = dungeonsScanned + 1
            end
            di = di + 1
        end
    end

    if EJ_SelectTier and savedTier then EJ_SelectTier(savedTier) end
    if EJ_SetLootFilter and oldClass then EJ_SetLootFilter(oldClass, oldSpec or 0) end
    if oldSlot and EJ.SetSlotFilter then EJ.SetSlotFilter(oldSlot) end

    -- Items the journal listed before their data loaded have no link (it holds
    -- their level). They were asked for: scan again once they're in (2 more tries).
    attempt = attempt or 1
    local noLink = 0
    for _, bucket in ipairs({ VoidGearDB.lootCache.raid, VoidGearDB.lootCache.mplus, VoidGearDB.lootCache.worldBoss }) do
        for _, it in ipairs(bucket) do if not it.link then noLink = noLink + 1 end end
    end
    if noLink > 0 and attempt < 3 then
        if onComplete then onComplete() end
        C_Timer.After(2, function() self:Scan(onComplete, attempt + 1) end)
        return
    end

    VoidGear:Print(string.format(
        "Scan: %d raids, %d dungeons (loot at +%d), %d world bosses | items: raid=%d, M+=%d, world=%d",
        raidsScanned, dungeonsScanned, keyLevel, worldBossesScanned,
        #VoidGearDB.lootCache.raid, #VoidGearDB.lootCache.mplus, #VoidGearDB.lootCache.worldBoss))

    self.scanning = false
    if onComplete then onComplete() end
end

-- The key level to show dungeon loot at: your highest key this week, else
-- your own keystone, else +10.
function DB:PreviewKeyLevel()
    local runs = self:GetWeeklyMplusRuns()
    if runs[1] and (runs[1].level or 0) > 0 then return runs[1].level end
    local own = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel and C_MythicPlus.GetOwnedKeystoneLevel()
    if own and own > 0 then return own end
    return 10
end

-- M+ drops are shown as the Great Vault would give them. The journal lists
-- dungeon loot at a low base level with matching tiny stats (Bladesorrow: 214,
-- 31 Agility), and the game has no end-of-dungeon item level (probed 2026-10-30
-- on 12.1.7: GetRewardLevelForDifficultyLevel's end-of-run value is 0).
-- But an unlocked M+ vault slot comes with a real example item, and its link's
-- bonus IDs set level and track. Put those on a drop's item ID and the game
-- gives that drop's real stats at the vault level (AtVaultLevel).

-- Is any unlocked vault slot's example item still loading? (Asks for it; the
-- UI redraws when it arrives, else drops would score at journal level.)
function DB:VaultPending()
    local vault = self:GetVault()
    local pending = false
    for _, key in ipairs({ "mplus", "raid", "world" }) do
        for _, slot in ipairs(vault and vault[key] or {}) do
            if slot.exampleLink and not GetDetailedItemLevelInfo(slot.exampleLink) then
                C_Item.RequestLoadItemDataByID(slot.exampleLink)
                pending = true
            end
        end
    end
    return pending
end

-- The best unlocked M+ vault slot's example: link, item level, key level.
function DB:MplusVaultTemplate()
    local vault = self:GetVault()
    local best
    for _, slot in ipairs(vault and vault.mplus or {}) do
        if slot.exampleLink and (not best or (slot.level or 0) > (best.level or 0)) then best = slot end
    end
    if not best then return nil end
    local ilvl = GetDetailedItemLevelInfo(best.exampleLink)
    if not ilvl or ilvl <= 0 then return nil end
    return best.exampleLink, ilvl, best.level
end

-- itemID as an item string carrying the template's bonus IDs (no enchant or
-- gems). Returns the string and its level, or nil when the game doesn't put
-- it at the template's level (then don't trust it).
function DB:AtVaultLevel(itemID, template, templateIlvl)
    local body = template and template:match("item:([%-%d:]+)")
    if not (itemID and body) then return nil end
    local f = {}
    for part in (body .. ":"):gmatch("([^:]*):") do f[#f + 1] = part end
    f[1] = tostring(itemID)
    for i = 2, 6 do f[i] = "" end   -- enchant + 4 gem slots
    local s = "item:" .. table.concat(f, ":")
    local ilvl = GetDetailedItemLevelInfo(s)
    if not ilvl or math.abs(ilvl - templateIlvl) > 3 then return nil end
    return s, ilvl
end

----------------------------------------------------------------------
-- Get this week's M+ runs — list of { mapID, level, completed, timed }
----------------------------------------------------------------------
function DB:GetWeeklyMplusRuns()
    local runs = {}
    if not C_MythicPlus or not C_MythicPlus.GetRunHistory then return runs end
    -- (includePreviousWeeks, includeIncompleteRuns): an abandoned key isn't a key you did
    local ok, history = pcall(C_MythicPlus.GetRunHistory, false, false)
    if not ok or not history then return runs end
    for _, r in ipairs(history) do
        table.insert(runs, {
            mapID     = r.mapChallengeModeID,
            level     = r.level,
            completed = r.completed,
            timed     = r.thisWeek and not r.runFailed,
        })
    end
    -- Sort by level descending (highest-key runs first)
    table.sort(runs, function(a, b) return (a.level or 0) > (b.level or 0) end)
    return runs
end

-- Raid difficulty IDs, lowest to highest (LFR, Normal, Heroic, Mythic).
local RAID_RANK = { [17] = 1, [14] = 2, [15] = 3, [16] = 4 }

-- The journal raid an encounter belongs to.
local function RaidOf(e)
    return EJ_GetEncounterInfo and select(6, EJ_GetEncounterInfo(e.encounterID)) or 0
end

-- A raid vault unlock lasts the season, but the game only lists this week's
-- kills. Save them as they happen: raidUnlocks[raid][rank] = furthest uiOrder.
-- Runs on login and every vault update, not only when the Vault tab is open.
function DB:RecordRaidUnlocks()
    VoidGearCharDB = VoidGearCharDB or {}
    local season = self:SeasonKey()
    local store = VoidGearCharDB.raidUnlocks
    if not store or store.season ~= season then
        store = { season = season }
        VoidGearCharDB.raidUnlocks = store
    end
    local RAID = (Enum and Enum.WeeklyRewardChestThresholdType and Enum.WeeklyRewardChestThresholdType.Raid) or 1
    local encounters = C_WeeklyRewards and C_WeeklyRewards.GetActivityEncounterInfo
        and C_WeeklyRewards.GetActivityEncounterInfo(RAID, 1)
    for _, e in ipairs(encounters or {}) do
        local rank = RAID_RANK[e.bestDifficulty or 0]
        if rank then
            local r = RaidOf(e)
            store[r] = store[r] or {}
            store[r][rank] = math.max(store[r][rank] or -1, e.uiOrder or 0)
        end
    end
    return store
end

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("WEEKLY_REWARDS_UPDATE")
    f:RegisterEvent("ENCOUNTER_END")
    f:SetScript("OnEvent", function(_, event)
        -- WoW Forever has no seasons or Adventure Guide raids (EJ_SelectTier(0) errored, 2026-11-09)
        if VoidGear.IS_FOREVER then return end
        -- the season's dungeon list loads after login; record a moment later
        C_Timer.After(event == "PLAYER_ENTERING_WORLD" and 5 or 1, function() DB:RecordRaidUnlocks() end)
    end)
end

----------------------------------------------------------------------
-- Get loot pool for a specific vault slot.
-- Returns { items={...}, sourceLabel="...", missingData=nil|string }
----------------------------------------------------------------------
function DB:GetVaultSlotLootPool(slot)
    if not slot then return { items = {}, missingData = "no slot data" } end

    if slot.type == "mplus" then
        -- The dungeon row draws from the whole season's Mythic+ loot pool, whichever
        -- dungeons (Heroic and Mythic 0 included) unlocked the slot.
        local items = self:GetMplusLoot()
        if #items == 0 then
            return { items = {}, missingData = "Click Scan Loot to read this season's dungeon loot" }
        end
        local n = 0
        for _ in pairs(self:SeasonDungeons()) do n = n + 1 end
        return { items = items, sourceLabel = string.format("this season's %d dungeons", n) }

    elseif slot.type == "raid" then
        -- A kill unlocks that boss's loot AND every earlier boss's, on that
        -- difficulty, and an unlock stays for the season: the pool is every boss
        -- up to the furthest one you've killed at the slot's difficulty or higher.
        local raidCache = self:GetRaidLoot()
        local encounters = C_WeeklyRewards.GetActivityEncounterInfo
            and C_WeeklyRewards.GetActivityEncounterInfo(slot.typeID, slot.index)
        if not encounters or #encounters == 0 then
            return { items = {}, missingData = "No raid kills this week (or saved info hasn't loaded)" }
        end
        -- per raid: uiOrder counts within one instance (Blizzard groups them the same way)
        local need = RAID_RANK[slot.level] or 0
        local store = self:RecordRaidUnlocks()
        local furthest = {}
        for r, ranks in pairs(store) do
            if type(ranks) == "table" then
                for rank, order in pairs(ranks) do
                    if rank >= need then furthest[r] = math.max(furthest[r] or -1, order) end
                end
            end
        end
        local eligible, count = {}, 0
        local raidOf = RaidOf
        for _, e in ipairs(encounters) do
            if (e.uiOrder or 0) <= (furthest[raidOf(e)] or -1) then
                eligible[e.encounterID] = true; count = count + 1
            end
        end
        local items = {}
        for _, item in ipairs(raidCache) do
            if item.encounterID and eligible[item.encounterID] then table.insert(items, item) end
        end
        if count == 0 then
            return { items = {}, missingData = "No boss killed at this slot's difficulty this season" }
        end
        return {
            items = items,
            sourceLabel = string.format("%d boss(es) up to your furthest kill", count),
        }

    elseif slot.type == "world" then
        -- Delves don't expose granular history — show all delve-tagged drops or note unavailable
        return {
            items = {},
            missingData = "Delve loot history not exposed by API — open vault NPC for actual roll",
        }
    end
    return { items = {} }
end

----------------------------------------------------------------------
-- Vault reward item level + upgrade track, read from the game: an unlocked
-- vault slot comes with an example reward link (GetVault -> exampleLink), and
-- that item carries the real level and track for this season. Nothing to
-- update per season. Locked slots have no example, so nothing is shown there.
----------------------------------------------------------------------
local TRACK_COLOR = {
    Explorer = "|cff9d9d9d", Adventurer = "|cffffffff", Veteran = "|cff1eff00",
    Champion = "|cff0070dd", Hero = "|cffa335ee", Myth = "|cffff8000",
}

function DB:GetExpectedVaultIlvl(slot)
    local link = slot and slot.exampleLink
    if not link then return nil end
    local ilvl = GetDetailedItemLevelInfo(link)
    return (ilvl and ilvl > 0) and ilvl or nil
end

function DB:GetVaultTrackForSlot(slot)
    local link = slot and slot.exampleLink
    if not (link and C_Item.GetItemUpgradeInfo) then return nil end
    local ok, info = pcall(C_Item.GetItemUpgradeInfo, link)
    local track = ok and info and info.trackString
    if not track or track == "" then return nil end
    return track, TRACK_COLOR[track] or "|cffaaaaaa"
end

-- Filter out clearly-not-current junk items that ended up in the EJ cache
-- (e.g., TBC/WoD/Legion base-ilvl drops from legacy M+ dungeons).
--
-- itemQuality can be either a numeric quality (Enum.ItemQuality 0-7) OR a
-- hex color string like "ff1eff00" depending on where the cache entry came
-- from. Map both forms to a numeric quality for the comparison.
local QUALITY_COLOR_TO_INT = {
    ["ff9d9d9d"] = 0, ["fff0f0f0"] = 1, ["ff1eff00"] = 2,  -- Poor/Common/Uncommon
    ["ff0070dd"] = 3, ["ffa335ee"] = 4, ["ffff8000"] = 5,  -- Rare/Epic/Legendary
    ["ffe6cc80"] = 6, ["ff00ccff"] = 7,                    -- Artifact/Heirloom
}

local function ResolveQuality(q)
    if type(q) == "number" then return q end
    if type(q) == "string" then
        local n = tonumber(q)
        if n then return n end
        return QUALITY_COLOR_TO_INT[q:lower()] or 0
    end
    return 0
end

function DB:IsCurrentSeasonLoot(item)
    if not item then return false end
    -- Drop low-quality (anything below Rare/blue). No item-level floor: the
    -- scan only holds this season's content now, and an old-expansion keystone
    -- dungeon can list low base levels for gear that drops scaled up.
    if ResolveQuality(item.itemQuality) < 3 then return false end
    -- Must have an equippable slot
    if not item.slot or item.slot == 0 then return false end
    return true
end

----------------------------------------------------------------------
-- Great Vault — read live data from C_WeeklyRewards
----------------------------------------------------------------------
function DB:GetVault()
    if not C_WeeklyRewards or not C_WeeklyRewards.GetActivities then return nil end

    local TYPE_MAP = {
        [Enum and Enum.WeeklyRewardChestThresholdType and Enum.WeeklyRewardChestThresholdType.Raid or 1]      = "raid",
        [Enum and Enum.WeeklyRewardChestThresholdType and Enum.WeeklyRewardChestThresholdType.Activities or 2] = "mplus",
        [Enum and Enum.WeeklyRewardChestThresholdType and Enum.WeeklyRewardChestThresholdType.World or 3]     = "world",
    }
    local TYPE_LABEL = {
        raid  = "Raid",
        mplus = "Mythic+",
        world = "World (Delves)",
    }

    local result = { raid = {}, mplus = {}, world = {}, order = { "mplus", "raid", "world" } }

    for typeID, key in pairs(TYPE_MAP) do
        local ok, activities = pcall(C_WeeklyRewards.GetActivities, typeID)
        if ok and activities then
            for _, a in ipairs(activities) do
                local slot = {
                    type      = key,
                    typeID    = typeID,   -- for C_WeeklyRewards.GetActivityEncounterInfo
                    typeLabel = TYPE_LABEL[key],
                    index     = a.index,
                    threshold = a.threshold,
                    progress  = a.progress or 0,
                    level     = a.level or 0,
                    id        = a.id,
                    unlocked  = (a.progress or 0) >= (a.threshold or 999),
                    activityID = a.id,
                    rewards   = a.rewards,
                }
                -- Fetch example item links for unlocked slots
                if slot.unlocked and a.id and C_WeeklyRewards.GetExampleRewardItemHyperlinks then
                    local okLinks, hyperlink, upgradeHyperlink = pcall(C_WeeklyRewards.GetExampleRewardItemHyperlinks, a.id)
                    if okLinks then
                        slot.exampleLink = hyperlink
                        slot.upgradeLink = upgradeHyperlink
                    end
                end
                table.insert(result[key], slot)
            end
            -- Sort by threshold ascending (1, 4, 8 for M+)
            table.sort(result[key], function(a, b) return (a.threshold or 0) < (b.threshold or 0) end)
        end
    end

    return result
end

----------------------------------------------------------------------
-- Scan a single instance for loot at the appropriate difficulty.
-- Returns array of { id, name, slot, encounterID, encounterName, link, ilvl }
----------------------------------------------------------------------
function DB:ScanInstance(instanceID, isRaid)
    if not EJ_SelectInstance then return {} end
    EJ_SelectInstance(instanceID)
    -- Mythic raid difficulty for raids. Dungeons: Mythic Keystone (8) when the
    -- journal offers it for that dungeon; if that comes back with no loot (seen
    -- on legacy dungeons), go back to the journal's own difficulty.
    if isRaid and EJ_SetDifficulty then
        pcall(EJ_SetDifficulty, 16)
    end
    local prevDiff = (not isRaid) and EJ_GetDifficulty and EJ_GetDifficulty()
    if prevDiff and EJ_IsValidInstanceDifficulty and EJ_IsValidInstanceDifficulty(8) then
        pcall(EJ_SetDifficulty, 8)
        if (EJ_GetNumLoot and EJ_GetNumLoot() or 0) == 0 then pcall(EJ_SetDifficulty, prevDiff) end
    end

    local results = {}
    local numLoot = EJ_GetNumLoot and EJ_GetNumLoot() or 0
    for i = 1, numLoot do
        local info = nil
        if C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex then
            local ok, data = pcall(C_EncounterJournal.GetLootInfoByIndex, i)
            if ok then info = data end
        end
        if info and info.itemID then
            -- Use INVTYPE-based slot lookup (handles weapons/shields properly)
            local slotID = self:SlotFromItem(info.itemID, info.slot)
            local ilvl = 0
            if info.link then
                ilvl = select(1, GetDetailedItemLevelInfo(info.link)) or 0
            end
            -- not cached yet: ask now, FillMissing() completes the entry later
            if not info.name or ilvl == 0 then C_Item.RequestLoadItemDataByID(info.itemID) end
            table.insert(results, {
                id            = info.itemID,
                name          = info.name or "?",
                slot          = slotID,
                slotStr       = info.slot,
                encounterID   = info.encounterID,
                encounterName = info.encounterID and EJ_GetEncounterInfo and EJ_GetEncounterInfo(info.encounterID) or nil,
                link          = info.link,
                icon          = info.icon,
                ilvl          = ilvl,
                itemQuality   = info.itemQuality,
            })
        end
    end
    return results
end

----------------------------------------------------------------------
-- Public getters — return cached data, or empty list if not yet scanned
----------------------------------------------------------------------
function DB:GetRaidLoot()
    if not self:IsScanned() then return {} end
    return VoidGearDB.lootCache.raid or {}
end

function DB:GetMplusLoot()
    if not self:IsScanned() then return {} end
    return VoidGearDB.lootCache.mplus or {}
end

function DB:GetWorldLoot()
    local out = {}
    -- World bosses from EJ scan
    if self:IsScanned() and VoidGearDB.lootCache.worldBoss then
        for _, item in ipairs(VoidGearDB.lootCache.worldBoss) do
            table.insert(out, item)
        end
    end
    -- Curated additions (prey hunts, delves, world quests)
    for _, item in ipairs(self.CURATED_WORLD or {}) do
        table.insert(out, item)
    end
    return out
end

-- Scanned items whose name or level wasn't loaded at scan time: fill them in
-- now if the game has them, else ask for them. Returns true while any are missing.
function DB:FillMissing()
    local c = VoidGearDB and VoidGearDB.lootCache
    if not c then return false end
    local missing, linkReady = false, false
    for _, bucket in ipairs({ c.raid, c.mplus, c.worldBoss }) do
        for _, it in ipairs(bucket or {}) do
            -- an item that had no link at scan time has loaded since: the journal
            -- can give its link now (rescan below)
            if it.id and not it.link and C_Item.IsItemDataCachedByID and C_Item.IsItemDataCachedByID(it.id) then
                linkReady = true
            end
            if it.id and (not it.name or it.name == "?") then
                it.name = C_Item.GetItemNameByID(it.id) or it.name
            end
            -- The journal can hand back an ID only. Its link carries the scanned
            -- difficulty / key level, so it comes from a re-scan (DB:Scan retries),
            -- never from the base item (that's a different, lower item level).
            if it.id and not it.link and it.itemQuality == nil then
                it.itemQuality = select(3, C_Item.GetItemInfo(it.id))
            end
            if it.link and (it.ilvl or 0) == 0 then
                it.ilvl = GetDetailedItemLevelInfo(it.link) or 0
            end
            if it.id and (not it.name or it.name == "?" or not it.link or it.ilvl == 0) then
                C_Item.RequestLoadItemDataByID(it.id)
                missing = true
            end
        end
    end
    -- the scan's own retries ran out before the data came: scan again (twice at most)
    if linkReady and not self.scanning and (c.lateRescans or 0) < 2 and self:IsScanned() then
        local late = (c.lateRescans or 0) + 1
        self:Scan(function()
            if VoidGearDB.lootCache then VoidGearDB.lootCache.lateRescans = late end
            if VoidGear.UI then VoidGear.UI:Refresh() end
        end)
    end
    return missing
end

function DB:CurrentSpecID()
    local idx = GetSpecialization and GetSpecialization()
    return idx and idx > 0 and GetSpecializationInfo(idx) or nil
end

-- A scan from an older season, or for another spec (its loot filter), doesn't count.
function DB:IsScanned()
    local c = VoidGearDB and VoidGearDB.lootCache
    return c and c.scannedAt ~= nil and c.seasonKey == self:SeasonKey()
        and c.specID == self:CurrentSpecID() or false
end

-- This season was scanned, but for another spec: the loot is spec-filtered, so
-- a spec change needs a fresh scan (the UI runs it by itself).
function DB:NeedsSpecRescan()
    local c = VoidGearDB and VoidGearDB.lootCache
    return c and c.scannedAt ~= nil and c.seasonKey == self:SeasonKey()
        and c.specID ~= self:CurrentSpecID() or false
end

function DB:GetScanInfo()
    if not self:IsScanned() then return nil end
    local c = VoidGearDB.lootCache
    return {
        scannedAt = c.scannedAt,
        raidCount = #c.raid,
        mplusCount = #c.mplus,
        instances = c.instances,
    }
end
