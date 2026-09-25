-- ============================================================================
-- PartyBotUI: Comprehensive Management Addon for vMaNGOS Vanilla 1.12.1 Bots
-- Author: Adam & Antigravity
-- ============================================================================

PartyBotUIDB = PartyBotUIDB or {}


local PartyBotUI_ActiveBots = {}
local PartyBotUI_BotEquip = {}
local PartyBotUI_BotBags = {}
local PartyBotUI_BotMoney = {}
local PartyBotUI_PendingGivebacks = {}
local PartyBotUI_SelectedBot = 1
local PartyBotUI_CurrentTab = 1
local PartyBotUI_AOEState = false
local PartyBotUI_PendingInspect = nil
local PartyBotUI_SelectedBagFilter = -1

-- Standard 1.12.1 Equipment Slot IDs and Names
local PB_SLOT_NAMES = {
    [1] = "Head", [2] = "Neck", [3] = "Shoulders", [4] = "Shirt",
    [5] = "Chest", [6] = "Waist", [7] = "Legs", [8] = "Feet",
    [9] = "Wrist", [10] = "Hands", [11] = "Finger 1", [12] = "Finger 2",
    [13] = "Trinket 1", [14] = "Trinket 2", [15] = "Back",
    [16] = "Main Hand", [17] = "Off Hand", [18] = "Ranged", [19] = "Tabard"
}

-- Mapping ItemEquipLoc to Slot IDs
local PB_EQUIPLOC_TO_SLOTS = {
    ["INVTYPE_HEAD"] = {1},
    ["INVTYPE_NECK"] = {2},
    ["INVTYPE_SHOULDER"] = {3},
    ["INVTYPE_BODY"] = {4},
    ["INVTYPE_CHEST"] = {5},
    ["INVTYPE_ROBE"] = {5},
    ["INVTYPE_WAIST"] = {6},
    ["INVTYPE_LEGS"] = {7},
    ["INVTYPE_FEET"] = {8},
    ["INVTYPE_WRIST"] = {9},
    ["INVTYPE_HAND"] = {10},
    ["INVTYPE_FINGER"] = {11, 12},
    ["INVTYPE_TRINKET"] = {13, 14},
    ["INVTYPE_CLOAK"] = {15},
    ["INVTYPE_WEAPON"] = {16, 17},
    ["INVTYPE_SHIELD"] = {17},
    ["INVTYPE_2HWEAPON"] = {16},
    ["INVTYPE_WEAPONMAINHAND"] = {16},
    ["INVTYPE_WEAPONOFFHAND"] = {17},
    ["INVTYPE_HOLDABLE"] = {17},
    ["INVTYPE_RANGED"] = {18},
    ["INVTYPE_THROWN"] = {18},
    ["INVTYPE_RANGEDRIGHT"] = {18},
    ["INVTYPE_TABARD"] = {19},
    ["INVTYPE_RELIC"] = {18},
}

-- Race and Class Name Lookups for Account Alts
local PB_RACE_NAMES = {
    [1] = "Human", [2] = "Orc", [3] = "Dwarf", [4] = "Night Elf",
    [5] = "Undead", [6] = "Tauren", [7] = "Gnome", [8] = "Troll"
}

local PB_CLASS_NAMES = {
    [1] = "Warrior", [2] = "Paladin", [3] = "Hunter", [4] = "Rogue",
    [5] = "Priest", [7] = "Shaman", [8] = "Mage", [9] = "Warlock", [11] = "Druid"
}

-- ============================================================================
-- Utility & Command Functions
-- ============================================================================

function PartyBotUI_Command(cmd)
    if cmd and cmd ~= "" then
        SendChatMessage(".partybot " .. cmd, "SAY")
    end
end

function PartyBotUI_ToggleAOE()
    PartyBotUI_AOEState = not PartyBotUI_AOEState
    if PartyBotUI_AOEState then
        PartyBotUI_Command("aoe on")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[PartyBot]|r AOE enabled for partybots.")
        if PartyBotDockAOEBtn then PartyBotDockAOEBtn:SetText("AOE*") end
    else
        PartyBotUI_Command("aoe off")
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd200[PartyBot]|r AOE disabled for partybots.")
        if PartyBotDockAOEBtn then PartyBotDockAOEBtn:SetText("AOE") end
    end
end

function PartyBotUI_ToggleMain()
    if PartyBotMainFrame:IsShown() then
        PartyBotMainFrame:Hide()
    else
        PartyBotMainFrame:Show()
        PartyBotUI_UpdateAll()
    end
end

-- ============================================================================
-- Roster & Active Bots Detection
-- ============================================================================

function PartyBotUI_UpdateRoster()
    PartyBotUI_ActiveBots = {}
    local numParty = GetNumPartyMembers()
    for i = 1, numParty do
        local unit = "party" .. i
        local name = UnitName(unit)
        if name and name ~= UNKNOWNOBJECT and name ~= "" then
            local _, class = UnitClass(unit)
            local level = UnitLevel(unit)
            local race = UnitRace(unit)
            table.insert(PartyBotUI_ActiveBots, {
                unit = unit,
                name = name,
                class = class or "WARRIOR",
                level = level or 1,
                race = race or "Human",
                index = i
            })
        end
    end

    -- Update Dock counter
    if PartyBotDockCountText then
        PartyBotDockCountText:SetText(string.format("Bots: %d/4", table.getn(PartyBotUI_ActiveBots)))
    end

    -- Trigger inspect for active bots
    for idx, bot in ipairs(PartyBotUI_ActiveBots) do
        if CheckInteractDistance(bot.unit, 1) then
            NotifyInspect(bot.unit)
        end
    end
end

-- ============================================================================
-- Equipment Inspection & Paperdoll Caching
-- ============================================================================

function PartyBotUI_CacheBotEquipment(botUnit)
    if not botUnit or not UnitExists(botUnit) then return end
    local botName = UnitName(botUnit)
    if not botName then return end

    if not PartyBotUI_BotEquip[botName] then
        PartyBotUI_BotEquip[botName] = {}
    end

    for slotId = 1, 19 do
        local link = GetInventoryItemLink(botUnit, slotId)
        local texture = GetInventoryItemTexture(botUnit, slotId)
        if link then
            local _, _, itemQuality = GetItemInfo(link)
            PartyBotUI_BotEquip[botName][slotId] = {
                link = link,
                icon = texture,
                quality = itemQuality or 1
            }
        else
            PartyBotUI_BotEquip[botName][slotId] = nil
        end
    end
end

-- ============================================================================
-- Bag Message Parser ([PB_BAGS] Server Extension)
-- ============================================================================

local function PartyBotUI_ConfirmGiveback(msg)
    local _, _, itemId, botName = string.find(msg, "^Received .-|Hitem:(%d+):.- from (%S+)%.$")
    if not itemId then return end

    itemId = tonumber(itemId)
    for index = table.getn(PartyBotUI_PendingGivebacks), 1, -1 do
        local pending = PartyBotUI_PendingGivebacks[index]
        if GetTime() - pending.sentAt > 30 then
            table.remove(PartyBotUI_PendingGivebacks, index)
        elseif pending.botName == botName and pending.itemId == itemId then
            table.remove(PartyBotUI_PendingGivebacks, index)

            -- Giveback takes the first matching item in backpack/bag order.
            -- Clear that cached slot immediately, then request authoritative data.
            local bagData = PartyBotUI_BotBags[botName]
            if bagData then
                local removed = false
                for bagNum = 0, 4 do
                    local items = bagData.items[bagNum] or {}
                    local container = bagData.containers[bagNum]
                    local slots = container and container.slots or 0
                    for slot = 0, slots - 1 do
                        if items[slot] and items[slot].id == itemId then
                            items[slot] = nil
                            removed = true
                            break
                        end
                    end
                    if removed then break end
                end
            end

            if PartyBotMainFrame:IsShown() and PartyBotUI_CurrentTab == 3 then
                PartyBotUI_RenderBags()
            end
            PartyBotUI_Command("bags " .. botName)
            return
        end
    end
