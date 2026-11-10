----------------------------------------------------------------------
-- VoidGear ForeverUI -- the gear panel on WoW Forever.
--
-- The user, 2026-11-09: "voidgear is completely botched for forever". The main panel is
-- Midnight's raid / M+ planner (top players, vault, seasons) and showed "no data for this
-- spec" there. On Forever the minimap button, the Void hub and /vgear open this instead:
--   Gear       what you wear, scored with your class's weights (the spec API is a placeholder
--              on Forever: a Rogue reports Intellect), the stats that count most per piece
--   Dungeons   drops from dungeons near your level that beat what you wear (VoidDungeon's
--              loot tables with drop chances; optional)
--   Quests     quest rewards you can still get that beat what you wear (VoidQuest's Forever
--              quest list; optional). Click: the way to the quest giver
-- Scores come from VoidGear's scorer: item stats plus Classic "Equip:" lines (crit %, hit %,
-- attack power, spell damage ...) and weapon / wand DPS, weighted per class.
----------------------------------------------------------------------
if (select(4, GetBuildInfo()) or 0) >= 100000 then return end   -- WoW Forever only

local VG = VoidGear
local F = {}
VG.ForeverUI = F

local A = { 0, 0.78, 1 }
local FONT = "Fonts\\FRIZQT__.TTF"
local GetItemInfo = C_Item.GetItemInfo
local GetItemInfoInstant = C_Item.GetItemInfoInstant

local function VoidPX()
    local s = UIParent and UIParent:GetEffectiveScale()
    if s and s > 0 and PixelUtil and PixelUtil.GetPixelToUIUnitFactor then return PixelUtil.GetPixelToUIUnitFactor() / s end
    return 1
end

----------------------------------------------------------------------
-- What your class can wear / wield (Classic rules). Item class 4 armor subclasses, class 2
-- weapon subclasses; a number = the level you learn it at (mail / plate at 40).
----------------------------------------------------------------------
local ARMOR = {
    WARRIOR = { [1] = 1, [2] = 1, [3] = 1, [4] = 40, [6] = 1 },
    PALADIN = { [1] = 1, [2] = 1, [3] = 1, [4] = 40, [6] = 1 },
    HUNTER  = { [1] = 1, [2] = 1, [3] = 40 },
    SHAMAN  = { [1] = 1, [2] = 1, [3] = 40, [6] = 1 },
    ROGUE   = { [1] = 1, [2] = 1 },
    DRUID   = { [1] = 1, [2] = 1 },
    MAGE    = { [1] = 1 }, PRIEST = { [1] = 1 }, WARLOCK = { [1] = 1 },
}
local function set(...) local t = {} for _, v in ipairs({ ... }) do t[v] = true end return t end
local WEAPON = {   -- 0/1 axe 1H/2H, 2 bow, 3 gun, 4/5 mace, 6 polearm, 7/8 sword, 10 staff,
                   -- 13 fist, 15 dagger, 16 thrown, 18 crossbow, 19 wand
    WARRIOR = set(0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18),
    PALADIN = set(0, 1, 4, 5, 6, 7, 8),
    HUNTER  = set(0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18),
    ROGUE   = set(2, 3, 4, 7, 13, 15, 16, 18),
    SHAMAN  = set(0, 1, 4, 5, 10, 13, 15),
    DRUID   = set(4, 5, 10, 13, 15),
    MAGE    = set(7, 10, 15, 19), PRIEST = set(4, 10, 15, 19), WARLOCK = set(7, 10, 15, 19),
}
local DUAL = set("WARRIOR", "ROGUE", "HUNTER")

