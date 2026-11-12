-- 12.1.5 (and WoW Forever) removed the old global item functions; use C_Item's.
-- Borders are one screen pixel (tools/cmd/pixelfix, 2026-11-09). WoW snaps each border
-- piece to the pixel grid, and a thin line on a fractional position can snap to 0 px: a side
-- of a box vanishes. VoidPX() asks for one real pixel, and the hook below (installed once, by
-- the first Void addon loaded) turns snapping off on the edges of flat WHITE8X8 borders, like
-- Blizzard's NineSliceUtil.DisableSharpening, so a 1 px line always covers a pixel. It also
-- moves the border 1/8 px up-left: a side sitting exactly on a pixel's middle (a box centred
-- in an odd-width window) covered no pixel and vanished (2026-11-12).
local function VoidPX()
    local s = UIParent and UIParent:GetEffectiveScale()
    if s and s > 0 and PixelUtil and PixelUtil.GetPixelToUIUnitFactor then return PixelUtil.GetPixelToUIUnitFactor() / s end
    return 1
end
if not _G.__VoidBorderHook2 and hooksecurefunc and NineSliceUtil and NineSliceUtil.ApplyLayout then
    _G.__VoidBorderHook2 = true
    local EDGES = { "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
                    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner" }
    hooksecurefunc(NineSliceUtil, "ApplyLayout", function(c)
        local i = type(c) == "table" and c.backdropInfo
        local e = i and i.edgeFile
        if type(e) ~= "string" or not e:lower():find("white8x8", 1, true) or (tonumber(i.edgeSize) or 0) > 3 then return end
        for _, k in ipairs(EDGES) do
            local t = c[k]
            if t and t.SetSnapToPixelGrid then
                t:SetSnapToPixelGrid(false)
                t:SetTexelSnappingBias(0)
            end
        end
        -- the corners hold the box's own points; the edges and the background hang off them
        local sc = c.GetEffectiveScale and c:GetEffectiveScale()
        if not (sc and sc > 0 and PixelUtil and PixelUtil.GetPixelToUIUnitFactor) then return end
        local d = PixelUtil.GetPixelToUIUnitFactor() / sc / 8
        for n = 5, 8 do
            local t = c[EDGES[n]]
            if t and t.GetNumPoints and t:GetNumPoints() == 1 then
                local p, rel, rp, x, y = t:GetPoint(1)
                if rel == c then
                    t:ClearAllPoints()
                    t:SetPoint(p, c, rp, (x or 0) - d, (y or 0) + d)
                end
            end
        end
    end)
end
local _, ns = ...   -- ns.Move (VoidMove.lua)
local GetDetailedItemLevelInfo = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
----------------------------------------------------------------------
-- VoidGear UI — main panel with tabs for different gear-source views.
-- Tabs: Top | Prep | Vault | Raid | M+ | World | Spares
-- All tabs use the active stat-priority preset for scoring/comparison.
----------------------------------------------------------------------

VoidGear = VoidGear or {}
VoidGear.UI = {}
local UI = VoidGear.UI

local panel
local tabs = {}
local tabContent = {}
local activeTab = "top"
local topRowFrames = {}     -- Top tab rows (one per gear slot)
local upgradeRowPool = {}   -- shared row pool for Raid/M+/World tabs

-- Right after a /reload the game may not have item details yet (your gear's
-- level and stats, a scanned drop's name). Ask, then redraw once they arrive.
-- RequestLoadItemDataByID answers with ITEM_DATA_LOAD_RESULT; a plain item-info
-- cache fill with GET_ITEM_INFO_RECEIVED. Either one means: look again.
local itemWait = CreateFrame("Frame")
itemWait:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    C_Timer.After(0.3, function()
        self.armed = false
        if panel and panel:IsShown() then UI:Refresh() end
    end)
end)
local function WaitForItems()
    if itemWait.armed then return end
    itemWait.armed = true
    itemWait:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    itemWait:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    itemWait:RegisterEvent("SPELL_DATA_LOAD_RESULT")   -- a consumable's "Use:" text
end

----------------------------------------------------------------------
-- Helper: themed button
----------------------------------------------------------------------
local function StyleButton(btn, w, h, label)
    local P = VoidUI.palette
    local aR, aG, aB = P.accent[1], P.accent[2], P.accent[3]
    btn:SetSize(w, h)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = VoidPX(),
    })
    btn:SetBackdropColor(0.10, 0.12, 0.15, 1)
    btn:SetBackdropBorderColor(aR, aG, aB, 0.6)
    local text = btn:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(text, 10, "OUTLINE")
    text:SetPoint("CENTER")
    text:SetText(label)
    btn._text = text
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.18, 0.22, 0.28, 1)
        self:SetBackdropBorderColor(aR, aG, aB, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.10, 0.12, 0.15, 1)
        self:SetBackdropBorderColor(aR, aG, aB, 0.6)
    end)
    return btn
end
VoidGear.StyleButton = StyleButton   -- SparesUI's buttons (one of them secure, so made elsewhere)

local function MakeButton(parent, w, h, label, onClick)
    local btn = StyleButton(CreateFrame("Button", nil, parent, "BackdropTemplate"), w, h, label)
    if onClick then btn:SetScript("OnClick", onClick) end
    return btn
end

----------------------------------------------------------------------
-- Tab button — toggles active tab
----------------------------------------------------------------------
local function MakeTab(parent, key, label, onClick)
    local P = VoidUI.palette
    local aR, aG, aB = P.accent[1], P.accent[2], P.accent[3]
    local tab = CreateFrame("Button", nil, parent, "BackdropTemplate")
    tab:SetSize(86, 24)
    tab:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = VoidPX(),
    })
    local text = tab:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(text, 11, "OUTLINE")
    text:SetPoint("CENTER")
    text:SetText(label)
    tab._text = text
    tab._key = key

    function tab:SetActive(active)
        if active then
            self:SetBackdropColor(aR * 0.3, aG * 0.3, aB * 0.3, 1)
            self:SetBackdropBorderColor(aR, aG, aB, 1)
            self._text:SetTextColor(aR, aG, aB)
        else
            self:SetBackdropColor(0.08, 0.09, 0.11, 1)
            self:SetBackdropBorderColor(aR, aG, aB, 0.4)
            self._text:SetTextColor(0.7, 0.7, 0.75)
        end
    end

    tab:SetScript("OnClick", function(self)
        UI:SwitchTab(self._key)
        if onClick then onClick(self) end
    end)
    tab:SetActive(false)
    return tab
end

----------------------------------------------------------------------
-- Top tab row: one gear slot, the top players' item vs yours
-- Column x positions are shared with the header labels (TOP_COLS), so the
-- headings sit exactly over their columns.
----------------------------------------------------------------------
local TOP_ROW_H = 26
local TOP_COLS = { slot = 6, item = 106, itemW = 260, source = 374, youW = 88 }

local function CreateTopRow(parent, idx)
    local P = VoidUI.palette
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetHeight(TOP_ROW_H)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture((idx % 2 == 0) and 0.08 or 0.05, 0.08, 0.08, 0.5)

    local slotLbl = row:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(slotLbl, 10, "OUTLINE")
    slotLbl:SetPoint("LEFT", 6, 0)
    slotLbl:SetWidth(70)
    slotLbl:SetJustifyH("LEFT")
    slotLbl:SetTextColor(P.accent[1], P.accent[2], P.accent[3])
    row._slotLbl = slotLbl

    local iconBtn = CreateFrame("Button", nil, row)
    iconBtn:SetSize(20, 20)
    iconBtn:SetPoint("LEFT", slotLbl, "RIGHT", 4, 0)
    local icon = iconBtn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    iconBtn:SetScript("OnEnter", function(self)
        if not self._itemID then return end
        VoidGear:ShowItemTooltip(self, self._itemID, self._ilvl, self._link)
    end)
    iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    iconBtn:SetScript("OnClick", function(self)
        if not self._itemID then return end
        local link = select(2, C_Item.GetItemInfo(self._itemID))
        if link and IsShiftKeyDown() and ChatEdit_GetActiveWindow() then
            ChatEdit_InsertLink(link)
        elseif link then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00c7ff[VoidGear]|r " .. link)
        end
    end)
    row._iconBtn = iconBtn
    row._icon = icon

    local target = row:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(target, 10, "")
    target:SetPoint("LEFT", TOP_COLS.item, 0)
    target:SetWidth(TOP_COLS.itemW)
    target:SetJustifyH("LEFT")
    target:SetWordWrap(false)
    row._target = target

    local source = row:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(source, 9, "")
    source:SetPoint("LEFT", TOP_COLS.source, 0)
    source:SetPoint("RIGHT", -(TOP_COLS.youW + 8), 0)
    source:SetJustifyH("LEFT")
    source:SetWordWrap(false)
    source:SetTextColor(P.textDim[1], P.textDim[2], P.textDim[3])
    row._source = source

    local status = row:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(status, 10, "OUTLINE")
    status:SetPoint("RIGHT", -8, 0)
    status:SetWidth(TOP_COLS.youW)
    status:SetJustifyH("RIGHT")
    row._status = status

    return row
end

local function GetEquippedItemInfo(slot)
    local link = GetInventoryItemLink("player", slot)
    if not link then return nil end
    local id = tonumber(link:match("item:(%d+)"))
    local realIlvl = id and select(1, GetDetailedItemLevelInfo(link)) or nil
    if id and not realIlvl then C_Item.RequestLoadItemDataByID(id) end   -- fires GET_ITEM_INFO_RECEIVED
    local name = link:match("%[(.-)%]") or "?"
    return { id = id, name = name, ilvl = realIlvl, link = link }
end