end

function PartyBotUI_ProcessPBMessage(msg)
    if not msg then return end

    -- 1. Start of bag listing: [PB_BAGS_START] <botName>
    local _, _, startBot = string.find(msg, "^%[PB_BAGS_START%]%s+(%S+)")
    if startBot then
        PartyBotUI_BotBags[startBot] = {
            containers = {
                [0] = { name = "Backpack", slots = 16, icon = "Interface\\Buttons\\Button-Backpack-Up" },
                [1] = { name = "Bag 1", slots = 0 },
                [2] = { name = "Bag 2", slots = 0 },
                [3] = { name = "Bag 3", slots = 0 },
                [4] = { name = "Bag 4", slots = 0 },
            },
            items = {
                [0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {}
            }
        }
        return
    end

    -- 2. Bag container info: [PB_BAG_CONTAINER] <botName> <bagNum> <entry> <slots> <link>
    local _, _, cBot, cBag, cEntry, cSlots, cLink = string.find(msg, "^%[PB_BAG_CONTAINER%]%s+(%S+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(.+)")
    if cBot and cBag and PartyBotUI_BotBags[cBot] then
        local bNum = tonumber(cBag)
        local numSlots = tonumber(cSlots)
        local entry = tonumber(cEntry)
        local icon = nil
        local name = "Bag " .. bNum
        if entry > 0 then
            local itemName, _, _, _, _, _, _, _, itemTexture = GetItemInfo(entry)
            icon = itemTexture
            if itemName then name = itemName end
        end
        PartyBotUI_BotBags[cBot].containers[bNum] = {
            name = name,
            slots = numSlots,
            entry = entry,
            link = cLink,
            icon = icon
        }
        return
    end

    -- 3. Bag item entry: [PB_BAG_ITEM] <botName> <bagNum> <slot> <entry> <count> <link>
    local _, _, iBot, iBag, iSlot, iEntry, iCount, iLink = string.find(msg, "^%[PB_BAG_ITEM%]%s+(%S+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(.+)")
    if iBot and iBag and PartyBotUI_BotBags[iBot] then
        local b = tonumber(iBag)
        local s = tonumber(iSlot)
        local id = tonumber(iEntry)
        local cnt = tonumber(iCount)

        if not PartyBotUI_BotBags[iBot].items[b] then
            PartyBotUI_BotBags[iBot].items[b] = {}
        end

        local itemName, _, itemQuality, _, _, _, _, _, itemTexture = GetItemInfo(id)
        PartyBotUI_BotBags[iBot].items[b][s] = {
            id = id,
            count = cnt,
            link = iLink,
            icon = itemTexture,
            quality = itemQuality or 1
        }
        return
    end

    -- 4. End of bag listing: [PB_BAGS_END] <botName> <totalCount>
    local _, _, endBot = string.find(msg, "^%[PB_BAGS_END%]%s+(%S+)")
    if endBot then
        if PartyBotMainFrame:IsShown() and PartyBotUI_CurrentTab == 3 then
            PartyBotUI_RenderBags()
        end
        return
    end

    -- 4b. Bot money update: [PB_MONEY] <botName> <copper>
    local _, _, mBot, mCopper = string.find(msg, "^%[PB_MONEY%]%s+(%S+)%s+(%d+)")
    if mBot and mCopper then
        PartyBotUI_BotMoney[mBot] = tonumber(mCopper) or 0
        if PartyBotMainFrame:IsShown() and PartyBotUI_CurrentTab == 3 then
            PartyBotUI_RenderBags()
        end
        return
    end

    -- 5. Start of alts listing: [PB_ALTS_START]
    if string.find(msg, "^%[PB_ALTS_START%]") then
        PartyBotUI_AccountAlts = {}
        return
    end

    -- 6. Alt character entry: [PB_ALT] <name> <level> <race> <class> <gender>
    local _, _, aName, aLevel, aRace, aClass, aGender = string.find(msg, "^%[PB_ALT%]%s+(%S+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)")
    if aName then
        table.insert(PartyBotUI_AccountAlts, {
            name = aName,
            level = tonumber(aLevel) or 1,
            race = tonumber(aRace) or 1,
            class = tonumber(aClass) or 1,
            gender = tonumber(aGender) or 0
        })
        return
    end

    -- 7. End of alts listing: [PB_ALTS_END] <count>
    if string.find(msg, "^%[PB_ALTS_END%]") then
        PartyBotUIDB = PartyBotUIDB or {}
        PartyBotUIDB.accountAlts = PartyBotUI_AccountAlts
        PartyBotUI_AccountAltsLoaded = true
        if PartyBotMainFrame:IsShown() and PartyBotUI_CurrentTab == 1 then
            PartyBotUI_RenderRoster()
        end
        return
    end
end

-- Hook ChatFrame_OnEvent to suppress raw [PB_ signals from chat
local pb_orig_ChatFrame_OnEvent = ChatFrame_OnEvent
ChatFrame_OnEvent = function(event)
    if event == "CHAT_MSG_SYSTEM" and arg1 then
        PartyBotUI_ConfirmGiveback(arg1)
    end
    if event == "CHAT_MSG_SYSTEM" and arg1 and string.find(arg1, "^%[PB_") then
        PartyBotUI_ProcessPBMessage(arg1)
        return -- Suppress from appearing in user's chat window!
    end
    return pb_orig_ChatFrame_OnEvent(event)
end

-- ============================================================================
-- UI Top Navigation Menu & Tab Switching
-- ============================================================================

local PB_NAV_TITLES = {
    [1] = "Roster",
    [2] = "Character Sheet",
    [3] = "Bot Bags",
    [4] = "Tactics & Roles"
}

function PartyBotUI_UpdateNavButtons(activeTabIndex)
    for i = 1, 4 do
        local btn = getglobal("PartyBotMainFrameTab" .. i)
        if btn then
            local text = getglobal(btn:GetName() .. "Text")
            local ind = getglobal(btn:GetName() .. "ActiveIndicator")
            local rawText = PB_NAV_TITLES[i] or "Menu"

            if i == activeTabIndex then
                -- Selected Menu Button: Rich dark gold backdrop with bright golden border
                btn:SetBackdropColor(0.26, 0.20, 0.05, 0.95)
                btn:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
                if text then
                    text:SetText("|cffffd200" .. rawText .. "|r")
                end
                if ind then ind:Show() end
            else
                -- Inactive Menu Button: Sleek dark slate with subtle border
                btn:SetBackdropColor(0.10, 0.10, 0.12, 0.85)
                btn:SetBackdropBorderColor(0.35, 0.35, 0.40, 0.75)
                if text then
                    text:SetText("|cffb8b8c0" .. rawText .. "|r")
                end
                if ind then ind:Hide() end
            end

            btn:SetScript("OnEnter", function()
                if this:GetID() ~= PartyBotUI_CurrentTab then
                    this:SetBackdropColor(0.18, 0.18, 0.22, 0.95)
                    this:SetBackdropBorderColor(0.85, 0.85, 0.90, 1.0)
                    local t = getglobal(this:GetName() .. "Text")
                    if t then
                        local label = PB_NAV_TITLES[this:GetID()] or "Menu"
                        t:SetText("|cffffffff" .. label .. "|r")
                    end
                end
            end)

            btn:SetScript("OnLeave", function()
                if this:GetID() ~= PartyBotUI_CurrentTab then
                    this:SetBackdropColor(0.10, 0.10, 0.12, 0.85)
                    this:SetBackdropBorderColor(0.35, 0.35, 0.40, 0.75)
                    local t = getglobal(this:GetName() .. "Text")
                    if t then
                        local label = PB_NAV_TITLES[this:GetID()] or "Menu"
                        t:SetText("|cffb8b8c0" .. label .. "|r")
                    end
                end
            end)
        end
    end
end

function PartyBotUI_SelectTab(tabIndex)
    PartyBotUI_CurrentTab = tabIndex
    PartyBotUI_UpdateNavButtons(tabIndex)

    PartyBotRosterTabFrame:Hide()
    PartyBotSheetTabFrame:Hide()
    PartyBotBagsTabFrame:Hide()
    PartyBotTacticsTabFrame:Hide()

    if tabIndex == 1 then
        PartyBotRosterTabFrame:Show()
        if not PartyBotUI_AccountAltsLoaded then
            PartyBotUI_Command("alts")
        end
        PartyBotUI_RenderRoster()
    elseif tabIndex == 2 then
        PartyBotSheetTabFrame:Show()
        PartyBotUI_RenderSheet()
    elseif tabIndex == 3 then
        PartyBotBagsTabFrame:Show()
        local bot = PartyBotUI_ActiveBots[PartyBotUI_SelectedBot]
        if bot then
            TargetUnit(bot.unit)
            if not PartyBotUI_BotBags[bot.name] then
                PartyBotUI_Command("bags " .. bot.name)
            else
                PartyBotUI_Command("money " .. bot.name)
            end
        end
        PartyBotUI_RenderBags()
    elseif tabIndex == 4 then
        PartyBotTacticsTabFrame:Show()
        PartyBotUI_RenderTactics()
    end
end

function PartyBotUI_UpdateAll()
    PartyBotUI_UpdateRoster()
    PartyBotUI_SelectTab(PartyBotUI_CurrentTab)
end

-- ============================================================================
-- TAB 1: Roster & Summoning Manager
-- ============================================================================

function PartyBotUI_RenderRoster()
    local frame = PartyBotRosterTabFrame

    -- Clean old dynamic children
    if not frame.initialized then
        frame.initialized = true

        -- Section 1: Active Bots Header
        local header1 = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        header1:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -68)
        header1:SetText("Active PartyBots (Max 4):")
        frame.header1 = header1

        frame.activeBotButtons = {}
        for i = 1, 4 do
            local btn = CreateFrame("Button", "PBRosterActiveBtn" .. i, frame, "UIPanelButtonTemplate")
            btn:SetWidth(230)
            btn:SetHeight(24)
            btn:SetPoint("TOPLEFT", header1, "BOTTOMLEFT", 0, - (i - 1) * 28 - 6)
            btn:SetText("Slot " .. i .. ": Empty")

            local remBtn = CreateFrame("Button", "PBRosterDismissBtn" .. i, frame, "UIPanelButtonTemplate")
            remBtn:SetWidth(65)
            remBtn:SetHeight(24)
            remBtn:SetPoint("LEFT", btn, "RIGHT", 6, 0)
            remBtn:SetText("Dismiss")

            frame.activeBotButtons[i] = { btn = btn, remBtn = remBtn }
        end

        -- Section 2: Account Alts
        local header2 = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        header2:SetPoint("TOPLEFT", header1, "BOTTOMLEFT", 0, -126)
        header2:SetText("Your Account Characters:")
        frame.header2 = header2

        local refreshAltsBtn = CreateFrame("Button", "PBRosterRefreshAltsBtn", frame, "UIPanelButtonTemplate")
        refreshAltsBtn:SetWidth(65)
        refreshAltsBtn:SetHeight(20)
        refreshAltsBtn:SetPoint("LEFT", header2, "RIGHT", 10, 0)
        refreshAltsBtn:SetText("Refresh")
        refreshAltsBtn:SetScript("OnClick", function()
            PartyBotUI_Command("alts")
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[PartyBot]|r Querying account alts list...")
        end)
        frame.refreshAltsBtn = refreshAltsBtn

        local altStatus = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        altStatus:SetPoint("LEFT", refreshAltsBtn, "RIGHT", 8, 0)
        altStatus:SetText("")
        frame.altStatus = altStatus

        frame.altButtons = {}
        for row = 0, 3 do
            for col = 0, 2 do
                local idx = row * 3 + col + 1
                local btn = CreateFrame("Button", "PBAltSummonBtn" .. idx, frame, "UIPanelButtonTemplate")
                btn:SetWidth(152)
                btn:SetHeight(24)
                btn:SetPoint("TOPLEFT", header2, "BOTTOMLEFT", col * 158, - row * 28 - 8)
                frame.altButtons[idx] = btn
            end
        end

        -- Section 3: Generic Fill Bots
        local header3 = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        header3:SetPoint("TOPLEFT", header2, "BOTTOMLEFT", 0, -135)
        header3:SetText("Quick-Add Class Role Bots (.partybot add):")
        frame.header3 = header3

        local genericRoles = { "tank", "healer", "dps", "warrior", "priest", "mage", "rogue", "druid", "hunter" }
        for idx, role in ipairs(genericRoles) do
            local col = math.mod(idx - 1, 3)
            local row = math.floor((idx - 1) / 3)
            local btn = CreateFrame("Button", "PBGenericAddBtn" .. idx, frame, "UIPanelButtonTemplate")
            btn:SetWidth(152)
            btn:SetHeight(24)
            btn:SetPoint("TOPLEFT", header3, "BOTTOMLEFT", col * 158, - row * 28 - 8)
            btn:SetText("+" .. string.upper(string.sub(role, 1, 1)) .. string.sub(role, 2))
            btn.role = role
            btn:SetScript("OnClick", function()
                PartyBotUI_Command("add " .. this.role)
            end)
        end
    end

    -- Update Active Bots List
    for i = 1, 4 do
        local entry = frame.activeBotButtons[i]
        local bot = PartyBotUI_ActiveBots[i]
        if bot then
            entry.btn:SetText(string.format("%s (Lvl %d %s)", bot.name, bot.level, bot.class))
            entry.btn:Enable()
            entry.btn.botIndex = i
            entry.btn:SetScript("OnClick", function()
                PartyBotUI_SelectedBot = this.botIndex
                PartyBotUI_SelectTab(2) -- Switch to character sheet
            end)
            entry.remBtn:Show()
            entry.remBtn.botName = bot.name
            entry.remBtn:SetScript("OnClick", function()
                PartyBotUI_Command("remove " .. this.botName)
            end)
        else
            entry.btn:SetText(string.format("Slot %d: Empty", i))
            entry.btn:Disable()
            entry.remBtn:Hide()
        end
    end

    -- Update Alt Buttons (ONLY player's account alts, displaying ONLY character name)
    PartyBotUIDB = PartyBotUIDB or {}
    local alts = PartyBotUIDB.accountAlts or {}
    local numAlts = table.getn(alts)

    if numAlts == 0 then
        if not PartyBotUI_AccountAltsLoaded then
            frame.altStatus:SetText("|cffffff00(Loading...)|r")
        else
            frame.altStatus:SetText("|cff888888(No other characters found)|r")
        end
    else
        frame.altStatus:SetText(string.format("|cff888888(%d found)|r", numAlts))
    end

    for idx = 1, 12 do
        local btn = frame.altButtons[idx]
        if idx <= numAlts then
            local alt = alts[idx]
            -- Only character name on button!
            btn:SetText(alt.name)
            btn:Show()
            btn.altName = alt.name
            btn.altInfo = alt

            local alreadyInParty = false
            for _, b in ipairs(PartyBotUI_ActiveBots) do
                if b.name == alt.name then
                    alreadyInParty = true
                    break
                end
            end

            if alreadyInParty then
                btn:Disable()
            else
                btn:Enable()
            end

            btn:SetScript("OnEnter", function()
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                GameTooltip:SetText(this.altName, 1, 1, 1)
                if this.altInfo then
                    local raceStr = PB_RACE_NAMES[this.altInfo.race] or "Unknown"
                    local classStr = PB_CLASS_NAMES[this.altInfo.class] or "Unknown"
                    GameTooltip:AddLine(string.format("Level %d %s %s", this.altInfo.level, raceStr, classStr), 1, 0.82, 0)
                end
                if alreadyInParty then
                    GameTooltip:AddLine("|cffff8000Already in party|r", 0.7, 0.7, 0.7)
                else
                    GameTooltip:AddLine("|cff00ff00Click to summon into party|r", 0.7, 0.7, 0.7)
                end
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            btn:SetScript("OnClick", function()
                PartyBotUI_Command("load " .. this.altName)
            end)
        else
            btn:Hide()
        end
    end
end

-- ============================================================================
-- TAB 2: Multi-Bot Character Sheet (Paperdoll)
-- ============================================================================

function PartyBotUI_RenderSheet()
    local frame = PartyBotSheetTabFrame

    if not frame.initialized then
        frame.initialized = true

        -- Sub-tabs for each active bot
        frame.botSubTabs = {}
        for i = 1, 4 do
            local tab = CreateFrame("Button", "PBSheetSubTab" .. i, frame, "UIPanelButtonTemplate")
            tab:SetWidth(110)
            tab:SetHeight(24)
            tab:SetPoint("TOPLEFT", frame, "TOPLEFT", 24 + (i - 1) * 122, -66)
            tab.botIndex = i
            tab:SetScript("OnClick", function()
                PartyBotUI_SelectedBot = this.botIndex
                PartyBotUI_RenderSheet()
            end)
            frame.botSubTabs[i] = tab
        end

        -- Header Information
        frame.infoText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
        frame.infoText:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -96)

        frame.statsText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        frame.statsText:SetPoint("TOPLEFT", frame.infoText, "BOTTOMLEFT", 0, -3)

        -- Create Paperdoll Equipment Slots
        frame.slots = {}

        -- Left Column: Head(1), Neck(2), Shoulders(3), Back(15), Chest(5), Shirt(4), Tabard(19), Wrist(9)
        local leftSlots = { 1, 2, 3, 15, 5, 4, 19, 9 }
        for i, slotId in ipairs(leftSlots) do
            local btn = CreateFrame("Button", "PBSlotBtn" .. slotId, frame, "PartyBotSlotTemplate")
            btn:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, -135 - (i - 1) * 40)
            btn.slotId = slotId
            frame.slots[slotId] = btn
        end

        -- Right Column: Hands(10), Waist(6), Legs(7), Feet(8), Ring1(11), Ring2(12), Trinket1(13), Trinket2(14)
        local rightSlots = { 10, 6, 7, 8, 11, 12, 13, 14 }
        for i, slotId in ipairs(rightSlots) do
            local btn = CreateFrame("Button", "PBSlotBtn" .. slotId, frame, "PartyBotSlotTemplate")
            btn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -25, -135 - (i - 1) * 40)
            btn.slotId = slotId
            frame.slots[slotId] = btn
        end

        -- Bottom Row: MainHand(16), OffHand(17), Ranged(18)
        local bottomSlots = { 16, 17, 18 }
        for i, slotId in ipairs(bottomSlots) do
            local btn = CreateFrame("Button", "PBSlotBtn" .. slotId, frame, "PartyBotSlotTemplate")
            btn:SetPoint("BOTTOM", frame, "BOTTOM", (i - 2) * 48, 48)
            btn.slotId = slotId
            frame.slots[slotId] = btn
        end

        -- Trade to Bot Button
        frame.tradeBtn = CreateFrame("Button", "PBSheetTradeBtn", frame, "UIPanelButtonTemplate")
        frame.tradeBtn:SetWidth(110)
        frame.tradeBtn:SetHeight(24)
        frame.tradeBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 25, 14)
        frame.tradeBtn:SetText("Trade to Bot")
        frame.tradeBtn:SetScript("OnClick", function()
            local bot = PartyBotUI_ActiveBots[PartyBotUI_SelectedBot]
            if bot then
                InitiateTrade(bot.unit)
            end
        end)

        -- View Bags Button
        frame.viewBagsBtn = CreateFrame("Button", "PBSheetViewBagsBtn", frame, "UIPanelButtonTemplate")
        frame.viewBagsBtn:SetWidth(110)
