----------------------------------------------------------------------------------------------------
-- loader
----------------------------------------------------------------------------------------------------
-- Purpose: Loads the guidanceSeeding mod.
--
-- Copyright (c) Wopster, 2020
----------------------------------------------------------------------------------------------------

local directory = g_currentModDirectory
local modName = g_currentModName

source(Utils.getFilename("src/stream.lua", directory))
source(Utils.getFilename("src/GuidanceSeeding.lua", directory))

local guidanceSeeding

---Returns true when the local instance of guidanceSeeding is set, false otherwise.
local function isEnabled()
    return guidanceSeeding ~= nil
end

---Load the mod.
local function load(mission)
    assert(guidanceSeeding == nil)

    guidanceSeeding = GuidanceSeeding:new(mission, g_inputBinding, g_soundManager, directory, modName)

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
    VehicleTypeManager.validateVehicleTypes = Utils.prependedFunction(VehicleTypeManager.validateVehicleTypes, validateVehicleTypes)
end

init()
