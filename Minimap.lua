----------------------------------------------------------------------
-- VoidGear Minimap Icon — matches the standardized Void* spec
-- (see ~/.claude/projects/.../void-addons-architecture.md).
----------------------------------------------------------------------

VoidGear = VoidGear or {}

local minimapBtn

local function PositionButton(btn)
    VoidGearCharDB = VoidGearCharDB or {}
    local angle = math.rad(VoidGearCharDB.minimapAngle or 165)
    local radius = (Minimap:GetWidth() / 2) + 6
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", radius * math.cos(angle), radius * math.sin(angle))
end

local function CreateMinimapButton()
    if minimapBtn then return minimapBtn end
    if not Minimap then return nil end

    local btn = CreateFrame("Button", "VoidGearMinimapBtn", Minimap)
    btn:SetSize(28, 28)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 10)

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\INV_Helmet_08")  -- plain plate helm (67 is the Winter Veil hat)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", -2, 2)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(_, button)
        if button == "RightButton" and not VoidGear.IS_FOREVER then
            -- Right-click cycles through bundled loadouts (retail top players; none on WoW Forever)
            local keys = {}
            for k in pairs(VoidGear:GetAllLoadouts()) do keys[#keys + 1] = k end
            table.sort(keys)
            local active, _ = VoidGear:GetActiveLoadout()
            local nextIdx = 1
            for i, k in ipairs(keys) do
                if k == active then nextIdx = (i % #keys) + 1; break end
            end
            if keys[nextIdx] then
                VoidGear:SetActiveLoadout(keys[nextIdx])
                VoidGear:Print("Switched to loadout: " .. keys[nextIdx])
            end
        else
            if VoidGear.UI and VoidGear.UI.Toggle then VoidGear.UI:Toggle() end
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("|cff00c7ffVoidGear|r")
        if VoidGear.IS_FOREVER then
            GameTooltip:AddLine("Click: your gear and the dungeon / quest upgrades for your level", 1, 1, 1, true)
            GameTooltip:AddLine("Drag: reposition", 0.7, 0.7, 0.7)
            GameTooltip:Show()
            return
        end
        GameTooltip:AddLine("Left-click: open gear planner", 1, 1, 1)
        GameTooltip:AddLine("Right-click: cycle loadout", 1, 1, 1)
        GameTooltip:AddLine("Drag: reposition", 0.7, 0.7, 0.7)
        local active, l = VoidGear:GetActiveLoadout()
        if l then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Active: " .. (l.displayName or active), 1, 0.82, 0)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:SetMovable(true)
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self) self._dragging = true end)
    btn:SetScript("OnDragStop",  function(self) self._dragging = false end)
    btn:SetScript("OnUpdate", function(self)
        if self._dragging then
            local mx, my = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            local px, py = GetCursorPosition()
            px = px / scale; py = py / scale
            VoidGearCharDB = VoidGearCharDB or {}
            VoidGearCharDB.minimapAngle = math.deg(math.atan2(py - my, px - mx))
            PositionButton(self)
        end
    end)

    PositionButton(btn)
    minimapBtn = btn
    return btn
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function() CreateMinimapButton() end)
