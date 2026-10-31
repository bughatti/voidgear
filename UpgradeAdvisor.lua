-- 12.1.5 (and WoW Forever) removed the old global item functions; use C_Item's.
local GetDetailedItemLevelInfo = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
----------------------------------------------------------------------
-- VoidGear Upgrade Advisor -- "which equipped item should my crests go into?"
--
-- For every equipped item that can still be upgraded, value its NEXT upgrade
-- step as (spec-weighted stat gain) / (crests it costs), then rank items within
-- each crest pool. Re-ranked after every upgrade, so this is a greedy "best next
-- step": when an item's later steps get pricier (or switch to a higher crest),
-- another item's cheaper step overtakes it -- i.e. it tells you when to stop at
-- 4/6 and start a second item.
--
-- Exact costs come from the upgrade NPC: C_Item.GetItemUpgradeInfo works anywhere
-- but has no costs (and its maxItemLevel is 0 on 12.1.5), so when the NPC window
-- opens we put each equipped item in the upgrade slot for an instant, read
-- C_ItemUpgrade.GetItemUpgradeItemInfo (per-step crest cost incl. discounts,
-- per-step ilvl), and clear it again. Cached per item + upgrade level in
-- VoidGearCharDB, and only exact while the item's discount watermark is the same
-- (DiscountSig). Items never seen at the NPC, or whose watermark moved since,
-- fall back to "same cost per step" and say so in the tooltip.
--
-- Gain model: stats grow ~1% per item level (approximate). Weapon DPS in the
-- Scorer is linear in ilvl, so it grows by step/ilvl instead.
----------------------------------------------------------------------

VoidGear = VoidGear or {}
VoidGear.UpgradeAdvisor = {}
local UA = VoidGear.UpgradeAdvisor

local STAT_GROWTH_PER_ILVL = 0.01

-- slotID -> PaperDoll button name
local SLOTS = {
    { 1,  "CharacterHeadSlot" },     { 2,  "CharacterNeckSlot" },
    { 3,  "CharacterShoulderSlot" }, { 15, "CharacterBackSlot" },
    { 5,  "CharacterChestSlot" },    { 9,  "CharacterWristSlot" },
    { 10, "CharacterHandsSlot" },    { 6,  "CharacterWaistSlot" },
    { 7,  "CharacterLegsSlot" },     { 8,  "CharacterFeetSlot" },
    { 11, "CharacterFinger0Slot" },  { 12, "CharacterFinger1Slot" },
    { 13, "CharacterTrinket0Slot" }, { 14, "CharacterTrinket1Slot" },
    { 16, "CharacterMainHandSlot" }, { 17, "CharacterSecondaryHandSlot" },
}

local TRACK_COLOR = {
    Explorer = "ff9d9d9d", Adventurer = "ffffffff", Veteran = "ff1eff00",
    Champion = "ff0070dd", Hero = "ffa335ee", Myth = "ffff8000",
}
-- Badge colour = priority within that crest type: green = do first,
-- yellow = next, grey = later. (Track colours on the badge told you nothing
-- about what to do first.)
local PRIORITY_RGB = {
    { 0.20, 1.00, 0.20 },   -- #1
    { 1.00, 0.85, 0.10 },   -- #2
    { 0.62, 0.62, 0.62 },   -- #3+
}

local results = {}   -- [slotID] = { track, cur, max, step, gain, rank, of, ilvl }

local function Enabled()
    return not (VoidGearDB and VoidGearDB.upgradeBadges == false)
end

----------------------------------------------------------------------
-- Upgrade-cost cache (filled at the upgrade NPC)
-- VoidGearCharDB.upgradeCosts[itemGUID] = { cur = n, at = time(), steps = {
--     [targetLevel] = { inc = ilvl gained by this step, crestID = id,
--                       crestName = "...", cost = crests, discounted = bool } } }
----------------------------------------------------------------------
local function CostDB()
    VoidGearCharDB = VoidGearCharDB or {}
    VoidGearCharDB.upgradeCosts = VoidGearCharDB.upgradeCosts or {}
    return VoidGearCharDB.upgradeCosts
