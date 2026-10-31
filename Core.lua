-- 12.1.5 (and WoW Forever) removed the old global item functions; use C_Item's.
local GetDetailedItemLevelInfo = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
-- VoidSpy hook: enable with /vspy enable VoidGear  (no-op if VoidSpy missing/disabled)
local function dbg(fmt, ...) if VoidSpy and VoidSpy.Log then VoidSpy:Log("VoidGear", fmt, ...) end end

----------------------------------------------------------------------
-- VoidGear Core — slash command, init.
----------------------------------------------------------------------

VoidGear = VoidGear or {}
VoidGear.version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("VoidGear", "Version")) or "?"

----------------------------------------------------------------------
-- Slash command: /vgear
----------------------------------------------------------------------
SLASH_VOIDGEAR1 = "/vgear"
SLASH_VOIDGEAR2 = "/voidgear"
SlashCmdList["VOIDGEAR"] = function(msg)
    dbg("slash: %s", tostring(msg))
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

    if (msg == "" or msg == "show" or msg == "toggle") and VoidGear.IS_FOREVER then
        -- The planner is raid/M+ loot for retail -- nothing for Forever.
        local preset = VoidGear.StatWeights:GetCurrent()
        VoidGear:Print("WoW Forever: VoidGear scores your drops for VoidBags' upgrade arrows using "
            .. (preset and preset.label or "class") .. " weights. |cffffd200/vgear weights|r shows them.")
    elseif msg == "" or msg == "show" or msg == "toggle" then
        if VoidGear.UI and VoidGear.UI.Toggle then VoidGear.UI:Toggle() end
    elseif msg == "upgrades" or msg == "up" then
        VoidGear.UpgradeAdvisor:Report()
    elseif msg == "catalyst" or msg == "cat" then
        VoidGear.UpgradeAdvisor:CatalystReport()
    elseif msg == "upgrades scan" then
        local n = VoidGear.UpgradeAdvisor:ScanAtNPC()
        VoidGear:Print(n and ("Read upgrade costs for %d items."):format(n)
            or "Open the item upgrade NPC first.")
    elseif msg == "upgrades off" or msg == "upgrades on" then
        local on = msg == "upgrades on"
        VoidGear.UpgradeAdvisor:SetEnabled(on)
        VoidGear:Print("Upgrade badges on the Character tab: " .. (on and "on" or "off"))
    elseif msg == "scan" or msg == "rescan" then
        VoidGear:Print("Reading this season's raid + M+ loot from the Adventure Guide...")
        VoidGear.LootDB:Scan(function()
            if VoidGear.UI and VoidGear.UI.Refresh then VoidGear.UI:Refresh() end
        end)
    elseif msg == "debug" or msg == "diag" or msg == "diagnose" then
        local cache = VoidGearDB and VoidGearDB.lootCache
        if not cache then
            VoidGear:Print("No scan data — run /vgear scan first")
            return
        end
        VoidGear:Print(string.format("Cache: %d raid, %d M+, %d world boss items, scanned %s",
            #(cache.raid or {}), #(cache.mplus or {}), #(cache.worldBoss or {}),
            cache.scannedAt and date("%Y-%m-%d %H:%M", cache.scannedAt) or "?"))
        DEFAULT_CHAT_FRAME:AddMessage("|cff00c7ffInstances in cache:|r")
        local sorted = {}
        for id, info in pairs(cache.instances or {}) do
            table.insert(sorted, { id = id, name = info.name, type = info.type, count = info.count })
        end
        table.sort(sorted, function(a, b)
            if a.type ~= b.type then return a.type < b.type end
            return (a.name or "") < (b.name or "")
        end)
        for _, inst in ipairs(sorted) do
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  [%s] %-30s %d items",
                inst.type or "?", inst.name or "?", inst.count or 0))
        end
        -- Also show how many items have missing slot info per bucket
        local function countMissingSlot(bucket, label)
            local miss, total = 0, 0
            for _, item in ipairs(bucket or {}) do
                total = total + 1
                if not item.slot then miss = miss + 1 end
            end
            if total > 0 then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  %s: %d/%d items have no slot mapping (those get filtered out)",
                    label, miss, total))
            end
        end
        countMissingSlot(cache.raid, "Raid")
        countMissingSlot(cache.mplus, "M+")
        countMissingSlot(cache.worldBoss, "WorldBoss")
    elseif msg == "budget" then
        if VoidGear.Scorer then
            local b = VoidGear.Scorer:RecalcTrinketBudget()
            VoidGear:Print(string.format("Trinket budget per ilvl: |cffffd200%.3f|r", b))
            DEFAULT_CHAT_FRAME:AddMessage(string.format(
                "  (a trinket at ilvl 280 should score ~%d if it had no proc; anything missing is attributed to proc)",
                math.floor(b * 280)))
            -- Show equipped trinket scoring
            for _, slotID in ipairs({ 13, 14 }) do
                local link = GetInventoryItemLink("player", slotID)
                if link then
                    local weights, primary = VoidGear.Scorer:GetActiveContext()
                    local static = VoidGear.Scorer:CalcStaticScore(link, weights, primary)
                    local proc = VoidGear.Scorer:CalcProcValue(link, weights, primary)
                    local name = link:match("%[(.-)%]") or "?"
                    DEFAULT_CHAT_FRAME:AddMessage(string.format(
                        "  Slot %d: %s -- static=%d, proc=%d, total=%d %s",
                        slotID, name, math.floor(static), math.floor(proc), math.floor(static + proc),
                        VoidGear.Scorer:HasProc(link) and "|cff00ff00[has proc]|r" or "|cff888888[stat-stick]|r"))
                end
            end
        end
    elseif msg == "effects" or msg:sub(1, 8) == "effects " then
        -- Tier-2 diagnostic: CAPTURE the readable effect data (use/equip spell,
        -- description, cooldown, sockets, set bonuses) for equipped gear into
        -- SavedVariables (VoidGearDB.effectDump) so it can be read off disk after
        -- a /reload -- no chat to screenshot. Optional: /vgear effects <link>.
        VoidGearDB = VoidGearDB or {}
        local specIdx = GetSpecialization and GetSpecialization() or 0
        local specID = (specIdx and specIdx > 0) and GetSpecializationInfo(specIdx) or 0
        local dump = { specID = specID, items = {} }
        local argID = tonumber(msg:match("item:(%d+)"))
        -- Active scoring context, so we can also record what the EffectValuer
        -- decided per item (its class + value) for verification off disk.
        local evWeights, evPrimary
        if VoidGear.Scorer and VoidGear.Scorer.GetActiveContext then
            evWeights, evPrimary = VoidGear.Scorer:GetActiveContext()
        end
        local evBudget = (VoidGear.Scorer and VoidGear.Scorer.trinketBudgetPerIlvl) or 0
        dump.weightsLabel = evWeights and (VoidGear.StatWeights:GetCurrent().label) or nil

        local function collect(ref, tag)
            if not ref then return end
            local itemID = C_Item.GetItemInfoInstant(ref)
            if not itemID then return end
            local entry = {
                tag    = tag,
                itemID = itemID,
                name   = (type(ref) == "string" and ref:match("%[(.-)%]")) or ("id:" .. tostring(itemID)),
                ilvl   = GetDetailedItemLevelInfo(ref) or 0,
            }
            local spellName, spellID = C_Item.GetItemSpell(ref)
            if spellID then
                entry.effectSpellID = spellID
                entry.effectName    = spellName
                entry.effectDesc    = (C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(spellID)) or ""
                local cd = C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(spellID)
                if type(cd) == "table" then entry.effectCooldown = cd.duration end
            end
            -- Tooltip lines: GetItemSpell misses passive "Equip:" procs, so grab
            -- the rendered tooltip text (numbers already scaled to this item).
            local tt
            if type(ref) == "string" then
                tt = C_TooltipInfo.GetHyperlink and C_TooltipInfo.GetHyperlink(ref)
            else
                tt = C_TooltipInfo.GetItemByID and C_TooltipInfo.GetItemByID(ref)
            end
            if tt and tt.lines then
                entry.tooltip = {}
                for _, line in ipairs(tt.lines) do
                    if TooltipUtil and TooltipUtil.SurfaceArgs then TooltipUtil.SurfaceArgs(line) end
                    local lt = line.leftText
                    if lt and lt ~= "" then entry.tooltip[#entry.tooltip + 1] = lt end
                end
            end
            entry.sockets = (C_Item.GetItemNumSockets and C_Item.GetItemNumSockets(ref)) or 0
            if specID > 0 and C_Item.GetSetBonusesForSpecializationByItemID then
                local ok, spellIDs = pcall(C_Item.GetSetBonusesForSpecializationByItemID, specID, itemID)
                if ok and type(spellIDs) == "table" and #spellIDs > 0 then
                    entry.setBonuses = {}
                    for _, sid in ipairs(spellIDs) do
                        entry.setBonuses[#entry.setBonuses + 1] = {
                            spellID = sid,
                            desc    = (C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(sid)) or "",
                        }
                    end
                end
            end
            -- What did the EffectValuer decide for this item? (verification)
            if VoidGear.EffectValuer and evWeights then
                local extra, det = VoidGear.EffectValuer:ValueExtras(
                    ref, evWeights, evPrimary, evBudget, { noCache = true })
                entry.valuer = {
                    total       = extra,
                    empty       = det and det.empty,
                    socketValue = det and det.socketValue,
                    setValue    = det and det.setValue,
                    effectSource = det and det.effectSource,
                    tier        = det and det.tier,
                }
                if det and det.effects then
                    entry.valuer.effects = {}
                    for _, e in ipairs(det.effects) do
                        entry.valuer.effects[#entry.valuer.effects + 1] = {
                            class = e.class, value = e.value, estimate = e.estimate,
                            stat = e.stat, statVal = e.statVal, dmg = e.dmg, dur = e.dur,
                        }
                    end
                end
            end
            dump.items[#dump.items + 1] = entry
        end

        if argID then
            collect(argID, "arg")
        else
            collect(GetInventoryItemLink("player", 13), "Trinket1")
            collect(GetInventoryItemLink("player", 14), "Trinket2")
            for _, s in ipairs({ 1, 3, 5, 7, 10, 15, 2, 11, 12 }) do
                collect(GetInventoryItemLink("player", s), "Slot" .. s)
            end
        end

        VoidGearDB.effectDump = dump
        VoidGear:Print(string.format(
            "Captured %d items to SavedVariables. Now |cffffd200/reload|r, then tell Claude.", #dump.items))
    elseif msg == "weights" or msg == "stats" then
        local cur = VoidGear.StatWeights:GetCurrent()
        VoidGear:Print("Active stat preset: |cffffd200" .. (cur.label or "?") .. "|r")
        if cur.note then DEFAULT_CHAT_FRAME:AddMessage("  " .. cur.note) end
        DEFAULT_CHAT_FRAME:AddMessage("  Weights:")
        local ranked = {}
        for k, v in pairs(cur.weights or {}) do table.insert(ranked, { k = k, v = v }) end
        table.sort(ranked, function(a, b) return a.v > b.v end)
        for _, r in ipairs(ranked) do
            DEFAULT_CHAT_FRAME:AddMessage(string.format("    %-12s %.2f", r.k, r.v))
        end
        if not VoidGear.IS_FOREVER then
            DEFAULT_CHAT_FRAME:AddMessage("  To change: open panel (/vgear) and use the Stat Priority dropdown")
        end
    elseif msg == "tab prep" or msg == "prep" then
        if VoidGear.UI then
            if not (_G.VoidGear_Panel and _G.VoidGear_Panel:IsShown()) then VoidGear.UI:Toggle() end
            VoidGear.UI:SwitchTab("prep")
        end
    elseif msg == "tab top" or msg == "top" then
        if VoidGear.UI then
            if not (_G.VoidGear_Panel and _G.VoidGear_Panel:IsShown()) then VoidGear.UI:Toggle() end
            VoidGear.UI:SwitchTab("top")
        end
    elseif msg == "tab vault" or msg == "vault" then
        if VoidGear.UI then
            if not (_G.VoidGear_Panel and _G.VoidGear_Panel:IsShown()) then VoidGear.UI:Toggle() end
            VoidGear.UI:SwitchTab("vault")
        end
    elseif msg == "tab raid" then
        if VoidGear.UI then
            if not (_G.VoidGear_Panel and _G.VoidGear_Panel:IsShown()) then VoidGear.UI:Toggle() end
            VoidGear.UI:SwitchTab("raid")
        end
    elseif msg == "tab mplus" or msg == "tab m+" then
        if VoidGear.UI then
            if not (_G.VoidGear_Panel and _G.VoidGear_Panel:IsShown()) then VoidGear.UI:Toggle() end
            VoidGear.UI:SwitchTab("mplus")
        end
    elseif msg == "tab world" then
        if VoidGear.UI then
            if not (_G.VoidGear_Panel and _G.VoidGear_Panel:IsShown()) then VoidGear.UI:Toggle() end
            VoidGear.UI:SwitchTab("world")
        end
    else
        VoidGear:Print("Commands:")
        VoidGear:Print("  |cffffd200/vgear|r - toggle panel")
        VoidGear:Print("  |cffffd200/vgear upgrades|r - which equipped item to spend crests on (|cffffd200on|r/|cffffd200off|r = Character-tab badges)")
        VoidGear:Print("  |cffffd200/vgear scan|r - scan EJ for raid + M+ loot")
        VoidGear:Print("  |cffffd200/vgear weights|r - show active stat priority")
        VoidGear:Print("  |cffffd200/vgear effects|r - dump trinket/set/socket effect data (Tier-2)")
        VoidGear:Print("  |cffffd200/vgear tab top|prep|vault|raid|mplus|world|r - switch tab")
    end
end

----------------------------------------------------------------------
-- Init at PLAYER_LOGIN
----------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    VoidGearDB = VoidGearDB or {}
    VoidGearCharDB = VoidGearCharDB or {}
    -- Imported loadouts are gone (2026-10-30; the Top tab reads TopGearData); drop what they saved.
    VoidGearDB.userLoadouts = nil
    VoidGearCharDB.activeLoadout = nil

    -- Initialize scorer (calibrates the trinket budget once your gear has loaded,
    -- and again on gear / spec changes)
    if VoidGear.Scorer and VoidGear.Scorer.Init then
        VoidGear.Scorer:Init()
    end

    VoidGear:Print("Loaded v" .. VoidGear.version .. " - type |cffffd200/vgear|r to open.")
end)