----------------------------------------------------------------------
-- Generic upgrade row (used by Raid/M+/World tabs)
----------------------------------------------------------------------
local function AcquireUpgradeRow(parent)
    for _, r in ipairs(upgradeRowPool) do
        if not r:IsShown() and r:GetParent() == parent then
            return r
        end
    end
    local P = VoidUI.palette
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetHeight(30)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.06, 0.07, 0.09, 0.6)
    row._bg = bg

    -- Item icon button (tooltip)
    local iconBtn = CreateFrame("Button", nil, row)
    iconBtn:SetSize(24, 24)
    iconBtn:SetPoint("LEFT", 6, 0)
    local icon = iconBtn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    iconBtn._tex = icon
    iconBtn:SetScript("OnEnter", function(self)
        if not self._itemID then return end
        VoidGear:ShowItemTooltip(self, self._itemID, self._ilvl, self._link)
    end)
    iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    iconBtn:SetScript("OnClick", function(self)
        if not self._link and not self._itemID then return end
        if self._link and IsShiftKeyDown() and ChatEdit_GetActiveWindow() then
            ChatEdit_InsertLink(self._link)
        elseif self._link then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00c7ff[VoidGear]|r " .. self._link)
        end
    end)
    row._iconBtn = iconBtn

    -- Slot label
    local slotLbl = row:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(slotLbl, 9, "OUTLINE")
    slotLbl:SetPoint("LEFT", iconBtn, "RIGHT", 6, 0)
    slotLbl:SetWidth(60)
    slotLbl:SetJustifyH("LEFT")
    slotLbl:SetTextColor(P.accent[1], P.accent[2], P.accent[3])
    row._slotLbl = slotLbl

    -- Item name
    local nameLbl = row:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(nameLbl, 11, "")
    nameLbl:SetPoint("LEFT", slotLbl, "RIGHT", 4, 0)
    nameLbl:SetWidth(220)
    nameLbl:SetJustifyH("LEFT")
    nameLbl:SetWordWrap(false)
    row._nameLbl = nameLbl

    -- ilvl change "276 → 289"
    local ilvlLbl = row:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(ilvlLbl, 10, "")
    ilvlLbl:SetPoint("LEFT", nameLbl, "RIGHT", 6, 0)
    ilvlLbl:SetWidth(90)
    ilvlLbl:SetJustifyH("LEFT")
    ilvlLbl:SetTextColor(0.7, 0.7, 0.75)
    row._ilvlLbl = ilvlLbl

    -- Score delta
    local scoreLbl = row:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(scoreLbl, 11, "OUTLINE")
    scoreLbl:SetPoint("LEFT", ilvlLbl, "RIGHT", 6, 0)
    scoreLbl:SetWidth(90)
    scoreLbl:SetJustifyH("LEFT")
    row._scoreLbl = scoreLbl

    -- Source / boss
    local sourceLbl = row:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(sourceLbl, 9, "")
    sourceLbl:SetPoint("LEFT", scoreLbl, "RIGHT", 6, 0)
    sourceLbl:SetPoint("RIGHT", -6, 0)
    sourceLbl:SetJustifyH("LEFT")
    sourceLbl:SetWordWrap(false)
    sourceLbl:SetTextColor(P.textDim[1], P.textDim[2], P.textDim[3])
    row._sourceLbl = sourceLbl

    table.insert(upgradeRowPool, row)
    return row
end

local function ReleaseAllUpgradeRows()
    for _, r in ipairs(upgradeRowPool) do
        r:Hide()
        r:ClearAllPoints()
    end
end

----------------------------------------------------------------------
-- Compute upgrades from a loot list against player's current gear
-- Returns list sorted by score delta descending
----------------------------------------------------------------------
-- Score a drop. M+ drops are scored as the Great Vault would give them: the
-- drop's item ID with your best M+ vault example's bonus IDs, so the game
-- returns its real stats at that level (LootDB:AtVaultLevel). Without an
-- unlocked M+ vault slot they stay at the journal's level. Returns score,
-- the item level it was scored at, and the link scored.
local function ScoreCandidate(item, weights, primary, template, templateIlvl)
    local link, ilvl = item.link, item.ilvl
    if item.contentType == "mplus" and template then
        local s, l = VoidGear.LootDB:AtVaultLevel(item.id, template, templateIlvl)
        if s then
            link, ilvl = s, l
            if not C_Item.GetItemStats(s) then WaitForItems() end   -- stats still loading
        end
    end
    -- No link: the journal hasn't handed this drop over at its level yet. Don't
    -- score it at some other level (the scan asks again until it has it).
    if not link then return 0, ilvl, nil end
    return (VoidGear.Scorer:ScoreLink(link, weights, primary)) or 0, ilvl, link
end