frame.viewBagsBtn:SetHeight(24)
        frame.viewBagsBtn:SetPoint("LEFT", frame.tradeBtn, "RIGHT", 8, 0)
        frame.viewBagsBtn:SetText("View Bot Bags")
        frame.viewBagsBtn:SetScript("OnClick", function()
            PartyBotUI_SelectTab(3)
        end)
    end

    -- Update sub-tabs
    for i = 1, 4 do
        local tab = frame.botSubTabs[i]
        local bot = PartyBotUI_ActiveBots[i]
        if bot then
            tab:Show()
            tab:SetText(bot.name)
            if i == PartyBotUI_SelectedBot then
                tab:LockHighlight()
            else
                tab:UnlockHighlight()
            end
        else
            tab:Hide()
        end
    end

    local currentBot = PartyBotUI_ActiveBots[PartyBotUI_SelectedBot]
    if not currentBot then
        frame.infoText:SetText("No partybot active in this slot.")
        frame.statsText:SetText("Summon a bot using the Roster tab.")
        for _, btn in pairs(frame.slots) do
            btn:Hide()
        end
        if PartyBotCharacterModel then
            PartyBotCharacterModel:Hide()
        end
        return
    end

    -- Inspect unit and refresh equipment
    NotifyInspect(currentBot.unit)
    PartyBotUI_CacheBotEquipment(currentBot.unit)

    -- Update 3D Character Model
    if PartyBotCharacterModel then
        PartyBotCharacterModel:Show()
        PartyBotCharacterModel:SetUnit(currentBot.unit)
        PartyBotCharacterModel.rotation = 0
        PartyBotCharacterModel:SetRotation(0)
    end

    local hp = UnitHealth(currentBot.unit)
    local maxHp = UnitHealthMax(currentBot.unit)
    local mana = UnitMana(currentBot.unit)
    local maxMana = UnitManaMax(currentBot.unit)

    frame.infoText:SetText(string.format("%s - Level %d %s %s", currentBot.name, currentBot.level, currentBot.race, currentBot.class))
    frame.statsText:SetText(string.format("Health: %d/%d  |  Mana/Energy: %d/%d  |  Unit: %s", hp, maxHp, mana, maxMana, currentBot.unit))

    local botEquip = PartyBotUI_BotEquip[currentBot.name] or {}

    -- Render all 19 equipment slots
    for slotId, btn in pairs(frame.slots) do
        btn:Show()
        local slotData = botEquip[slotId]
        local iconTexture = getglobal(btn:GetName() .. "Icon")
        local borderTexture = getglobal(btn:GetName() .. "Border")

        if slotData and slotData.icon then
            iconTexture:SetTexture(slotData.icon)
            iconTexture:Show()

            local color = ITEM_QUALITY_COLORS[slotData.quality or 1]
            if color and slotData.quality > 1 then
                borderTexture:SetVertexColor(color.r, color.g, color.b)
                borderTexture:Show()
            else
                borderTexture:Hide()
            end
            btn.itemLink = slotData.link
        else
            iconTexture:SetTexture(nil)
            iconTexture:Hide()
            borderTexture:Hide()
            btn.itemLink = nil
        end
    end
