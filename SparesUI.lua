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
    { key = "check",  title = "Check after logging in", color = RED },
    { key = "vendor", title = "Vendor",      color = DIM },
    { key = "wait",   title = "Still loading", color = DIM },
}
local QUALITY_MAT = { [2] = "Eversinging Dust", [3] = "Radiant Shard", [4] = "Dawn Crystal" }

local frame

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

    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -60)
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
        r:SetScript("OnEnter", function(self)
            if not self.link then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.link)
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
