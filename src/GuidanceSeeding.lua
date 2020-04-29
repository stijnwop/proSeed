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

function GuidanceSeeding:new(mission, i18n, inputBinding, gui, soundManager, modDirectory, modName)
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


    local uiFilename = Utils.getFilename("resources/hud/guidanceSeeding_1080p.png", modDirectory)
    self.hud = InteractiveHUD:new(mission, i18n, inputBinding, gui, modDirectory, uiFilename)

    self:loadGuidanceSeedingSamples()

    return self
end

function GuidanceSeeding:delete()
    self.soundManager:deleteSamples(self.samples)
    self.hud:delete()
end

function GuidanceSeeding:onMissionLoaded()
    self.hud:load()
end

function GuidanceSeeding:mouseEvent(posX, posY, isDown, isUp, button)
    self.hud:mouseEvent(posX, posY, isDown, isUp, button)
end

function GuidanceSeeding:loadGuidanceSeedingSamples()
    self.samples = {}

    local xmlFile = loadXMLFile("GuidanceSeedingSamples", Utils.getFilename("resources/sounds/sounds.xml", self.modDirectory))
    if xmlFile ~= nil then
        local soundsNode = getRootNode()

        self.samples.lowered = self.soundManager:loadSampleFromXML(xmlFile, "vehicle.sounds", "lowered", self.modDirectory, soundsNode, 1, AudioGroup.VEHICLE, nil, nil)
        self.samples.highered = self.soundManager:loadSampleFromXML(xmlFile, "vehicle.sounds", "highered", self.modDirectory, soundsNode, 1, AudioGroup.VEHICLE, nil, nil)
        self.samples.empty = self.soundManager:loadSampleFromXML(xmlFile, "vehicle.sounds", "empty", self.modDirectory, soundsNode, 1, AudioGroup.VEHICLE, nil, nil)
        self.samples.tramline = self.soundManager:loadSampleFromXML(xmlFile, "vehicle.sounds", "tramline", self.modDirectory, soundsNode, 1, AudioGroup.VEHICLE, nil, nil)

        delete(xmlFile)
    end
end

function GuidanceSeeding.installSpecializations(vehicleTypeManager, specializationManager, modDirectory, modName)
    specializationManager:addSpecialization("guidanceSeedingTramLines", "GuidanceSeedingTramLines", Utils.getFilename("src/vehicle/GuidanceSeedingTramLines.lua", modDirectory), nil)
    specializationManager:addSpecialization("guidanceSeedingSowingExtension", "GuidanceSeedingSowingExtension", Utils.getFilename("src/vehicle/GuidanceSeedingSowingExtension.lua", modDirectory), nil)

    for typeName, typeEntry in pairs(vehicleTypeManager:getVehicleTypes()) do
        if SpecializationUtil.hasSpecialization(SowingMachine, typeEntry.specializations) then
            vehicleTypeManager:addSpecialization(typeName, modName .. ".guidanceSeedingTramLines")
            vehicleTypeManager:addSpecialization(typeName, modName .. ".guidanceSeedingSowingExtension")
        end
    end
end
