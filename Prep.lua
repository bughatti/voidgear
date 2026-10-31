----------------------------------------------------------------------
-- VoidGear Prep — what to enchant and gem, matched to what the top Mythic+
-- players of your spec use, and the shopping list to get there.
--
-- Data, all from the game or Blizzard's API:
--   TopGearData.specs[specID].enchants / .gems  which enchants and gems the top
--     players use (stat-pull, Blizzard API)
--   PrepData.enchants / .sameName  enchant -> its scrolls, and each gem / kit at
--     every crafted quality (prep-data, Blizzard's game tables)
--
-- Best / Budget: Best buys the higher crafted quality, Budget the same item at
-- the lower one (never a different stat). A global switch, a per-item override
-- (remembered for that exact item), and items you'll likely replace soon (low
-- upgrade track, or well below your average item level) default to Budget.
--
-- Consumables: the top-player data has none (the API doesn't show what anyone
-- eats), so each candidate in PrepData.consumables is read from its tooltip
-- and scored with your spec's stat priority, like gear (ScoreConsumable).
--
-- Applying: the game needs your click on the gear slot (enchants) and in the
-- socket window (gems); Prep can only find and list what to buy.
----------------------------------------------------------------------

VoidGear = VoidGear or {}
VoidGear.Prep = {}
local Prep = VoidGear.Prep

local GetDetailedItemLevelInfo = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo

-- Blizzard's equipment slot -> inventory slots (same pools as TopGearData).
local POOL_SLOTS = {
    HEAD = { 1 }, NECK = { 2 }, SHOULDER = { 3 }, BACK = { 15 }, CHEST = { 5 }, WRIST = { 9 },
    HANDS = { 10 }, WAIST = { 6 }, LEGS = { 7 }, FEET = { 8 }, FINGER = { 11, 12 },
    MAIN_HAND = { 16 }, MAIN_HAND_SOLO = { 16 }, OFF_HAND = { 17 },
}
local POOL_ORDER = { "HEAD", "NECK", "SHOULDER", "BACK", "CHEST", "WRIST", "HANDS", "WAIST", "LEGS",
    "FEET", "FINGER", "MAIN_HAND", "MAIN_HAND_SOLO", "OFF_HAND" }

-- A slot "should be enchanted" when at least this share of top players use its top enchant.
local MIN_SHARE = 0.5
-- Tracks you'll usually replace soon: these default to Budget.
local LOW_TRACKS = { Explorer = true, Adventurer = true, Veteran = true }
local LOW_ILVL_GAP = 15

local function SpecData()
    local idx = GetSpecialization and GetSpecialization()
    local specID = idx and idx > 0 and GetSpecializationInfo(idx)
    local data = VoidGear.TopGearData
    return specID and data and data.specs and data.specs[specID]
end

local function DB()
    VoidGearCharDB = VoidGearCharDB or {}
    VoidGearCharDB.prep = VoidGearCharDB.prep or { mode = "best", overrides = {} }
    return VoidGearCharDB.prep
end

local function ItemIDFromLink(link)
    return link and tonumber(link:match("item:(%d+)"))
end

local function SlotGUID(slotID)
    if not (C_Item.GetItemGUID and ItemLocation) then return nil end
    local ok, guid = pcall(C_Item.GetItemGUID, ItemLocation:CreateFromEquipmentSlot(slotID))
    return ok and guid or nil
end

-- Crafted quality of an item (1 = lower, 2 = higher in Midnight). Falls back to
-- its place in its group: the game data lists qualities in item ID order.
local function Quality(itemID, group)
    for _, fn in ipairs({ C_TradeSkillUI and C_TradeSkillUI.GetItemCraftedQualityByItemInfo,
                          C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityByItemInfo }) do
        if fn then
            local ok, q = pcall(fn, itemID)
            if ok and q and q > 0 then return q end
        end
    end
    for i, id in ipairs(group or {}) do
        if id == itemID then return i end
    end
    return 1
end

-- The item to buy from a group (same thing at each quality) for a mode.
local function Pick(group, mode)
    if not group or #group == 0 then return nil end
    local best, bestQ
    for _, id in ipairs(group) do
        local q = Quality(id, group)
        local better = not best or (mode == "budget" and q < bestQ) or (mode ~= "budget" and q > bestQ)
        if better then best, bestQ = id, q end
    end
    return best
end

