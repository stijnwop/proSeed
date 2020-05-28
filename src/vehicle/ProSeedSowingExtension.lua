----------------------------------------------------------------------------------------------------
-- ProSeedSowingExtension
----------------------------------------------------------------------------------------------------
-- Purpose: Specialization for extending the sowing machine.
--
-- Copyright (c) Wopster, 2020
----------------------------------------------------------------------------------------------------

---@class ProSeedSowingExtension
ProSeedSowingExtension = {}
ProSeedSowingExtension.MOD_NAME = g_currentModName

function ProSeedSowingExtension.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(SowingMachine, specializations)
end

function ProSeedSowingExtension.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "toggleSowingSounds", ProSeedSowingExtension.toggleSowingSounds)
    SpecializationUtil.registerFunction(vehicleType, "toggleSowingFertilizer", ProSeedSowingExtension.toggleSowingFertilizer)
    SpecializationUtil.registerFunction(vehicleType, "setSowingData", ProSeedSowingExtension.setSowingData)
    SpecializationUtil.registerFunction(vehicleType, "resetVehicleHectareSession", ProSeedSowingExtension.resetVehicleHectareSession)
end

function ProSeedSowingExtension.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "processSowingMachineArea", ProSeedSowingExtension.processSowingMachineArea)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "removeActionEvents", ProSeedSowingExtension.removeActionEvents)
end

function ProSeedSowingExtension.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", ProSeedSowingExtension)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", ProSeedSowingExtension)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", ProSeedSowingExtension)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", ProSeedSowingExtension)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", ProSeedSowingExtension)
    SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", ProSeedSowingExtension)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", ProSeedSowingExtension)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", ProSeedSowingExtension)
    SpecializationUtil.registerEventListener(vehicleType, "onDeactivate", ProSeedSowingExtension)
    SpecializationUtil.registerEventListener(vehicleType, "onEndWorkAreaProcessing", ProSeedSowingExtension)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", ProSeedSowingExtension)
end

