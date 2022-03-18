----------------------------------------------------------------------------------------------------
-- ProSeed
----------------------------------------------------------------------------------------------------
-- Purpose: Main class to handle the ProSeed mod.
--
-- Copyright (c) Wopster, 2020
----------------------------------------------------------------------------------------------------

---@class ProSeed
ProSeed = {}

local ProSeed_mt = Class(ProSeed)

function ProSeed.new(mission, i18n, inputBinding, gui, soundManager, modDirectory, modName)
    local self = setmetatable({}, ProSeed_mt)

    self.version = 1.0
    self.isServer = mission:getIsServer()
    self.isClient = mission:getIsClient()
    self.modDirectory = modDirectory
    self.modName = modName

    --Debug flags
    self.debug = false

    self.mission = mission
    self.soundManager = soundManager

    local uiFilename = Utils.getFilename("resources/hud/proSeed.png", modDirectory)
    self.hud = InteractiveHUD.new(mission, i18n, inputBinding, gui, modDirectory, uiFilename)

    self:loadSamples()

    return self
end

function ProSeed:delete()
    self.soundManager:deleteSamples(self.samples)
    self.hud:delete()
end

function ProSeed:onMissionLoaded()
    self.hud:load()
end

---Called when mission is loaded.
function ProSeed:onMissionLoadFromSavegame(xmlFile)
    self.hud:loadFromXMLFile(xmlFile)
end

---Called when mission is being saved with our own xml file.
function ProSeed:onMissionSaveToSavegame(xmlFile)
    self.hud:saveToXMLFile(xmlFile)
end

function ProSeed:mouseEvent(posX, posY, isDown, isUp, button)
    self.hud:mouseEvent(posX, posY, isDown, isUp, button)
end

function ProSeed:update(dt)
    self.hud:update(dt)
end

function ProSeed:loadSamples()
    self.samples = {}

    local xmlFile = loadXMLFile("ProSeedSamples", Utils.getFilename("resources/sounds/sounds.xml", self.modDirectory))
    if xmlFile ~= nil then
        self.samples.lowered = self.soundManager:loadSample2DFromXML(xmlFile, "vehicle.sounds", "lowered", self.modDirectory, 1, AudioGroup.VEHICLE, nil, nil)
        self.samples.highered = self.soundManager:loadSample2DFromXML(xmlFile, "vehicle.sounds", "highered", self.modDirectory, 1, AudioGroup.VEHICLE, nil, nil)
        self.samples.empty = self.soundManager:loadSample2DFromXML(xmlFile, "vehicle.sounds", "empty", self.modDirectory, 1, AudioGroup.VEHICLE, nil, nil)
        self.samples.tramline = self.soundManager:loadSample2DFromXML(xmlFile, "vehicle.sounds", "tramline", self.modDirectory, 1, AudioGroup.VEHICLE, nil, nil)

        delete(xmlFile)
    end
end

function ProSeed.installSpecializations(vehicleTypeManager, specializationManager, modDirectory, modName)
    specializationManager:addSpecialization("proSeedTramLines", "ProSeedTramLines", Utils.getFilename("src/vehicle/ProSeedTramLines.lua", modDirectory), nil)
    specializationManager:addSpecialization("proSeedSowingExtension", "ProSeedSowingExtension", Utils.getFilename("src/vehicle/ProSeedSowingExtension.lua", modDirectory), nil)

    for typeName, typeEntry in pairs(vehicleTypeManager:getTypes()) do
        if SpecializationUtil.hasSpecialization(SowingMachine, typeEntry.specializations) then
            vehicleTypeManager:addSpecialization(typeName, modName .. ".proSeedTramLines")
            vehicleTypeManager:addSpecialization(typeName, modName .. ".proSeedSowingExtension")
        end
    end
end
