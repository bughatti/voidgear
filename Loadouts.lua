----------------------------------------------------------------------
-- VoidGear Top loadouts — "what the top Mythic+ players of a spec wear".
--
-- One loadout per spec, built from TopGearData.lua (generated from Blizzard's
-- own API by voidscout-data/tools/cmd/stat-pull: leaderboards -> each top
-- player's equipment, counts only). The Top tab compares it to your gear.
-- It follows your current spec unless you pick another one in the dropdown.
--
-- Loadout shape (what the Top tab reads):
--   displayName ("Top Subtlety Rogue"), spec, statProfile, ilvl, source
--   gear[slotID] = { id, ilvl, name, share }   share = fraction of players wearing it
----------------------------------------------------------------------

VoidGear = VoidGear or {}

-- Blizzard's equipment slot -> inventory slot(s). Rings and trinkets come
-- pooled: the two most-worn fill the two slots.
local POOL_SLOTS = {
    HEAD = { 1 }, NECK = { 2 }, SHOULDER = { 3 }, BACK = { 15 }, CHEST = { 5 }, WRIST = { 9 },
    HANDS = { 10 }, WAIST = { 6 }, LEGS = { 7 }, FEET = { 8 }, FINGER = { 11, 12 },
    TRINKET = { 13, 14 }, MAIN_HAND = { 16 }, OFF_HAND = { 17 },
}

local built = {}

local function StatProfile(key)
    local p = VoidGear.StatWeights and VoidGear.StatWeights.presets and VoidGear.StatWeights.presets[key]
    if not (p and p.weights) then return "?" end
    local order = {}
    for stat, w in pairs(p.weights) do order[#order + 1] = { stat, w } end
    table.sort(order, function(a, b) return a[2] > b[2] end)
    for i, o in ipairs(order) do order[i] = o[1] end
    return table.concat(order, " > ")
end

local function Build(d)
    local gear, sum, n = {}, 0, 0
    -- Weapons as one setup: if most top players use an off hand, the main hand
    -- comes from those players (MAIN_HAND); otherwise from the players without
    -- one (MAIN_HAND_SOLO, two-handers) and no off hand is suggested.
    local dual = (d.offHand or 0) * 2 >= (d.players or 0)
    for pool, slots in pairs(POOL_SLOTS) do
        local list = d.slots and d.slots[pool]
        if pool == "MAIN_HAND" and not dual then list = d.slots and d.slots.MAIN_HAND_SOLO end
        local skip = pool == "OFF_HAND" and not dual
        if list and not skip then
            for i, slotID in ipairs(slots) do
                local e = list[i]
                if e then
                    gear[slotID] = { id = e.id, ilvl = e.ilvl, name = e.name, share = e.n / d.players }
                    sum, n = sum + e.ilvl, n + 1
                end
            end
        end
    end
    return {
        displayName = "Top " .. d.label,
        spec        = d.label,
        statProfile = StatProfile(d.key),
        ilvl        = n > 0 and math.floor(sum / n + 0.5) or nil,
        source      = ("%d top M+ players (Blizzard API, %s)"):format(d.players or 0,
            VoidGear.TopGearData.generated or "?"),
        gear        = gear,
        data        = d,
    }
end

-- All top loadouts, keyed by preset key ("ROGUE_SUBTLETY").
function VoidGear:GetAllLoadouts()
    local data = VoidGear.TopGearData
    if not (data and data.specs) then return {} end
    if not next(built) then
        for _, d in pairs(data.specs) do built[d.key] = Build(d) end
    end
    return built
end

function VoidGear:GetLoadout(key)
    return key and self:GetAllLoadouts()[key] or nil
end

-- The player's own spec, as a loadout key (looked up by spec ID, not its name).
function VoidGear:CurrentSpecKey()
    local idx = GetSpecialization and GetSpecialization()
    local specID = idx and idx > 0 and GetSpecializationInfo(idx)
    local d = specID and VoidGear.TopGearData and VoidGear.TopGearData.specs[specID]
    return d and d.key or nil
end

-- Picked spec, else your current one. Picking your own spec goes back to following it.
function VoidGear:GetActiveLoadout()
    local key = (VoidGearCharDB and VoidGearCharDB.topSpec) or self:CurrentSpecKey()
    return key, self:GetLoadout(key)
end

function VoidGear:SetActiveLoadout(key)
    VoidGearCharDB = VoidGearCharDB or {}
    VoidGearCharDB.topSpec = (key ~= self:CurrentSpecKey()) and key or nil
    if VoidGear.UI and VoidGear.UI.Refresh then VoidGear.UI:Refresh() end
end