-- equip location -> the slots it can go in
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 },
    INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 },
    INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPON = { 16 }, INVTYPE_SHIELD = { 17 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
local SLOT_NAME = { [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [6] = "Waist", [7] = "Legs",
    [8] = "Feet", [9] = "Wrist", [10] = "Hands", [11] = "Ring", [12] = "Ring", [13] = "Trinket", [14] = "Trinket",
    [15] = "Back", [16] = "Main hand", [17] = "Off hand", [18] = "Ranged" }
local GEAR_SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }

local function MyClass() return select(2, UnitClass("player")) or "WARRIOR" end

-- Can this character wear / wield it (by its type), and from what level? true/false, learnAt
local function CanWear(itemID)
    local _, _, _, equipLoc, _, classID, subID = GetItemInfoInstant(itemID)
    if not (equipLoc and SLOTS[equipLoc]) then return false end
    local cls = MyClass()
    if classID == 4 then
        if subID == 0 then return true, 1 end            -- neck / ring / trinket / held in off hand
        local lv = ARMOR[cls] and ARMOR[cls][subID]
        return lv ~= nil, lv
    elseif classID == 2 then
        if not (WEAPON[cls] and WEAPON[cls][subID]) then return false end
        if equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONOFFHAND" then return true, 1 end
        return true, 1
    end
    return false
end

----------------------------------------------------------------------
-- Scoring
----------------------------------------------------------------------
local function Context()
    local Sc = VG.Scorer
    if not (Sc and Sc.GetActiveContext) then return nil end
    local ok, w, primary = pcall(Sc.GetActiveContext, Sc)
    if ok then return w, primary end
end

local function Score(link)
    local Sc = VG.Scorer
    local w, primary = Context()
    if not (link and w and Sc and Sc.ScoreLink) then return 0, {} end
    local ok, s, breakdown = pcall(Sc.ScoreLink, Sc, link, w, primary)
    if ok and type(s) == "number" then return s, breakdown or {} end
    return 0, {}
end

local function EquippedScore(slot)
    local link = GetInventoryItemLink("player", slot)
    if not link then return 0, nil end
    return (Score(link)), link
end

-- How much better than what you wear: gain (score points), pct, slot it would replace, or nil.
-- Two-slot kinds (rings, trinkets, a rogue's one-handers) are measured against the weaker.
-- Dual wield: a rogue at 10, warriors and hunters at 20 (Classic trainers); the spell if known.
local function CanDualWield()
    if not DUAL[MyClass()] then return false end
    if IsPlayerSpell and IsPlayerSpell(674) then return true end
    return (UnitLevel("player") or 0) >= (MyClass() == "ROGUE" and 10 or 20)
end

local function WearingTwoHander()
    local id = GetInventoryItemID("player", 16)
    return id and select(4, GetItemInfoInstant(id)) == "INVTYPE_2HWEAPON"
end

local HANDS = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true }

local function Upgrade(itemID, link)
    local _, _, _, equipLoc = GetItemInfoInstant(itemID)
    local slots = SLOTS[equipLoc]
    if not slots then return nil end
    if equipLoc == "INVTYPE_WEAPON" and CanDualWield() then slots = { 16, 17 } end
    -- an off-hand weapon needs dual wield (Sol review)
    if equipLoc == "INVTYPE_WEAPONOFFHAND" and not CanDualWield() then return nil end
    -- a slot already holding this very item isn't one it would go in: a second copy can still
    -- beat the OTHER ring / trinket / hand (Sol review); none left = nothing to compare
    local free = {}
    for _, slot in ipairs(slots) do
        if GetInventoryItemID("player", slot) ~= itemID then free[#free + 1] = slot end
    end
    if #free == 0 then return nil end
    slots = free
    local s = Score(link)
    if s <= 0 then return nil end
    local worst, worstSlot
    for _, slot in ipairs(slots) do
        local cur = EquippedScore(slot)
        if equipLoc == "INVTYPE_2HWEAPON" then cur = cur + EquippedScore(17) end   -- a 2H replaces both hands
        -- with a two-hander on, a one-hander / shield / off-hand item replaces it (it's measured
        -- against the two-hander, not against an empty off hand; Sol review)
        if HANDS[equipLoc] and WearingTwoHander() then cur = EquippedScore(16) end
        if not worst or cur < worst then worst, worstSlot = cur, slot end
    end
    if s <= (worst or 0) * 1.02 then return nil end
    local pct = (worst and worst > 0) and math.floor((s - worst) / worst * 100 + 0.5) or nil
    return s - (worst or 0), pct, worstSlot
end

----------------------------------------------------------------------
-- Candidates
----------------------------------------------------------------------
local loading = false   -- some item data was still on its way: the list fills in as it arrives

-- One candidate item: its row, or nil if it isn't for you. fromLevel/toLevel: the level window.
local function Candidate(itemID, lvl)
    local ok, learnAt = CanWear(itemID)
    if not ok then return nil end
    local name, link, quality, _, reqLevel = GetItemInfo(itemID)
    if not link then
        loading = true
        C_Item.RequestLoadItemDataByID(itemID)
        return nil
    end
    if (quality or 0) < 2 then return nil end                     -- greens and better
    reqLevel = math.max(reqLevel or 0, learnAt or 0)
    if reqLevel > lvl + 3 then return nil end                     -- not yet
    local gain, pct, slot = Upgrade(itemID, link)
    if not gain then return nil end
    return { id = itemID, link = link, name = name, gain = gain, pct = pct, slot = slot, req = reqLevel }
end

local function DungeonRows(lvl)
    local J = _G.VoidDungeon
    if not (J and J.dungeons and J.Bosses and J.Loot) then return nil end
    local out, seen = {}, {}
    for _, d in ipairs(J.dungeons) do
        local lo, hi = (d.lv or ""):match("^(%d+)%-(%d+)")
        lo, hi = tonumber(lo) or d.min or 99, tonumber(hi) or (d.min or 99) + 5
        if lo <= lvl + 4 and hi >= lvl - 2 then
            for _, b in ipairs(J:Bosses(d)) do
                for _, l in ipairs(J:Loot(b.npc)) do
                    local id, chance = l[1], l[2]
                    if not seen[id] then
                        local c = Candidate(id, lvl)
                        if c then
                            seen[id] = true
                            c.where = ("%s, %s (%s)"):format(b.name, d.name, d.lv or "?")
                            c.near = math.abs((lo + hi) / 2 - lvl)   -- how far the dungeon is from your level
                            c.chance = chance
                            out[#out + 1] = c
                        end
                    end
                end
            end
        end
    end
    return out
end

-- developer leftovers in Forever's quest data ("Lee's Ultimate Test Quest... of Doom!", seen 2026-11-10)
local function IsTestQuest(title)
    local t = (title or ""):lower()
    return t:find("test quest", 1, true) or t:find("[dnt]", 1, true) or t:find("[ph]", 1, true) or t:find("deprecated", 1, true)
end

local BATTLEGROUNDS = { ["Alterac Valley"] = true, ["Arathi Basin"] = true, ["Warsong Gulch"] = true }

local function QuestRows(lvl)
    local VQ = _G.VoidQuest
    local FQ = VQ and VQ.Forever
    if not (VQ and VQ.ForeverQuests and FQ and FQ.Eligible and FQ.Status) then return nil end
    local names = VQ.ForeverNames or {}
    local out = {}
    for qid, r in pairs(VQ.ForeverQuests) do
        local ids = r[11]
        -- the quest's own level (the client has it; loads on first ask): Alterac Valley / Arathi
        -- Basin quests (51+) came up at 31 because their rewards carry no level (2026-11-10)
        local zone = names[r[2]] or ""
        -- the cheap checks first; the level (which loads, and fires an event) only for the rest (Sol)
        local ok = ids and ids ~= "" and not BATTLEGROUNDS[zone] and not IsTestQuest(r[1])
            and FQ:Eligible(r) and FQ:Status(qid) ~= "done"
        local ql = ok and FQ.Level and FQ:Level(qid) or 0
        if ok and ql <= lvl + 3 then
            local best
            for tok in ids:gmatch("%d+") do
                local c = Candidate(tonumber(tok), lvl)
                if c and (not best or c.gain > best.gain) then best = c end
            end
            if best then
                best.quest, best.qid = r[1], qid
                best.where = ("%s%s"):format(r[1], names[r[2]] and (" (" .. names[r[2]] .. ")") or "")
                best.inLog = FQ:Status(qid) == "log"
                -- the reward's required level stands in for the quest's (the data has no quest level)
                best.near = (ql > 0 and math.abs(ql - lvl)) or ((best.req or 0) > 0 and math.abs(best.req - lvl)) or 99
                best.ql = ql > 0 and ql or nil
                out[#out + 1] = best
            end
        end
    end
    return out
end

----------------------------------------------------------------------
-- Panel
----------------------------------------------------------------------
local panel, tabs, rows, child, scroll, head, note
local current = "gear"
local MAX_ROWS = 40

local function Rows(n)
    for i = #rows + 1, n do
        local b = CreateFrame("Button", nil, child)
        b:SetHeight(18)
        b:SetPoint("TOPLEFT", 0, -(i - 1) * 19)
        b:SetPoint("RIGHT", child, "RIGHT", 0, 0)
        b.text = b:CreateFontString(nil, "OVERLAY")
        b.text:SetFont(FONT, 11, "")
        b.text:SetPoint("LEFT", 4, 0)
        b.text:SetPoint("RIGHT", -4, 0)
        b.text:SetJustifyH("LEFT")
        b.text:SetWordWrap(false)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(A[1], A[2], A[3], 0.12)
        b:SetScript("OnEnter", function(self)
            if not self.link then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.link)
            if self.hint then GameTooltip:AddLine(self.hint, 0, 0.78, 1, true) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnClick", function(self)
            if IsModifiedClick("CHATLINK") and self.link then ChatEdit_InsertLink(self.link) return end
            if self.qid and _G.VoidQuest and VoidQuest.Forever and VoidQuest.Forever.Go then VoidQuest.Forever:Go(self.qid) end
        end)
        rows[i] = b
    end
end

local function Fill(lines)
    Rows(#lines)
    for i, l in ipairs(lines) do
        local b = rows[i]
        b.text:SetText(l.text)
        b.link, b.hint, b.qid = l.link, l.hint, l.qid
        b:Show()
    end
    for i = #lines + 1, #rows do rows[i]:Hide() end
    child:SetHeight(math.max(1, #lines * 19))
end

local STAT_SHORT = { AttackPower = "AP", RangedAttackPower = "RAP", SpellPower = "Spell power", CritPct = "Crit %",
    HitPct = "Hit %", SpellCritPct = "Spell crit %", SpellHitPct = "Spell hit %", WeaponSkill = "Weapon skill",
    SchoolPower = "School spell dmg", WandDPS = "Wand DPS", DPS = "Weapon DPS", BlockValue = "Block value",
    DodgePct = "Dodge %", ParryPct = "Parry %", BlockPct = "Block %" }

local function GearLines()
    local lines = {}
    for _, slot in ipairs(GEAR_SLOTS) do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local s, breakdown = Score(link)
            local parts = {}
            for k, v in pairs(breakdown or {}) do
                if type(v) == "number" and v > 0 and k ~= "Effects" then parts[#parts + 1] = { k, v } end
            end
            table.sort(parts, function(a, b) return a[2] > b[2] end)
            local top = {}
            for i = 1, math.min(3, #parts) do top[i] = STAT_SHORT[parts[i][1]] or parts[i][1] end
            lines[#lines + 1] = { link = link, text = ("|cff9a9aa6%-9s|r %s  |cffffd200%d|r  |cff9a9aa6%s|r"):format(
                SLOT_NAME[slot] or "", link, math.floor(s + 0.5), table.concat(top, ", ")) }
        else
            lines[#lines + 1] = { text = ("|cff9a9aa6%-9s|r |cff666666(empty)|r"):format(SLOT_NAME[slot] or "") }
        end
    end
    return lines
end

local function UpgradeLines(list, what)
    if not list then
        return { { text = "|cffaaaaaa" .. (what == "dungeons" and "Install VoidDungeon to list dungeon drops."
            or "Install VoidQuest to list quest rewards.") .. "|r" } }
    end
    -- closest to your level first, the bigger upgrade first among those (the user, 2026-11-10:
    -- "can we sort them closest to my level")
    table.sort(list, function(a, b)
        local na, nb = a.near or 99, b.near or 99
        if na ~= nb then return na < nb end
        return a.gain > b.gain
    end)
    local lines = {}
    for i = 1, math.min(MAX_ROWS, #list) do
        local c = list[i]
        -- over +500% just means what you wear is almost nothing there (a headband with only armor)
        local up = c.pct and (c.pct > 500 and "+500%+" or ("+%d%%"):format(c.pct)) or "new"
        local later = c.req > (UnitLevel("player") or 0) and (" |cffff8800at %d|r"):format(c.req)
            or (c.qid and (c.ql or c.req) > 0 and (" |cff9a9aa6lvl %d|r"):format(c.ql or c.req)) or ""
        local extra = (c.chance and c.chance > 0) and ("  |cff9a9aa6%s%%|r"):format(c.chance >= 1 and math.floor(c.chance + 0.5) or ("%.1f"):format(c.chance)) or ""
        local log = c.inLog and " |cff66ff66(in your log)|r" or ""
        lines[#lines + 1] = { link = c.link, qid = c.qid,
            hint = c.qid and "Click: the way to its quest giver (VoidQuest)" or nil,
            text = ("|cff66ff66%5s|r %s |cff9a9aa6%s|r%s  %s%s%s"):format(up, c.link, SLOT_NAME[c.slot] or "", later,
                c.where or "", extra, log) }
    end
    if #lines == 0 then
        lines[1] = { text = "|cffaaaaaa" .. (loading and "Loading item data..." or
            (what == "dungeons" and "No dungeon drop near your level beats what you wear." or
             "No quest reward you can still get beats what you wear.")) .. "|r" }
    end
    return lines
end

function F:Refresh()
    if not (panel and panel:IsShown()) then return end
    loading = false
    local lvl = UnitLevel("player") or 1
    local w, primary = Context()
    local preset = VG.StatWeights and VG.StatWeights:GetCurrent()
    head:SetText(("Scored as |cffffffff%s|r: %s first, then %s"):format(preset and preset.label or MyClass(),
        primary or "?", F.TopWeights(w)))
    local lines
    if current == "gear" then
        lines = GearLines()
        note:SetText("Your gear with your class's weights (on Forever the spec doesn't matter). Hover an item for its tooltip.")
    elseif current == "dungeons" then
        lines = UpgradeLines(DungeonRows(lvl), "dungeons")
        note:SetText("Drops from dungeons near your level that beat what you wear, best first; % = drop chance. Up to 3 levels ahead.")
    else
        lines = UpgradeLines(QuestRows(lvl), "quests")
        note:SetText("Quest rewards you can still get that beat what you wear, best first. Click one for the way to its quest giver.")
    end
    Fill(lines)
end

-- The everyday stats only: weapon skill, HP5, crit / hit % ... are weighed per single point, so
-- next to these their weights read as a false priority ("Weapon DPS > Weapon skill > HP5" for a
-- Rogue, seen live 2026-11-10).
local EVERYDAY = { Strength = true, Agility = true, Intellect = true, Stamina = true, Spirit = true,
    AttackPower = true, RangedAttackPower = true, SpellPower = true, Healing = true, DPS = true, WandDPS = true }
function F.TopWeights(w)
    local list = {}
    for k, v in pairs(w or {}) do
        if type(v) == "number" and EVERYDAY[k] then list[#list + 1] = { k, v } end
    end
    table.sort(list, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[1] < b[1] end)
    local out = {}
    for i = 1, math.min(3, #list) do out[i] = STAT_SHORT[list[i][1]] or list[i][1] end
    return #out > 0 and table.concat(out, " > ") or "?"
end

local function MakeTab(key, label, x)
    local t = CreateFrame("Button", nil, panel)
    t:SetSize(120, 22)
    t:SetPoint("TOPLEFT", x, -34)
    t.bg = t:CreateTexture(nil, "BACKGROUND")
    t.bg:SetAllPoints()
    t.text = t:CreateFontString(nil, "OVERLAY")
    t.text:SetFont(FONT, 11, "OUTLINE")
    t.text:SetPoint("CENTER")
    t.text:SetText(label)
    t:SetScript("OnClick", function()
        current = key
        for k, b in pairs(tabs) do b.bg:SetColorTexture(k == key and 0 or 0.12, k == key and 0.4 or 0.12, k == key and 0.6 or 0.14, 1) end
        F:Refresh()
    end)
    tabs[key] = t
    return t
end

local function Build()
    if panel then return end
    panel = CreateFrame("Frame", "VoidGearForeverPanel", UIParent, "BackdropTemplate")
    panel:SetSize(680, 470)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")   -- above the Auction House window (it opened behind it, 2026-11-10)
    panel:SetToplevel(true)
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = VoidPX() })
    panel:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
    panel:SetBackdropBorderColor(A[1], A[2], A[3], 0.7)
    tinsert(UISpecialFrames, "VoidGearForeverPanel")

    local title = panel:CreateFontString(nil, "OVERLAY")
    title:SetFont(FONT, 14, "OUTLINE")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetTextColor(A[1], A[2], A[3])
    title:SetText("VoidGear - WoW Forever")
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    tabs = {}
    MakeTab("gear", "Your gear", 12)
    MakeTab("dungeons", "Dungeon upgrades", 138)
    MakeTab("quests", "Quest upgrades", 264)

    head = panel:CreateFontString(nil, "OVERLAY")
    head:SetFont(FONT, 11, "")
    head:SetPoint("TOPLEFT", 14, -66)
    head:SetPoint("RIGHT", -14, 0)
    head:SetJustifyH("LEFT")
    note = panel:CreateFontString(nil, "OVERLAY")
    note:SetFont(FONT, 10, "")
    note:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -4)
    note:SetPoint("RIGHT", -14, 0)
    note:SetJustifyH("LEFT")
    note:SetTextColor(0.6, 0.6, 0.65)

    scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -104)
    scroll:SetPoint("BOTTOMRIGHT", -30, 12)
    child = CreateFrame("Frame", nil, scroll)
    child:SetSize(620, 1)
    scroll:SetScrollChild(child)
    scroll:SetScript("OnSizeChanged", function(_, w) child:SetWidth(w) end)
    rows = {}
    panel:Hide()
    tabs.gear:Click()
end

function F:Toggle()
    if InCombatLockdown() then return end
    Build()
    if panel:IsShown() then panel:Hide() else panel:Show(); panel:Raise(); F:Refresh() end
end

-- item data arriving / gear or level changing: redraw (batched)
local queued
local ev = CreateFrame("Frame")
for _, e in ipairs({ "GET_ITEM_INFO_RECEIVED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "QUEST_TURNED_IN",
    "QUEST_DATA_LOAD_RESULT" }) do   -- quest levels load on first ask (Quest upgrades)
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, e)
    if not (panel and panel:IsShown()) or queued then return end
    if e == "GET_ITEM_INFO_RECEIVED" and not loading then return end
    queued = true
    C_Timer.After(0.6, function() queued = false; F:Refresh() end)
end)