end

local function SlotGUID(slotID)
    if not (C_Item.GetItemGUID and ItemLocation) then return nil end
    local loc = ItemLocation:CreateFromEquipmentSlot(slotID)
    local ok, g = pcall(C_Item.GetItemGUID, loc)
    return ok and g or nil
end

-- Crest discounts follow the highest item level you (and your account) have
-- had in that item's slot -- the "high watermark", which grows with ANY item
-- you get. A cost recorded under another watermark is no longer exact.
-- Falls back to your equipped item levels if the game won't say.
local function DiscountSig(link)
    local fn = C_ItemUpgrade and C_ItemUpgrade.GetHighWatermarkForItem
    local ok, char, account = false, nil, nil
    if fn and link then ok, char, account = pcall(fn, link) end
    if ok and char then return char .. ":" .. (account or 0) end
    local parts = {}
    for _, s in ipairs(SLOTS) do
        local l = GetInventoryItemLink("player", s[1])
        parts[#parts + 1] = l and (GetDetailedItemLevelInfo(l) or 0) or 0
    end
    return table.concat(parts, ",")
end

local function CurrencyName(id)
    local ok, c = pcall(C_CurrencyInfo.GetCurrencyInfo, id)
    return ok and c and c.name or nil
end

-- Read whatever item currently sits in the upgrade slot into the cache.
-- Returns true if something was recorded.
local function RecordPlacedItem(guid)
    local info = C_ItemUpgrade.GetItemUpgradeItemInfo()
    if not (guid and info and info.upgradeLevelInfos) then return false end
    local steps, prevInc = {}, 0
    for _, li in ipairs(info.upgradeLevelInfos) do
        if li.upgradeLevel > info.currUpgrade then
            -- itemLevelIncrement is cumulative from the current level.
            local s = { inc = (li.itemLevelIncrement or 0) - prevInc, cost = 0, discounted = false }
            prevInc = li.itemLevelIncrement or prevInc
            -- The crest is the currency with a "crest" name; take the largest such cost.
            for _, cc in ipairs(li.currencyCostsToUpgrade or {}) do
                local name = CurrencyName(cc.currencyID)
                if name and name:lower():find("crest", 1, true) and (cc.cost or 0) >= s.cost then
                    s.cost, s.crestID, s.crestName = cc.cost or 0, cc.currencyID, name
                    s.discounted = cc.discountInfo and cc.discountInfo.isDiscounted or false
                end
            end
            s.failure = li.failureMessage
            steps[li.upgradeLevel] = s
        end
    end
    local placed = C_ItemUpgrade.GetItemHyperlink and C_ItemUpgrade.GetItemHyperlink()
    CostDB()[guid] = { cur = info.currUpgrade, at = time(), steps = steps, sig = DiscountSig(placed) }
    return true
end

-- Upgrade NPC opened with an empty slot: snapshot every equipped item's costs.
local scanning = false
function UA:ScanAtNPC()
    if scanning or not (C_ItemUpgrade and C_ItemUpgrade.SetItemUpgradeFromLocation) then return end
    -- If the user already placed an equipped item, remember its slot and put it
    -- back afterwards (a bag item stays put: we don't scan then).
    local restoreSlot
    local placed = C_ItemUpgrade.GetItemHyperlink and C_ItemUpgrade.GetItemHyperlink()
    if placed then
        for _, s in ipairs(SLOTS) do
            if GetInventoryItemLink("player", s[1]) == placed then restoreSlot = s[1] break end
        end
        if not restoreSlot then return end
    end
    scanning = true
    local n = 0
    for _, s in ipairs(SLOTS) do
        local link = GetInventoryItemLink("player", s[1])
        local ok, info = false, nil
        if link then ok, info = pcall(C_Item.GetItemUpgradeInfo, link) end   -- (no `a and f()`: truncates returns)
        if ok and info and info.maxLevel and info.currentLevel and info.currentLevel < info.maxLevel then
            local loc = ItemLocation:CreateFromEquipmentSlot(s[1])
            if pcall(C_ItemUpgrade.SetItemUpgradeFromLocation, loc) and RecordPlacedItem(SlotGUID(s[1])) then
                n = n + 1
            end
        end
    end
    if restoreSlot then
        pcall(C_ItemUpgrade.SetItemUpgradeFromLocation, ItemLocation:CreateFromEquipmentSlot(restoreSlot))
    else
        pcall(C_ItemUpgrade.ClearItemUpgrade)
    end
    scanning = false
    self:RefreshBadges()
    return n
end

-- The user placed an item themselves (or just upgraded it): keep its entry fresh.
-- Matched by itemID + current upgrade level, not the exact link: right after an
-- upgrade the equipped link can still be the old one when the event fires
-- (that left Ula'tek's Bind cached at 1/6 while it was 4/6). Deferred a moment
-- so the inventory has caught up either way.
function UA:OnUpgradeSlotChanged()
    if scanning then return end
    C_Timer.After(0.3, function()
        if scanning then return end
        local info = C_ItemUpgrade.GetItemUpgradeItemInfo()
        local link = C_ItemUpgrade.GetItemHyperlink and C_ItemUpgrade.GetItemHyperlink()
        if not (info and link) then return end
        local itemID = C_Item.GetItemInfoInstant(link)
        local fallback
        for _, s in ipairs(SLOTS) do
            local eq = GetInventoryItemLink("player", s[1])
            if eq and C_Item.GetItemInfoInstant(eq) == itemID then
                local ok, ui = pcall(C_Item.GetItemUpgradeInfo, eq)
                if ok and ui and ui.currentLevel == info.currUpgrade then
                    fallback = s[1]
                    if eq == link then break end   -- exact match wins (two of the same ring)
                end
            end
        end
        if fallback and RecordPlacedItem(SlotGUID(fallback)) then self:RefreshBadges() end
    end)
end

----------------------------------------------------------------------
-- Compute: fills `results` for every equipped, still-upgradable item.
----------------------------------------------------------------------
local function Median(t)
    if #t == 0 then return nil end
    table.sort(t)
    return t[math.floor((#t + 1) / 2)]
end

function UA:Compute()
    wipe(results)
    if not (C_Item and C_Item.GetItemUpgradeInfo and VoidGear.Scorer) then return results end
    local okCtx, weights, primary = pcall(VoidGear.Scorer.GetActiveContext, VoidGear.Scorer)
    if not okCtx then return results end
    local db = CostDB()

    local groups = {}
    for _, s in ipairs(SLOTS) do
        local slotID = s[1]
        local link = GetInventoryItemLink("player", slotID)
        if link then
            local ok, info = pcall(C_Item.GetItemUpgradeInfo, link)
            local ilvl = GetDetailedItemLevelInfo(link) or 0
            if ok and info and info.maxLevel and info.currentLevel
               and info.currentLevel < info.maxLevel and info.trackString and ilvl > 0 then
                local r = {
                    slot = slotID, track = info.trackString,
                    cur = info.currentLevel, max = info.maxLevel, ilvl = ilvl,
                }
                -- Exact next step from the NPC cache, if it matches the item's current
                -- level and its discount watermark hasn't moved since.
                local entry = db[SlotGUID(slotID) or ""]
                local nextStep = entry and entry.cur == info.currentLevel and entry.sig == DiscountSig(link)
                                 and entry.steps[info.currentLevel + 1]
                if nextStep and nextStep.inc > 0 then
                    r.known, r.step = true, nextStep.inc
                    r.cost, r.crestName = nextStep.cost, nextStep.crestName
                    r.discounted, r.failure = nextStep.discounted, nextStep.failure
                    -- After this step: does the one after cost more / a different crest?
                    local after = entry.steps[info.currentLevel + 2]
                    if after then r.nextCost, r.nextCrest = after.cost, after.crestName end
                end
                local score, breakdown, _, extras = VoidGear.Scorer:ScoreLink(link, weights, primary)
                score = score or 0
                local wdps = (breakdown and breakdown.WeaponDPS) or 0
                -- a socket's gem is the same gem at any item level: it doesn't grow
                local sockets = (extras and extras.socketValue) or 0
                r.gainPerIlvl = (score - wdps - sockets) * STAT_GROWTH_PER_ILVL + wdps / ilvl
                results[slotID] = r
            end
        end
    end

    -- Group = the crest pool the next step spends. An item with no fresh cost
    -- data joins the crest its track-mates use (else it would form its own
    -- group and get a second "#1" badge for the same crest).
    local trackCrest = {}
    for _, r in pairs(results) do
        if r.crestName and not trackCrest[r.track] then trackCrest[r.track] = r.crestName end
    end
    for _, r in pairs(results) do
        r.group = r.crestName or trackCrest[r.track] or (r.track .. " crests")
        r.letter = r.group:sub(1, 1)
        groups[r.group] = groups[r.group] or {}
        table.insert(groups[r.group], r)
    end

    for _, list in pairs(groups) do
        -- Items not yet seen at the NPC borrow the group's typical step + cost.
        local steps, costs = {}, {}
        for _, r in ipairs(list) do
            if r.known then steps[#steps + 1] = r.step; costs[#costs + 1] = r.cost end
        end
        local typStep, typCost = Median(steps) or 1, Median(costs)
        for _, r in ipairs(list) do
            local step = r.known and r.step or typStep
            local cost = r.known and r.cost or typCost
            r.gain = r.gainPerIlvl * step
            if cost == nil then
                r.value = r.gain                     -- nothing known: rank by gain
            elseif cost <= 0 then
                r.value, r.free = math.huge, true    -- fully discounted step
            else
                r.value = r.gain / cost
            end
        end
        table.sort(list, function(a, b) return a.value > b.value end)
        local best = list[1].value
        for i, r in ipairs(list) do
            r.rank, r.of = i, #list
            r.pct = (best == math.huge) and (r.free and 100 or 0)
                    or (best > 0 and math.floor(r.value / best * 100 + 0.5) or 0)
        end
    end
    return results
end

----------------------------------------------------------------------
-- Badges on the Character tab slots
----------------------------------------------------------------------
local badges = {}

-- Character-sheet addons (Chonky Character Sheet etc.) reuse Blizzard's slot
-- buttons but move them and stack their own art on top. So the badge lives on
-- its OWN child frame, parented to the slot button (follows it anywhere) and
-- kept a few levels above it (nothing the sheet adds to the button covers it).
local function GetBadge(slotID, btnName)
    local btn = _G[btnName]
    if not btn then return nil end
    local holder = badges[slotID]
    if not holder then
        holder = CreateFrame("Frame", nil, btn)
        holder:SetAllPoints(btn)
        -- Text only (no box -- it hid too much of the icon). Thick outline +
        -- shadow keep it readable on any item art.
        holder.text = holder:CreateFontString(nil, "OVERLAY")
        holder.text:SetFont(STANDARD_TEXT_FONT, 12, "THICKOUTLINE")
        holder.text:SetShadowOffset(1, -1)
        holder.text:SetShadowColor(0, 0, 0, 1)
        holder.text:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 2, 2)
        holder.text:SetJustifyH("RIGHT")
        badges[slotID] = holder
    end
    holder:SetFrameStrata(btn:GetFrameStrata())
    holder:SetFrameLevel(btn:GetFrameLevel() + 10)
    return holder.text, holder
end

function UA:RefreshBadges()
    local on = Enabled()
    if on then self:Compute() end   -- always, so tooltips stay current
    if not (_G.CharacterFrame and CharacterFrame:IsShown()) then return end
    for _, s in ipairs(SLOTS) do
        local fs, holder = GetBadge(s[1], s[2])
        if fs then
            local r = on and results[s[1]]
            if r then
                -- Colour = PRIORITY (what to do first); the letter = which crest.
                local c = PRIORITY_RGB[math.min(r.rank, 3)]
                fs:SetText(r.letter .. r.rank)
                fs:SetTextColor(c[1], c[2], c[3])
                holder:Show()
            else
                fs:SetText("")
                holder:Hide()
            end
        end
    end
end

----------------------------------------------------------------------
-- Tooltip line when hovering a Character-tab slot
----------------------------------------------------------------------
-- Matched by the hovered ITEM, not by which frame owns the tooltip, so it works
-- under any character-sheet addon (even ones that build their own slot buttons)
-- and when hovering the same item anywhere else.
local function SlotForTooltip(tooltip, data)
    local guid = data and data.guid
    if guid and C_Item.GetItemGUID and ItemLocation then
        for _, s in ipairs(SLOTS) do
            local loc = ItemLocation:CreateFromEquipmentSlot(s[1])
            local ok, g = pcall(C_Item.GetItemGUID, loc)
            if ok and g == guid then return s[1] end
        end
        return nil
    end
    -- No item GUID on this tooltip: fall back to an exact link match.
    local _, link = tooltip:GetItem()
    if not link then return nil end
    for _, s in ipairs(SLOTS) do
        if GetInventoryItemLink("player", s[1]) == link then return s[1] end
    end
end

local function OnItemTooltip(tooltip, data)
    if tooltip ~= GameTooltip or not Enabled() then return end
    local slotID = SlotForTooltip(tooltip, data)
    if not slotID then return end
    if not next(results) then UA:Compute() end
    local r = results[slotID]
    if not r then return end
    local col = TRACK_COLOR[r.track] or "ffffffff"
    tooltip:AddLine(" ")
    local stepTxt = r.known and ("  (+%d ilvl)"):format(math.floor(r.step + 0.5)) or ""
    tooltip:AddLine(("|cff00c7ffVoidGear upgrade:|r |c%s%s %d/%d|r -> %d/%d%s")
        :format(col, r.track, r.cur, r.max, r.cur + 1, r.max, stepTxt))
    if r.known then
        if r.free or (r.cost or 0) <= 0 then
            tooltip:AddLine("Next step is FREE (discounted) -- do it now", 0.2, 1, 0.2)
        else
            tooltip:AddLine(("Next step costs %d %s%s"):format(r.cost, r.crestName or "crests",
                r.discounted and " |cff33ff33(discounted)|r" or ""), 1, 1, 1)
        end
        -- Heads-up when the step after this one gets pricier or needs another crest.
        if r.nextCost and r.cost and (r.nextCost > r.cost or r.nextCrest ~= r.crestName) then
            tooltip:AddLine(("The step after costs %d %s"):format(r.nextCost, r.nextCrest or "crests"),
                1, 0.82, 0.3)
        end
        if r.failure then tooltip:AddLine(r.failure, 1, 0.3, 0.3, true) end
    else
        tooltip:AddLine("Open the upgrade NPC once for exact crest costs", 0.6, 0.6, 0.6)
    end
    local pool = r.crestName or (r.track .. " crests")
    if r.of == 1 then
        tooltip:AddLine(("Your only item using %s"):format(pool), 0.2, 1, 0.2)
    elseif r.rank == 1 then
        tooltip:AddLine(("Best value for your %s (1 of %d)"):format(pool, r.of), 0.2, 1, 0.2)
    else
        tooltip:AddLine(("#%d of %d for your %s -- %d%% of the stats-per-crest of the best one")
            :format(r.rank, r.of, pool, r.pct), 1, 1, 1, true)
    end
    tooltip:AddLine("Badge: |cff33ff33green|r = do first, |cffffd919yellow|r = next, |cff9e9e9egrey|r = later. Letter = crest type.",
        0.6, 0.6, 0.6, true)
end

----------------------------------------------------------------------
-- Slash report: /vgear upgrades
----------------------------------------------------------------------
function UA:Report()
    self:Compute()
    local byGroup, groups = {}, {}
    for _, r in pairs(results) do
        if not byGroup[r.group] then byGroup[r.group] = {}; groups[#groups + 1] = r.group end
        table.insert(byGroup[r.group], r)
    end
    if #groups == 0 then
        VoidGear:Print("No equipped item can be upgraded further.")
        return
    end
    VoidGear:Print("Upgrade priority (best stats per crest first):")
    for _, g in ipairs(groups) do
        table.sort(byGroup[g], function(a, b) return a.rank < b.rank end)
        local parts = {}
        for _, r in ipairs(byGroup[g]) do
            local link = GetInventoryItemLink("player", r.slot)
            local cost = r.known and (r.free and "free" or (r.cost .. " crests")) or "cost ?"
            parts[#parts + 1] = ("%s %d/%d (%s, %d%%)"):format(link or "?", r.cur, r.max, cost, r.pct)
        end
        DEFAULT_CHAT_FRAME:AddMessage(("  |cffffd200%s|r: %s"):format(g, table.concat(parts, ", ")))
    end
end

----------------------------------------------------------------------
-- /vgear catalyst -- what to put through the Catalyst.
-- For each tier slot: what's equipped (and its set), plus every equipped or
-- bagged item the Catalyst will take (C_Item.IsItemConvertibleAndValidForPlayer),
-- with ilvl, upgrade track and spec score. Season 2's Catalyst keeps the item's
-- stats (it only adds set membership), so the best candidate per slot is simply
-- the highest-scoring convertible item you'd actually wear.
----------------------------------------------------------------------
local TIER_SLOTS = {
    { 1,  "Head",      { INVTYPE_HEAD = true } },
    { 3,  "Shoulders", { INVTYPE_SHOULDER = true } },
    { 5,  "Chest",     { INVTYPE_CHEST = true, INVTYPE_ROBE = true } },
    { 10, "Hands",     { INVTYPE_HAND = true } },
    { 7,  "Legs",      { INVTYPE_LEGS = true } },
}

local manafluxID
local function ManafluxCharges()
    -- Each season has its own Manaflux (S1 Dawnlight 3378, S2 Venomblight 3465 --
    -- probed 2026-10-19). Only the newest one converts current-season gear, so take
    -- the HIGHEST id (the old season's leftover charges are useless here).
    if manafluxID == nil then
        manafluxID = false
        for id = 2800, 6000 do
            local ok, c = pcall(C_CurrencyInfo.GetCurrencyInfo, id)
            if ok and c and c.name and c.name:find("Manaflux", 1, true) and c.discovered then
                manafluxID = id
            end
        end
    end
    if not manafluxID then return nil end
    local c = C_CurrencyInfo.GetCurrencyInfo(manafluxID)
    return c and c.quantity, c and c.name
end

local function DescribeItem(link, loc, weights, primary)
    local ilvl = GetDetailedItemLevelInfo(link) or 0
    local track = ""
    local ok, ui = pcall(C_Item.GetItemUpgradeInfo, link)
    if ok and ui and ui.trackString then track = (" %s %d/%d"):format(ui.trackString, ui.currentLevel, ui.maxLevel) end
    local setID = select(16, C_Item.GetItemInfo(link))
    local getSetInfo = (C_Item and C_Item.GetItemSetInfo) or GetItemSetInfo   -- global gone in 12.1.5
    local setName = setID and setID > 0 and getSetInfo and getSetInfo(setID)
    local conv = loc and C_Item.IsItemConvertibleAndValidForPlayer
        and select(2, pcall(C_Item.IsItemConvertibleAndValidForPlayer, loc))
    local score = VoidGear.Scorer:ScoreLink(link, weights, primary) or 0
    return { link = link, ilvl = ilvl, track = track, set = setName, conv = conv == true, score = score }
end

function UA:CatalystReport()
    local okCtx, weights, primary = pcall(VoidGear.Scorer.GetActiveContext, VoidGear.Scorer)
    if not okCtx then VoidGear:Print("No stat weights loaded.") return end
    local n, cname = ManafluxCharges()
    VoidGear:Print(("Catalyst: %s"):format(n and (n .. " " .. cname) or "charge currency not found"))

    -- Bag candidates by tier slot.
    local bagItems = {}
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local link = C_Container.GetContainerItemLink(bag, slot)
            if link then
                local equipLoc = select(4, C_Item.GetItemInfoInstant(link))
                for _, ts in ipairs(TIER_SLOTS) do
                    if ts[3][equipLoc] then
                        local d = DescribeItem(link, ItemLocation:CreateFromBagAndSlot(bag, slot), weights, primary)
                        if d.conv then
                            bagItems[ts[1]] = bagItems[ts[1]] or {}
                            table.insert(bagItems[ts[1]], d)
                        end
                    end
                end
            end
        end
    end

    for _, ts in ipairs(TIER_SLOTS) do
        local link = GetInventoryItemLink("player", ts[1])
        local eq = link and DescribeItem(link, ItemLocation:CreateFromEquipmentSlot(ts[1]), weights, primary)
        local line = ("|cffffd200%s|r: "):format(ts[2])
        if eq then
            line = line .. ("%s %d%s%s%s"):format(eq.link, eq.ilvl, eq.track,
                eq.set and (" |cff1eff00[" .. eq.set .. "]|r") or "",
                eq.conv and " |cff00c7ff(convertible)|r" or "")
        else
            line = line .. "empty"
        end
        DEFAULT_CHAT_FRAME:AddMessage(line)
        local list = bagItems[ts[1]]
        if list then
            table.sort(list, function(a, b) return a.score > b.score end)
            for _, d in ipairs(list) do
                local pct = (eq and eq.score > 0) and math.floor((d.score / eq.score - 1) * 100 + 0.5) or 0
                DEFAULT_CHAT_FRAME:AddMessage(("    bag: %s %d%s  (%+d%% vs equipped)"):format(d.link, d.ilvl, d.track, pct))
            end
        end
    end
end

function UA:SetEnabled(on)
    VoidGearDB = VoidGearDB or {}
    VoidGearDB.upgradeBadges = on and true or false
    self:RefreshBadges()
end

----------------------------------------------------------------------
-- Wiring
----------------------------------------------------------------------
local refreshPending
local function QueueRefresh()
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0.3, function()
        refreshPending = false
        UA:RefreshBadges()
    end)
end

local ef = CreateFrame("Frame")
ef:RegisterEvent("PLAYER_LOGIN")
ef:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ef:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ef:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
ef:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
ef:RegisterEvent("ITEM_UPGRADE_MASTER_SET_ITEM")
ef:RegisterEvent("ITEM_UPGRADE_MASTER_UPDATE")
ef:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        if Enum.PlayerInteractionType and arg1 == Enum.PlayerInteractionType.ItemUpgrade then
            -- Let Blizzard's frame finish opening, then snapshot all costs.
            C_Timer.After(0.2, function() UA:ScanAtNPC() end)
        end
        return
    elseif event == "ITEM_UPGRADE_MASTER_SET_ITEM" or event == "ITEM_UPGRADE_MASTER_UPDATE" then
        UA:OnUpgradeSlotChanged()
        return
    elseif event == "PLAYER_LOGIN" then
        -- Both: sheet addons may show the paper doll without re-showing the frame.
        if _G.CharacterFrame then CharacterFrame:HookScript("OnShow", QueueRefresh) end
        if _G.PaperDollFrame then PaperDollFrame:HookScript("OnShow", QueueRefresh) end
        if TooltipDataProcessor and Enum.TooltipDataType then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
        end
        return
    end
    QueueRefresh()
end)
