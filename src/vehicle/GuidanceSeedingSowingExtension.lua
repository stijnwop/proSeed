----------------------------------------------------------------------------------------------------
-- GuidanceSeedingSowingExtension
----------------------------------------------------------------------------------------------------
-- Purpose: Specialization for extending the sowing machine.
--
-- Copyright (c) Wopster, 2020
----------------------------------------------------------------------------------------------------

---@class GuidanceSeedingSowingExtension
GuidanceSeedingSowingExtension = {}
GuidanceSeedingSowingExtension.MOD_NAME = g_currentModName

function GuidanceSeedingSowingExtension.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(SowingMachine, specializations)
end

function GuidanceSeedingSowingExtension.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "toggleSowingSounds", GuidanceSeedingSowingExtension.toggleSowingSounds)
    SpecializationUtil.registerFunction(vehicleType, "toggleSowingFertilizer", GuidanceSeedingSowingExtension.toggleSowingFertilizer)
    SpecializationUtil.registerFunction(vehicleType, "setSowingData(", GuidanceSeedingSowingExtension.setSowingData)
end

function GuidanceSeedingSowingExtension.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "processSowingMachineArea", GuidanceSeedingSowingExtension.processSowingMachineArea)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "removeActionEvents", GuidanceSeedingSowingExtension.removeActionEvents)
end

function GuidanceSeedingSowingExtension.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", GuidanceSeedingSowingExtension)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", GuidanceSeedingSowingExtension)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", GuidanceSeedingSowingExtension)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", GuidanceSeedingSowingExtension)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", GuidanceSeedingSowingExtension)
    SpecializationUtil.registerEventListener(vehicleType, "onDeactivate", GuidanceSeedingSowingExtension)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", GuidanceSeedingSowingExtension)
end

---Called onLoad.
function GuidanceSeedingSowingExtension:onLoad(savegame)
    self.spec_guidanceSeedingSowingExtension = self[("spec_%s.guidanceSeedingSowingExtension"):format(g_guidanceSeeding.modName)]
    local spec = self.spec_guidanceSeedingSowingExtension

    spec.fillUnitsToCheck = {}
    spec.fillUnitIndexForFrame = 1 -- current frame fillUnit to check
    table.insert(spec.fillUnitsToCheck, { fillUnitIndex = Utils.getNoNil(self:getFirstValidFillUnitToFill(FillType.SEEDS, true), 1), didPlay = false })

    --Insert solid fertilizer if present.
    local fillUnitIndexFertilizer = self:getFirstValidFillUnitToFill(FillType.FERTILIZER, true)
    if fillUnitIndexFertilizer ~= nil then
        table.insert(spec.fillUnitsToCheck, { fillUnitIndex = fillUnitIndexFertilizer, didPlay = false })
    end

    --Insert liquid fertilizer if present.
    local fillUnitIndexLiquidFertilizer = self:getFirstValidFillUnitToFill(FillType.LIQUIDFERTILIZER, true)
    if fillUnitIndexLiquidFertilizer ~= nil then
        table.insert(spec.fillUnitsToCheck, { fillUnitIndex = fillUnitIndexLiquidFertilizer, didPlay = false })
    end

    spec.allowSound = false
    spec.allowFertilizer = false

    if self.isClient then
        --TODO: cleanup with better loading.
        local linkNode = self.components[1].node
        if self.getInputAttacherJoints ~= nil then
            local inputAttacherJoint = self:getInputAttacherJoints()[1]
            linkNode = inputAttacherJoint.node
        end

        spec.samples = {}
        local sampleLowered = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.guidanceSeeding.sounds", "lowered", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
        if sampleLowered == nil then
            sampleLowered = g_soundManager:cloneSample(g_guidanceSeeding.samples.lowered, linkNode, self)
        end

        spec.samples.lowered = sampleLowered
        spec.playedLowered = false

        local sampleHighered = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.guidanceSeeding.sounds", "highered", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
        if sampleHighered == nil then
            sampleHighered = g_soundManager:cloneSample(g_guidanceSeeding.samples.highered, linkNode, self)
        end

        spec.samples.highered = sampleHighered

        local sampleEmpty = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.guidanceSeeding.sounds", "empty", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
        if sampleEmpty == nil then
            sampleEmpty = g_soundManager:cloneSample(g_guidanceSeeding.samples.empty, linkNode, self)
        end

        spec.samples.empty = sampleEmpty
        spec.activeFillUnitIndexEmptySound = nil
        spec.activeFillUnitIndexAlmostEmptySound = nil

        local sampleTramline = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.guidanceSeeding.sounds", "tramline", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
        if sampleTramline == nil then
            sampleTramline = g_soundManager:cloneSample(g_guidanceSeeding.samples.tramline, linkNode, self)
        end

        spec.samples.tramline = sampleTramline
        spec.playedTramline = false
    end