---Called on load.
function ProSeedSowingExtension:onLoad(savegame)
    self.spec_proSeedSowingExtension = self[("spec_%s.proSeedSowingExtension"):format(g_proSeed.modName)]
    local spec = self.spec_proSeedSowingExtension

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

    spec.sessionHectares = 0
    spec.totalHectares = 0
    spec.seedUsage = 0
    spec.hectareTime = 0
    spec.hectarePerHour = 0

    spec.sessionHectaresSent = 0
    spec.totalHectaresSent = 0

    spec.allowSound = false
    spec.allowFertilizer = false

    if self.isClient then
        local linkNode = self.components[1].node
        if self.getInputAttacherJoints ~= nil then
            local _, inputAttacherJoint = next(self:getInputAttacherJoints())
            if inputAttacherJoint ~= nil then
                linkNode = inputAttacherJoint.node
            end
        end

        spec.samples = {}
        local function loadSample(name)
            local sample = g_soundManager:loadSample2DFromXML(self.xmlFile, "vehicle.proSeed.sounds", name, self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
            if sample == nil then
                sample = g_soundManager:cloneSample(g_proSeed.samples[name], linkNode, self)
            end

            return sample
        end

        spec.samples.lowered = loadSample("lowered")
        spec.samples.highered = loadSample("highered")
        spec.samples.empty = loadSample("empty")
        spec.samples.tramline = loadSample("tramline")

        spec.playedLowered = false
        spec.playedTramline = false
        spec.playedTramlineTimer = 0
        spec.playedTramlineTimerInterval = 5000 --ms
        spec.activeFillUnitIndexEmptySound = nil
        spec.activeFillUnitIndexAlmostEmptySound = nil
    end

    spec.dirtyFlag = self:getNextDirtyFlag()
end

---Called on post load.
function ProSeedSowingExtension:onPostLoad(savegame)
    local spec = self.spec_proSeedSowingExtension

    if savegame ~= nil and not savegame.resetVehicles then
        local key = ("%s.%s.proSeedSowingExtension"):format(savegame.key, g_proSeed.modName)
        spec.allowSound = Utils.getNoNil(getXMLBool(savegame.xmlFile, key .. "#allowSound"), spec.allowSound)
        spec.allowFertilizer = Utils.getNoNil(getXMLBool(savegame.xmlFile, key .. "#allowFertilizer"), spec.allowFertilizer)

        spec.sessionHectares = Utils.getNoNil(getXMLFloat(savegame.xmlFile, key .. "#sessionHectares"), spec.sessionHectares)
        spec.totalHectares = Utils.getNoNil(getXMLFloat(savegame.xmlFile, key .. "#totalHectares"), spec.totalHectares)
        spec.seedUsage = Utils.getNoNil(getXMLFloat(savegame.xmlFile, key .. "#seedUsage"), spec.seedUsage)
        spec.hectareTime = Utils.getNoNil(getXMLFloat(savegame.xmlFile, key .. "#hectareTime"), spec.hectareTime)
        spec.hectarePerHour = Utils.getNoNil(getXMLFloat(savegame.xmlFile, key .. "#hectarePerHour"), spec.hectarePerHour)
    end
end

---Called on delete.
function ProSeedSowingExtension:onDelete()
    local spec = self.spec_proSeedSowingExtension

    if self.isClient then
        g_soundManager:deleteSamples(spec.samples)
    end
end

---Called on save.
function ProSeedSowingExtension:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_proSeedSowingExtension

    setXMLBool(xmlFile, key .. "#allowSound", spec.allowSound)
    setXMLBool(xmlFile, key .. "#allowFertilizer", spec.allowFertilizer)

    setXMLFloat(xmlFile, key .. "#sessionHectares", spec.sessionHectares)
    setXMLFloat(xmlFile, key .. "#totalHectares", spec.totalHectares)
    setXMLFloat(xmlFile, key .. "#seedUsage", spec.seedUsage)
    setXMLFloat(xmlFile, key .. "#hectareTime", spec.hectareTime)
    setXMLFloat(xmlFile, key .. "#hectarePerHour", spec.hectarePerHour)
end

---Called on read stream.
function ProSeedSowingExtension:onReadStream(streamId, connection)
    local spec = self.spec_proSeedSowingExtension
    local allowSound = streamReadBool(streamId)
    local allowFertilizer = streamReadBool(streamId)
    self:setSowingData(allowSound, allowFertilizer, true)
    spec.sessionHectares = streamReadFloat32(streamId)
    spec.totalHectares = streamReadFloat32(streamId)
    spec.hectareTime = streamReadFloat32(streamId)
    spec.seedUsage = streamReadFloat32(streamId)
end

---Called on write stream.
function ProSeedSowingExtension:onWriteStream(streamId, connection)
    local spec = self.spec_proSeedSowingExtension
    streamWriteBool(streamId, spec.allowSound)
    streamWriteBool(streamId, spec.allowFertilizer)
    streamWriteFloat32(streamId, spec.sessionHectares)
    streamWriteFloat32(streamId, spec.totalHectares)
    streamWriteFloat32(streamId, spec.hectareTime)
    streamWriteFloat32(streamId, spec.seedUsage)
end

---Called on read update stream.
function ProSeedSowingExtension:onReadUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then
        local spec = self.spec_proSeedSowingExtension

        if streamReadBool(streamId) then
            spec.sessionHectares = streamReadFloat32(streamId)
            spec.totalHectares = streamReadFloat32(streamId)
            spec.hectareTime = streamReadFloat32(streamId)
            spec.seedUsage = streamReadFloat32(streamId)

            if spec.hectareTime > 0 then
                spec.hectarePerHour = spec.sessionHectares / spec.hectareTime
            end
        end
    end
end

---Called on write update stream.
function ProSeedSowingExtension:onWriteUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then
        local spec = self.spec_proSeedSowingExtension

        if streamWriteBool(streamId, bitAND(dirtyMask, spec.dirtyFlag) ~= 0) then
            streamWriteFloat32(streamId, spec.sessionHectares)
            streamWriteFloat32(streamId, spec.totalHectares)
            streamWriteFloat32(streamId, spec.hectareTime)
            streamWriteFloat32(streamId, spec.seedUsage)
        end
    end
end

---Called on update.
function ProSeedSowingExtension:onUpdate(dt)
    local spec = self.spec_proSeedSowingExtension

    if self.isClient and spec.allowSound and self:getIsActiveForInput(true) then
        local specTramLines = self.spec_proSeedTramLines
        if specTramLines ~= nil then
            if not spec.playedTramline then
                if specTramLines.createTramLines then
                    g_soundManager:playSample(spec.samples.tramline, 1)
                    spec.playedTramline = true
                    spec.playedTramlineTimer = 0
                end
            else
                if specTramLines.createTramLines then
                    spec.playedTramlineTimer = spec.playedTramlineTimer + dt

                    if spec.playedTramlineTimer > spec.playedTramlineTimerInterval then
                        spec.playedTramlineTimer = 0
                        g_soundManager:playSample(spec.samples.tramline, 1)
                    end
                end

                if not specTramLines.createTramLines then
                    spec.playedTramline = false
                end
            end
        end

        if self:getIsTurnedOn() then
            local isLowered = self:getIsImplementChainLowered()

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

            local desc = spec.fillUnitsToCheck[math.min(spec.fillUnitIndexForFrame, #spec.fillUnitsToCheck)]
            local fillPercentage = MathUtil.round(self:getFillUnitFillLevelPercentage(desc.fillUnitIndex) * 100)
            local isAlmostEmpty = fillPercentage == 5 or fillPercentage == 1

            local canPlayEmptySound = spec.activeFillUnitIndexEmptySound == desc.fillUnitIndex or spec.activeFillUnitIndexEmptySound == nil
            local isEmpty = fillPercentage == 0

            if not spec.allowFertilizer and not self:getFillUnitSupportsFillType(desc.fillUnitIndex, FillType.SEEDS) then
                canPlayEmptySound = false
                isAlmostEmpty = false
            end

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

function ProSeedSowingExtension:onDeactivate()
    local spec = self.spec_proSeedSowingExtension
    if self.isClient then
        g_soundManager:stopSamples(spec.samples)
        spec.playedTramline = false
        spec.playedLowered = false
    end
end

function ProSeedSowingExtension:removeActionEvents(superFunc, ...)
    local hud = g_proSeed.hud
    if hud:isVehicleActive(self) then
        hud:setVehicle(nil)
    end

    return superFunc(self, ...)
end

---Toggle playing sound.
function ProSeedSowingExtension:toggleSowingSounds()
    local spec = self.spec_proSeedSowingExtension
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
function ProSeedSowingExtension:toggleSowingFertilizer()
    local spec = self.spec_proSeedSowingExtension
    local allowFertilizer = not spec.allowFertilizer
    self:setSowingData(spec.allowSound, allowFertilizer)
    return allowFertilizer
end

---Set the active sowing data and sync with players and server.
function ProSeedSowingExtension:setSowingData(allowSound, allowFertilizer, noEventSend)
    local spec = self.spec_proSeedSowingExtension

    ProSeedDataEvent.sendEvent(self, allowSound, allowFertilizer, noEventSend)
    spec.allowSound = allowSound
    spec.allowFertilizer = allowFertilizer
end

---Reset session hectare counter.
function ProSeedSowingExtension:resetVehicleHectareSession(noEventSend)
    local spec = self.spec_proSeedSowingExtension
    ProSeedResetHectareSessionEvent.sendEvent(self, noEventSend)
    spec.sessionHectares = 0
end

---Overwrite sowing area processing to block fertilizer when set.
function ProSeedSowingExtension:processSowingMachineArea(superFunc, workArea, dt)
    local spec = self.spec_proSeedSowingExtension
    if not spec.allowFertilizer then
        local spec_sprayer = self.spec_sprayer
        if spec_sprayer ~= nil then
            spec_sprayer.workAreaParameters.sprayFillLevel = 0
        end
    end

    local changedArea, totalArea = superFunc(self, workArea, dt)
    return changedArea, totalArea
end

function ProSeedSowingExtension:onEndWorkAreaProcessing(dt, hasProcessed)
    if self.isServer then
        local spec = self.spec_proSeedSowingExtension

        local workAreaParameters = self.spec_sowingMachine.workAreaParameters

        if workAreaParameters.lastChangedArea > 0 then
            local fruitDesc = g_fruitTypeManager:getFruitTypeByIndex(workAreaParameters.seedsFruitType)
            local lastHa = MathUtil.areaToHa(workAreaParameters.lastChangedArea, g_currentMission:getFruitPixelsToSqm())
            local usage = fruitDesc.seedUsagePerSqm * lastHa * 10000
            local ha = MathUtil.areaToHa(workAreaParameters.lastStatsArea, g_currentMission:getFruitPixelsToSqm()) -- 4096px are mapped to 2048m

            local damage = self:getVehicleDamage()
            if damage > 0 then
                usage = usage * (1 + damage * SowingMachine.DAMAGED_USAGE_INCREASE)
            end

            spec.sessionHectares = spec.sessionHectares + ha
            spec.totalHectares = spec.totalHectares + ha
            spec.seedUsage = usage

            local sownTimeMinutes = dt / (1000 * 60)
            local sownTimeHours = sownTimeMinutes / 60
            spec.hectareTime = spec.hectareTime + sownTimeHours

            if spec.hectareTime > 0 then
                spec.hectarePerHour = spec.sessionHectares / spec.hectareTime
            end

            if math.abs(spec.sessionHectares - spec.sessionHectaresSent) > 0.01
                or math.abs(spec.totalHectares - spec.totalHectaresSent) > 0.01 then
                spec.sessionHectaresSent = spec.sessionHectares
                spec.totalHectaresSent = spec.totalHectares
                self:raiseDirtyFlags(spec.dirtyFlag)
            end
        end
    end
end

function ProSeedSowingExtension:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if self.isClient then
        local spec = self.spec_proSeedSowingExtension
        self:clearActionEventsTable(spec.actionEvents)

        if isActiveForInputIgnoreSelection then
            --TODO: add if active
            local hud = g_proSeed.hud
            hud:setVehicle(self)

            local _, actionEventToggleMouseCursor = self:addActionEvent(spec.actionEvents, InputAction.PS_TOGGLE_MOUSE_CURSOR, self, ProSeedSowingExtension.actionEventToggleMouseCursor, false, true, false, true, nil, nil, true)
            g_inputBinding:setActionEventText(actionEventToggleMouseCursor, g_i18n:getText("action_toggleMouseCursor"))
            g_inputBinding:setActionEventTextVisibility(actionEventToggleMouseCursor, true)
            g_inputBinding:setActionEventTextPriority(actionEventToggleMouseCursor, GS_PRIO_LOW)
        end
    end
end

function ProSeedSowingExtension.actionEventToggleMouseCursor(self, actionName, inputValue, callbackState, isAnalog)
    --We need to trigger the cursor somewhere.
    g_proSeed.hud:toggleMouseCursor()
end