end

local function PartyBotUI_ShowItemTooltip(tooltip, button, itemLink, fallbackId)
    if not button then return end
    if not itemLink and not fallbackId then return end
    tooltip:SetOwner(button, "ANCHOR_RIGHT")
    local linkToUse = nil
    if itemLink then
        local _, _, clean = string.find(itemLink, "(item:[%-%d:]+)")
        if clean then
            linkToUse = clean
        end
    end
    if not linkToUse and fallbackId then
        linkToUse = "item:" .. fallbackId .. ":0:0:0"
    end
    if linkToUse then
        local ok = pcall(function() tooltip:SetHyperlink(linkToUse) end)
        if not ok then
            tooltip:SetText("Item", 1, 1, 1)
        end
    else
        tooltip:SetText("Item", 1, 1, 1)
    end
end

function PartyBotUI_OnSlotEnter(button)
    if button.itemLink then
        PartyBotUI_ShowItemTooltip(GameTooltip, button, button.itemLink)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cffff8000Right-Click to unequip to bot bags|r", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cff00ff00Drag item here to replace / equip|r", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    else
        local slotName = PB_SLOT_NAMES[button.slotId] or "Slot"
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(slotName .. " (Empty)", 1, 1, 1)
        GameTooltip:AddLine("|cff00ff00Drag item here to equip|r", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end
end

-- Cursor tracking for drag-and-drop equipping
PartyBotUI_CursorItem = nil

local pb_orig_PickupContainerItem = PickupContainerItem
PickupContainerItem = function(bag, slot)
    local link = GetContainerItemLink(bag, slot)
    if CursorHasItem() then
        PartyBotUI_CursorItem = nil
    else
        if link then
            PartyBotUI_CursorItem = {
                type = "container",
                bag = bag,
                slot = slot,
                link = link
            }
        else
            PartyBotUI_CursorItem = nil
        end
    end
    return pb_orig_PickupContainerItem(bag, slot)
end

local pb_orig_PickupInventoryItem = PickupInventoryItem
PickupInventoryItem = function(slot)
    local link = GetInventoryItemLink("player", slot)
    if CursorHasItem() then
        PartyBotUI_CursorItem = nil
    else
        if link then
            PartyBotUI_CursorItem = {
                type = "inventory",
                slot = slot,
                link = link
            }
        else
            PartyBotUI_CursorItem = nil
        end
    end
    return pb_orig_PickupInventoryItem(slot)
end

local pb_orig_ClearCursor = ClearCursor
ClearCursor = function()
    PartyBotUI_CursorItem = nil
    return pb_orig_ClearCursor()
end

function PartyBotUI_OnSlotClick(button, mouseBtn)
    local currentBot = PartyBotUI_ActiveBots[PartyBotUI_SelectedBot]
    if not currentBot then return end

    -- Check if player is holding an item on cursor to equip onto bot
    if CursorHasItem() and PartyBotUI_CursorItem and PartyBotUI_CursorItem.link then
        local itemLink = PartyBotUI_CursorItem.link
        local slotId = button.slotId

        -- Safely restore cursor item to bag to prevent destroy prompts
        if PartyBotUI_CursorItem.type == "container" then
            pb_orig_PickupContainerItem(PartyBotUI_CursorItem.bag, PartyBotUI_CursorItem.slot)
        elseif PartyBotUI_CursorItem.type == "inventory" then
            pb_orig_PickupInventoryItem(PartyBotUI_CursorItem.slot)
        else
            pb_orig_ClearCursor()
        end
        PartyBotUI_CursorItem = nil

        local slotName = PB_SLOT_NAMES[slotId] or ("slot " .. slotId)
        TargetUnit(currentBot.unit)
        PartyBotUI_Command(string.format("equip %s %d %s", currentBot.name, slotId, itemLink))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00[PartyBot]|r Ordering %s to equip %s in %s slot...", currentBot.name, itemLink, slotName))
        PlaySound("ITEM_ARMOR_EQUIP")
        return
    end

    if mouseBtn == "RightButton" and button.itemLink then
        TargetUnit(currentBot.unit)
        PartyBotUI_Command("unequip " .. button.itemLink)
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00[PartyBot]|r Ordering %s to unequip %s...", currentBot.name, button.itemLink))
    end
end

-- ============================================================================
-- TAB 3: Bot Bags & Inventory Management
-- ============================================================================

function PartyBotUI_FormatMoneyCoins(copper)
    copper = tonumber(copper) or 0
    local gold = math.floor(copper / 10000)
    local silver = math.floor(math.mod(copper, 10000) / 100)
    local cop = math.mod(copper, 100)

    local str = ""
    if gold > 0 then
        str = str .. string.format("%d|cffffd700g|r ", gold)
    end
    if silver > 0 or gold > 0 then
        str = str .. string.format("%d|cffc7c7cfs|r ", silver)
    end
    str = str .. string.format("%d|cffeda55fc|r", cop)
    return str
end

function PartyBotUI_RenderBags()
    local frame = PartyBotBagsTabFrame

    if not frame.initialized then
        frame.initialized = true

        frame.subTabs = {}
        for i = 1, 4 do
            local tab = CreateFrame("Button", "PBBagSubTab" .. i, frame, "UIPanelButtonTemplate")
            tab:SetWidth(110)
            tab:SetHeight(24)
            tab:SetPoint("TOPLEFT", frame, "TOPLEFT", 24 + (i - 1) * 122, -66)
            tab.botIndex = i
            tab:SetScript("OnClick", function()
                PartyBotUI_SelectedBot = this.botIndex
                local b = PartyBotUI_ActiveBots[this.botIndex]
                if b then
                    TargetUnit(b.unit)
                    PartyBotUI_Command("bags " .. b.name)
                end
                PartyBotUI_RenderBags()
            end)
            frame.subTabs[i] = tab
        end

        frame.header = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        frame.header:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -96)
        frame.header:SetText("Bot Bags Inventory:")

        frame.refreshBtn = CreateFrame("Button", "PBBagsRefreshBtn", frame, "UIPanelButtonTemplate")
        frame.refreshBtn:SetWidth(110)
        frame.refreshBtn:SetHeight(24)
        frame.refreshBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -25, -92)
        frame.refreshBtn:SetText("Refresh Bags")
        frame.refreshBtn:SetScript("OnClick", function()
            local bot = PartyBotUI_ActiveBots[PartyBotUI_SelectedBot]
            if bot then
                TargetUnit(bot.unit)
                PartyBotUI_Command("bags " .. bot.name)
            end
        end)

        -- Container Bag Filter Buttons
        frame.bagFilterButtons = {}
        local bagFilters = {
            { label = "All Bags", filter = -1, width = 75 },
            { label = "Backpack", filter = 0, width = 75 },
            { label = "Bag 1", filter = 1, width = 65 },
            { label = "Bag 2", filter = 2, width = 65 },
            { label = "Bag 3", filter = 3, width = 65 },
            { label = "Bag 4", filter = 4, width = 65 },
        }

        local startX = 22
        for idx, bf in ipairs(bagFilters) do
            local bBtn = CreateFrame("Button", "PBBagFilterBtn" .. idx, frame, "UIPanelButtonTemplate")
            bBtn:SetWidth(bf.width)
            bBtn:SetHeight(22)
            bBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", startX, -124)
            bBtn:SetText(bf.label)
            bBtn.bagFilter = bf.filter
            bBtn:SetScript("OnClick", function()
                PartyBotUI_SelectedBagFilter = this.bagFilter
                PartyBotUI_RenderBags()
            end)
            frame.bagFilterButtons[idx] = bBtn
            startX = startX + bf.width + 6
        end

        -- Create up to 88 Bag Slots (11 columns x 8 rows)
        frame.bagSlots = {}
        for row = 0, 7 do
            for col = 0, 10 do
                local slotIndex = row * 11 + col
                local btn = CreateFrame("Button", "PBBagSlotBtn" .. slotIndex, frame, "PartyBotBagSlotTemplate")
                btn:SetPoint("TOPLEFT", frame, "TOPLEFT", 24 + col * 44, -152 - row * 37)
                btn.slotIndex = slotIndex
                frame.bagSlots[slotIndex] = btn
            end
        end

        -- Money Action Buttons at Bottom (PartyBotBagsMoneyLabel and PartyBotBagsMoneyFrame defined in XML)

        frame.takeAllMoneyBtn = CreateFrame("Button", "PBBagsTakeAllMoneyBtn", frame, "UIPanelButtonTemplate")
        frame.takeAllMoneyBtn:SetWidth(105)
        frame.takeAllMoneyBtn:SetHeight(22)
        frame.takeAllMoneyBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 42)
        frame.takeAllMoneyBtn:SetText("Take All Gold")
        frame.takeAllMoneyBtn:SetScript("OnClick", function()
            local bot = PartyBotUI_ActiveBots[PartyBotUI_SelectedBot]
            if bot then
                TargetUnit(bot.unit)
                PartyBotUI_Command("money " .. bot.name .. " take all")
            end
        end)

        frame.give5gBtn = CreateFrame("Button", "PBBagsGive5gBtn", frame, "UIPanelButtonTemplate")
        frame.give5gBtn:SetWidth(45)
        frame.give5gBtn:SetHeight(22)
        frame.give5gBtn:SetPoint("RIGHT", frame.takeAllMoneyBtn, "LEFT", -6, 0)
        frame.give5gBtn:SetText("+5g")
        frame.give5gBtn:SetScript("OnClick", function()
            local bot = PartyBotUI_ActiveBots[PartyBotUI_SelectedBot]
            if bot then
                TargetUnit(bot.unit)
                PartyBotUI_Command("money " .. bot.name .. " give 5g")
            end
        end)

        frame.give1gBtn = CreateFrame("Button", "PBBagsGive1gBtn", frame, "UIPanelButtonTemplate")
        frame.give1gBtn:SetWidth(45)
        frame.give1gBtn:SetHeight(22)
        frame.give1gBtn:SetPoint("RIGHT", frame.give5gBtn, "LEFT", -4, 0)
        frame.give1gBtn:SetText("+1g")
        frame.give1gBtn:SetScript("OnClick", function()
            local bot = PartyBotUI_ActiveBots[PartyBotUI_SelectedBot]
            if bot then
                TargetUnit(bot.unit)
                PartyBotUI_Command("money " .. bot.name .. " give 1g")
            end
        end)

        frame.giveLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        frame.giveLabel:SetPoint("RIGHT", frame.give1gBtn, "LEFT", -6, 0)
        frame.giveLabel:SetText("Deposit:")

        -- Capacity / Summary Footer
        frame.summaryText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        frame.summaryText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 18)
        frame.summaryText:SetText("Left-Click: Retrieve item to your bags. Right-Click: Equip item on bot.")
    end

    -- Update sub tabs
    for i = 1, 4 do
        local tab = frame.subTabs[i]
        local bot = PartyBotUI_ActiveBots[i]
        if bot then
            tab:Show()
            tab:SetText(bot.name)
            if i == PartyBotUI_SelectedBot then tab:LockHighlight() else tab:UnlockHighlight() end
        else
            tab:Hide()
        end
    end

    local currentBot = PartyBotUI_ActiveBots[PartyBotUI_SelectedBot]
    if not currentBot then
        frame.header:SetText("No active partybot in this slot.")
        for _, btn in pairs(frame.bagSlots) do btn:Hide() end
        for _, bBtn in pairs(frame.bagFilterButtons) do bBtn:Hide() end
        if PartyBotBagsMoneyFrame then PartyBotBagsMoneyFrame:Hide() end
        if PartyBotBagsMoneyLabel then PartyBotBagsMoneyLabel:Hide() end
        if frame.takeAllMoneyBtn then frame.takeAllMoneyBtn:Hide() end
        if frame.give5gBtn then frame.give5gBtn:Hide() end
        if frame.give1gBtn then frame.give1gBtn:Hide() end
        if frame.giveLabel then frame.giveLabel:Hide() end
        return
    end

    if PartyBotBagsMoneyFrame then PartyBotBagsMoneyFrame:Show() end
    if PartyBotBagsMoneyLabel then PartyBotBagsMoneyLabel:Show() end
    if frame.takeAllMoneyBtn then frame.takeAllMoneyBtn:Show() end
    if frame.give5gBtn then frame.give5gBtn:Show() end
    if frame.give1gBtn then frame.give1gBtn:Show() end
    if frame.giveLabel then frame.giveLabel:Show() end

    for _, bBtn in pairs(frame.bagFilterButtons) do bBtn:Show() end

    frame.header:SetText(string.format("Bags for: |cffffff00%s|r (Level %d %s)", currentBot.name, currentBot.level, currentBot.class))

    local botBagData = PartyBotUI_BotBags[currentBot.name]

    -- Update Bag Filter Buttons text & highlights
    local containers = botBagData and botBagData.containers
    for idx, bBtn in ipairs(frame.bagFilterButtons) do
        local f = bBtn.bagFilter
        if f == PartyBotUI_SelectedBagFilter then
            bBtn:LockHighlight()
        else
            bBtn:UnlockHighlight()
        end

        if f == -1 then
            bBtn:SetText("All Bags")
        elseif f == 0 then
            bBtn:SetText("Backpack")
        else
            local cInfo = containers and containers[f]
            if cInfo and cInfo.slots and cInfo.slots > 0 then
                bBtn:SetText(string.format("Bag %d (%d)", f, cInfo.slots))
            else
                bBtn:SetText(string.format("Bag %d", f))
            end
        end
    end

    -- Build list of displayable slots
    local slotList = {}
    local totalCapacity = 16
    local totalOccupied = 0

    if containers then
        local items = (botBagData and botBagData.items) or {}
        local bagsToScan = {}
        if PartyBotUI_SelectedBagFilter == -1 then
            bagsToScan = { 0, 1, 2, 3, 4 }
        else
            bagsToScan = { PartyBotUI_SelectedBagFilter }
        end

        totalCapacity = 0
        for _, bNum in ipairs(bagsToScan) do
            local cInfo = containers[bNum]
            local numSlots = (cInfo and cInfo.slots) or (bNum == 0 and 16 or 0)
            totalCapacity = totalCapacity + numSlots
            local bItems = items[bNum] or {}
            for s = 0, numSlots - 1 do
                local it = bItems[s]
                if it then totalOccupied = totalOccupied + 1 end
                table.insert(slotList, {
                    bagNum = bNum,
                    slotIndex = s,
                    bagName = (cInfo and cInfo.name) or (bNum == 0 and "Backpack" or ("Bag " .. bNum)),
                    item = it
                })
            end
        end
    else
        -- Default to 16 empty backpack slots if not yet queried
        for s = 0, 15 do
            table.insert(slotList, {
                bagNum = 0,
                slotIndex = s,
                bagName = "Backpack",
                item = nil
            })
        end
    end

    -- Render up to 88 slots
    local numToDisplay = table.getn(slotList)
    for i = 0, 87 do
        local btn = frame.bagSlots[i]
        if i < numToDisplay then
            btn:Show()
            local sData = slotList[i + 1]
            btn.bagNum = sData.bagNum
            btn.slotIndex = sData.slotIndex
            btn.bagName = sData.bagName
            btn.botName = currentBot.name

            local itemData = sData.item
            local icon = getglobal(btn:GetName() .. "Icon")
            local border = getglobal(btn:GetName() .. "Border")
            local countText = getglobal(btn:GetName() .. "Count")

            if itemData and itemData.link then
                btn.itemLink = itemData.link
                btn.itemId = itemData.id
                local itemIcon = itemData.icon
                if not itemIcon and itemData.id then
                    local _, _, _, _, _, _, _, _, queryTex = GetItemInfo(itemData.id)
                    if queryTex then
                        itemData.icon = queryTex
                        itemIcon = queryTex
                    end
                end
                icon:SetTexture(itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
                icon:Show()

                local color = ITEM_QUALITY_COLORS[itemData.quality or 1]
                if color and itemData.quality > 1 then
                    border:SetVertexColor(color.r, color.g, color.b)
                    border:Show()
                else
                    border:Hide()
                end

                if itemData.count and itemData.count > 1 then
                    countText:SetText(itemData.count)
                    countText:Show()
                else
                    countText:Hide()
                end
            else
                btn.itemLink = nil
                btn.itemId = nil
                icon:SetTexture(nil)
                icon:Hide()
                border:Hide()
                countText:Hide()
            end
        else
            btn:Hide()
        end
    end

    -- Update Money Display & Action Buttons
    local botMoneyCopper = PartyBotUI_BotMoney[currentBot.name] or 0
    if PartyBotBagsMoneyFrame then
        MoneyFrame_Update("PartyBotBagsMoneyFrame", botMoneyCopper)
        if botMoneyCopper == 0 then
            PartyBotBagsMoneyFrameCopperButton:SetText("0")
            PartyBotBagsMoneyFrameCopperButton:SetWidth(PartyBotBagsMoneyFrameCopperButton:GetTextWidth() + 13)
            PartyBotBagsMoneyFrameCopperButton:Show()
            PartyBotBagsMoneyFrameSilverButton:Hide()
            PartyBotBagsMoneyFrameGoldButton:Hide()
            PartyBotBagsMoneyFrame:SetWidth(PartyBotBagsMoneyFrameCopperButton:GetWidth() + 13)
        end
    end

    if botMoneyCopper > 0 then
        frame.takeAllMoneyBtn:Enable()
    else
        frame.takeAllMoneyBtn:Disable()
    end

    frame.summaryText:SetText(string.format("Capacity: %d/%d slots occupied (%d free)  |  Click an item to take it back.",
        totalOccupied, totalCapacity, totalCapacity - totalOccupied))
end

function PartyBotUI_OnBagSlotEnter(button)
    if button.itemLink or button.itemId then
        PartyBotUI_ShowItemTooltip(GameTooltip, button, button.itemLink, button.itemId)
        GameTooltip:AddLine(" ")
        local bagDesc = button.bagName or "Backpack"
        GameTooltip:AddLine(string.format("|cff888888%s, Slot %d|r", bagDesc, (button.slotIndex or 0) + 1))
        GameTooltip:AddLine("|cff00ff00Left-Click: Retrieve into your bags|r", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffffd200Right-Click: Equip on this bot|r", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    else
        local bagDesc = button.bagName or "Backpack"
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(string.format("%s Slot %d (Empty)", bagDesc, (button.slotIndex or 0) + 1), 1, 1, 1)
        GameTooltip:Show()
    end
end

function PartyBotUI_OnBagSlotClick(button, mouseBtn)
    if not button.itemLink then return end
    local currentBot = PartyBotUI_ActiveBots[PartyBotUI_SelectedBot]
    if not currentBot then return end

    if mouseBtn == "RightButton" then
        TargetUnit(currentBot.unit)
        PartyBotUI_Command(string.format("equip %s %s", currentBot.name, button.itemLink))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00[PartyBot]|r Ordering %s to equip %s...", currentBot.name, button.itemLink))
    else
        TargetUnit(currentBot.unit)
        local _, _, itemId = string.find(button.itemLink, "|Hitem:(%d+):")
        if itemId then
            table.insert(PartyBotUI_PendingGivebacks, {
                botName = currentBot.name,
                itemId = tonumber(itemId),
                sentAt = GetTime()
            })
        end
        PartyBotUI_Command("giveback " .. button.itemLink)
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00[PartyBot]|r Requesting %s from %s...", button.itemLink, currentBot.name))
    end
end

-- ============================================================================
-- TAB 4: Tactics & Roles Manager
-- ============================================================================

function PartyBotUI_RenderTactics()
    local frame = PartyBotTacticsTabFrame

    if not frame.initialized then
        frame.initialized = true

        -- Section 1: Role Configuration
        local rHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        rHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -68)
        rHeader:SetText("Combat Role Switcher (.partybot setrole):")

        local roles = {
            { name = "Tank", cmd = "setrole tank" },
            { name = "Healer", cmd = "setrole healer" },
            { name = "DPS", cmd = "setrole dps" },
            { name = "Melee DPS", cmd = "setrole meleedps" },
            { name = "Ranged DPS", cmd = "setrole rangedps" }
        }

        for idx, r in ipairs(roles) do
            local btn = CreateFrame("Button", "PBRoleBtn" .. idx, frame, "UIPanelButtonTemplate")
            btn:SetWidth(90)
btn:SetHeight(24)
            btn:SetPoint("TOPLEFT", rHeader, "BOTTOMLEFT", (idx - 1) * 94, -8)
            btn:SetText(r.name)
            btn.cmd = r.cmd
            btn:SetScript("OnClick", function()
                PartyBotUI_Command(this.cmd)
            end)
        end

        -- Section 2: Combat Flow Commands
        local cHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        cHeader:SetPoint("TOPLEFT", rHeader, "BOTTOMLEFT", 0, -45)
        cHeader:SetText("Tactical Commands:")

        local combatCmds = {
            { name = "Pull Target", cmd = "pull", tip = "Orders Tank bot to pull your target" },
            { name = "Attack Target", cmd = "attackstart", tip = "Orders all bots to attack your target" },
            { name = "Stop Attack", cmd = "attackstop", tip = "Orders all bots to cease attack" },
            { name = "Come To Me", cmd = "cometome", tip = "Forces bots to run to your coordinates" },
            { name = "Pause AI", cmd = "pause", tip = "Freezes bot AI" },
            { name = "Unpause AI", cmd = "unpause", tip = "Resumes bot AI" },
            { name = "Toggle AOE", cmd = "aoe_toggle", tip = "Toggle AoE spells on/off" },
            { name = "Interact Object", cmd = "usegobject", tip = "Orders bot to use targeted lever/door" }
        }

        for idx, c in ipairs(combatCmds) do
            local col = math.mod(idx - 1, 2)
            local row = math.floor((idx - 1) / 2)
            local btn = CreateFrame("Button", "PBTacticsCmdBtn" .. idx, frame, "UIPanelButtonTemplate")
            btn:SetWidth(225)
            btn:SetHeight(26)
            btn:SetPoint("TOPLEFT", cHeader, "BOTTOMLEFT", col * 235, - row * 30 - 8)
            btn:SetText(c.name)
            btn.cmd = c.cmd
            btn:SetScript("OnClick", function()
                if this.cmd == "aoe_toggle" then
                    PartyBotUI_ToggleAOE()
                else
                    PartyBotUI_Command(this.cmd)
                end
            end)
        end

        -- Section 3: Raid Marks CC & Focus
        local mHeader = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        mHeader:SetPoint("TOPLEFT", cHeader, "BOTTOMLEFT", 0, -145)
        mHeader:SetText("Crowd Control & Focus Marks:")

        local marks = { "star", "circle", "diamond", "triangle", "moon", "square", "cross", "skull" }

        local ccLbl = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        ccLbl:SetPoint("TOPLEFT", mHeader, "BOTTOMLEFT", 0, -8)
        ccLbl:SetText("CC Mark (.partybot ccmark):")

        for idx, m in ipairs(marks) do
            local btn = CreateFrame("Button", "PBCCMarkBtn" .. idx, frame, "UIPanelButtonTemplate")
            btn:SetWidth(52)
            btn:SetHeight(22)
            btn:SetPoint("TOPLEFT", ccLbl, "BOTTOMLEFT", (idx - 1) * 56, -4)
            btn:SetText(string.upper(string.sub(m, 1, 3)))
            btn.mark = m
            btn:SetScript("OnClick", function()
                PartyBotUI_Command("ccmark " .. this.mark)
            end)
        end

        local fLbl = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        fLbl:SetPoint("TOPLEFT", ccLbl, "BOTTOMLEFT", 0, -36)
        fLbl:SetText("Focus Mark (.partybot focusmark):")

        for idx, m in ipairs(marks) do
            local btn = CreateFrame("Button", "PBFoxusMarkBtn" .. idx, frame, "UIPanelButtonTemplate")
            btn:SetWidth(52)
            btn:SetHeight(22)
            btn:SetPoint("TOPLEFT", fLbl, "BOTTOMLEFT", (idx - 1) * 56, -4)
            btn:SetText(string.upper(string.sub(m, 1, 3)))
            btn.mark = m
            btn:SetScript("OnClick", function()
                PartyBotUI_Command("focusmark " .. this.mark)
            end)
        end

        local clearBtn = CreateFrame("Button", "PBClearMarksBtn", frame, "UIPanelButtonTemplate")
        clearBtn:SetWidth(120)
clearBtn:SetHeight(24)
        clearBtn:SetPoint("TOPLEFT", fLbl, "BOTTOMLEFT", 0, -36)
        clearBtn:SetText("Clear All Marks")
        clearBtn:SetScript("OnClick", function()
            PartyBotUI_Command("clearmarks")
        end)
    end
end

-- ============================================================================
-- Tooltip Gear Upgrade Advisor
-- ============================================================================

local function PartyBotUI_AppendUpgradeTooltip(tooltip, itemLink)
    if not itemLink or table.getn(PartyBotUI_ActiveBots) == 0 then return end

    local itemName, _, itemQuality, itemMinLevel, itemType, itemSubType, _, itemEquipLoc = GetItemInfo(itemLink)
    if not itemEquipLoc or not PB_EQUIPLOC_TO_SLOTS[itemEquipLoc] then return end

    local targetSlots = PB_EQUIPLOC_TO_SLOTS[itemEquipLoc]
    local upgradeSuggestions = {}

    for _, bot in ipairs(PartyBotUI_ActiveBots) do
        local botEquip = PartyBotUI_BotEquip[bot.name] or {}

        for _, slotId in ipairs(targetSlots) do
            local currentItem = botEquip[slotId]
            local slotName = PB_SLOT_NAMES[slotId] or "Slot"

            if not currentItem then
                -- Empty slot is always a huge upgrade!
                table.insert(upgradeSuggestions, string.format("  |cff00ff00%s|r (%s): Empty %s slot!", bot.name, bot.class, slotName))
            else
                local _, _, currQuality, currMinLevel = GetItemInfo(currentItem.link)
                if (currMinLevel and itemMinLevel and itemMinLevel > currMinLevel) or (itemQuality and currQuality and itemQuality > currQuality) then
                    table.insert(upgradeSuggestions, string.format("  |cff00ff00%s|r (%s): Upgrade over %s", bot.name, bot.class, currentItem.link))
                end
            end
        end
    end

    if table.getn(upgradeSuggestions) > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cffffd200PartyBot Upgrade Advisor:|r")
        for _, line in ipairs(upgradeSuggestions) do
            tooltip:AddLine(line)
        end
        tooltip:Show()
    end
end

-- Hook Bag Tooltips
local pb_orig_SetBagItem = GameTooltip.SetBagItem
GameTooltip.SetBagItem = function(self, bag, slot)
    local val = pb_orig_SetBagItem(self, bag, slot)
    local link = GetContainerItemLink(bag, slot)
    if link then
        pcall(PartyBotUI_AppendUpgradeTooltip, self, link)
    end
    return val
end

-- Hook Inventory Tooltips
local pb_orig_SetInventoryItem = GameTooltip.SetInventoryItem
GameTooltip.SetInventoryItem = function(self, unit, slot)
    local val = pb_orig_SetInventoryItem(self, unit, slot)
    local link = GetInventoryItemLink(unit, slot)
    if link then
        pcall(PartyBotUI_AppendUpgradeTooltip, self, link)
    end
    return val
end

-- ============================================================================
-- Event Listener & Initialization
-- ============================================================================

local eventFrame = CreateFrame("Frame", "PartyBotUIEventFrame", UIParent)
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        PartyBotUIDB = PartyBotUIDB or {}
        PartyBotUIDB.accountAlts = PartyBotUIDB.accountAlts or {}
        PartyBotUI_UpdateNavButtons(1)
        PartyBotUI_Command("alts")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00PartyBotUI v1.2 loaded.|r Type |cffffff00/pb|r or |cffffff00/partybot|r for commands.")
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        PartyBotUI_UpdateRoster()
        PartyBotUI_Command("alts")
        if PartyBotMainFrame:IsShown() then
            PartyBotUI_SelectTab(PartyBotUI_CurrentTab)
        end
    elseif event == "UNIT_INVENTORY_CHANGED" then
        if arg1 and string.find(arg1, "^party%d") then
            PartyBotUI_CacheBotEquipment(arg1)
            if PartyBotMainFrame:IsShown() and PartyBotUI_CurrentTab == 2 then
                PartyBotUI_RenderSheet()
            end
        end
    end
end)

