----------------------------------------------------------------------------------------------------
-- loader
----------------------------------------------------------------------------------------------------
-- Purpose: Loads the ProSeed mod.
--
-- Copyright (c) Wopster, 2020
----------------------------------------------------------------------------------------------------

local directory = g_currentModDirectory
local modName = g_currentModName

source(Utils.getFilename("src/events/ProSeedModeEvent.lua", directory))
source(Utils.getFilename("src/events/ProSeedHalfSideShutoffEvent.lua", directory))
source(Utils.getFilename("src/events/ProSeedTramLineDataEvent.lua", directory))
source(Utils.getFilename("src/events/ProSeedDataEvent.lua", directory))

source(Utils.getFilename("src/hud/elements/HUDElementBase.lua", directory))
source(Utils.getFilename("src/hud/elements/HUDMovableElement.lua", directory))
source(Utils.getFilename("src/hud/elements/HUDButtonElement.lua", directory))
source(Utils.getFilename("src/hud/elements/HUDTextElement.lua", directory))
source(Utils.getFilename("src/hud/InteractiveHUD.lua", directory))

source(Utils.getFilename("src/stream.lua", directory))
source(Utils.getFilename("src/ProSeed.lua", directory))

local proSeed

---Returns true when the local instance of proSeed is set, false otherwise.
local function isEnabled()
    return proSeed ~= nil
end

local function loadedMission(mission, node)
    if not isEnabled() then
        return
    end

    if mission.cancelLoading then
        return
    end

    proSeed:onMissionLoaded(mission)
end


---Load the mod.
local function load(mission)
    assert(proSeed == nil)

    proSeed = ProSeed:new(mission, g_i18n, g_inputBinding, g_gui, g_soundManager, directory, modName)

    getfenv(0)["g_proSeed"] = proSeed

    addModEventListener(proSeed)
end

local function validateVehicleTypes(vehicleTypeManager)
    ProSeed.installSpecializations(g_vehicleTypeManager, g_specializationManager, directory, modName)
end

---Unload the mod when the game is closed.
local function unload()
    if not isEnabled() then
        return
    end

    if proSeed ~= nil then
        proSeed:delete()
        -- GC
        proSeed = nil
        getfenv(0)["g_proSeed"] = nil
    end
end

local function init()
    FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, unload)

    Mission00.load = Utils.prependedFunction(Mission00.load, load)
    Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, loadedMission)
    VehicleTypeManager.validateVehicleTypes = Utils.prependedFunction(VehicleTypeManager.validateVehicleTypes, validateVehicleTypes)
end

init()
