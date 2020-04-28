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
end

function GuidanceSeedingSowingExtension.registerOverwrittenFunctions(vehicleType)
end

function GuidanceSeedingSowingExtension.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", GuidanceSeedingSowingExtension)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", GuidanceSeedingSowingExtension)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", GuidanceSeedingSowingExtension)
end

---Called onLoad.
function GuidanceSeedingSowingExtension:onLoad(savegame)
    self.spec_guidanceSeedingSowingExtension = self[("spec_%s.guidanceSeedingSowingExtension"):format(g_guidanceSeeding.modName)]
    local spec = self.spec_guidanceSeedingSowingExtension

    spec.fillUnitsToCheck = {}
    spec.fillUnitIndexForFrame = 1 -- current frame fillUnit to check
    table.insert(spec.fillUnitsToCheck, Utils.getNoNil(self:getFirstValidFillUnitToFill(FillType.SEEDS, true), 1))

    local fillUnitIndexFertilizer = self:getFirstValidFillUnitToFill(FillType.FERTILIZER, true)
    if fillUnitIndexFertilizer ~= nil then
        table.insert(spec.fillUnitsToCheck, fillUnitIndexFertilizer)
    end

    local fillUnitIndexLiquidFertilizer = self:getFirstValidFillUnitToFill(FillType.LIQUIDFERTILIZER, true)
    if fillUnitIndexLiquidFertilizer ~= nil then
        table.insert(spec.fillUnitsToCheck, fillUnitIndexLiquidFertilizer)
    end

    if self.isClient then
        --TODO: cleanup with better loading.
        spec.samples = {}
        local sampleLowered = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.guidanceSeeding.sounds", "lowered", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
        if sampleLowered == nil then
            sampleLowered = g_soundManager:cloneSample(g_guidanceSeeding.samples.lowered, self.components[1].node, self)
        end

        spec.samples.lowered = sampleLowered
        spec.playedLowered = false

        local sampleHighered = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.guidanceSeeding.sounds", "highered", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
        if sampleHighered == nil then
            sampleHighered = g_soundManager:cloneSample(g_guidanceSeeding.samples.highered, self.components[1].node, self)
        end

        spec.samples.highered = sampleHighered

        local sampleEmpty = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.guidanceSeeding.sounds", "empty", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
        if sampleEmpty == nil then
            sampleEmpty = g_soundManager:cloneSample(g_guidanceSeeding.samples.empty, self.components[1].node, self)
        end

        spec.samples.empty = sampleEmpty
        spec.playedEmpty = false

        local sampleTramline = g_soundManager:loadSampleFromXML(self.xmlFile, "vehicle.guidanceSeeding.sounds", "tramline", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
        if sampleTramline == nil then
            sampleTramline = g_soundManager:cloneSample(g_guidanceSeeding.samples.tramline, self.components[1].node, self)
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
function GuidanceSeedingSowingExtension:onUpdate(dt)
    local spec = self.spec_guidanceSeedingSowingExtension

    if self.isClient then
        if self:getIsActiveForInput() and self:getIsTurnedOn() then
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

            local fillUnitIndex = spec.fillUnitsToCheck[math.min(spec.fillUnitIndexForFrame, #spec.fillUnitsToCheck)]
            log(fillUnitIndex)
            local fillPercentage = MathUtil.round(self:getFillUnitFillLevelPercentage(fillUnitIndex) * 100)
            local isAlmostEmpty = fillPercentage == 5 or fillPercentage == 1
            local isEmpty = fillPercentage == 0

            --Warning when empty.
            if isEmpty then
                if not g_soundManager:getIsSamplePlaying(spec.samples.empty) then
                    g_soundManager:playSample(spec.samples.empty)
                end
            elseif not isAlmostEmpty then
                if g_soundManager:getIsSamplePlaying(spec.samples.empty) then
                    g_soundManager:stopSample(spec.samples.empty)
                end
            end

            --Headsup warning when almost empty.
            if not spec.playedEmpty then
                if isAlmostEmpty then
                    g_soundManager:playSample(spec.samples.empty, 1)
                    spec.playedEmpty = true
                end
            else
                if not isAlmostEmpty then
                    spec.playedEmpty = false
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

