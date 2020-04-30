----------------------------------------------------------------------------------------------------
-- loader
----------------------------------------------------------------------------------------------------
-- Purpose: Loads the guidanceSeeding mod.
--
-- Copyright (c) Wopster, 2020
----------------------------------------------------------------------------------------------------

local directory = g_currentModDirectory
local modName = g_currentModName

source(Utils.getFilename("src/events/GuidanceSeedingHalfSideShutoffEvent.lua", directory))
source(Utils.getFilename("src/events/GuidanceSeedingTramLineDataEvent.lua", directory))
source(Utils.getFilename("src/events/GuidanceSeedingDataEvent.lua", directory))

source(Utils.getFilename("src/hud/elements/HUDElementBase.lua", directory))
source(Utils.getFilename("src/hud/elements/HUDMovableElement.lua", directory))
source(Utils.getFilename("src/hud/elements/HUDButtonElement.lua", directory))
source(Utils.getFilename("src/hud/InteractiveHUD.lua", directory))

source(Utils.getFilename("src/stream.lua", directory))
source(Utils.getFilename("src/GuidanceSeeding.lua", directory))

local guidanceSeeding

---Returns true when the local instance of guidanceSeeding is set, false otherwise.
local function isEnabled()
    return guidanceSeeding ~= nil
end

local function loadedMission(mission, node)
    if not isEnabled() then
        return
    end

    if mission.cancelLoading then
        return
    end

    g_guidanceSeeding:onMissionLoaded(mission)
end


---Load the mod.
local function load(mission)
    assert(guidanceSeeding == nil)

    guidanceSeeding = GuidanceSeeding:new(mission, g_i18n, g_inputBinding, g_gui, g_soundManager, directory, modName)

    getfenv(0)["g_guidanceSeeding"] = guidanceSeeding

    addModEventListener(guidanceSeeding)
end

local function validateVehicleTypes(vehicleTypeManager)
    GuidanceSeeding.installSpecializations(g_vehicleTypeManager, g_specializationManager, directory, modName)
end

---Unload the mod when the game is closed.
local function unload()
    if not isEnabled() then
        return
    end

    if guidanceSeeding ~= nil then
        guidanceSeeding:delete()
        -- GC
        guidanceSeeding = nil
        getfenv(0)["g_guidanceSeeding"] = nil
    end
end

local function init()
    FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, unload)

    Mission00.load = Utils.prependedFunction(Mission00.load, load)
    Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, loadedMission)
    VehicleTypeManager.validateVehicleTypes = Utils.prependedFunction(VehicleTypeManager.validateVehicleTypes, validateVehicleTypes)
end

init()
