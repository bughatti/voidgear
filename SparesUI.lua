----------------------------------------------------------------------
-- VoidGear Spares tab -- Spares.lua's verdicts: what to disenchant (and on
-- which character), sell, keep (and for whom) or vendor. Hover a row for the
-- item's tooltip.
----------------------------------------------------------------------
VoidGear = VoidGear or {}
local SUI = {}
VoidGear.SparesUI = SUI

local ROW = 18
local GOLD, DIM, GREEN, RED, CYAN = "|cffffd200", "|cff9a9aa6", "|cff55ff55", "|cffff6060", "|cff00c7ff"
local SECTIONS = {
    { key = "de",     title = "Disenchant",  color = CYAN },
    { key = "sell",   title = "Sell",        color = GOLD },
    { key = "keep",   title = "Keep",        color = GREEN },
    { key = "check",  title = "Check: you decide", color = RED },
    { key = "vendor", title = "Vendor",      color = DIM },
    { key = "wait",   title = "Still loading", color = DIM },
}
local QUALITY_MAT = { [2] = "Eversinging Dust", [3] = "Radiant Shard", [4] = "Dawn Crystal" }

local frame

----------------------------------------------------------------------
-- Buttons, so nobody has to find each item in their bags (the user,
-- 2026-11-03: "i would have to then open my bags and start checking names
-- of each one"):
--   Disenchant next  -- secure: each click disenchants the next item this
--                       character should disenchant (one click per item:
--                       casting needs a click or key press every time)
--   Take from bank   -- moves this character's pile from its bank and the
--                       warband bank into its bags (bank open)
--   Put in warband bank -- on another character: deposits what an enchanter
--                       of yours should disenchant (bank open)
----------------------------------------------------------------------
local DISENCHANT = 13262
local STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
local deBtn, bankBtn, sendBtn, holder
local deHere, fromBank, toSend, sendTo = {}, {}, {}, nil
local deActive = false   -- the Disenchant button has something to do
local bankOpen = false

-- The next piece on the list, at the exact bag slot it was judged in: same
-- link, same bound state, not locked, not protected since. Matching by link
-- alone could pick an identical copy that was judged "keep" (a BoE copy kept
-- for an alt next to a soulbound one; Codex Sol, 2026-11-03). A piece that
-- moved isn't taken until the list is redrawn.
local function nextTarget()
    for _, e in ipairs(deHere) do
        local info = e.bag and C_Container.GetContainerItemInfo(e.bag, e.slot)
        if info and not info.isLocked and C_Container.GetContainerItemLink(e.bag, e.slot) == e.link
            and not VoidGear.Spares.ProtectedWhy(info.itemID) then
            local loc = ItemLocation:CreateFromBagAndSlot(e.bag, e.slot)
            local ok, bound = pcall(C_Item.IsBound, loc)
            if e.bound == nil or (ok and bound == e.bound) then
                return e.bag, e.slot, e.link
            end
        end
    end
end

-- No target left set between clicks: Blizzard's handler targets an item from
-- these attributes whenever a spell is waiting for one, whatever "type" says.
local function clearTarget(btn)
    if InCombatLockdown() then return end
    btn:SetAttribute("type", nil)
    btn:SetAttribute("spell", nil)
    btn:SetAttribute("target-bag", nil)
    btn:SetAttribute("target-slot", nil)
end

local function freeBagSlots()
    local n = 0
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local free, family = C_Container.GetContainerNumFreeSlots(bag)
        if family == 0 then n = n + (free or 0) end
    end
    return n
end

-- The secure button lives on UIParent, laid over `holder`: a protected child
-- would stop the panel from opening or closing in combat. Moves only out of combat.
local function placeDE()
    if not (deBtn and holder) or InCombatLockdown() then return end
    local l, b = holder:GetLeft(), holder:GetBottom()
    if not (l and b) then return end
    if deBtn._l ~= l or deBtn._b ~= b then
        deBtn._l, deBtn._b = l, b
        deBtn:SetScale(holder:GetEffectiveScale() / UIParent:GetEffectiveScale())
        deBtn:ClearAllPoints()
        deBtn:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
        -- one strata above the panel: at the panel's own strata it drew underneath
        -- the panel's backdrop (raised when clicked), 2026-11-03
        local s = holder:GetFrameStrata()
        for i, name in ipairs(STRATA) do
            if name == s then s = STRATA[i + 1] or name break end
        end
        deBtn:SetFrameStrata(s)
    end
end

local function syncDE()
    if not deBtn or InCombatLockdown() then return end
    if deActive and holder:IsVisible() then
        placeDE()
        deBtn:SetAlpha(1)
        deBtn:Show()
    else
        deBtn:Hide()
    end
end

local function moveNext(queue, done)
    local i = 0
    local function step()
        i = i + 1
        local q = queue[i]
        if not q or not bankOpen then
            done(i - 1)
            return
        end
        if C_Container.GetContainerItemLink(q.bag, q.slot) == q.link then
            C_Container.UseContainerItem(q.bag, q.slot, nil, q.bankType)
        end
        C_Timer.After(0.1, step)
    end
    step()
end

local function takeFromBank()
    if not bankOpen then
        VoidGear:Print("Open your bank first, then press Take from bank again.")
        return
    end
    local want = {}
    for _, e in ipairs(fromBank) do want[e.link] = (want[e.link] or 0) + 1 end
    local queue, room = {}, freeBagSlots()
    for _, bt in ipairs({ Enum.BankType.Character, Enum.BankType.Account }) do
        if C_Bank.CanViewBank(bt) then
            for _, tab in ipairs(C_Bank.FetchPurchasedBankTabData(bt) or {}) do
                for slot = 1, C_Container.GetContainerNumSlots(tab.ID) or 0 do
                    local link = C_Container.GetContainerItemLink(tab.ID, slot)
                    if link and (want[link] or 0) > 0 and #queue < room then
                        want[link] = want[link] - 1
                        queue[#queue + 1] = { bag = tab.ID, slot = slot, link = link }
                    end
                end
            end
        end
    end
    if #queue == 0 then
        VoidGear:Print(room == 0 and "Your bags are full." or "None of them are in this bank right now.")
        return
    end
    moveNext(queue, function(n)
        VoidGear:Print(("Took %d item%s to disenchant into your bags%s."):format(n, n == 1 and "" or "s",
            #queue < #fromBank and " (bags full or some weren't there: disenchant these, then take more)" or ""))
    end)
end

local function putInWarband()
    if not (bankOpen and C_Bank.CanViewBank(Enum.BankType.Account)) then
        VoidGear:Print("Open your bank (warband bank tab available) first, then press the button again.")
        return
    end
    local queue = {}
    for _, e in ipairs(toSend) do
        queue[#queue + 1] = { bag = e.bag, slot = e.slot, link = e.link, bankType = Enum.BankType.Account }
    end
    moveNext(queue, function(n)
        VoidGear:Print(("Put %d item%s in the warband bank for %s to disenchant."):format(n, n == 1 and "" or "s",
            sendTo and VoidGear.Spares.ShortName(sendTo) or "your enchanter"))
    end)
end

function SUI:BuildButtons(parent)
    holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(190, 22)
    holder:SetPoint("TOPLEFT", 6, -60)
    holder:SetScript("OnShow", syncDE)
    holder:SetScript("OnHide", function()
        if not deBtn then return end
        if InCombatLockdown() then deBtn:SetAlpha(0) else deBtn:Hide() end
    end)
    holder:SetScript("OnUpdate", placeDE)   -- follows the panel when it's dragged

    deBtn = CreateFrame("Button", "VoidGearDisenchantButton", UIParent, "SecureActionButtonTemplate, BackdropTemplate")
    VoidGear.StyleButton(deBtn, 190, 22, "Disenchant next")
    deBtn:RegisterForClicks("LeftButtonUp")
    deBtn:SetAttribute("useOnKeyDown", false)
    deBtn:Hide()
    -- pick the item at click time: bags change (sorting, looting) between redraws
    deBtn:SetScript("PreClick", function(self)
        if InCombatLockdown() then return end   -- attributes were cleared when combat began
        local bag, slot = nextTarget()
        if bag then
            self:SetAttribute("type", "spell")
            self:SetAttribute("spell", DISENCHANT)
            self:SetAttribute("target-bag", bag)
            self:SetAttribute("target-slot", slot)
        else
            clearTarget(self)
            VoidGear:Print("Nothing left to disenchant in your bags (or the list needs a moment to redraw).")
        end
    end)
    -- one click, one target: nothing lingers for the next click or a later cursor
    deBtn:SetScript("PostClick", clearTarget)
    deBtn:HookScript("OnEnter", function(self)
        local _, _, link = nextTarget()
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Disenchant next", 0, 0.78, 1)
        if link then GameTooltip:AddLine("Next: " .. link, 1, 1, 1) end
        GameTooltip:AddLine("One click per item; the list updates as you go.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    deBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    bankBtn = VoidGear.StyleButton(CreateFrame("Button", nil, parent, "BackdropTemplate"), 170, 22, "Take from bank")
    bankBtn:SetPoint("LEFT", holder, "RIGHT", 6, 0)
    bankBtn:SetScript("OnClick", takeFromBank)
    bankBtn:Hide()

    sendBtn = VoidGear.StyleButton(CreateFrame("Button", nil, parent, "BackdropTemplate"), 230, 22, "Put in warband bank")
    sendBtn:SetScript("OnClick", putInWarband)
    sendBtn:Hide()

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("BANKFRAME_OPENED")
    ev:RegisterEvent("BANKFRAME_CLOSED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then syncDE() return end
        -- fires just before the lockdown: the last moment attributes can change
        if event == "PLAYER_REGEN_DISABLED" then
            if deBtn then
                deBtn:SetAttribute("type", nil)
                deBtn:SetAttribute("spell", nil)
                deBtn:SetAttribute("target-bag", nil)
                deBtn:SetAttribute("target-slot", nil)
            end
            return
        end
        bankOpen = event == "BANKFRAME_OPENED"
        if parent:IsVisible() then SUI:Refresh() end
    end)
end

-- Which items each button acts on, from the verdicts.
local function updateButtons(res)
    local me = VoidGear.Roster:Key()
    wipe(deHere); wipe(fromBank); wipe(toSend)
    local sendCount = {}
    for _, e in ipairs(res.de) do
        if e.who == me then
            if e.owner == me and not e.bank and e.bag then
                deHere[#deHere + 1] = e
            elseif e.owner == "warband" or (e.owner == me and e.bank) then
                fromBank[#fromBank + 1] = e
            end
        elseif e.owner == me and not e.bank and e.bag then
            toSend[#toSend + 1] = e
            sendCount[e.who] = (sendCount[e.who] or 0) + 1
        end
    end
    sendTo = nil
    for who, n in pairs(sendCount) do
        if not sendTo or n > sendCount[sendTo] then sendTo = who end
    end

    deActive = #deHere > 0
    -- name the piece the next click disenchants, so you see it before you click
    local _, _, nextLink = nextTarget()
    local nextName = nextLink and nextLink:match("%[(.-)%]")
    deBtn._text:SetText(nextName and ("Disenchant: %s  (%d)"):format(nextName, #deHere)
        or ("Disenchant next  (%d in bags)"):format(#deHere))
    syncDE()

    -- lay the shown buttons out left to right
    local prev = deActive and holder or nil
    local function place(btn)
        btn:ClearAllPoints()
        if prev then btn:SetPoint("LEFT", prev, "RIGHT", 6, 0) else btn:SetPoint("LEFT", holder, "LEFT") end
        btn:Show()
        prev = btn
    end
    if #fromBank > 0 then
        bankBtn._text:SetText(bankOpen and ("Take %d from the bank"):format(#fromBank)
            or ("%d in the bank: open it"):format(#fromBank))
        place(bankBtn)
    else
        bankBtn:Hide()
    end
    if #toSend > 0 then
        local who = VoidGear.Spares.ShortName(sendTo)
        sendBtn._text:SetText(bankOpen and ("Put %d in warband bank for %s"):format(#toSend, who)
            or ("%d for %s: open your bank"):format(#toSend, who))
        place(sendBtn)
    else
        sendBtn:Hide()
    end
end

local function where(owner, bank)
    if owner == "warband" then return "warband bank" end
    return VoidGear.Spares.ShortName(owner) .. (bank and " bank" or "")
end

function SUI:Build(parent)
    frame = parent
    local summary = parent:CreateFontString(nil, "OVERLAY")
    VoidUI:SetFont(summary, 11, "")
    summary:SetPoint("TOPLEFT", 6, -4)
    summary:SetPoint("RIGHT", -6, 0)
    summary:SetJustifyH("LEFT")
    summary:SetWordWrap(true)
    summary:SetTextColor(0.85, 0.85, 0.9)
    parent._summary = summary

    SUI:BuildButtons(parent)

    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -88)
    scroll:SetPoint("BOTTOMRIGHT", -22, 0)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    scroll:SetScript("OnSizeChanged", function(self) child:SetWidth(math.max(1, self:GetWidth())) end)
    C_Timer.After(0, function() child:SetWidth(math.max(1, scroll:GetWidth())) end)
    parent._scroll, parent._child, parent._rows = scroll, child, {}
end

local function row(child, rows, i)
    local r = rows[i]
    if not r then
        r = CreateFrame("Button", nil, child)
        r:SetHeight(ROW)
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(0, 0.78, 1, 0.12)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(ROW - 2, ROW - 2)
        r.icon:SetPoint("LEFT", 14, 0)
        r.fs = r:CreateFontString(nil, "OVERLAY")
        VoidUI:SetFont(r.fs, 10, "")
        r.fs:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
        r.fs:SetPoint("RIGHT", -6, 0)
        r.fs:SetJustifyH("LEFT")
        r.fs:SetWordWrap(false)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        -- right-click: never sell / disenchant / vendor this item (again: undo)
        r:SetScript("OnClick", function(self, button)
            if button ~= "RightButton" or not self.link then return end
            local id = C_Item.GetItemInfoInstant(self.link)
            local kept = VoidGear.Spares:ToggleKeep(id)
            VoidGear:Print((kept and "Kept: %s will never be disenchanted, sold or vendored by VoidGear."
                or "%s is judged normally again."):format(self.link))
            SUI:Refresh()
        end)
        r:SetScript("OnEnter", function(self)
            if not self.link then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.link)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Right-click: always keep it (never disenchant)", 0.6, 0.8, 1)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rows[i] = r
    end
    r:Show()
    return r
end

function SUI:Refresh()
    if not frame then return end
    local res = VoidGear.Spares:Judge()
    updateButtons(res)
    local child, rows = frame._child, frame._rows
    -- rows are about to show other items: a tooltip one of them owns would be stale
    local owner = GameTooltip:IsShown() and GameTooltip:GetOwner()
    for _, r in ipairs(rows) do if owner == r then GameTooltip:Hide() end end

    -- Summary: what disenchanting gives, who does it, what's missing.
    local lines = {}
    local mats, total = {}, 0
    for q = 2, 4 do
        local n = res.deMats[q]
        if n then
            mats[#mats + 1] = ("~%d %s"):format(n, QUALITY_MAT[q])
            local p = VoidAH_Price and VoidAH_Price(VoidGear.Spares.DE_MAT[q][1])
            if p then total = total + p * n end
        end
    end
    lines[#lines + 1] = ("%sDisenchant %d|r  ·  %sSell %d|r  ·  %sKeep %d|r  ·  %sCheck %d|r  ·  %sVendor %d|r"):format(
        CYAN, #res.de, GOLD, #res.sell, GREEN, #res.keep, RED, #res.check, DIM, #res.vendor)
    if #mats > 0 then
        lines[#lines + 1] = ("Disenchanting gives %s%s %s(one per piece is an estimate)|r"):format(table.concat(mats, ", "),
            total > 0 and ("  ≈ " .. GOLD .. VoidGear.Spares.Money(total) .. "|r") or "", DIM)
    end
    local unknown = {}
    for key in pairs(res.unknown) do unknown[#unknown + 1] = VoidGear.Spares.ShortName(key) end
    table.sort(unknown)
    if #unknown > 0 then
        lines[#lines + 1] = RED .. "Log in once on " .. table.concat(unknown, ", ")
            .. "|r so spare gear is checked against them too (until then nothing is kept for them)."
    end
    if #res.enchanters == 0 then
        lines[#lines + 1] = RED .. "No character with Enchanting is known yet: log in on your enchanters once.|r"
    end
    if not _G.VoidBagsDB then
        lines[#lines + 1] = DIM .. "Only this character's bags: with VoidBags, your other characters and the warband bank count too.|r"
    end
    frame._summary:SetText(table.concat(lines, "\n"))

    local i, y = 0, 0
    for _, sec in ipairs(SECTIONS) do
        local list = res[sec.key]
        if #list > 0 then
            table.sort(list, function(a, b)
                if (a.who or "") ~= (b.who or "") then return (a.who or "") < (b.who or "") end
                if (a.quality or 0) ~= (b.quality or 0) then return (a.quality or 0) > (b.quality or 0) end
                return (a.ilvl or 0) > (b.ilvl or 0)
            end)
            i = i + 1
            local h = row(child, rows, i)
            h:SetPoint("TOPLEFT", 0, y)
            h:SetPoint("RIGHT", child, "RIGHT", 0, 0)
            h.icon:SetTexture(nil)
            h.link = nil
            h.fs:SetText(("%s%s|r  %s%d|r"):format(sec.color, sec.title, DIM, #list))
            y = y - ROW
            for _, e in ipairs(list) do
                i = i + 1
                local r = row(child, rows, i)
                r:SetPoint("TOPLEFT", 0, y)
                r:SetPoint("RIGHT", child, "RIGHT", 0, 0)
                r.icon:SetTexture(C_Item.GetItemIconByID(e.link) or 134400)
                r.link = e.link
                r.fs:SetText(("%s %s%s|r  %s[%s]|r  %s"):format(e.link, DIM, e.ilvl and e.ilvl > 0 and tostring(e.ilvl) or "",
                    DIM, where(e.owner, e.bank), e.why or ""))
                y = y - ROW
            end
            y = y - 6
        end
    end
    if i == 0 then
        i = 1
        local r = row(child, rows, 1)
        r:SetPoint("TOPLEFT", 0, 0)
        r:SetPoint("RIGHT", child, "RIGHT", 0, 0)
        r.icon:SetTexture(nil)
        r.link = nil
        r.fs:SetText(DIM .. "No spare gear found.|r")
        y = -ROW
    end
    for j = i + 1, #rows do rows[j]:Hide() end
    child:SetHeight(math.max(1, -y))
    return res.pending
end
