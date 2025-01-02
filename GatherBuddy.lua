-- GatherBuddy.lua

-- Addon initialization
local addonName, addon = ...
local frame = CreateFrame("Frame")
local nodes = {}

-- SavedVariables
GatherBuddyDB = GatherBuddyDB or {}

-- Constants
local GATHERING_EVENTS = {
    "LOOT_OPENED", "CHAT_MSG_LOOT"
}
local SYNC_INTERVAL = 86400 -- 24 hours in seconds
local lastSyncTime = 0

-- Settings
local filterSettings = { showHerbs = true, showOres = true }

-- Utility functions
local function GetPlayerMapPosition()
    local uiMapID = C_Map.GetBestMapForUnit("player")
    if not uiMapID then return nil, nil, nil end
    local position = C_Map.GetPlayerMapPosition(uiMapID, "player")
    if not position then return nil, nil, nil end
    return uiMapID, position.x, position.y
end

local function AddNode(nodeType, mapID, x, y)
    nodes[mapID] = nodes[mapID] or {}
    table.insert(nodes[mapID], { type = nodeType, x = x, y = y, timestamp = time() })
    print(string.format("[GatherBuddy] Added node: %s at (%.2f, %.2f) on map %d", nodeType, x * 100, y * 100, mapID))
end

local function SyncDatabase()
    local data = SerializeTable(nodes)
    C_ChatInfo.SendAddonMessage("GatherBuddy", data, "GUILD")
end

local function ReceiveDatabase(prefix, message, distribution, sender)
    if prefix ~= "GatherBuddy" or sender == UnitName("player") then return end
    local incomingNodes = DeserializeTable(message)
    for mapID, mapNodes in pairs(incomingNodes) do
        nodes[mapID] = nodes[mapID] or {}
        for _, node in ipairs(mapNodes) do
            table.insert(nodes[mapID], node)
        end
    end
    print(string.format("[GatherBuddy] Database updated from %s.", sender))
end

local function AutomaticSync()
    local currentTime = time()
    if currentTime - lastSyncTime >= SYNC_INTERVAL then
        lastSyncTime = currentTime
        SyncDatabase()
        print("[GatherBuddy] Automatic database sync completed.")
    end
end

-- World map integration
local worldMapPins = {}

local function CreateWorldMapPin(mapID, x, y, nodeType)
    local pin = CreateFrame("Frame", nil, WorldMapFrame)
    pin:SetSize(12, 12)
    local texture = pin:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()

    if nodeType == "Herb" then
        texture:SetTexture("Interface\\Icons\\inv_misc_herb_ancientlitchen")
    elseif nodeType == "Ore" then
        texture:SetTexture("Interface\\Icons\\inv_ore_copper_01")
    else
        texture:SetTexture("Interface\\Icons\\inv_misc_questionmark")
    end

    pin.texture = texture
    pin:SetPoint("CENTER", WorldMapFrame.ScrollContainer, "CENTER", x * WorldMapFrame:GetWidth(), -y * WorldMapFrame:GetHeight())
    table.insert(worldMapPins, pin)
end

local function DisplayNodesOnWorldMap()
    for _, pin in ipairs(worldMapPins) do
        pin:Hide()
    end
    worldMapPins = {}

    local mapID = WorldMapFrame:GetMapID()
    if not mapID or not nodes[mapID] then return end

    for _, node in ipairs(nodes[mapID]) do
        CreateWorldMapPin(mapID, node.x, node.y, node.type)
    end
end

WorldMapFrame:HookScript("OnShow", DisplayNodesOnWorldMap)

-- Minimap integration
local minimapPins = {}

local function CreateMinimapIcon(mapID, x, y, nodeType)
    if (nodeType == "Herb" and not filterSettings.showHerbs) or (nodeType == "Ore" and not filterSettings.showOres) then
        return
    end

    minimapPins[mapID] = minimapPins[mapID] or {}

    local pin = CreateFrame("Frame", nil, Minimap)
    pin:SetSize(12, 12)
    pin:SetFrameLevel(Minimap:GetFrameLevel() + 1)

    local texture = pin:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()

    if nodeType == "Herb" then
        texture:SetTexture("Interface\\Icons\\inv_misc_herb_ancientlitchen")
    elseif nodeType == "Ore" then
        texture:SetTexture("Interface\\Icons\\inv_ore_copper_01")
    else
        texture:SetTexture("Interface\\Icons\\inv_misc_questionmark")
    end

    pin.texture = texture

    local radius = 140 -- Minimap radius in pixels
    local xOffset = (x - 0.5) * radius
    local yOffset = (y - 0.5) * radius
    pin:SetPoint("CENTER", Minimap, "CENTER", xOffset, yOffset)
    table.insert(minimapPins[mapID], pin)

    pin:SetScript("OnEnter", function()
        GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
        GameTooltip:SetText(string.format("%s\nCoordinates: %.2f, %.2f", nodeType, x * 100, y * 100))
        GameTooltip:Show()
    end)

    pin:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function DisplayNodesOnMinimap()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID or not nodes[mapID] then return end
    for _, node in ipairs(nodes[mapID]) do
        CreateMinimapIcon(mapID, node.x, node.y, node.type)
    end
end

frame:SetScript("OnUpdate", function(self, elapsed)
    DisplayNodesOnMinimap()
    AutomaticSync()
end)

-- Utility for serialization/deserialization
local function SerializeTable(t)
    local serialized = ""
    for k, v in pairs(t) do
        serialized = serialized .. tostring(k) .. "=" .. tostring(v) .. ";"
    end
    return serialized
end

local function DeserializeTable(s)
    local t = {}
    for k, v in string.gmatch(s, "(.-)=(.-);") do
        t[k] = v
    end
    return t
end

-- Debugging settings
local function EnableDebugMode(enable)
    if enable then
        print("[GatherBuddy] Debug mode enabled.")
    else
        print("[GatherBuddy] Debug mode disabled.")
    end
end

SLASH_YOURADDON1 = "/youraddon"
SlashCmdList["YOURADDON"] = function(msg)
    local cmd, arg = strsplit(" ", msg, 2)
    if cmd == "debug" then
        EnableDebugMode(arg == "on")
    elseif cmd == "filter" then
        if arg == "herbs" then
            filterSettings.showHerbs = not filterSettings.showHerbs
            print("[GatherBuddy] Herb filter toggled.")
        elseif arg == "ores" then
            filterSettings.showOres = not filterSettings.showOres
            print("[GatherBuddy] Ore filter toggled.")
        end
    elseif cmd == "sync" then
        SyncDatabase()
        print("[GatherBuddy] Manual database sync triggered.")
    else
        print("[GatherBuddy] Commands:\n/debug on|off - Toggle debug mode\n/filter herbs|ores - Toggle filters\n/sync - Manual database sync")
    end
end