----------------------------------------------------------------------
-- Best / Budget
----------------------------------------------------------------------
function Prep:GetMode() return DB().mode or "best" end

function Prep:SetMode(mode)
    DB().mode = (mode == "budget") and "budget" or "best"
end

-- Mode for one equipped item, and why: your choice for that item, else Budget
-- for gear you'll likely replace soon, else the global switch.
function Prep:ModeFor(slotID)
    local guid = SlotGUID(slotID)
    local o = guid and DB().overrides[guid]
    if o then return o, "your choice for this item" end
    local mode = self:GetMode()
    if mode == "best" then
        local link = GetInventoryItemLink("player", slotID)
        local ok, info = pcall(C_Item.GetItemUpgradeInfo, link or "")
        if ok and info and info.trackString and LOW_TRACKS[info.trackString] then
            return "budget", info.trackString .. " track: likely replaced soon"
        end
        local _, avg = GetAverageItemLevel()
        local ilvl = link and GetDetailedItemLevelInfo(link)
        if ilvl and avg and ilvl < avg - LOW_ILVL_GAP then
            return "budget", ("item level %d, well below your %d: likely replaced soon"):format(ilvl, math.floor(avg))
        end
    end
    return mode, nil
end

-- Flip one item between Best and Budget (remembered for that exact item).
function Prep:ToggleItem(slotID)
    local guid = SlotGUID(slotID)
    if not guid then return end
    DB().overrides[guid] = (self:ModeFor(slotID) == "best") and "budget" or "best"
end

-- Back to automatic for every item (global switch + the likely-replaced rule).
function Prep:ClearOverrides()
    DB().overrides = {}
end

