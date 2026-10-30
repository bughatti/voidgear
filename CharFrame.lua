----------------------------------------------------------------------
-- VoidGear Character Frame tab — a "Gear Plan" tab after the Character /
-- Reputation / Currency tabs. Clicking it opens the VoidGear panel, same as
-- the minimap icon or /vgear.
--
-- It looks like the tabs beside it, but it isn't one of them: it opens our own
-- window and never joins CharacterFrame.Tabs (PanelTabButtonTemplate's
-- parentArray="Tabs" lands on our holder frame instead), so Blizzard's tab
-- code never touches it.
--   Plain sheet:  Blizzard's tab art with the text "Gear Plan".
--   Chonky Character Sheet: Chonky turns those tabs into 48px round icons, so
--                 ours is a round icon too, wearing the same frame as the tab
--                 beside it (read from that tab at runtime; no files copied).
----------------------------------------------------------------------

VoidGear = VoidGear or {}

local ICON = "Interface\\Icons\\INV_Helmet_08"   -- same as the minimap button
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local function Tooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("|cff00c7ffGear Plan|r")
    GameTooltip:AddLine("Open VoidGear: upgrades from raid, M+ and the vault, and where your crests should go.", 1, 1, 1, true)
    local _, l = VoidGear:GetActiveLoadout()
    if l then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Active: " .. (l.displayName or "?"), 1, 0.82, 0)
    end
    GameTooltip:Show()
end

local function Open()
    if VoidGear.UI and VoidGear.UI.Toggle then VoidGear.UI:Toggle() end
end

-- Blizzard's tab look.
local function MakeTextTab(holder)
    local tab = CreateFrame("Button", "VoidGear_CharFrameBtn", holder, "PanelTabButtonTemplate")
    tab:SetText("Gear Plan")
    PanelTemplates_TabResize(tab, 0)
    PanelTemplates_DeselectTab(tab)
    tab:HookScript("OnEnter", Tooltip)
    tab:HookScript("OnLeave", function() GameTooltip:Hide() end)
    tab:SetScript("OnClick", Open)
    return tab
end

-- Round icon tab, sized like Chonky's. Its frame copies the one on the tab beside
-- it (whatever frame style and color the player picked in Chonky), so all four
-- match; a plain dark frame when that isn't there yet.
local function MakeIconTab(holder)
    local tab = CreateFrame("Button", "VoidGear_CharFrameBtn", holder)
    tab:SetSize(48, 48)

    local mask = tab:CreateMaskTexture()
    mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetSize(42, 42)
    mask:SetPoint("CENTER")
    local function Round(layer, sub)
        local x = tab:CreateTexture(nil, layer, nil, sub)
        x:SetSize(42, 42)
        x:SetPoint("CENTER")
        x:AddMaskTexture(mask)
        return x
    end

    tab.bg = tab:CreateTexture(nil, "BACKGROUND", nil, -8)   -- copy of the neighbor's frame
    tab.bg:SetAllPoints()
    tab.plain = Round("BACKGROUND", -7)                  -- fallback disc
    tab.plain:SetColorTexture(0.10, 0.10, 0.12, 1)

    tab.icon = Round("ARTWORK")
    tab.icon:SetTexture(ICON)

    -- Hover: a soft white glow over the icon (no color of our own).
    tab.glow = Round("OVERLAY")
    tab.glow:SetColorTexture(1, 1, 1, 0.15)
    tab.glow:Hide()

    function tab:MatchNeighbor()
        local ref = _G.CharacterFrameTab2 and CharacterFrameTab2.CCS_BG
        local tex = ref and ref:GetTexture()
        if tex then
            self.bg:SetTexture(tex)
            self.bg:SetTexCoord(ref:GetTexCoord())
            self.bg:SetVertexColor(ref:GetVertexColor())
            self.bg:Show()
            self.plain:Hide()
        else
            self.bg:Hide()
            self.plain:Show()
        end
    end
    tab:MatchNeighbor()

    tab:SetScript("OnEnter", function(self)
        self.glow:Show()
        Tooltip(self)
    end)
    tab:SetScript("OnLeave", function(self)
        self.glow:Hide()
        GameTooltip:Hide()
    end)
    tab:SetScript("OnClick", Open)
    return tab
end

-- Sit right after the last tab that's showing (Currency hides on characters
-- with no currencies yet).
local function Place(tab)
    local last = _G.CharacterFrameTab1
    for i = 2, 3 do
        local t = _G["CharacterFrameTab" .. i]
        if t and t:IsShown() then last = t end
    end
    if not last then return end
    tab:ClearAllPoints()
    tab:SetPoint("TOPLEFT", last, "TOPRIGHT", 1, 0)
end

local function CreateCharFrameTab()
    if not _G.CharacterFrame then return end
    if _G.VoidGear_CharFrameBtn then return end  -- already created
    if VoidGear.IS_FOREVER then return end        -- planner is retail-only

    local holder = CreateFrame("Frame", nil, CharacterFrame)
    holder:SetSize(1, 1)
    holder:SetPoint("TOPLEFT")
    local chonky = C_AddOns and C_AddOns.IsAddOnLoaded("ChonkyCharacterSheet")
    local tab = chonky and MakeIconTab(holder) or MakeTextTab(holder)

    Place(tab)
    CharacterFrame:HookScript("OnShow", function()
        if tab.MatchNeighbor then tab:MatchNeighbor() end   -- Chonky may restyle after login
        Place(tab)
    end)
    if _G.CharacterFrameTab3 then
        CharacterFrameTab3:HookScript("OnShow", function() Place(tab) end)
        CharacterFrameTab3:HookScript("OnHide", function() Place(tab) end)
    end
end

-- Hook character frame show — character frame is loaded via Blizzard_PaperDoll
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    if _G.CharacterFrame then
        CreateCharFrameTab()
    else
        -- Defer until character frame is created (rare timing on first login)
        local poll = CreateFrame("Frame")
        local elapsed = 0
        poll:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            if _G.CharacterFrame then
                CreateCharFrameTab()
                self:SetScript("OnUpdate", nil)
            elseif elapsed > 5 then
                self:SetScript("OnUpdate", nil)
            end
        end)
    end
end)
