--
-- main
--
-- Author: Stijn Wopereis
-- Description: loads the mod.
-- Name: main
-- Hide: yes
--
-- Copyright (c) Wopster, 2022

---@type string directory of the mod.
local modDirectory = g_currentModDirectory or ""
---@type string name of the mod.
local modName = g_currentModName or "unknown"
---@type ProSeed the current loaded mod env.
local modEnvironment

---Loading order should be based on dependency order
---@type table<string> files to source.
local sourceFiles = {
    "src/events/ProSeedModeEvent.lua",
    "src/events/ProSeedHalfSideShutoffEvent.lua",
    "src/events/ProSeedTramLineDataEvent.lua",
    "src/events/ProSeedDataEvent.lua",
    "src/events/ProSeedCreateTramLineEvent.lua",
    "src/events/ProSeedResetHectareSessionEvent.lua",
    "src/hud/elements/HUDElementBase.lua",
    "src/hud/elements/HUDMovableElement.lua",
    "src/hud/elements/HUDButtonElement.lua",
    "src/hud/elements/HUDTextElement.lua",
    "src/hud/InteractiveHUD.lua",
    "src/stream.lua",
    "src/ProSeed.lua"
}

for _, file in ipairs(sourceFiles) do
    source(modDirectory .. file)
end

---Returns true when the current mod env is loaded, false otherwise.
local function isLoaded()
    return modEnvironment ~= nil
end

---Load the mod.
local function load(mission)
    assert(modEnvironment == nil)
    modEnvironment = ProSeed.new(mission, g_i18n, g_inputBinding, g_gui, g_soundManager, modDirectory, modName)
    mission.proSeed = modEnvironment
    addModEventListener(modEnvironment)
end

---Unload the mod when the mod is unselected and savegame is (re)loaded or game is closed.
local function unload()
    if not isLoaded() then
        return
    end

    if modEnvironment ~= nil then
        removeModEventListener(modEnvironment)
        modEnvironment:delete()
        modEnvironment = nil -- GC

        if g_currentMission ~= nil then
            g_currentMission.proSeed = nil
        end
    end
end

local function loadedMission(mission, node)
    if not isLoaded() then
        return
    end

    if mission.cancelLoading then
        return
    end

    mission.proSeed:onMissionLoaded(mission)
end

---Load settings from xml file.
local function loadedItems(mission)
    if not isLoaded() then
        return
    end

    if mission:getIsServer() then
        if mission.missionInfo.savegameDirectory ~= nil and fileExists(mission.missionInfo.savegameDirectory .. "/proSeed.xml") then
            local xmlFile = loadXMLFile("ProSeedXML", mission.missionInfo.savegameDirectory .. "/proSeed.xml")
            if xmlFile ~= nil then
                modEnvironment:onMissionLoadFromSavegame(xmlFile)
                delete(xmlFile)
            end
        end
    end
end

---Save settings to xml file.
local function saveToXMLFile(missionInfo)
    if not isLoaded() then
        return
    end

    if missionInfo.isValid then
        local xmlFile = createXMLFile("ProSeedXML", missionInfo.savegameDirectory .. "/proSeed.xml", "proSeed")
        if xmlFile ~= nil then
            modEnvironment:onMissionSaveToSavegame(xmlFile)

            saveXMLFile(xmlFile)
            delete(xmlFile)
        end
    end
end

local function validateVehicleTypes(typeManager)
    if typeManager.typeName == "vehicle" then
        ProSeed.installSpecializations(typeManager, g_specializationManager, modDirectory, modName)
    end
end

--- Init the mod.
local function init()
    FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, unload)
    Mission00.load = Utils.prependedFunction(Mission00.load, load)
    Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, loadedMission)
    TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, validateVehicleTypes)
    Mission00.loadItemsFinished = Utils.appendedFunction(Mission00.loadItemsFinished, loadedItems)

    FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, saveToXMLFile)
end

init()

---Make modName globally available
g_proSeedModName = modName -- Todo: look for better solution..
