----------------------------------------------------------------------
-- VoidGear Roster -- your characters, so spare gear can be judged against
-- all of them (Spares.lua), not just the one you're on.
--
-- Each character saves itself when you log in and when its gear or spec
-- changes: class, level, its spec's stat weights and primary stat, what it
-- wears (one link per slot), whether it can dual wield and whether it has
-- Enchanting. VoidGearDB.roster["Name-Realm"]. A character you haven't
-- logged into since installing this isn't known yet; Spares says so.
----------------------------------------------------------------------
VoidGear = VoidGear or {}
local R = {}
VoidGear.Roster = R

local ENCHANTING = 333

function R:Key(name, realm)
    name = name or UnitName("player")
    realm = realm or (GetNormalizedRealmName and GetNormalizedRealmName())
    if not (name and realm and realm ~= "") then return nil end
    return name .. "-" .. realm:gsub("[%s%-']", "")
end

function R:All()
    VoidGearDB = VoidGearDB or {}
    VoidGearDB.roster = VoidGearDB.roster or {}
    return VoidGearDB.roster
end

local function hasEnchanting()
    if not (GetProfessions and GetProfessionInfo) then return false end
    local raw = { GetProfessions() }
    for i = 1, 2 do   -- the two primary professions
        local idx = raw[i]
        if idx and select(7, GetProfessionInfo(idx)) == ENCHANTING then return true end
    end
    return false
end

function R:SaveMe()
    local key = self:Key()
    if not key or VoidGear.IS_FOREVER then return end
    local weights, primary, preset = VoidGear.Scorer:GetActiveContext()
    local gear = {}
    for _, slotID in ipairs(VoidGear.PLAN_SLOTS) do
        gear[slotID] = GetInventoryItemLink("player", slotID)
    end
    local specIndex = GetSpecialization and GetSpecialization()
    self:All()[key] = {
        class = select(2, UnitClass("player")),
        level = UnitLevel("player"),
        spec = specIndex and select(2, GetSpecializationInfo(specIndex)) or nil,
        specID = specIndex and GetSpecializationInfo(specIndex) or nil,
        titansGrip = ((C_SpellBook and C_SpellBook.IsSpellKnown) or IsPlayerSpell)(46917) or false,   -- Fury: two two-handers
        label = preset and preset.label,
        weights = weights,
        primary = primary,
        gear = gear,
        dualWield = CanDualWield and CanDualWield() or false,
        enchanter = hasEnchanting(),
        t = time(),
    }
end

function R:Init()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    f:RegisterEvent("SKILL_LINES_CHANGED")
    f:RegisterEvent("PLAYER_LEVEL_UP")   -- the level decides what it can wear
    local queued
    local function save()
        queued = nil
        R:SaveMe()
        -- an open Spares tab was judged without this save: judge again
        if _G.VoidGear_Panel and _G.VoidGear_Panel:IsShown() and VoidGear.UI then VoidGear.UI:Refresh() end
    end
    f:SetScript("OnEvent", function()
        if queued then return end
        queued = true
        C_Timer.After(2, save)
    end)
    C_Timer.After(5, save)   -- gear and professions are loaded by then
end