----------------------------------------------------------------------
-- Compute: rows (one per problem) + the shopping list
----------------------------------------------------------------------
-- row = { slot, kind = "enchant"|"gem", socket, severity = "need"|"swap"|"rank",
--         problem, buy = itemID, buyGroup, mode, modeWhy }
function Prep:Compute()
    local d = SpecData()
    if not d then return nil end
    local rows = {}
    local pd = VoidGear.PrepData or { enchants = {}, sameName = {} }
    -- highest crafted quality each enchant comes in (Best wants that one)
    local maxTier = {}
    for _, e in pairs(pd.enchants) do
        if (maxTier[e.name] or 0) < e.tier then maxTier[e.name] = e.tier end
    end

    -- Enchants ---------------------------------------------------------
    local hasOffHand = GetInventoryItemLink("player", 17) ~= nil
    for _, pool in ipairs(POOL_ORDER) do
        local list = d.enchants and d.enchants[pool]
        local top = list and list[1]
        local skipWeapon = (pool == "MAIN_HAND" and not hasOffHand) or (pool == "MAIN_HAND_SOLO" and hasOffHand)
        if top and not skipWeapon then
            local per = (pool == "FINGER") and 2 * d.players
                or (pool == "OFF_HAND" or pool == "MAIN_HAND") and math.max(d.offHand or 0, 1)
                or pool == "MAIN_HAND_SOLO" and math.max(d.players - (d.offHand or 0), 1)
                or d.players
            if top.n / per >= MIN_SHARE then
                local topInfo = pd.enchants[top.id]
                local group = topInfo and topInfo.items or (top.item and (pd.sameName[top.item] or { top.item }))
                local topName = topInfo and topInfo.name or top.name
                for _, slotID in ipairs(POOL_SLOTS[pool]) do
                    local link = GetInventoryItemLink("player", slotID)
                    if link then   -- no group = nothing to buy (e.g. a runeforge); still say it's missing
                        local meta = VoidGear.Scanner:ParseLink(link)
                        local have = meta and meta.enchant or 0
                        local haveInfo = pd.enchants[have]
                        local mode, why = self:ModeFor(slotID)
                        local row = { slot = slotID, kind = "enchant", buyGroup = group, mode = mode, modeWhy = why,
                            topName = topName, share = top.n / per }
                        if have == 0 then
                            row.severity, row.problem = "need", "No enchant"
                        elseif haveInfo and topInfo and haveInfo.name == topInfo.name then
                            -- same enchant: only Best asks for its highest quality
                            if mode == "best" and haveInfo.tier < (maxTier[haveInfo.name] or haveInfo.tier) then
                                row.severity, row.problem = "rank", "Lower quality of the same enchant"
                            else
                                row = nil
                            end
                        elseif have == top.id or (top.item and list[2] and have == list[2].id) then
                            row = nil   -- what top players use (kits: either of their top two)
                            row = nil
                        elseif haveInfo then
                            row.severity, row.problem = "swap", "Top players use another enchant"
                            row.haveName = haveInfo.name
                        else
                            row.severity, row.problem = "need", "Old or unknown enchant"
                        end
                        if row then
                            row.buy = group and Pick(group, mode)
                            rows[#rows + 1] = row
                        end
                    end
                end
            end
        end
    end

    -- Gems ---------------------------------------------------------------
    local normal, diamond
    for _, g in ipairs(d.gems or {}) do
        local isDiamond = (g.name or ""):find("Diamond")
        if isDiamond and not diamond then diamond = g elseif not isDiamond and not normal then normal = g end
    end
    local wantDiamond = diamond and diamond.n >= 0.4 * d.players
    local hasDiamond = false
    local sockets = {}
    for _, slotID in ipairs(VoidGear.PLAN_SLOTS) do
        local link = GetInventoryItemLink("player", slotID)
        local n = link and C_Item.GetItemNumSockets and C_Item.GetItemNumSockets(link) or 0
        for i = 1, n do
            local gemName, gemLink = C_Item.GetItemGem(link, i)
            local gemID = ItemIDFromLink(gemLink)
            -- only a current diamond counts (an old one gets replaced below)
            if gemID and pd.sameName[gemID] and gemName and gemName:find("Diamond") then hasDiamond = true end
            sockets[#sockets + 1] = { slot = slotID, socket = i, gemID = gemID, gemName = gemName }
        end
    end
    local diamondPlaced = hasDiamond or not wantDiamond
    for _, s in ipairs(sockets) do
        local problem
        if not s.gemID then
            problem = "Empty socket"
        elseif not pd.sameName[s.gemID] then
            problem = "Old gem (earlier expansion)"
        end
        if problem then
            local g = normal
            if not diamondPlaced then g, diamondPlaced = diamond, true end
            if g then
                local group = pd.sameName[g.id] or { g.id }
                local mode, why = self:ModeFor(s.slot)
                rows[#rows + 1] = { slot = s.slot, kind = "gem", socket = s.socket, severity = "need",
                    problem = problem, buyGroup = group, buy = Pick(group, mode), mode = mode, modeWhy = why,
                    topName = g.name, haveName = s.gemName }
            end
        end
    end
    -- every socket holds a current gem but none is the diamond: swap one
    if not diamondPlaced and sockets[1] then
        local s = sockets[1]
        local group = pd.sameName[diamond.id] or { diamond.id }
        local mode, why = self:ModeFor(s.slot)
        rows[#rows + 1] = { slot = s.slot, kind = "gem", socket = s.socket, severity = "need",
            problem = "No diamond: swap this gem", buyGroup = group, buy = Pick(group, mode), mode = mode,
            modeWhy = why, topName = diamond.name, haveName = s.gemName }
    end

    -- Consumables ----------------------------------------------------------
    local consumables, pending = self:Consumables()

    -- Shopping list: one line per item to buy ---------------------------------
    local shop, byID = {}, {}
    for _, r in ipairs(rows) do
        -- a swap (other enchant) or a higher quality of what you have are optional
        -- upgrades, shown in the tab but not must-buys (an enchanted slot is done)
        if r.buy and r.severity == "need" then
            local e = byID[r.buy]
            if not e then
                e = { id = r.buy, count = 0, have = C_Item.GetItemCount(r.buy, true) or 0 }
                byID[r.buy] = e
                shop[#shop + 1] = e
            end
            e.count = e.count + 1
        end
    end
    for _, c in ipairs(consumables) do
        if c.buy and c.have == 0 and not c.other then   -- nothing at all for this job
            shop[#shop + 1] = { id = c.buy, have = 0, consumable = true }
        end
    end
    return { rows = rows, consumables = consumables, shop = shop, players = d.players, label = d.label,
        pending = pending }
end

----------------------------------------------------------------------
-- Consumables
----------------------------------------------------------------------
local CONSUMABLE_JOBS = {   -- labels fit the slot column
    { job = "flask",  label = "Flask" },
    { job = "potion", label = "Potion" },
    { job = "health", label = "Healing", from = "potion" },
    { job = "food",   label = "Food" },
    { job = "oil",    label = "Weapon oil" },
    { job = "rune",   label = "Rune" },
}

-- Stat words in tooltips -> stat weight keys. "primary stat" = yours.
local STAT_WORDS = {
    { "critical strike", "Crit" }, { "haste", "Haste" }, { "mastery", "Mastery" },
    { "versatility", "Versatility" }, { "agility", "Agility" }, { "strength", "Strength" },
    { "intellect", "Intellect" }, { "highest secondary stat", "BESTSEC" }, { "primary stat", "PRIMARY" },
}

local tipCache = {}   -- itemID -> lower-cased tooltip text (once loaded)

-- Tooltips name your spec's own stat ("Increases Agility by 25" on the augment
-- rune; Intellect as Resto), so text cached in one spec is wrong in the next.
local specWatch = CreateFrame("Frame")
specWatch:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
specWatch:SetScript("OnEvent", function() wipe(tipCache) end)

local function TooltipText(itemID)
    if tipCache[itemID] then return tipCache[itemID] end
    -- An item still loading has a placeholder tooltip ("Retrieving item
    -- information"); reading (and caching) that scored it 0 for the session.
    if C_Item.IsItemDataCachedByID and not C_Item.IsItemDataCachedByID(itemID) then
        C_Item.RequestLoadItemDataByID(itemID)
        return nil
    end
    -- The "Use:" text is the item's spell, which loads on its own: an item that
    -- is cached but whose spell isn't has a tooltip with no stats in it.
    local _, spellID = C_Item.GetItemSpell(itemID)
    if spellID and C_Spell.IsSpellDataCached and not C_Spell.IsSpellDataCached(spellID) then
        C_Spell.RequestLoadSpellData(spellID)
        return nil
    end
    local ok, data = pcall(C_TooltipInfo.GetItemByID, itemID)
    if not ok or not data or not data.lines or #data.lines < 2 then
        C_Item.RequestLoadItemDataByID(itemID)
        return nil
    end
    local parts = {}
    for _, line in ipairs(data.lines) do
        local t = line.leftText
        if t and not (issecretvalue and issecretvalue(t)) then parts[#parts + 1] = t end
    end
    local text = table.concat(parts, "\n"):lower()
    tipCache[itemID] = text
    return text
end

local function Num(s) return tonumber((s:gsub(",", ""))) end

-- Amount of each stat a tooltip gives: "gain 50 mastery", "increases your
-- critical strike by 151" (flask), "increases agility by 25" (augment rune),
-- "250 of your highest secondary stat", "increasing your critical strike and
-- haste by 600" (Phoenix Oil: every stat in the list gets the number).
local function ParseStats(text)
    local got = {}
    local function add(key, n)
        if n and n > (got[key] or 0) then got[key] = n end
    end
    for _, w in ipairs(STAT_WORDS) do
        add(w[2], Num(text:match("([%d,]+) " .. w[1]) or ""))
        add(w[2], Num(text:match("([%d,]+) of your " .. w[1]) or ""))   -- "250 of your highest secondary stat"
        add(w[2], Num(text:match(w[1] .. " by ([%d,]+)") or ""))   -- "increases agility by 25" (augment rune)
    end
    -- "increases your critical strike and haste by 600", "increasing your ..." (Phoenix Oil)
    for segment, n in text:gmatch("increas%a* your ([^%.]-) by ([%d,]+)") do
        for _, w in ipairs(STAT_WORDS) do
            if segment:find(w[1], 1, true) then add(w[2], Num(n)) end
        end
    end
    -- "highest secondary stat" also contains "secondary stat"; "primary stat" isn't a stat word clash
    return got
end

-- Score by the spec's weights: your primary stat counts 1, secondaries their weight.
function Prep:ScoreConsumable(text)
    local weights, primary = VoidGear.Scorer:GetActiveContext()
    local best = 0
    for _, k in ipairs({ "Crit", "Haste", "Mastery", "Versatility" }) do
        best = math.max(best, weights[k] or 0)
    end
    local score = 0
    for key, n in pairs(ParseStats(text)) do
        local w = (key == "PRIMARY" or key == primary) and 1 or (key == "BESTSEC" and best) or weights[key] or 0
        score = score + n * w
    end
    return score
end

-- An effect with a catch: never the main pick, shown as the stronger-but-risky
-- option instead. "While under the effects of this potion the Void may extract
-- its toll, opening a void zone at your feet" (Draught of Rampant Abandon);
-- "gain 1,584 of your highest secondary stat while losing 213 of your lowest"
-- (Potion of Recklessness).
local function HasCatch(text)
    return text:find("while under the effects of this") or text:find("while losing")
        or text:find("reduc") or text:find("decreas")
end

-- In your bags only: a consumable in the bank doesn't help in a key.
local function CountGroup(group)
    local n = 0
    for _, id in ipairs(group) do n = n + (C_Item.GetItemCount(id) or 0) end
    return n
end

-- Fleeting (from a cauldron) and Hearty (persists through death) versions:
-- count as "you have one", but the pick to buy is the regular item.
local function Buyable(group)
    local name = C_Item.GetItemNameByID(group[1]) or ""
    return not (name:find("^Fleeting ") or name:find("^Hearty "))
end

-- One line per job: the best candidate for your spec, and what you carry.
--   have      = how many of the pick (any quality) you have
--   other     = { group, count } the job item you carry most of, when not the pick
--   risky     = { group } a stronger option with a catch, if any
-- Returns list, pending (some tooltips not loaded yet).
function Prep:Consumables()
    local pd = VoidGear.PrepData
    local mode = self:GetMode()
    local out, pending = {}, false
    local hasMana = (UnitPowerMax("player", Enum.PowerType.Mana) or 0) > 0
    for _, j in ipairs(CONSUMABLE_JOBS) do
        local best, bestScore, risky, riskyScore, other, otherCount
        for _, group in ipairs(pd and pd.consumables and pd.consumables[j.from or j.job] or {}) do
            local text = TooltipText(group[1])
            if not text then
                pending = true
            else
                local score = 0
                if j.job == "health" then
                    score = Num(text:match("restores? ([%d,]+) health") or "") or 0
                    if text:find("mana") and not hasMana then score = 0 end
                elseif j.job == "potion" then
                    if not text:find("restores? [%d,]+ health") and not text:find("restores? [%d,]+ mana") then
                        score = self:ScoreConsumable(text)
                    end
                elseif j.job == "food" then
                    if text:find("well fed") then score = self:ScoreConsumable(text) end
                else
                    score = self:ScoreConsumable(text)
                end
                -- food you set out for the group (Amani Cornucopia) counts as food you
                -- have, but the pick is food for yourself
                local groupFood = j.job == "food" and text:find("for all players")
                if score > 0 then
                    if not Buyable(group) or groupFood then
                        -- carried alternative only
                    elseif HasCatch(text) then
                        if not riskyScore or score > riskyScore then risky, riskyScore = group, score end
                    elseif not bestScore or score > bestScore then
                        best, bestScore = group, score
                    end
                    local n = CountGroup(group)
                    if n > 0 and (not otherCount or n > otherCount) then other, otherCount = group, n end
                end
            end
        end
        if best then
            local have = CountGroup(best)
            out[#out + 1] = { job = j.job, label = j.label, buy = Pick(best, mode), buyGroup = best, have = have,
                other = (have == 0 and other) and { group = other, count = otherCount } or nil,
                risky = (risky and riskyScore > bestScore) and { group = risky } or nil }
        end
    end
    return out, pending
end

-- For other addons (VoidAH's shopping list): { { id, count, have }, ... } or nil.
function Prep:GetShoppingList()
    local r = self:Compute()
    return r and r.shop
end

----------------------------------------------------------------------
-- Auction House: put the item's name in Blizzard's search box. You press
-- Search: starting the search from addon code would run Blizzard's AH code
-- tainted, which can block the Buy click after it.
----------------------------------------------------------------------
function Prep:SearchAH(itemID)
    local name = itemID and C_Item.GetItemNameByID(itemID)
    if not name then return false, "item not loaded yet" end
    -- VoidAH replaces (and hides) Blizzard's AH window: search in VoidAH's Browse tab
    local vah = _G.VoidUI_AuctionPanel
    if _G.VoidAH_SearchItem and vah and vah:IsShown() then
        _G.VoidAH_SearchItem(name)
        return true, "voidah"
    end
    local ah = _G.AuctionHouseFrame
    if ah and ah:IsShown() and ah.SearchBar and ah.SearchBar.SetSearchText then
        ah.SearchBar:SetSearchText(name)
        return true
    end
    return false, "open the Auction House first"
end
