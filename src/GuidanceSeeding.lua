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

function ManureSystem.installSpecializations(vehicleTypeManager, specializationManager, modDirectory, modName)
end