end

function GuidanceSeedingSowingExtension:onDelete()
    local spec = self.spec_guidanceSeedingSowingExtension

    if self.isClient then
        g_soundManager:deleteSamples(spec.samples)
    end
end

function GuidanceSeedingSowingExtension:onReadStream(streamId, connection)
    local allowSound = streamReadBool(streamId)
    local allowFertilizer = streamReadBool(streamId)
    self:setSowingData(allowSound, allowFertilizer, true)
end

function GuidanceSeedingSowingExtension:onWriteStream(streamId, connection)
    local spec = self.spec_guidanceSeedingSowingExtension
    streamWriteBool(streamId, spec.allowSound)
    streamWriteBool(streamId, spec.allowFertilizer)
end

function GuidanceSeedingSowingExtension:onUpdate(dt)
    local spec = self.spec_guidanceSeedingSowingExtension

    if self.isClient then
        if self:getIsActiveForInput() and self:getIsTurnedOn() and spec.allowSound then
            local isLowered = self:getIsLowered()

            ---TODO: cleanup with function playing.
            if not spec.playedLowered then
                if isLowered then
                    g_soundManager:playSample(spec.samples.lowered, 1)
                    spec.playedLowered = true
                end
            else
                if not isLowered then
                    spec.playedLowered = false
                end
            end

            if not isLowered then
                if not g_soundManager:getIsSamplePlaying(spec.samples.highered) then
                    g_soundManager:playSample(spec.samples.highered)
                end
            else
                if g_soundManager:getIsSamplePlaying(spec.samples.highered) then
                    g_soundManager:stopSample(spec.samples.highered)
                end
            end

            local specTramLines = self.spec_guidanceSeedingTramLines
            if specTramLines ~= nil then
                if not spec.playedTramline then
                    if specTramLines.createTramLines then
                        g_soundManager:playSample(spec.samples.tramline, 1)
                        spec.playedTramline = true
                    end
                else
                    if not specTramLines.createTramLines then
                        spec.playedTramline = false
                    end
                end
            end

            local desc = spec.fillUnitsToCheck[math.min(spec.fillUnitIndexForFrame, #spec.fillUnitsToCheck)]
            local fillPercentage = MathUtil.round(self:getFillUnitFillLevelPercentage(desc.fillUnitIndex) * 100)
            local isAlmostEmpty = fillPercentage == 5 or fillPercentage == 1

            local canPlayEmptySound = spec.activeFillUnitIndexEmptySound == desc.fillUnitIndex or spec.activeFillUnitIndexEmptySound == nil
            local isEmpty = fillPercentage == 0

            --Warning when empty.
            if isEmpty and canPlayEmptySound then
                if not g_soundManager:getIsSamplePlaying(spec.samples.empty) then
                    g_soundManager:playSample(spec.samples.empty)
                    spec.activeFillUnitIndexEmptySound = desc.fillUnitIndex
                end
            elseif not isAlmostEmpty and canPlayEmptySound then
                if g_soundManager:getIsSamplePlaying(spec.samples.empty) then
                    g_soundManager:stopSample(spec.samples.empty)
                    spec.activeFillUnitIndexEmptySound = nil
                end
            end

            --Headsup warning when almost empty.
            if not desc.didPlay then
                if isAlmostEmpty then
                    g_soundManager:playSample(spec.samples.empty, 1)
                    desc.didPlay = true
                end
            else
                if not isAlmostEmpty then
                    desc.didPlay = false
                end
            end

            -- We only check one per frame.
            spec.fillUnitIndexForFrame = spec.fillUnitIndexForFrame + 1
            if spec.fillUnitIndexForFrame > #spec.fillUnitsToCheck then
                spec.fillUnitIndexForFrame = 1
            end
        end
    end
end

function GuidanceSeedingSowingExtension:onDeactivate()
    local spec = self.spec_guidanceSeedingSowingExtension
    if self.isClient then
        g_soundManager:stopSamples(spec.samples)
        spec.playedTramline = false
        spec.playedLowered = false
    end
end

function GuidanceSeedingSowingExtension:removeActionEvents(superFunc, ...)
    local hud = g_guidanceSeeding.hud
    if hud:isVehicleActive(self) then
        hud:setVehicle(nil)
    end

    return superFunc(self, ...)
end

---Toggle playing sound.
function GuidanceSeedingSowingExtension:toggleSowingSounds()
    local spec = self.spec_guidanceSeedingSowingExtension
    local allowSound = not spec.allowSound

    if not allowSound then
        if self.isClient then
            g_soundManager:stopSamples(spec.samples)
            spec.playedTramline = false
            spec.playedLowered = false
        end
    end

    self:setSowingData(allowSound, spec.allowFertilizer)
    return allowSound
end

---Toggle usage of fertilizer.
function GuidanceSeedingSowingExtension:toggleSowingFertilizer()
    local spec = self.spec_guidanceSeedingSowingExtension
    local allowFertilizer = not spec.allowFertilizer
    self:setSowingData(spec.allowSound, allowFertilizer)
    return allowFertilizer
end

---Set the active sowing data and sync with players and server.
function GuidanceSeedingSowingExtension:setSowingData(allowSound, allowFertilizer, noEventSend)
    local spec = self.spec_guidanceSeedingSowingExtension

    GuidanceSeedingDataEvent.sendEvent(self, allowSound, allowFertilizer, noEventSend)
    spec.allowSound = allowSound
    spec.allowFertilizer = allowFertilizer
end

---Overwrite sowing area processing to block fertilizer when set.
function GuidanceSeedingSowingExtension:processSowingMachineArea(superFunc, workArea, dt)
    local spec = self.spec_guidanceSeedingSowingExtension
    if not spec.allowFertilizer then
        local spec_sprayer = self.spec_sprayer
        if spec_sprayer ~= nil then
            spec_sprayer.workAreaParameters.sprayFillLevel = 0
        end
    end

    local changedArea, totalArea = superFunc(self, workArea, dt)
    return changedArea, totalArea
end

function GuidanceSeedingSowingExtension:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if self.isClient then
        local spec = self.spec_guidanceSeedingSowingExtension
        self:clearActionEventsTable(spec.actionEvents)

        if isActiveForInput then
            --TODO: add if active
            local hud = g_guidanceSeeding.hud
            hud:setVehicle(self)

            local _, actionEventToggleMouseCursor = self:addActionEvent(spec.actionEvents, InputAction.GS_TOGGLE_MOUSE_CURSOR, self, GuidanceSeedingSowingExtension.actionEventToggleMouseCursor, false, true, false, true, nil, nil, true)
            g_inputBinding:setActionEventText(actionEventToggleMouseCursor, g_i18n:getText("function_toggleMouseCursor"))
            g_inputBinding:setActionEventTextVisibility(actionEventToggleMouseCursor, false)
        end
    end
end

function GuidanceSeedingSowingExtension.actionEventToggleMouseCursor(self, actionName, inputValue, callbackState, isAnalog)
    --We need to trigger the cursor somewhere.
    g_guidanceSeeding.hud:toggleMouseCursor()
end
