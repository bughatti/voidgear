----------------------------------------------------------------------
-- VoidGear Compat — VoidUI namespace shim for palette/font/backdrop.
-- Same pattern as VoidProf/VoidLFG/etc. so styling is consistent.
----------------------------------------------------------------------

VoidGear = VoidGear or {}
VoidUI = VoidUI or {}

-- WoW Forever (Classic+ on the modern client, TOC 16001): classic stats
-- (Str/Agi/Sta/Int/Spirit, spell power, weapon DPS, armor), no specs, no
-- upgrade tracks, no raid/M+ planner content.
VoidGear.IS_FOREVER = (select(4, GetBuildInfo()) or 0) < 100000

if not VoidUI.palette then
    VoidUI.palette = {
        accent     = { 0x00 / 255, 0xC7 / 255, 0xFF / 255 },
        accentHex  = "00c7ff",
        text       = { 0xEB / 255, 0xEB / 255, 0xF2 / 255 },
        textDim    = { 0x8C / 255, 0x8C / 255, 0x9E / 255 },
        bg         = { 0.05, 0.05, 0.07, 0.95 },
        border     = { 0x00 / 255, 0xC7 / 255, 0xFF / 255, 0.7 },
    }
end
if not VoidUI.media then
    VoidUI.media = {
        font    = "Fonts\\FRIZQT__.TTF",
        texture = "Interface\\Buttons\\WHITE8X8",
    }
end
if not VoidUI.SetFont then
    function VoidUI:SetFont(fontString, size, flags)
        fontString:SetFont(self.media.font, size or 11, flags or "")
    end
end
if not VoidUI.CreateBackdrop then
    function VoidUI:CreateBackdrop(frame, r, g, b, a, br, bg, bb, ba)
        if not frame.SetBackdrop then
            Mixin(frame, BackdropTemplateMixin)
            frame:HookScript("OnSizeChanged", frame.OnBackdropSizeChanged)
        end
        frame:SetBackdrop({
            bgFile   = self.media.texture,
            edgeFile = self.media.texture,
            edgeSize = 1,
        })
        frame:SetBackdropColor(r or 0.05, g or 0.05, b or 0.07, a or 0.95)
        frame:SetBackdropBorderColor(br or 0, bg or 0.78, bb or 1, ba or 0.7)
    end
end

function VoidGear:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00c7ff[VoidGear]|r " .. tostring(msg))
end
function VoidGear:Warn(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00c7ff[VoidGear]|r |cffff5050" .. tostring(msg) .. "|r")
end

----------------------------------------------------------------------
-- Show item tooltip SCALED to the target ilvl (not base item).
-- SetItemByID() shows the BASE item (ilvl 44 for a base raid template etc).
-- Use SetItemKey(itemID, itemLevel, itemSuffix) to get scaled stats —
-- this is what Blizzard's AH UI uses internally.
--
-- For a stored loadout slot with bonus IDs (Mythic track etc), if a full
-- itemLink is available, SetHyperlink with that link is most accurate.
-- Otherwise SetItemKey with (id, ilvl) is the next best.
----------------------------------------------------------------------
function VoidGear:ShowItemTooltip(owner, itemID, ilvl, link)
    if not owner or not itemID then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    -- 1. Full link is most accurate (encodes bonus IDs, gems, enchants); a bare
    --    "item:..." string (vault-level items, LootDB:AtVaultLevel) works too
    if link and type(link) == "string" and link:find("item:%d") then
        GameTooltip:SetHyperlink(link)
    -- 2. SetItemKey scales to the requested ilvl
    elseif GameTooltip.SetItemKey and ilvl and ilvl > 0 then
        GameTooltip:SetItemKey(itemID, ilvl, 0)
    -- 3. Last resort — base item
    else
        GameTooltip:SetItemByID(itemID)
    end
    GameTooltip:Show()
end

-- Standard slot indexes mapped to readable names
VoidGear.SLOTS = {
    [1]  = "Head",
    [2]  = "Neck",
    [3]  = "Shoulders",
    [4]  = "Shirt",
    [5]  = "Chest",
    [6]  = "Belt",
    [7]  = "Legs",
    [8]  = "Boots",
    [9]  = "Wrists",
    [10] = "Gloves",
    [11] = "Ring 1",
    [12] = "Ring 2",
    [13] = "Trinket 1",
    [14] = "Trinket 2",
    [15] = "Cloak",
    [16] = "Main Hand",
    [17] = "Off Hand",
    [18] = "Tabard",
}
-- Slots we care about for planning (skip Shirt and Tabard)
VoidGear.PLAN_SLOTS = {
    1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17,
}
