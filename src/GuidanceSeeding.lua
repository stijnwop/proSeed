----------------------------------------------------------------------------------------------------
-- GuidanceSeeding
----------------------------------------------------------------------------------------------------
-- Purpose: Main class the handle the Guidance Seeding.
--
-- Copyright (c) Wopster, 2020
----------------------------------------------------------------------------------------------------

---@class GuidanceSeeding
GuidanceSeeding = {}

local GuidanceSeeding_mt = Class(GuidanceSeeding)

function GuidanceSeeding:new(mission, input, soundManager, modDirectory, modName)
    local self = setmetatable({}, GuidanceSeeding_mt)

    self.version = 1.0
    self.isServer = mission:getIsServer()
    self.isClient = mission:getIsClient()
    self.modDirectory = modDirectory
    self.modName = modName

    --Debug flags
    self.debug = false

    self.mission = mission
    self.soundManager = soundManager

    return self
end

function GuidanceSeeding:delete()
end

function GuidanceSeeding.installSpecializations(vehicleTypeManager, specializationManager, modDirectory, modName)
    specializationManager:addSpecialization("guidanceSeedingTramLines", "GuidanceSeedingTramLines", Utils.getFilename("src/vehicle/GuidanceSeedingTramLines.lua", modDirectory), nil)

    for typeName, typeEntry in pairs(vehicleTypeManager:getVehicleTypes()) do
        if SpecializationUtil.hasSpecialization(SowingMachine, typeEntry.specializations) then
            vehicleTypeManager:addSpecialization(typeName, modName .. ".guidanceSeedingTramLines")
        end
    end
end