-- ============================================================================
-- Slash Commands
-- ============================================================================

SLASH_PARTYBOTUI1 = "/pb"
SLASH_PARTYBOTUI2 = "/partybot"
SlashCmdList["PARTYBOTUI"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "" or msg == "ui" then
        PartyBotUI_ToggleMain()
    elseif msg == "dock" then
        if PartyBotDockFrame:IsShown() then
            PartyBotDockFrame:Hide()
        else
            PartyBotDockFrame:Show()
        end
    elseif msg == "pull" then
        PartyBotUI_Command("pull")
    elseif msg == "attack" or msg == "atk" then
        PartyBotUI_Command("attackstart")
    elseif msg == "stop" then
        PartyBotUI_Command("attackstop")
    elseif msg == "follow" or msg == "regrp" then
        PartyBotUI_Command("cometome")
    elseif msg == "aoe" then
        PartyBotUI_ToggleAOE()
    elseif msg == "bags" then
        local name = UnitName("target")
        if name then
            PartyBotUI_Command("bags " .. name)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[PartyBot]|r Please target a bot first.")
        end
    elseif msg == "money" or string.find(msg, "^money") then
        local name = UnitName("target")
        local _, _, mArgs = string.find(msg, "^money%s*(.*)")
        if name then
            PartyBotUI_Command("money " .. name .. (mArgs and mArgs ~= "" and (" " .. mArgs) or ""))
        else
            PartyBotUI_Command("money " .. (mArgs or ""))
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00PartyBotUI Commands:|r")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/pb|r - Toggle main PartyBot manager window")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/pb dock|r - Toggle floating tactical dock")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/pb pull|r - Order Tank bot to pull target")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/pb atk|r - Order bots to attack target")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/pb stop|r - Order bots to stop attack")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/pb follow|r - Order bots to regroup to you")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/pb aoe|r - Toggle AOE spells on/off")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/pb bags|r - Query targeted bot's bags")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/pb money|r - Manage targeted bot's gold")
    end
end