----------------------------------------------------------------------
-- What a drop would replace, and the score you'd give up for it.
-- current = { [slotID] = { score, ilvl, link, id } } for what you wear.
--   Rings / trinkets: the weaker of the two, unless you wear the same item or
--     one from its unique-equipped group: then that one has to come off.
--   Two-handers: the main hand AND the off hand (Titan's Grip: the weaker one).
--   Off-hand items: nothing while you wield a two-hander.
--   One-handers: the main hand, or the weaker hand when you dual-wield.
--   An empty slot counts as 0 (the drop is pure gain).
-- Returns slotID, score given up, equipped data (nil = empty), both hands?
----------------------------------------------------------------------
local WAND = (Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Wand) or 19

local function IsTwoHand(idOrLink)
    if not idOrLink then return false end
    local _, _, _, loc, _, _, subID = C_Item.GetItemInfoInstant(idOrLink)
    if loc == "INVTYPE_2HWEAPON" or loc == "INVTYPE_RANGED" then return true end
    return loc == "INVTYPE_RANGEDRIGHT" and subID ~= WAND   -- guns, crossbows; a wand is one-handed
end

-- Fury's Titan's Grip (spell 46917): two two-handers at once.
local function TitansGrip()
    local known = (C_SpellBook and C_SpellBook.IsSpellKnown) or IsPlayerSpell   -- the global is deprecated in 12.x
    return known and known(46917) or false
end

local function IsHandWeapon(idOrLink)
    local loc = idOrLink and select(4, C_Item.GetItemInfoInstant(idOrLink))
    return loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONOFFHAND"
end

-- Same unique-equipped group (only one of them can be worn), as a comparable key.
local function UniqueKey(itemID)
    if not (itemID and C_Item.GetItemUniquenessByID) then return nil end
    local ok, _, _, count, catID = pcall(C_Item.GetItemUniquenessByID, itemID)
    if ok and catID and catID > 0 and (count or 0) <= 1 then return catID end
    return nil
end

local function ReplaceTarget(item, current)
    local s = item.slot
    if s == 11 or s == 13 then
        local key = UniqueKey(item.id)
        for _, slot in ipairs({ s, s + 1 }) do
            local cur = current[slot]
            if cur and (cur.id == item.id or (key and UniqueKey(cur.id) == key)) then
                return slot, cur.score, cur
            end
        end
        local a, b = current[s], current[s + 1]
        local sa, sb = a and a.score or 0, b and b.score or 0
        if sa <= sb then return s, sa, a end
        return s + 1, sb, b
    end
    if s == 16 or s == 17 then
        local mh, oh = current[16], current[17]
        -- a two-hander takes both hands, except with Titan's Grip
        local mhTwo = mh and IsTwoHand(mh.link) and not TitansGrip()
        if IsTwoHand(item.id) then
            -- Fury (Titan's Grip) wields two two-handers: a new one replaces the
            -- weaker hand (an empty hand first)
            if TitansGrip() then
                local sm, so = mh and mh.score or 0, oh and oh.score or 0
                if so < sm then return 17, so, oh end
                return 16, sm, mh
            end
            return 16, (mh and mh.score or 0) + (oh and oh.score or 0), mh, oh ~= nil
        end
        if s == 17 then
            if mhTwo then return nil end
            return 17, oh and oh.score or 0, oh
        end
        if not mhTwo and CanDualWield and CanDualWield()
           and select(4, C_Item.GetItemInfoInstant(item.id)) == "INVTYPE_WEAPON"
           and (not oh or IsHandWeapon(oh.link) or (TitansGrip() and IsTwoHand(oh.link))) then
            local sm, so = mh and mh.score or 0, oh and oh.score or 0
            if so < sm then return 17, so, oh end
        end
        return 16, mh and mh.score or 0, mh
    end
    local cur = current[s]
    return s, cur and cur.score or 0, cur
end

-- Your equipped gear scored: { [slotID] = { score, ilvl, link, id } }.
local function ScoreEquipped(weights, primary)
    local out = {}
    for slotID, eq in pairs(VoidGear.Scanner:GetAll()) do
        local s = VoidGear.Scorer:ScoreLink(eq.link, weights, primary)
        out[slotID] = { score = s, ilvl = eq.ilvl, link = eq.link, id = eq.id }
    end
    return out
end

-- Every drop scored against what it would replace; upgradesOnly drops the rest.
local function ScoreDrops(lootList, upgradesOnly)
    local weights, primary = VoidGear.Scorer:GetActiveContext()
    local template, templateIlvl = VoidGear.LootDB:MplusVaultTemplate()
    local currentScore = ScoreEquipped(weights, primary)

    local result = {}
    for _, item in ipairs(lootList) do
        if item.slot and item.id then
            local slot, curScore, curData, both = ReplaceTarget(item, currentScore)
            local candScore, candIlvl, candLink = ScoreCandidate(item, weights, primary, template, templateIlvl)
            if slot and candScore > 0 then
                local delta, pct = VoidGear.Scorer:Delta(curScore, candScore)
                if delta > 0 or not upgradesOnly then
                    table.insert(result, {
                        item = item, targetSlot = slot, bothHands = both, empty = curScore <= 0,
                        currentScore = curScore, candScore = candScore, ilvl = candIlvl, link = candLink,
                        delta = delta, pct = pct, current = curData,
                    })
                end
            end
        end
    end
    table.sort(result, function(a, b) return a.delta > b.delta end)
    return result
end

local function ComputeUpgrades(lootList) return ScoreDrops(lootList, true) end

----------------------------------------------------------------------
-- Compute scored items (NOT filtered to upgrades) — used for "Show All"
----------------------------------------------------------------------
local function ComputeAllScored(lootList) return ScoreDrops(lootList, false) end

----------------------------------------------------------------------
-- Render scored items into a scroll content frame.
-- mode = "upgrades" (default) | "all"
----------------------------------------------------------------------
local function RenderUpgrades(content, lootList, emptyMsg, mode)
    ReleaseAllUpgradeRows()
    local sc = content._scrollChild
    if not lootList or #lootList == 0 then
        content._emptyText:SetText(emptyMsg or "No data — click |cffffd200Scan Loot|r above")
        content._emptyText:Show()
        return
    end

    -- Your gear has to be loaded to compare against it (else everything reads 0).
    if VoidGear.Scanner:AnyPending() then
        WaitForItems()
        content._emptyText:SetText("|cffaaaaaaReading your equipped gear...|r")
        content._emptyText:Show()
        return
    end

    mode = mode or "upgrades"
    local list
    if mode == "all" then
        list = ComputeAllScored(lootList)
    else
        list = ComputeUpgrades(lootList)
    end

    if #list == 0 then
        if mode == "upgrades" then
            content._emptyText:SetText(string.format(
                "|cff66ff66No upgrades found in %d items — your gear beats this database.|r\n\n" ..
                "|cffaaaaaaTip: click |cffffd200Show All|r |cffaaaaaato see the full pool ranked by score.|r",
                #lootList))
        else
            content._emptyText:SetText("|cffff5555No scorable items found.|r")
        end
        content._emptyText:Show()
        return
    end
    content._emptyText:Hide()

    local maxShow = math.min(#list, 200)
    for i = 1, maxShow do
        local up = list[i]
        local row = AcquireUpgradeRow(sc)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, -((i - 1) * 32))
        row:SetPoint("RIGHT", sc, "RIGHT", 0, 0)

        row._iconBtn._itemID = up.item.id
        row._iconBtn._ilvl   = up.ilvl or up.item.ilvl
        row._iconBtn._link   = up.link or up.item.link
        row._iconBtn._tex:SetTexture(up.item.icon or C_Item.GetItemIconByID(up.item.id) or 134400)

        row._slotLbl:SetText(up.bothHands and "Both Hands" or VoidGear.SLOTS[up.targetSlot] or up.item.slotStr or "?")
        row._nameLbl:SetText(up.item.name or "?")

        local newIlvl = up.ilvl or up.item.ilvl or 0
        if up.current then
            row._ilvlLbl:SetText(string.format("%d -> %d", up.current.ilvl or 0, newIlvl))
        else
            row._ilvlLbl:SetText(string.format("empty -> %d", newIlvl))
        end

        if up.empty then
            row._scoreLbl:SetText("|cff00ff00empty slot|r")   -- no % of nothing
        else
            local deltaColor
            if up.pct >= 20 then deltaColor = "|cff00ff00"
            elseif up.pct >= 10 then deltaColor = "|cff66ff66"
            elseif up.pct >= 3 then deltaColor = "|cffffd200"
            else deltaColor = "|cffaaaaaa" end
            row._scoreLbl:SetText(string.format("%s%+.1f%%|r", deltaColor, up.pct))
        end

        local src = up.item.instance or "?"
        if up.item.encounterName then src = src .. " - " .. up.item.encounterName end
        if up.item.contentType == "mplus" then
            local _, _, vaultKey = VoidGear.LootDB:MplusVaultTemplate()
            src = src .. (vaultKey and (" (+%d vault)"):format(vaultKey) or " (journal level)")
        end
        row._sourceLbl:SetText(src)

        row:Show()
    end

    sc:SetHeight(maxShow * 32 + 10)
end

----------------------------------------------------------------------
-- Build a scroll frame inside a tab content area
----------------------------------------------------------------------
local function CreateScrollArea(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -22, 0)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    parent._scrollChild = child
    parent._scroll = scroll
    -- Keep child width in sync with scroll frame so rows fill horizontally
    local function syncWidth()
        child:SetWidth(math.max(1, scroll:GetWidth()))
    end
    scroll:SetScript("OnSizeChanged", syncWidth)
    C_Timer.After(0, syncWidth)

    local empty = child:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(empty, 12, "")
    empty:SetPoint("TOP", 0, -40)
    empty:SetTextColor(0.6, 0.6, 0.65)
    empty:SetWidth(560)
    empty:SetJustifyH("CENTER")
    parent._emptyText = empty

    return child
end

----------------------------------------------------------------------
-- Top tab: what the top M+ players of a spec wear (Loadouts.lua)
-- Forward-declare RefreshTopTab so BuildTopTab's dropdown callbacks
-- can call it before its definition appears further down.
----------------------------------------------------------------------
local RefreshTopTab

local function BuildTopTab(parent)
    parent._loadoutLbl = parent:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(parent._loadoutLbl, 11, "OUTLINE")
    parent._loadoutLbl:SetPoint("TOPLEFT", 4, -4)
    parent._loadoutLbl:SetText("|cff00c7ffShowing:|r")

    parent._loadoutText = parent:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(parent._loadoutText, 11, "")
    parent._loadoutText:SetPoint("LEFT", parent._loadoutLbl, "RIGHT", 6, 0)
    parent._loadoutText:SetTextColor(1, 0.82, 0)

    -- Spec picker: "Top Subtlety Rogue", "Top Guardian Druid", ... (yours is marked).
    parent._loadoutDropdown = CreateFrame("Frame", "VoidGearLoadoutDropdown", parent, "UIDropDownMenuTemplate")
    -- (the template has ~16px of empty space at its right edge)
    parent._loadoutDropdown:SetPoint("TOPRIGHT", 14, 6)

    local function PopulateLoadoutMenu(self, level)
        local all = VoidGear:GetAllLoadouts()
        local keys = {}
        for k in pairs(all) do table.insert(keys, k) end
        table.sort(keys)

        local activeKey = VoidGear:GetActiveLoadout()
        local mine = VoidGear:CurrentSpecKey()

        for _, key in ipairs(keys) do
            local loadout = all[key]
            local info = UIDropDownMenu_CreateInfo()
            info.text = (loadout.displayName or key) .. (key == mine and " |cff888888(your spec)|r" or "")
            info.value = key
            info.checked = (key == activeKey)
            info.func = function()
                VoidGear:SetActiveLoadout(key)
                UIDropDownMenu_SetText(parent._loadoutDropdown, info.text)
                RefreshTopTab()
            end
            UIDropDownMenu_AddButton(info, level)
        end

        if #keys == 0 then
            local info = UIDropDownMenu_CreateInfo()
            info.text = "|cff888888(no top-player data in this build)|r"
            info.notCheckable = true
            info.disabled = true
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(parent._loadoutDropdown, PopulateLoadoutMenu)
    UIDropDownMenu_SetWidth(parent._loadoutDropdown, 220)

    -- Info line below the dropdown, full width (nothing sits on top of it).
    parent._sub = parent:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(parent._sub, 9, "")
    parent._sub:SetPoint("TOPLEFT", 4, -30)
    parent._sub:SetPoint("RIGHT", -4, 0)
    parent._sub:SetJustifyH("LEFT")
    parent._sub:SetWordWrap(false)
    parent._sub:SetTextColor(0.55, 0.55, 0.62)

    -- Headings and rows share one left edge and one right edge (the scroll bar
    -- takes 22px on the right), so TOP_COLS lines them up.
    local head = CreateFrame("Frame", nil, parent)
    head:SetPoint("TOPLEFT", 4, -48)
    head:SetPoint("TOPRIGHT", -26, -48)
    head:SetHeight(14)
    local function Heading(text, x, rightAligned)
        local fs = head:CreateFontString(nil, "OVERLAY")
        VoidUI:SetFont(fs, 10, "OUTLINE")
        fs:SetTextColor(0.7, 0.7, 0.75)
        fs:SetText(text)
        if rightAligned then fs:SetPoint("RIGHT", -8, 0) else fs:SetPoint("LEFT", x, 0) end
    end
    Heading("Slot", TOP_COLS.slot)
    Heading("Their item  (ilvl, % who wear it)", TOP_COLS.item)
    Heading("Where it comes from", TOP_COLS.source)
    Heading("vs yours", nil, true)

    -- The rows scroll: 16 slots don't fit the default window height.
    local list = CreateFrame("Frame", nil, parent)
    list:SetPoint("TOPLEFT", 4, -64)
    list:SetPoint("BOTTOMRIGHT", -4, 0)
    local child = CreateScrollArea(list)
    child:SetHeight(#VoidGear.PLAN_SLOTS * TOP_ROW_H)
    for i, slotID in ipairs(VoidGear.PLAN_SLOTS) do
        local row = CreateTopRow(child, i)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * TOP_ROW_H)
        row:SetPoint("RIGHT", 0, 0)
        row._slotID = slotID
        topRowFrames[i] = row
    end
end

function RefreshTopTab()
    local content = tabContent["top"]
    if not content then return end
    local key, loadout = VoidGear:GetActiveLoadout()

    -- Refresh dropdown label so it reflects the active loadout
    if content._loadoutDropdown then
        UIDropDownMenu_SetText(content._loadoutDropdown,
            loadout and (loadout.displayName or key) or "|cff888888(pick a spec)|r")
    end

    if not loadout then
        content._loadoutText:SetText("|cffff5555(no data for this spec)|r")
        content._sub:SetText("Pick a spec from the dropdown above.")
        for _, row in ipairs(topRowFrames) do row:Hide() end
        return
    end
    content._loadoutText:SetText(loadout.displayName or key)
    content._sub:SetText((loadout.spec or "?") ..
        "   |   Stat profile: " .. (loadout.statProfile or "?") ..
        "   |   Avg ilvl: " .. (loadout.ilvl or "?") ..
        "   |   From: " .. (loadout.source or "?"))

    -- Rings and trinkets: the data ranks the two most-worn, not which slot each
    -- goes in. If you wear one of them in the other slot, swap the two targets
    -- so each row compares against the right item.
    local gear = setmetatable({}, { __index = loadout.gear or {} })
    for _, pair in ipairs({ { 11, 12 }, { 13, 14 } }) do
        local a, b = pair[1], pair[2]
        local ta, tb = gear[a], gear[b]
        local ea, eb = GetEquippedItemInfo(a), GetEquippedItemInfo(b)
        if ta and tb and ((ea and ea.id == tb.id) or (eb and eb.id == ta.id)) then
            gear[a], gear[b] = tb, ta
        end
    end

    for i, row in ipairs(topRowFrames) do
        local slotID = row._slotID
        local target = gear[slotID]
        local equipped = GetEquippedItemInfo(slotID)
        row._slotLbl:SetText(VoidGear.SLOTS[slotID] or "?")

        if target and target.id then
            local titemName = C_Item.GetItemNameByID(target.id)
            row._target:SetText((titemName or target.name) .. ("  |cff888888(%s, %d%%)|r"):format(
                target.ilvl or "?", math.floor((target.share or 0) * 100 + 0.5)))
            local icon = C_Item.GetItemIconByID(target.id) or 134400
            row._icon:SetTexture(icon)
            row._icon:Show()
            row._iconBtn._itemID = target.id
            row._iconBtn._ilvl   = target.ilvl
            row._iconBtn._link   = target.link

            local src = VoidGear:GetItemSource(target.id)
            if src then
                local color = src.kind == "Crafted" and "|cffaa66ff"
                    or src.kind == "Unknown" and "|cff888888"
                    or "|cff66ccff"
                row._source:SetText(color .. (src.kind or "?") .. ":|r " .. (src.text or ""))
            else
                row._source:SetText("|cff666666(no source data)|r")
            end

            if equipped and equipped.id == target.id then
                row._status:SetText("|cff00ff00MATCH|r")
            elseif equipped and not equipped.ilvl then
                row._status:SetText("|cff888888...|r")   -- item details still loading
                WaitForItems()
            elseif equipped and target.ilvl then
                local diff = (target.ilvl or 0) - (equipped.ilvl or 0)
                if diff > 0 then
                    row._status:SetText(string.format("|cffffd200+%d ilvl|r", diff))
                elseif diff < 0 then
                    row._status:SetText(string.format("|cff66ff66%d ilvl|r", diff))
                else
                    row._status:SetText("|cffaaaaaaequal|r")
                end
            else
                row._status:SetText("|cffff5555empty|r")
            end
        else
            row._target:SetText("|cff666666(no target item)|r")
            row._icon:SetTexture(nil)
            row._icon:Hide()
            row._source:SetText("")
            row._status:SetText("")
        end
        row:Show()
    end
end

----------------------------------------------------------------------
-- Stat priority dropdown (shared across all tabs)
----------------------------------------------------------------------
local function BuildStatPriorityRow(parent)
    local P = VoidUI.palette
    local lbl = parent:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(lbl, 10, "OUTLINE")
    lbl:SetPoint("LEFT", 4, 0)
    lbl:SetTextColor(P.accent[1], P.accent[2], P.accent[3])
    lbl:SetText("Stat Priority:")

    local dd = CreateFrame("Frame", "VoidGear_StatDropdown", parent, "UIDropDownMenuTemplate")
    dd:SetPoint("LEFT", lbl, "RIGHT", -6, -2)
    UIDropDownMenu_SetWidth(dd, 180)

    local function refreshLabel()
        local cur = VoidGear.StatWeights:GetCurrent()
        UIDropDownMenu_SetText(dd, cur.label or "Custom")
    end

    -- Nested dropdown: class → spec. Top level lists classes; hover
    -- expands into the spec presets for that class.
    UIDropDownMenu_Initialize(dd, function(self, level, menuList)
        local cur = VoidGear.StatWeights:GetCurrent()

        if level == 1 then
            -- Top-level: class names
            for _, group in ipairs(VoidGear.StatWeights:ListPresetsByClass()) do
                local info = UIDropDownMenu_CreateInfo()
                info.text         = group.display
                info.hasArrow     = true
                info.menuList     = group.class  -- passed to level-2 expand
                info.notCheckable = true
                info.keepShownOnClick = true
                UIDropDownMenu_AddButton(info, level)
            end
        elseif level == 2 then
            -- Submenu: spec presets for the chosen class
            local groups = VoidGear.StatWeights:ListPresetsByClass()
            local targetGroup
            for _, g in ipairs(groups) do
                if g.class == menuList then targetGroup = g; break end
            end
            if not targetGroup then return end

            for _, p in ipairs(targetGroup.presets) do
                local info = UIDropDownMenu_CreateInfo()
                info.text  = p.specLabel
                info.value = p.key
                info.checked = (cur.label == p.label)
                info.func = function()
                    VoidGear.StatWeights:SetPreset(p.key)
                    refreshLabel()
                    UI:Refresh()
                    CloseDropDownMenus()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end)
    parent._statDropdown = dd
    refreshLabel()

    -- Show current weight summary
    local summary = parent:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(summary, 9, "")
    summary:SetPoint("LEFT", dd, "RIGHT", 0, 2)
    summary:SetTextColor(0.6, 0.6, 0.7)
    parent._statSummary = summary

    function parent:UpdateSummary()
        refreshLabel()   -- the preset follows your spec, so a spec change renames it
        local cur = VoidGear.StatWeights:GetCurrent()
        local parts = {}
        local ranked = {}
        for k, v in pairs(cur.weights or {}) do table.insert(ranked, { k = k, v = v }) end
        table.sort(ranked, function(a, b) return a.v > b.v end)
        for i = 1, math.min(4, #ranked) do
            table.insert(parts, ranked[i].k)
        end
        summary:SetText(table.concat(parts, " > "))
    end
    parent:UpdateSummary()

    -- "Show All Items" toggle (top-right of stat row)
    local showAllBtn = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    showAllBtn:SetSize(22, 22)
    showAllBtn:SetPoint("RIGHT", -130, 0)
    showAllBtn:SetChecked(VoidGearCharDB and VoidGearCharDB.showAll or false)
    local saLbl = parent:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(saLbl, 10, "OUTLINE")
    saLbl:SetPoint("RIGHT", showAllBtn, "LEFT", -2, 0)
    saLbl:SetText("Show All Items")
    saLbl:SetTextColor(P.text[1], P.text[2], P.text[3])
    showAllBtn:SetScript("OnClick", function(self)
        VoidGearCharDB = VoidGearCharDB or {}
        VoidGearCharDB.showAll = self:GetChecked() and true or false
        UI:Refresh()
    end)
    showAllBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Show All Items")
        GameTooltip:AddLine("When OFF: only items that beat your current gear show up.", 1, 1, 1, true)
        GameTooltip:AddLine("When ON: full database, ranked by score (downgrades shown too).", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    showAllBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    parent._showAllBtn = showAllBtn
end

----------------------------------------------------------------------
-- Great Vault tab — scrollable list of slots, each with its loot pool
-- (items that COULD roll into this slot based on what you ran this week).
----------------------------------------------------------------------
local vaultSlotPool = {}
local vaultItemPool = {}

local function AcquireVaultItem(parent)
    -- Reuse any unshown row regardless of past parent — we reparent below
    for _, r in ipairs(vaultItemPool) do
        if not r:IsShown() then
            r:SetParent(parent)
            return r
        end
    end
    local P = VoidUI.palette
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(22)

    local iconBtn = CreateFrame("Button", nil, row)
    iconBtn:SetSize(18, 18)
    iconBtn:SetPoint("LEFT", 0, 0)
    local tex = iconBtn:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    iconBtn._tex = tex
    iconBtn:SetScript("OnEnter", function(self)
        if self._link then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self._link)
            if self._vaultIlvl then
                GameTooltip:AddLine(" ", 1, 1, 1)
                GameTooltip:AddLine("|cff00c7ffVault drop ilvl:|r " ..
                    (self._vaultTrackColor or "") ..
                    self._vaultIlvl .. " " .. (self._vaultTrackName or "") .. "|r",
                    1, 1, 1)
                GameTooltip:AddLine("|cff888888(tooltip above shows the item's base ilvl)|r", 1, 1, 1)
            end
            GameTooltip:Show()
        elseif self._itemID then
            VoidGear:ShowItemTooltip(self, self._itemID, self._ilvl, self._link)
        end
    end)
    iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    iconBtn:SetScript("OnClick", function(self)
        if self._link and IsShiftKeyDown() and ChatEdit_GetActiveWindow() then
            ChatEdit_InsertLink(self._link)
        end
    end)
    row._iconBtn = iconBtn

    local nameLbl = row:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(nameLbl, 10, "")
    nameLbl:SetPoint("LEFT", iconBtn, "RIGHT", 6, 0)
    nameLbl:SetWidth(220)
    nameLbl:SetJustifyH("LEFT")
    nameLbl:SetWordWrap(false)
    row._nameLbl = nameLbl

    local sourceLbl = row:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(sourceLbl, 9, "")
    sourceLbl:SetPoint("LEFT", nameLbl, "RIGHT", 6, 0)
    sourceLbl:SetWidth(180)
    sourceLbl:SetJustifyH("LEFT")
    sourceLbl:SetWordWrap(false)
    sourceLbl:SetTextColor(P.textDim[1], P.textDim[2], P.textDim[3])
    row._sourceLbl = sourceLbl

    local scoreLbl = row:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(scoreLbl, 10, "OUTLINE")
    scoreLbl:SetPoint("LEFT", sourceLbl, "RIGHT", 6, 0)
    scoreLbl:SetWidth(80)
    scoreLbl:SetJustifyH("LEFT")
    row._scoreLbl = scoreLbl

    table.insert(vaultItemPool, row)
    return row
end

local function ReleaseAllVaultItems()
    for _, r in ipairs(vaultItemPool) do r:Hide() end
end

-- Each card has:
--   _header / _progressLbl   (top header row, 36px)
--   _summaryLbl              (pool summary line, ~14px)
--   _innerScroll             (per-slot ScrollFrame with item list)
--   _innerChild              (scrollchild — anchor item rows here)
local VAULT_CARD_HEADER_H = 50
local VAULT_CARD_SCROLL_H = 180     -- ~8 rows visible per slot
local VAULT_CARD_HEIGHT   = VAULT_CARD_HEADER_H + VAULT_CARD_SCROLL_H + 6

local function AcquireVaultSlot(parent)
    for _, s in ipairs(vaultSlotPool) do
        if not s:IsShown() and s:GetParent() == parent then return s end
    end
    local P = VoidUI.palette
    local aR, aG, aB = P.accent[1], P.accent[2], P.accent[3]
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetSize(640, VAULT_CARD_HEIGHT)
    card:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = VoidPX(),
    })
    card:SetBackdropColor(0.06, 0.07, 0.09, 0.9)
    card:SetBackdropBorderColor(aR, aG, aB, 0.5)

    local header = card:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(header, 10, "OUTLINE")
    header:SetPoint("TOPLEFT", 6, -4)
    header:SetTextColor(aR, aG, aB)
    card._header = header

    local progressLbl = card:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(progressLbl, 9, "")
    progressLbl:SetPoint("TOPLEFT", 6, -18)
    progressLbl:SetTextColor(0.75, 0.75, 0.8)
    card._progressLbl = progressLbl

    local summaryLbl = card:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(summaryLbl, 9, "")
    summaryLbl:SetPoint("TOPLEFT", 6, -34)
    summaryLbl:SetTextColor(0.55, 0.55, 0.62)
    card._summaryLbl = summaryLbl

    -- Inner scrollframe for the item pool — gives each slot its own slider
    local inner = CreateFrame("ScrollFrame", nil, card, "UIPanelScrollFrameTemplate")
    inner:SetPoint("TOPLEFT", 4, -VAULT_CARD_HEADER_H)
    inner:SetPoint("BOTTOMRIGHT", -26, 4)  -- leave room for the scrollbar
    local innerChild = CreateFrame("Frame", nil, inner)
    innerChild:SetSize(1, 1)
    inner:SetScrollChild(innerChild)

    -- Inner mousewheel scrolls only the inner; outer page scrolls when
    -- mouse is OFF the inner. Standard nested-scroll pattern.
    inner:EnableMouseWheel(true)
    inner:SetScript("OnMouseWheel", function(self, delta)
        local newScroll = self:GetVerticalScroll() - delta * 30
        local max = self:GetVerticalScrollRange()
        newScroll = math.max(0, math.min(max, newScroll))
        self:SetVerticalScroll(newScroll)
    end)

    card._innerScroll = inner
    card._innerChild  = innerChild

    table.insert(vaultSlotPool, card)
    return card
end

local function ReleaseAllVaultSlots()
    for _, c in ipairs(vaultSlotPool) do c:Hide() end
end

local function BuildVaultTab(parent)
    local P = VoidUI.palette
    local title = parent:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(title, 12, "OUTLINE")
    title:SetPoint("TOPLEFT", 6, -4)
    title:SetTextColor(P.accent[1], P.accent[2], P.accent[3])
    title:SetText("Great Vault — This Week's Possible Rewards")
    parent._title = title

    local sub = parent:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(sub, 9, "")
    sub:SetPoint("TOPLEFT", 6, -22)
    sub:SetTextColor(0.6, 0.6, 0.7)
    sub:SetText("Each slot shows every item that COULD roll based on activities you completed this week. Sorted by score.")
    parent._sub = sub

    -- Scrollable content
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -42)
    scroll:SetPoint("BOTTOMRIGHT", -22, 0)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    parent._scrollChild = child
    parent._scroll = scroll
    local function syncWidth() child:SetWidth(math.max(1, scroll:GetWidth())) end
    scroll:SetScript("OnSizeChanged", syncWidth)
    C_Timer.After(0, syncWidth)
end

-- Forward decl for slot-card builder
local function MakeSlotHeader(parent, idx, slot, lootPool, weights, primary, equippedScoreAvg)
    local P = VoidUI.palette
    local aR, aG, aB = P.accent[1], P.accent[2], P.accent[3]
    local card = AcquireVaultSlot(parent)

    local TYPE_HEADER = {
        mplus = "Mythic+ Slot",
        raid  = "Raid Slot",
        world = "World Slot",
    }

    if slot and slot.unlocked then
        card._header:SetText(string.format("|cff00ff00%s %d - UNLOCKED|r",
            TYPE_HEADER[slot.type] or "Slot", idx))
        if slot.type == "mplus" then
            card._progressLbl:SetText(string.format("Reward from key +%d  (%d/%d runs done)",
                slot.level or 0, slot.progress or 0, slot.threshold or 0))
        elseif slot.type == "raid" then
            local diffName = slot.level == 16 and "Mythic" or slot.level == 15 and "Heroic" or slot.level == 14 and "Normal" or "LFR"
            card._progressLbl:SetText(string.format("Reward from %s difficulty  (%d/%d kills)",
                diffName, slot.progress or 0, slot.threshold or 0))
        else
            card._progressLbl:SetText(string.format("Reward tier %d  (%d/%d activities)",
                slot.level or 0, slot.progress or 0, slot.threshold or 0))
        end
    else
        card._header:SetText(string.format("|cffaa6666%s %d - LOCKED|r",
            TYPE_HEADER[slot and slot.type or ""] or "Slot", idx))
        local need = (slot and slot.threshold or 0) - (slot and slot.progress or 0)
        if slot and slot.type == "mplus" then
            card._progressLbl:SetText(string.format("%d/%d keys done - need %d more (+2 or higher)",
                slot.progress or 0, slot.threshold or 0, need))
        elseif slot and slot.type == "raid" then
            card._progressLbl:SetText(string.format("%d/%d bosses killed - need %d more",
                slot.progress or 0, slot.threshold or 0, need))
        else
            card._progressLbl:SetText(string.format("%d/%d delves T8+ - need %d more",
                slot and slot.progress or 0, slot and slot.threshold or 0, need))
        end
    end
    card._summaryLbl:SetText("")  -- populated by RefreshVaultTab when pool known

    return card
end

local function RefreshVaultTab()
    local content = tabContent["vault"]
    if not content then return end
    ReleaseAllVaultSlots()
    ReleaseAllVaultItems()

    local vault = VoidGear.LootDB:GetVault()
    if not vault then
        content._sub:SetText("|cffff5555Great Vault API not available — try again after /reload|r")
        return
    end

    local sc = content._scrollChild
    local weights, primary = VoidGear.Scorer:GetActiveContext()

    -- Precompute equipped scores
    local equippedScores = ScoreEquipped(weights, primary)
    local avgScore, count = 0, 0
    for _, eq in pairs(equippedScores) do
        avgScore = avgScore + eq.score; count = count + 1
    end
    if count > 0 then avgScore = avgScore / count end

    -- delta, pct, slot it replaces, empty slot?; nil when it can't be scored at
    -- the vault's level (no vault link: the base item would be a different level)
    local function bestUpgradeDelta(item)
        if not (item.slot and item.link) then return nil end
        local slot, curScore = ReplaceTarget(item, equippedScores)
        local cand = (VoidGear.Scorer:ScoreLink(item.link, weights, primary)) or 0
        if slot and cand > 0 then
            local d, p = VoidGear.Scorer:Delta(curScore, cand)
            return d, p, slot, curScore <= 0
        end
        return nil
    end

    local y = 0
    local typeOrder = { "mplus", "raid", "world" }

    for _, key in ipairs(typeOrder) do
        local slots = vault[key] or {}
        for slotIdx, slot in ipairs(slots) do
            local pool = VoidGear.LootDB:GetVaultSlotLootPool(slot)

            -- Expected vault reward ilvl + track from the slot's own difficulty
            -- (NOT from the loot item's base ilvl — that's stale EJ data)
            local expectedIlvl = VoidGear.LootDB:GetExpectedVaultIlvl(slot)
            local trackName, trackColor = VoidGear.LootDB:GetVaultTrackForSlot(slot)

            -- Full-card with inner scroll for items
            local card = MakeSlotHeader(sc, slotIdx, slot, pool, weights, primary, avgScore)
            card:SetSize(640, VAULT_CARD_HEIGHT)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", sc, "TOPLEFT", 4, -y)
            card:SetPoint("RIGHT", sc, "RIGHT", -4, 0)
            card:Show()

            -- Populate inner scroll with ALL items from the pool
            local innerChild = card._innerChild
            local innerScroll = card._innerScroll
            -- Match inner-child width to inner-scroll width so rows lay out cleanly
            innerChild:SetWidth(math.max(1, innerScroll:GetWidth()))

            if slot.unlocked and pool and pool.items and #pool.items > 0 then
                local scored = {}
                local filteredOut = 0
                for _, item in ipairs(pool.items) do
                    -- Filter out junk: low-quality, ancient base ilvls, no slot
                    -- (clears the level 70 / ilvl 214 noise from legacy M+
                    -- dungeon EJ data that isn't current-season loot)
                    if not VoidGear.LootDB:IsCurrentSeasonLoot(item) then
                        filteredOut = filteredOut + 1
                    else
                    -- Override displayed ilvl with the actual vault reward ilvl
                    -- (EJ cache stores BASE ilvl which is wildly low for legacy M+
                    -- dungeons — e.g. 214 for Skyreach because EJ defaults to
                    -- WoD heroic). The vault scales loot to the key/difficulty.
                    local displayIlvl = expectedIlvl or item.ilvl
                    -- The item as this slot would give it: its ID with the slot's
                    -- example reward's bonus IDs, so stats (and the tooltip) are the
                    -- real ones at the vault level (LootDB:AtVaultLevel).
                    local vaultLink = expectedIlvl
                        and VoidGear.LootDB:AtVaultLevel(item.id, slot.exampleLink, expectedIlvl)
                    if vaultLink and not C_Item.GetItemStats(vaultLink) then WaitForItems() end
                    local syntheticItem = {
                        id = item.id, name = item.name, slot = item.slot,
                        icon = item.icon, encounterName = item.encounterName,
                        instance = item.instance,
                        ilvl = displayIlvl,
                        -- Never the journal's own link: that one is at its low base
                        -- level. Without a vault link, scoring falls back to the itemID.
                        link = vaultLink or nil,
                    }
                    local d, p, slotMatch, empty = bestUpgradeDelta(syntheticItem)
                    table.insert(scored, {
                        item = syntheticItem,
                        origItem = item,
                        delta = d or -math.huge, pct = p or 0, targetSlot = slotMatch,
                        empty = empty, unscored = d == nil,
                    })
                    end  -- close IsCurrentSeasonLoot else
                end
                table.sort(scored, function(a, b) return a.delta > b.delta end)

                local upgradesShown = 0
                local rowY = 0
                for i = 1, #scored do
                    local s = scored[i]
                    if s.delta > 0 then upgradesShown = upgradesShown + 1 end
                    local row = AcquireVaultItem(innerChild)
                    row:SetParent(innerChild)
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", innerChild, "TOPLEFT", 4, -rowY)
                    row:SetPoint("RIGHT", innerChild, "RIGHT", -4, 0)
                    row._iconBtn._itemID = s.item.id
                    row._iconBtn._ilvl   = s.item.ilvl
                    row._iconBtn._link   = s.item.link or s.origItem.link  -- vault-level item when known
                    -- Inject the corrected vault ilvl as tooltip hint
                    row._iconBtn._vaultIlvl       = expectedIlvl
                    row._iconBtn._vaultTrackName  = trackName
                    row._iconBtn._vaultTrackColor = trackColor
                    row._iconBtn._tex:SetTexture(s.item.icon or C_Item.GetItemIconByID(s.item.id) or 134400)
                    -- Append ilvl + track to the name so it's immediately visible
                    local trackTag = trackName and (" " .. (trackColor or "|cffaaaaaa") .. "[" .. trackName .. "]|r") or ""
                    row._nameLbl:SetText(string.format("%s |cff888888(%d)|r%s",
                        s.item.name or "?", s.item.ilvl or 0, trackTag))
                    local src = s.item.instance or "?"
                    if s.item.encounterName then src = s.item.encounterName .. " (" .. src .. ")" end
                    row._sourceLbl:SetText(src)
                    if s.unscored then
                        row._scoreLbl:SetText("|cff888888...|r")   -- not at the vault's level yet
                    elseif s.empty then
                        row._scoreLbl:SetText("|cff00ff00empty slot|r")
                    else
                        local color
                        if s.pct >= 10 then color = "|cff00ff00"
                        elseif s.pct > 0 then color = "|cff66ff66"
                        elseif s.pct == 0 then color = "|cffaaaaaa"
                        else color = "|cffaa6666" end
                        row._scoreLbl:SetText(string.format("%s%+.1f%%|r", color, s.pct))
                    end
                    row:Show()
                    rowY = rowY + 22
                end
                innerChild:SetHeight(math.max(VAULT_CARD_SCROLL_H, rowY + 4))

                local trackBadge = (trackName and trackColor and expectedIlvl)
                    and (" " .. trackColor .. trackName .. " track ilvl " .. expectedIlvl .. "|r")
                    or ""
                local filterNote = (filteredOut > 0)
                    and string.format(" |cff666666(%d legacy items hidden)|r", filteredOut)
                    or ""
                card._summaryLbl:SetText(string.format(
                    "Pool: |cffffffff%d|r items (%s).  |cff00ff00%d|r upgrade%s.%s%s",
                    #scored, pool.sourceLabel or "from your activities",
                    upgradesShown, upgradesShown == 1 and "" or "s",
                    trackBadge, filterNote))
            elseif slot.unlocked and pool and pool.missingData then
                innerChild:SetHeight(1)
                card._summaryLbl:SetText("|cffaaaa55Note:|r " .. pool.missingData)
            else
                innerChild:SetHeight(1)
                card._summaryLbl:SetText("")
            end

            y = y + VAULT_CARD_HEIGHT + 8  -- spacing between slot cards
        end
        y = y + 6  -- spacing between sections (mplus / raid / world)
    end

    sc:SetHeight(math.max(y, 100))
end

----------------------------------------------------------------------
-- Prep tab: what to enchant and gem (VoidGear.Prep), and the shopping list.
-- Sections: Must fix | Optional upgrades | Consumables | Shopping list.
-- Rows: slot | what you have now | what to get | Best/Budget (click to flip that item) | in bags
----------------------------------------------------------------------
local PREP_ROW_H = 26
local PREP_COLS = { slot = 6, now = 80, nowW = 210, icon = 296, item = 320, modeW = 62, haveW = 50 }
local SEVERITY_COLOR = { need = "|cffff5555", rank = "|cffffd200", swap = "|cffcccccc" }
local prepRows, prepShop, prepHeads = {}, {}, {}

local function QualityIcon(itemID, group)
    local tier
    for i, id in ipairs(group or {}) do if id == itemID then tier = i end end
    local fn = C_TradeSkillUI and C_TradeSkillUI.GetItemCraftedQualityByItemInfo
    local ok, q = pcall(fn or function() end, itemID)
    tier = (ok and q) or tier
    return tier and CreateAtlasMarkup and CreateAtlasMarkup(("Professions-ChatIcon-Quality-12-Tier%d"):format(tier), 16, 16) or ""
end

local function ItemIcon(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(20, 20)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints()
    b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b:SetScript("OnEnter", function(self)
        if self._itemID then VoidGear:ShowItemTooltip(self, self._itemID) end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function Text(parent, size, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(fs, size, flags or "")
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function AcquirePrepRow(sc, i)
    local row = prepRows[i]
    if row then return row end
    row = CreateFrame("Frame", nil, sc)
    row:SetHeight(PREP_ROW_H)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture((i % 2 == 0) and 0.08 or 0.05, 0.08, 0.08, 0.5)
    local P = VoidUI.palette
    row.slot = Text(row, 10, "OUTLINE")
    row.slot:SetPoint("LEFT", PREP_COLS.slot, 0)
    row.slot:SetWidth(70)
    row.slot:SetTextColor(P.accent[1], P.accent[2], P.accent[3])
    row.now = Text(row, 10)
    row.now:SetPoint("LEFT", PREP_COLS.now, 0)
    row.now:SetWidth(PREP_COLS.nowW)
    row.icon = ItemIcon(row)
    row.icon:SetPoint("LEFT", PREP_COLS.icon, 0)
    row.item = Text(row, 10)
    row.item:SetPoint("LEFT", PREP_COLS.item, 0)
    row.item:SetPoint("RIGHT", -(PREP_COLS.modeW + PREP_COLS.haveW + 14), 0)
    row.have = Text(row, 10)
    row.have:SetPoint("RIGHT", -6, 0)
    row.have:SetWidth(PREP_COLS.haveW)
    row.have:SetJustifyH("RIGHT")
    row.mode = MakeButton(row, PREP_COLS.modeW, 18, "", function(self)
        VoidGear.Prep:ToggleItem(self._slot)
        UI:Refresh()
    end)
    row.mode:SetPoint("RIGHT", row.have, "LEFT", -6, 0)
    row.mode:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self._mode == "budget" and "Budget" or "Best")
        GameTooltip:AddLine(self._mode == "budget" and "The lower crafted quality: same item, cheaper."
            or "The higher crafted quality.", 1, 1, 1, true)
        if self._why then GameTooltip:AddLine(self._why, 1, 0.82, 0, true) end
        GameTooltip:AddLine("Click to switch for this item only.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    row.mode:HookScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnEnter", function(self)
        if not self._tip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self._tipTitle or "")
        GameTooltip:AddLine(self._tip, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    prepRows[i] = row
    return row
end

local function AcquireShopLine(sc, i)
    local line = prepShop[i]
    if line then return line end
    line = CreateFrame("Frame", nil, sc)
    line:SetHeight(PREP_ROW_H)
    line.icon = ItemIcon(line)
    line.icon:SetPoint("LEFT", PREP_COLS.slot, 0)
    line.text = Text(line, 10)
    line.text:SetPoint("LEFT", PREP_COLS.slot + 26, 0)
    line.text:SetPoint("RIGHT", -110, 0)
    line.search = MakeButton(line, 96, 20, "Search AH", function(self)
        local ok, why = VoidGear.Prep:SearchAH(self._itemID)
        if ok and why ~= "voidah" then   -- VoidAH searches by itself; Blizzard's box needs your click
            VoidGear:Print("Put it in the Auction House search box -- press Search.")
        elseif not ok then
            VoidGear:Print(why or "couldn't search")
        end
    end)
    line.search:SetPoint("RIGHT", -6, 0)
    prepShop[i] = line
    return line
end

local function BuildPrepTab(parent)
    parent._title = parent:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(parent._title, 11, "OUTLINE")
    parent._title:SetPoint("TOPLEFT", 4, -6)
    parent._title:SetTextColor(0, 0.78, 1)

    -- Global Best / Budget switch (top right)
    local function ModeButton(label, mode)
        local b = MakeButton(parent, 70, 20, label, function()
            VoidGear.Prep:SetMode(mode)
            UI:Refresh()
        end)
        b._mode = mode
        b:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(label)
            GameTooltip:AddLine(mode == "best" and "Buy the higher crafted quality of each item."
                or "Buy the lower crafted quality: same items, cheaper.", 1, 1, 1, true)
            GameTooltip:AddLine("Gear you'll likely replace soon (low upgrade track, or well below your item level) uses Budget either way. Click Best/Budget on a row to change one item.", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function() GameTooltip:Hide() end)
        return b
    end
    parent._budget = ModeButton("Budget", "budget")
    parent._budget:SetPoint("TOPRIGHT", -4, -2)
    parent._best = ModeButton("Best", "best")
    parent._best:SetPoint("RIGHT", parent._budget, "LEFT", -4, 0)
    local quality = parent:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(quality, 10, "")
    quality:SetPoint("RIGHT", parent._best, "LEFT", -6, 0)
    quality:SetTextColor(0.7, 0.7, 0.7)
    quality:SetText("Quality to buy:")

    parent._sub = parent:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(parent._sub, 9, "")
    parent._sub:SetPoint("TOPLEFT", 4, -26)
    parent._sub:SetPoint("RIGHT", -4, 0)
    parent._sub:SetJustifyH("LEFT")
    parent._sub:SetWordWrap(false)
    parent._sub:SetTextColor(0.55, 0.55, 0.62)

    local list = CreateFrame("Frame", nil, parent)
    list:SetPoint("TOPLEFT", 4, -44)
    list:SetPoint("BOTTOMRIGHT", -4, 0)
    parent._sc = CreateScrollArea(list)
    parent._list = list
end

local function RefreshPrepTab()
    local content = tabContent["prep"]
    if not content then return end
    local Prep = VoidGear.Prep
    local mode = Prep:GetMode()
    -- the active mode in bright accent, the other dimmed (hover would reset a backdrop color)
    content._best._text:SetText(mode == "best" and "|cff00c7ffBest|r" or "|cff777777Best|r")
    content._budget._text:SetText(mode == "budget" and "|cff00c7ffBudget|r" or "|cff777777Budget|r")
    for _, r in ipairs(prepRows) do r:Hide(); r.mode:Hide() end
    for _, l in ipairs(prepShop) do l:Hide() end
    for _, h in ipairs(prepHeads) do h:Hide() end
    if prepHeads.cols then for _, fs in ipairs(prepHeads.cols) do fs:Hide() end end
    local sc = content._sc
    local empty = content._list._emptyText

    if VoidGear.Scanner:AnyPending() then
        WaitForItems()
        content._title:SetText("Prep")
        content._sub:SetText("")
        empty:SetText("|cffaaaaaaReading your equipped gear...|r")
        empty:Show()
        return
    end
    local res = Prep:Compute()
    if not res then
        content._title:SetText("Prep")
        content._sub:SetText("")
        empty:SetText("No top-player data for your spec in this build.")
        empty:Show()
        return
    end
    if res.pending then WaitForItems() end   -- consumable tooltips still loading
    content._title:SetText("Enchants, gems and consumables: what to fix and buy")
    content._sub:SetText(("Enchants and gems: what the %d top Mythic+ %s players use. Consumables: the best for your stats.")
        :format(res.players or 0, res.label or "?"))
    empty:Hide()

    local y, nHead, nRow = 0, 0, 0
    -- column labels over the rows
    if not prepHeads.cols then
        local function label(point, x, text)
            local fs = sc:CreateFontString(nil, "OVERLAY")
            VoidUI:SetFont(fs, 9, "")
            fs:SetTextColor(0.55, 0.55, 0.62)
            fs:SetPoint(point, x, 0)
            fs:SetText(text)
            return fs
        end
        prepHeads.cols = { label("TOPLEFT", PREP_COLS.now, "You have"), label("TOPLEFT", PREP_COLS.icon, "Get"),
            label("TOPRIGHT", -(PREP_COLS.haveW + 12), "This item"), label("TOPRIGHT", -6, "In bags") }
    end
    for _, fs in ipairs(prepHeads.cols) do fs:Show() end
    y = 14

    local function head(text)
        if nHead > 0 then y = y + 8 end
        nHead = nHead + 1
        local fs = prepHeads[nHead]
        if not fs then
            fs = sc:CreateFontString(nil, "OVERLAY")
            VoidUI:SetFont(fs, 11, "OUTLINE")
            fs:SetTextColor(0, 0.78, 1)
            fs:SetJustifyH("LEFT")
            prepHeads[nHead] = fs
        end
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", PREP_COLS.slot, -y)
        fs:SetText(text)
        fs:Show()
        y = y + 18
    end
    local function nextRow()
        nRow = nRow + 1
        local row = AcquirePrepRow(sc, nRow)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", 0, 0)
        row.now:SetWidth(PREP_COLS.nowW)
        row.icon:Show()
        row.mode:Hide()   -- gear rows show it; consumables follow the switch at the top
        row:Show()
        y = y + PREP_ROW_H
        return row
    end
    local function countText(n) return n > 0 and ("|cff66ff66%d|r"):format(n) or "|cff8888880|r" end

    local function gearRow(r)
        local row = nextRow()
        local slotName = VoidGear.SLOTS[r.slot] or "?"
        if r.kind == "gem" then slotName = slotName .. " gem" end
        row.slot:SetText(slotName)
        row.now:SetText((SEVERITY_COLOR[r.severity] or "") .. (r.now or r.problem) .. "|r")
        local name = r.buy and C_Item.GetItemNameByID(r.buy)
        if r.buy and not name then C_Item.RequestLoadItemDataByID(r.buy); WaitForItems() end
        row.item:SetText((Prep:ShortName(name or r.topName) or "?") .. " " .. QualityIcon(r.buy, r.buyGroup))
        row.icon._itemID = r.buy
        row.icon.tex:SetTexture(r.buy and C_Item.GetItemIconByID(r.buy) or 134400)
        row.have:SetText(r.buy and countText(C_Item.GetItemCount(r.buy, true) or 0) or "")
        row.mode._slot, row.mode._mode, row.mode._why = r.slot, r.mode, r.modeWhy
        row.mode._text:SetText(r.mode == "budget" and "Budget" or "Best")
        row.mode:SetShown(r.buy ~= nil)   -- nothing to buy (e.g. a runeforge): no Best/Budget
        row._tipTitle = r.problem
        local tip = {}
        if r.haveName then tip[#tip + 1] = "You have: " .. r.haveName end
        tip[#tip + 1] = ("Top players: %s (%d%% of them)"):format(r.topName or "?", math.floor((r.share or 1) * 100 + 0.5))
        if r.note then tip[#tip + 1] = r.note end
        if r.buy then
            tip[#tip + 1] = (r.mode == "budget" and "Buying the cheaper quality" or "Buying the best quality")
                .. (r.modeWhy and (": " .. r.modeWhy) or ".")
        end
        row._tip = table.concat(tip, "\n")
    end

    local must, optional = {}, {}
    for _, r in ipairs(res.rows) do
        if r.severity == "need" then must[#must + 1] = r else optional[#optional + 1] = r end
    end
    if #res.rows == 0 then
        head("Enchants and gems")
        local row = nextRow()
        row.slot:SetText("Gear")
        row.now:SetText("|cff66ff66Every enchant and gem matches what the top players use.|r")
        row.now:SetWidth(500)
        row.icon:Hide(); row.item:SetText(""); row.have:SetText("")
        row._tip = nil
    end
    if #must > 0 then
        head("Must fix")
        for _, r in ipairs(must) do gearRow(r) end
    end
    if #optional > 0 then
        head("Optional upgrades |cff888888- yours works; top players use these (not on the shopping list)|r")
        for _, r in ipairs(optional) do gearRow(r) end
    end

    -- Consumables: one line per job, the best one for your spec
    if #res.consumables > 0 then
        head("Consumables")
        for _, c in ipairs(res.consumables) do
            local row = nextRow()
            row.slot:SetText(c.label)
            local otherName = c.other and C_Item.GetItemNameByID(c.other.group[1])
            row.now:SetText(c.have > 0 and "|cff66ff66This one|r"
                or c.other and ("|cffffd200%s (%d)|r"):format(otherName or "Another one", c.other.count)
                or "|cffff5555None|r")
            local name = C_Item.GetItemNameByID(c.buy)
            if not name then C_Item.RequestLoadItemDataByID(c.buy); WaitForItems() end
            row.icon._itemID = c.buy
            row.icon.tex:SetTexture(C_Item.GetItemIconByID(c.buy) or 134400)
            row.item:SetText((name or "?") .. " " .. QualityIcon(c.buy, c.buyGroup))
            row.have:SetText(countText(c.have))
            row._tipTitle = c.label
            row._tip = "Best for your spec's stat priority, read from each item's tooltip. Top-player data doesn't include consumables."
            if c.other then
                row._tip = row._tip .. ("\n\nYou carry %s, which does the job, so it's not on the shopping list."):format(otherName or "another one")
            end
            if c.risky then
                row._tip = row._tip .. ("\n\nStronger, but with a catch: %s (see its tooltip)."):format(
                    C_Item.GetItemNameByID(c.risky.group[1]) or "?")
            end
        end
    end

    -- Shopping list
    if #res.shop > 0 then
        head(("Shopping list |cff888888- %s|r"):format(mode == "budget" and "cheaper quality" or "best quality"))
        for i, e in ipairs(res.shop) do
            local line = AcquireShopLine(sc, i)
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", 0, -y)
            line:SetPoint("RIGHT", 0, 0)
            local name = C_Item.GetItemNameByID(e.id) or "?"
            if e.consumable then
                line.text:SetText(("%s %s   |cff888888none in your bags|r"):format(name, QualityIcon(e.id, nil)))
            else
                local need = math.max(e.count - e.have, 0)
                line.text:SetText(("%s %s   %s"):format(Prep:ShortName(name), QualityIcon(e.id, VoidGear.PrepData.sameName[e.id]),
                    need == 0 and "|cff66ff66you have enough|r"
                    or e.have > 0 and ("|cff888888have %d, buy %d|r"):format(e.have, need)
                    or ("|cff888888buy %d|r"):format(need)))
            end
            line.icon._itemID = e.id
            line.icon.tex:SetTexture(C_Item.GetItemIconByID(e.id) or 134400)
            line.search._itemID = e.id
            line:Show()
            y = y + PREP_ROW_H
        end
    end
    sc:SetHeight(math.max(y, 100))
end

----------------------------------------------------------------------
-- Build the panel
----------------------------------------------------------------------
local function BuildPanel()
    if panel then return panel end
    local P = VoidUI.palette
    local aR, aG, aB = P.accent[1], P.accent[2], P.accent[3]

    panel = CreateFrame("Frame", "VoidGear_Panel", UIParent, "BackdropTemplate")
    -- Restore saved size if any, else default
    local savedW = VoidGearCharDB and VoidGearCharDB.panelW or 740
    local savedH = VoidGearCharDB and VoidGearCharDB.panelH or 580
    panel:SetSize(savedW, savedH)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("HIGH")
    -- VoidAH's window is HIGH too and built later, so it covered this one (and
    -- the Prep tab's Search AH buttons) while the AH was open: come to the
    -- front on open and on click.
    panel:SetToplevel(true)
    panel:HookScript("OnShow", function(self) self:Raise() end)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:SetResizable(true)
    if panel.SetResizeBounds then
        panel:SetResizeBounds(600, 400, 1400, 1000)
    elseif panel.SetMinResize then
        panel:SetMinResize(600, 400)
        panel:SetMaxResize(1400, 1000)
    end
    panel:SetClampedToScreen(true)
    VoidUI:CreateBackdrop(panel, 0.08, 0.08, 0.10, 0.97)
    panel:SetBackdropBorderColor(aR, aG, aB, 0.4)
    panel:Hide()
    tinsert(UISpecialFrames, "VoidGear_Panel")

    -- Resize grip at bottom-right
    local resizeGrip = CreateFrame("Button", nil, panel)
    resizeGrip:SetSize(16, 16)
    resizeGrip:SetPoint("BOTTOMRIGHT", -2, 2)
    resizeGrip:SetFrameLevel(panel:GetFrameLevel() + 10)
    -- Visual: cyan triangle/dots in corner
    local gripTex = resizeGrip:CreateTexture(nil, "OVERLAY")
    gripTex:SetAllPoints()
    gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    gripTex:SetVertexColor(aR, aG, aB, 0.7)
    resizeGrip:RegisterForDrag("LeftButton")
    resizeGrip:SetScript("OnDragStart", function() panel:StartSizing("BOTTOMRIGHT") end)
    resizeGrip:SetScript("OnDragStop", function()
        panel:StopMovingOrSizing()
        ns.MoveSave(panel)   -- sizing re-anchors it: keep the spot it has now (VoidMove.lua)
        if VoidGearCharDB then
            VoidGearCharDB.panelW = math.floor(panel:GetWidth())
            VoidGearCharDB.panelH = math.floor(panel:GetHeight())
        end
        UI:Refresh()
    end)
    resizeGrip:SetScript("OnEnter", function(self)
        gripTex:SetVertexColor(aR, aG, aB, 1)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText("Drag to resize")
        GameTooltip:Show()
    end)
    resizeGrip:SetScript("OnLeave", function()
        gripTex:SetVertexColor(aR, aG, aB, 0.7)
        GameTooltip:Hide()
    end)

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, panel)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetHeight(28)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() panel:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)
    ns.Move(panel, { db = function() return VoidGearDB end, key = "panel", handle = titleBar })   -- drag + kept after a restart (VoidMove.lua)
    local tbBg = titleBar:CreateTexture(nil, "BACKGROUND")
    tbBg:SetAllPoints()
    tbBg:SetColorTexture(0.06, 0.06, 0.08, 1)
    local tbAccent = titleBar:CreateTexture(nil, "BORDER")
    tbAccent:SetPoint("BOTTOMLEFT")
    tbAccent:SetPoint("BOTTOMRIGHT")
    tbAccent:SetHeight(1)
    tbAccent:SetColorTexture(aR, aG, aB, 0.6)
    local title = titleBar:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(title, 13, "OUTLINE")
    title:SetTextColor(aR, aG, aB)
    title:SetPoint("LEFT", 12, 0)
    title:SetText("VoidGear - Gear Planner")

    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("RIGHT", -6, 0)
    local closeText = closeBtn:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(closeText, 14, "OUTLINE")
    closeText:SetPoint("CENTER")
    closeText:SetText("|cffff5555x|r")
    closeBtn:SetScript("OnClick", function() panel:Hide() end)

    -- Tab bar (under title)
    local tabBar = CreateFrame("Frame", nil, panel)
    tabBar:SetPoint("TOPLEFT", 0, -28)
    tabBar:SetPoint("TOPRIGHT", 0, -28)
    tabBar:SetHeight(28)
    local tabBarBg = tabBar:CreateTexture(nil, "BACKGROUND")
    tabBarBg:SetAllPoints()
    tabBarBg:SetColorTexture(0.04, 0.04, 0.06, 1)

    local tabDefs = {
        { key = "top",   label = "Top" },
        { key = "prep",  label = "Prep" },
        { key = "vault", label = "Vault" },
        { key = "raid",  label = "Raid" },
        { key = "mplus", label = "M+" },
        { key = "world", label = "World" },
        { key = "spares", label = "Spares" },   -- keep / sell / disenchant your spare gear (SparesUI.lua)
    }
    local prev = nil
    for _, def in ipairs(tabDefs) do
        local t = MakeTab(tabBar, def.key, def.label)
        if prev then
            t:SetPoint("LEFT", prev, "RIGHT", 2, 0)
        else
            t:SetPoint("LEFT", 6, 0)
        end
        tabs[def.key] = t
        prev = t
    end

    -- Scan loot button (top-right of tab bar) — declare local first so closure can capture it
    local scanBtn
    scanBtn = MakeButton(tabBar, 100, 22, "Scan Loot", function()
        scanBtn._text:SetText("Scanning...")
        C_Timer.After(0.1, function()
            VoidGear.LootDB:Scan(function()
                scanBtn._text:SetText("Scan Loot")
                UI:Refresh()
            end)
        end)
    end)
    scanBtn:SetPoint("RIGHT", -6, 0)
    panel._scanBtn = scanBtn

    -- Stat priority row (under tab bar)
    local statRow = CreateFrame("Frame", nil, panel)
    statRow:SetPoint("TOPLEFT", 0, -56)
    statRow:SetPoint("TOPRIGHT", 0, -56)
    statRow:SetHeight(28)
    BuildStatPriorityRow(statRow)
    panel._statRow = statRow

    -- Content area (below stat row)
    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", 8, -86)
    content:SetPoint("BOTTOMRIGHT", -8, 22)
    panel._content = content

    -- Build each tab's content frame
    for _, def in ipairs(tabDefs) do
        local f = CreateFrame("Frame", nil, content)
        f:SetAllPoints()
        f:Hide()
        tabContent[def.key] = f
        if def.key == "top" then
            BuildTopTab(f)
        elseif def.key == "vault" then
            BuildVaultTab(f)
        elseif def.key == "prep" then
            BuildPrepTab(f)
        elseif def.key == "spares" then
            VoidGear.SparesUI:Build(f)
        else
            CreateScrollArea(f)
        end
    end

    -- Footer
    local footer = panel:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(footer, 8, "")
    footer:SetPoint("BOTTOMLEFT", 14, 6)
    footer:SetTextColor(0.42, 0.42, 0.48)
    footer:SetText("v" .. VoidGear.version .. "  |  /vgear scan  /vgear budget  /vgear debug")

    UI:SwitchTab(activeTab or "top")
    return panel
end

----------------------------------------------------------------------
-- Switch active tab
----------------------------------------------------------------------
function UI:SwitchTab(key)
    if not tabs[key] then return end
    activeTab = key
    for k, t in pairs(tabs) do
        t:SetActive(k == key)
    end
    for k, c in pairs(tabContent) do
        if k == key then c:Show() else c:Hide() end
    end
    UI:Refresh()
end

----------------------------------------------------------------------
-- Refresh active tab's content
----------------------------------------------------------------------
local specRescan = false   -- a scan for the new spec is running

function UI:Refresh()
    if not panel then return end
    if panel._statRow and panel._statRow.UpdateSummary then
        panel._statRow:UpdateSummary()
    end

    local mode = (VoidGearCharDB and VoidGearCharDB.showAll) and "all" or "upgrades"
    if activeTab == "spares" then
        -- items from other characters may still be loading: redraw when they arrive
        if VoidGear.SparesUI:Refresh() then WaitForItems() end
        return
    end
    -- spec changed since the last scan: the loot list is per spec, so rescan
    if activeTab ~= "prep" and activeTab ~= "top" and not specRescan and VoidGear.LootDB:NeedsSpecRescan() then
        specRescan = true
        VoidGear.LootDB:Scan(function()
            specRescan = false
            UI:Refresh()
        end)
        return
    end
    -- scanned drops or vault examples still loading: redraw when they arrive
    if VoidGear.LootDB:FillMissing() then WaitForItems() end
    if VoidGear.LootDB:VaultPending() then WaitForItems() end

    if activeTab == "top" then
        RefreshTopTab()
    elseif activeTab == "prep" then
        RefreshPrepTab()
    elseif activeTab == "vault" then
        RefreshVaultTab()
    elseif activeTab == "raid" then
        local content = tabContent["raid"]
        local loot = VoidGear.LootDB:GetRaidLoot()
        local msg
        if not VoidGear.LootDB:IsScanned() then
            msg = "Click |cffffd200Scan Loot|r above to read this season's raid loot from the Adventure Guide."
        end
        RenderUpgrades(content, loot, msg, mode)
    elseif activeTab == "mplus" then
        local content = tabContent["mplus"]
        local loot = VoidGear.LootDB:GetMplusLoot()
        local msg
        if not VoidGear.LootDB:IsScanned() then
            msg = "Click |cffffd200Scan Loot|r above to read this season's Mythic+ dungeon loot from the Adventure Guide."
        end
        RenderUpgrades(content, loot, msg, mode)
    elseif activeTab == "world" then
        local content = tabContent["world"]
        local loot = VoidGear.LootDB:GetWorldLoot()
        RenderUpgrades(content, loot, VoidGear.LootDB:IsScanned()
            and "No world boss loot found for this season's world bosses yet."
            or "Click |cffffd200Scan Loot|r above to read this season's world boss loot from the Adventure Guide.", mode)
    end
end

-- While the panel is open, redraw when what it shows changes: gear swapped,
-- an enchant or gem applied, something bought, spec changed. Batched (0.5s):
-- bag events come in bursts, and the scorer recalibrates on the same events.
local liveEvents = CreateFrame("Frame")
liveEvents:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
liveEvents:RegisterEvent("BAG_UPDATE_DELAYED")
liveEvents:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
liveEvents:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
local liveQueued = false
liveEvents:SetScript("OnEvent", function(_, event)
    if liveQueued or not (panel and panel:IsShown()) then return end
    -- bags only matter to Prep (what you carry); elsewhere a redraw while
    -- looting would just reset the scroll
    if event == "BAG_UPDATE_DELAYED" and activeTab ~= "prep" and activeTab ~= "spares" then return end
    liveQueued = true
    C_Timer.After(0.5, function()
        liveQueued = false
        if panel and panel:IsShown() then UI:Refresh() end
    end)
end)

function UI:Toggle()
    -- WoW Forever: its own panel (ForeverUI.lua); this one is Midnight's raid / M+ planner.
    -- The minimap button and the Void hub reached it on Forever (audit, 2026-11-09).
    if VoidGear.IS_FOREVER and VoidGear.ForeverUI then return VoidGear.ForeverUI:Toggle() end
    BuildPanel()
    if panel:IsShown() then
        panel:Hide()
    else
        UI:Refresh()
        panel:Show()
    end
end
