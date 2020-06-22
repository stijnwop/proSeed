----------------------------------------------------------------------------------------------------
-- ProSeedTramLines
----------------------------------------------------------------------------------------------------
-- Purpose: Specialization for creation tramlines.
--
-- Copyright (c) Wopster, 2020
----------------------------------------------------------------------------------------------------

---Create guidance node for area calculation.
local function createGuideNode(name, linkNode, x, y, z)
    local node = createTransformGroup(name)
    link(linkNode, node)
    setTranslation(node, x or 0, y or 0, z or 0)
    return node
end

---Exclude ridged markers from workArea calculation
local skipWorkAreas = {
    ["processRidgeMarkerArea"] = true
}

---Returns true when function name is not being skipped and when the type is different from `AUXILIARY`, false otherwise.
local function isWorkAreaValid(workArea)
    if skipWorkAreas[workArea.functionName] ~= nil then
        return false
    end

    return workArea.type ~= WorkAreaType.AUXILIARY
end

---Debug line area.
local function drawArea(area, r, g, b, a)
    local x0, _, z0 = getWorldTranslation(area.start)
    local x1, _, z1 = getWorldTranslation(area.width)
    local x2, _, z2 = getWorldTranslation(area.height)
    DebugUtil.drawDebugNode(area.start, "lineStart")
    DebugUtil.drawDebugNode(area.width, "lineWidth")
    DebugUtil.drawDebugNode(area.height, "lineHeight")
    local x, z, widthX, widthZ, heightX, heightZ = MathUtil.getXZWidthAndHeight(x0, z0, x1, z1, x2, z2)
    DebugUtil.drawDebugParallelogram(x, z, widthX, widthZ, heightX, heightZ, 0, r, g, b, a)
end

---@class ProSeedTramLines
ProSeedTramLines = {}
ProSeedTramLines.MOD_NAME = g_currentModName

ProSeedTramLines.TRAMLINE_MAX_WIDTH = 72 -- m

ProSeedTramLines.TRAMLINE_SPACING = 1.4 -- m
ProSeedTramLines.TRAMELINE_WIDTH = 0.5 -- m
ProSeedTramLines.TRAMELINE_HEIGHT_OFFSET = 0.3 -- offset to drop our workArea behind the seeder

ProSeedTramLines.SHUTOFF_MODE_OFF = 0
ProSeedTramLines.SHUTOFF_MODE_LEFT = 1
ProSeedTramLines.SHUTOFF_MODE_RIGHT = 2

ProSeedTramLines.TRAMLINE_MODE_MANUAL = 0
ProSeedTramLines.TRAMLINE_MODE_SEMI = 1
ProSeedTramLines.TRAMLINE_MODE_AUTO = 2

ProSeedTramLines.TRAMLINE_MODE_TO_KEY = {
    [ProSeedTramLines.TRAMLINE_MODE_AUTO] = "auto",
    [ProSeedTramLines.TRAMLINE_MODE_SEMI] = "semi",
    [ProSeedTramLines.TRAMLINE_MODE_MANUAL] = "manual"
}

ProSeedTramLines.TRAMLINE_MIM_PERIODIC_SEQUENCE = 2 -- minimum sequence is 1.

function ProSeedTramLines.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(SowingMachine, specializations)
end

function ProSeedTramLines.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "createTramLineAreas", ProSeedTramLines.createTramLineAreas)
    SpecializationUtil.registerFunction(vehicleType, "setTramLineDistance", ProSeedTramLines.setTramLineDistance)
    SpecializationUtil.registerFunction(vehicleType, "setTramLineData", ProSeedTramLines.setTramLineData)
    SpecializationUtil.registerFunction(vehicleType, "setCurrentLane", ProSeedTramLines.setCurrentLane)
    SpecializationUtil.registerFunction(vehicleType, "setTramLineMode", ProSeedTramLines.setTramLineMode)
    SpecializationUtil.registerFunction(vehicleType, "setHalfSideShutoffMode", ProSeedTramLines.setHalfSideShutoffMode)
    SpecializationUtil.registerFunction(vehicleType, "isHalfSideShutoffActive", ProSeedTramLines.isHalfSideShutoffActive)
    SpecializationUtil.registerFunction(vehicleType, "canActivateHalfSideShutoff", ProSeedTramLines.canActivateHalfSideShutoff)
    SpecializationUtil.registerFunction(vehicleType, "togglePreMarkersState", ProSeedTramLines.togglePreMarkersState)
end

function ProSeedTramLines.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", ProSeedTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", ProSeedTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", ProSeedTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", ProSeedTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", ProSeedTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", ProSeedTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", ProSeedTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", ProSeedTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", ProSeedTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onEndWorkAreaProcessing", ProSeedTramLines)
end

---Called on load.
function ProSeedTramLines:onLoad(savegame)
    self.spec_proSeedTramLines = self[("spec_%s.proSeedTramLines"):format(g_proSeed.modName)]
    local spec = self.spec_proSeedTramLines

    local width, center, workAreaIndex = ProSeedTramLines.getMaxWorkAreaWidth(self)

    spec.workingWidth = width
    spec.workingWidthRounded = MathUtil.round(width * 2) / 2 -- round to the nearest 0.5
    spec.tramlinesAreas, spec.tramlinesWorkAreaIndex = self:createTramLineAreas(center, workAreaIndex)

    spec.createTramLines = false
    spec.createPreMarkedTramLines = true
    spec.createTramLinesSent = false
    spec.currentLaneSent = 1

    spec.currentLane = 1
    spec.shutoffMode = ProSeedTramLines.SHUTOFF_MODE_OFF
    spec.tramLineMode = ProSeedTramLines.TRAMLINE_MODE_AUTO

    spec.isLowered = false

    spec.tramLinePeriodicSequence = ProSeedTramLines.TRAMLINE_MIM_PERIODIC_SEQUENCE
    spec.tramLineDistanceMultiplier = 1
    spec.tramLineDistance = spec.workingWidthRounded * spec.tramLineDistanceMultiplier

    local originalAreas = {}
    local node = createGuideNode("width_node", self.rootNode)
    for _, workArea in ipairs(self.spec_workArea.workAreas) do
        if isWorkAreaValid(workArea) then
            local area = {}
            area.start = { localToLocal(workArea.start, node, 0, 0, 0) }
            area.width = { localToLocal(workArea.width, node, 0, 0, 0) }
            area.height = { localToLocal(workArea.height, node, 0, 0, 0) }

            originalAreas[workArea.index] = area
        end
    end

    --Set direct planting on vanilla planters (as they all support that IRL e.g. downforce).
    if self.customEnvironment == nil then
        local storeItem = g_storeManager:getItemByXMLFilename(self.configFileName)
        if storeItem.categoryName ~= nil and storeItem.categoryName == "PLANTERS" then
            self.spec_sowingMachine.useDirectPlanting = true
        end
    end

    delete(node)

    spec.originalAreas = originalAreas
    spec.dirtyFlag = self:getNextDirtyFlag()
end

---Called on post load.
function ProSeedTramLines:onPostLoad(savegame)
    local spec = self.spec_proSeedTramLines

    if savegame ~= nil and not savegame.resetVehicles then
        local key = ("%s.%s.proSeedTramLines"):format(savegame.key, g_proSeed.modName)
        spec.isLowered = Utils.getNoNil(getXMLBool(savegame.xmlFile, key .. "#isLowered"), spec.isLowered)
        spec.createTramLines = Utils.getNoNil(getXMLBool(savegame.xmlFile, key .. "#createTramLines"), spec.createTramLines)
        spec.currentLane = Utils.getNoNil(getXMLInt(savegame.xmlFile, key .. "#currentLane"), spec.currentLane)

        local tramLineDistance = Utils.getNoNil(getXMLFloat(savegame.xmlFile, key .. "#tramLineDistance"), spec.tramLineDistance)
        local tramLinePeriodicSequence = Utils.getNoNil(getXMLInt(savegame.xmlFile, key .. "#tramLinePeriodicSequence"), spec.tramLinePeriodicSequence)
        local createPreMarkedTramLines = Utils.getNoNil(getXMLBool(savegame.xmlFile, key .. "#createPreMarkedTramLines"), spec.createPreMarkedTramLines)
        self:setTramLineData(tramLineDistance, tramLinePeriodicSequence, createPreMarkedTramLines, true)

        local tramLineMode = Utils.getNoNil(getXMLInt(savegame.xmlFile, key .. "#tramLineMode"), spec.tramLineMode)
        self:setTramLineMode(tramLineMode, true)

        local shutoffMode = Utils.getNoNil(getXMLInt(savegame.xmlFile, key .. "#shutoffMode"), spec.shutoffMode)
        self:setHalfSideShutoffMode(shutoffMode, true)
    end
end

---Called on save.
function ProSeedTramLines:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_proSeedTramLines

    setXMLBool(xmlFile, key .. "#isLowered", spec.isLowered)
    setXMLBool(xmlFile, key .. "#createTramLines", spec.createTramLines)
    setXMLInt(xmlFile, key .. "#currentLane", spec.currentLane)

    setXMLFloat(xmlFile, key .. "#tramLineDistance", spec.tramLineDistance)
    setXMLInt(xmlFile, key .. "#tramLinePeriodicSequence", spec.tramLinePeriodicSequence)
    setXMLBool(xmlFile, key .. "#createPreMarkedTramLines", spec.createPreMarkedTramLines)

    setXMLInt(xmlFile, key .. "#tramLineMode", spec.tramLineMode)
    setXMLInt(xmlFile, key .. "#shutoffMode", spec.shutoffMode)
end

---Called on read stream.
function ProSeedTramLines:onReadStream(streamId, connection)
    local spec = self.spec_proSeedTramLines
    spec.createTramLines = streamReadBool(streamId)
    spec.currentLane = streamReadInt8(streamId)

    local tramLineDistance = streamReadFloat32(streamId)
    local tramLinePeriodicSequence = streamReadInt8(streamId)
    local createPreMarkedTramLines = streamReadBool(streamId)
    self:setTramLineData(tramLineDistance, tramLinePeriodicSequence, createPreMarkedTramLines, true)

    local shutoffMode = streamReadUIntN(streamId, 2)
    self:setHalfSideShutoffMode(shutoffMode, true)
end

---Called on write stream.
function ProSeedTramLines:onWriteStream(streamId, connection)
    local spec = self.spec_proSeedTramLines
    streamWriteBool(streamId, spec.createTramLines)
    streamWriteInt8(streamId, spec.currentLane)

    streamWriteFloat32(streamId, spec.tramLineDistance)
    streamWriteInt8(streamId, spec.tramLinePeriodicSequence)
    streamWriteBool(streamId, spec.createPreMarkedTramLines)

    --Send current halfside shutoff mode.
    streamWriteUIntN(streamId, spec.shutoffMode, 2)
end

---Called on read update stream.
function ProSeedTramLines:onReadUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then
        local spec = self.spec_proSeedTramLines

        if streamReadBool(streamId) then
            spec.createTramLines = streamReadBool(streamId)
            spec.currentLane = streamReadInt8(streamId)
        end
    end
end

---Called on write update stream.
function ProSeedTramLines:onWriteUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then
        local spec = self.spec_proSeedTramLines

        if streamWriteBool(streamId, bitAND(dirtyMask, spec.dirtyFlag) ~= 0) then
            streamWriteBool(streamId, spec.createTramLines)
            streamWriteInt8(streamId, spec.currentLane)
        end
    end
end

---Called on update.
function ProSeedTramLines:onUpdate(dt)
    local spec = self.spec_proSeedTramLines

    if self.isClient then
        if spec.actionEvents ~= nil then
            local actionEvent = spec.actionEvents[InputAction.PS_SET_HALF_SIDE_SHUTOFF]
            if actionEvent ~= nil then
                g_inputBinding:setActionEventActive(actionEvent.actionEventId, self:canActivateHalfSideShutoff())
            end
        end
    end
end

---Called on update tick.
function ProSeedTramLines:onUpdateTick(dt)
    local spec = self.spec_proSeedTramLines

    if self.isServer then
        local lanesForDistance = spec.tramLineDistance / spec.workingWidthRounded

        if spec.tramLineMode == ProSeedTramLines.TRAMLINE_MODE_AUTO then
            local rootVehicle = self:getRootVehicle()
            --Get GuidanceSteering information when active.
            if rootVehicle.getHasGuidanceSystem ~= nil and rootVehicle:getHasGuidanceSystem() then
                local data = rootVehicle:getGuidanceData()
                self:setCurrentLane((math.abs(data.currentLane) % lanesForDistance) + 1, true)
            end
        elseif spec.tramLineMode == ProSeedTramLines.TRAMLINE_MODE_SEMI then
            local isLowered = self:getIsImplementChainLowered()

            if spec.isLowered ~= isLowered then
                if isLowered then
                    self:setCurrentLane()
                end

                spec.isLowered = isLowered
            end
        end

        if spec.tramLineMode ~= ProSeedTramLines.TRAMLINE_MODE_MANUAL then
            local rest = 1 - lanesForDistance % 2
            local laneForTramLine = math.floor((lanesForDistance / 2) + 0.5) + rest
            --We create lines when we can divide.
            spec.createTramLines = spec.currentLane == laneForTramLine
        end

        if spec.createTramLines then
            --Turnoff half side shutoff when we create tramlines.
            if self:isHalfSideShutoffActive() then
                self:setHalfSideShutoffMode(ProSeedTramLines.SHUTOFF_MODE_OFF)
            end
        end

        if spec.createTramLines ~= spec.createTramLinesSent
            or spec.currentLane ~= spec.currentLaneSent then
            spec.createTramLinesSent = spec.createTramLines
            spec.currentLaneSent = spec.currentLane
            self:raiseDirtyFlags(spec.dirtyFlag)
        end
    end
end

---Process tramline creation on the end of work area processing.
function ProSeedTramLines:onEndWorkAreaProcessing(dt, hasProcessed)
    local spec = self.spec_proSeedTramLines
    if spec.createTramLines and hasProcessed then
        local params = self.spec_sowingMachine.workAreaParameters

        for _, area in ipairs(spec.tramlinesAreas) do
            local xs, _, zs = getWorldTranslation(area.start)
            local xw, _, zw = getWorldTranslation(area.width)
            local xh, _, zh = getWorldTranslation(area.height)

            if spec.createPreMarkedTramLines then
                FSDensityMapUtil.updateCultivatorArea(xs, zs, xw, zw, xh, zh, false, false, params.angle, nil)
            else
                FSDensityMapUtil.updateDestroyCommonArea(xs, zs, xw, zw, xh, zh, false, false, params.angle, nil)
            end

            if VehicleDebug.state == VehicleDebug.DEBUG_ATTRIBUTES then
                drawArea(area, 0, 0, 1, 1)
            end
        end
    end
end

---Sets the tram line mode.
function ProSeedTramLines:setTramLineMode(mode, noEventSend)
    local spec = self.spec_proSeedTramLines

    if mode ~= spec.tramLineMode then
        ProSeedModeEvent.sendEvent(self, mode, noEventSend)
        spec.tramLineMode = mode

        if spec.actionEvents ~= nil then
            local actionEvent = spec.actionEvents[InputAction.PS_SET_LANES_TILL_TRAMLINE]
            if actionEvent ~= nil then
                local text = g_i18n:getText("action_setTramlineDistance")
                if spec.tramLineMode == ProSeedTramLines.TRAMLINE_MODE_MANUAL then
                    text = g_i18n:getText("action_setTramline")
                end

                g_inputBinding:setActionEventText(actionEvent.actionEventId, text)
            end
        end
    end
end

---Sets the half side shutoff mode.
function ProSeedTramLines:setHalfSideShutoffMode(mode, noEventSend)
    local spec = self.spec_proSeedTramLines

    if mode ~= spec.shutoffMode then
        ProSeedHalfSideShutoffEvent.sendEvent(self, mode, noEventSend)

        for workAreaIndex, area in ipairs(spec.originalAreas) do
            local workArea = self:getWorkAreaByIndex(workAreaIndex)
            local sx, sy, sz = unpack(area.start)
            local wx, wy, wz = unpack(area.width)
            local hx, hy, hz = unpack(area.height)

            -- Always reset
            setTranslation(workArea.start, sx, sy, sz)
            setTranslation(workArea.width, wx, wy, wz)
            setTranslation(workArea.height, hx, hy, hz)

            if mode ~= ProSeedTramLines.SHUTOFF_MODE_OFF then
                local shutOffLeft = mode == ProSeedTramLines.SHUTOFF_MODE_LEFT
                local shutOffRight = mode == ProSeedTramLines.SHUTOFF_MODE_RIGHT
                local moveSXToZero = sx < 0 and shutOffLeft or sx > 0 and shutOffRight
                local moveWXToZero = wx < 0 and shutOffLeft or wx > 0 and shutOffRight
                local moveHXToZero = hx < 0 and shutOffLeft or hx > 0 and shutOffRight

                if moveSXToZero then
                    setTranslation(workArea.start, 0, sy, sz)
                end

                if moveWXToZero then
                    setTranslation(workArea.width, 0, wy, wz)
                end

                if moveHXToZero then
                    setTranslation(workArea.height, 0, hy, hz)
                end
            end
        end

        spec.shutoffMode = mode
    end
end

---Returns true when the shut off mode is not on mode `SHUTOFF_MODE_OFF`, false otherwise.
function ProSeedTramLines:isHalfSideShutoffActive()
    return self.spec_proSeedTramLines.shutoffMode ~= ProSeedTramLines.SHUTOFF_MODE_OFF
end

---Returns true when we're not creating tramlines, false otherwise.
function ProSeedTramLines:canActivateHalfSideShutoff()
    return not self.spec_proSeedTramLines.createTramLines
end

---Creates the tram lines centered in the workArea.
function ProSeedTramLines:createTramLineAreas(center, workAreaIndex)
    local lineAreas = {}
    local workArea = self:getWorkAreaByIndex(workAreaIndex)
    local _, start, _ = worldToLocal(self.rootNode, getWorldTranslation(workArea.start))
    local _, _, height = worldToLocal(self.rootNode, getWorldTranslation(workArea.height))

    local x = center + ProSeedTramLines.TRAMLINE_SPACING
    local y = start
    local z = height - ProSeedTramLines.TRAMELINE_HEIGHT_OFFSET --Put ourselves 0.3 meter behind the seed workArea
    local hz = z - ProSeedTramLines.TRAMELINE_WIDTH

    local linkNode = self.rootNode

    --We only need 2 lanes.
    for i = 1, 2 do
        local startNode = createGuideNode(("startNode(%d)"):format(i), linkNode, x, y, z)
        local heightNode = createGuideNode(("heightNode(%d)"):format(i), linkNode, x, y, hz)
        x = x - ProSeedTramLines.TRAMELINE_WIDTH
        local widthNode = createGuideNode(("widthNode(%d)"):format(i), linkNode, x, y, hz)
        x = center - (ProSeedTramLines.TRAMLINE_SPACING - ProSeedTramLines.TRAMELINE_WIDTH)
        table.insert(lineAreas, { start = startNode, height = heightNode, width = widthNode })
    end

    return lineAreas, workArea.index
end

---Calculates the tramline distance based on the given multiplier.
function ProSeedTramLines:setTramLineDistance(tramLineDistanceMultiplier)
    local spec = self.spec_proSeedTramLines
    spec.tramLineDistanceMultiplier = tramLineDistanceMultiplier

    local tramLineDistance = spec.workingWidthRounded * tramLineDistanceMultiplier
    if tramLineDistance >= ProSeedTramLines.TRAMLINE_MAX_WIDTH then
        spec.tramLineDistanceMultiplier = 1
        tramLineDistance = spec.workingWidthRounded * tramLineDistanceMultiplier
    end

    local tramLinePeriodicSequence = tramLineDistance / spec.workingWidthRounded
    if tramLinePeriodicSequence < ProSeedTramLines.TRAMLINE_MIM_PERIODIC_SEQUENCE then
        tramLinePeriodicSequence = ProSeedTramLines.TRAMLINE_MIM_PERIODIC_SEQUENCE
    end

    self:setTramLineData(tramLineDistance, tramLinePeriodicSequence, spec.createPreMarkedTramLines)
end

---Set current tram line data and sync to server and clients.
function ProSeedTramLines:setTramLineData(tramLineDistance, tramLinePeriodicSequence, createPreMarkedTramLines, noEventSend)
    local spec = self.spec_proSeedTramLines

    ProSeedTramLineDataEvent.sendEvent(self, tramLineDistance, tramLinePeriodicSequence, createPreMarkedTramLines, noEventSend)
    spec.tramLineDistance = tramLineDistance
    spec.tramLinePeriodicSequence = tramLinePeriodicSequence
    spec.createPreMarkedTramLines = createPreMarkedTramLines
end

---Set current lane count.
function ProSeedTramLines:setCurrentLane(value, force)
    value = value or 1
    force = force or false
    local spec = self.spec_proSeedTramLines

    if force then
        spec.currentLane = value
    else
        if spec.tramLineMode ~= ProSeedTramLines.TRAMLINE_MODE_AUTO then
            local lanesForDistance = spec.tramLineDistance / spec.workingWidthRounded
            if spec.currentLane < lanesForDistance then
                spec.currentLane = math.max(1, spec.currentLane + value)
            else
                spec.currentLane = 1
            end
        end
    end

    if self.isClient and not self.isServer then
        g_client:getServerConnection():sendEvent(ProSeedCreateTramLineEvent:new(self, spec.createTramLines, spec.currentLane))
    end
end

---Determine the area width of the vehicle.
function ProSeedTramLines.getMaxWorkAreaWidth(object)
    local workAreaSpec = object.spec_workArea
    local maxWidth, minWidth = 0, 0

    local node = createGuideNode("width_node", object.rootNode)

    local function toLocalArea(workArea)
        if not isWorkAreaValid(workArea) then
            return nil -- will GC table value cause ipairs
        end

        local x0 = localToLocal(workArea.start, node, 0, 0, 0)
        local x1 = localToLocal(workArea.width, node, 0, 0, 0)
        local x2 = localToLocal(workArea.height, node, 0, 0, 0)

        return { x0, x1, x2, workArea.index }
    end

    local areaWidths = stream(workAreaSpec.workAreas):map(toLocalArea):toList()
    maxWidth = stream(areaWidths):reduce(0, function(r, e)
        return math.max(r, unpack(e, 1, 3))
    end)
    minWidth = stream(areaWidths):reduce(math.huge, function(r, e)
        return math.min(r, unpack(e, 1, 3))
    end)

    local width = maxWidth + math.abs(minWidth)
    local offset = (minWidth + maxWidth) * 0.5
    if math.abs(offset) < 0.1 then
        offset = 0
    end

    delete(node)

    local area = stream(areaWidths):first()

    return MathUtil.round(width, 3), MathUtil.round(offset, 3), area[4]
end

---Toggle state of pre marker for tramlines.
function ProSeedTramLines:togglePreMarkersState()
    local spec = self.spec_proSeedTramLines
    spec.createPreMarkedTramLines = not spec.createPreMarkedTramLines
    return spec.createPreMarkedTramLines
end

function ProSeedTramLines:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if self.isClient then
        local spec = self.spec_proSeedTramLines

        self:clearActionEventsTable(spec.actionEvents)

        if isActiveForInput then
            local _, actionEventIdSetTramlines = self:addActionEvent(spec.actionEvents, InputAction.PS_SET_LANES_TILL_TRAMLINE, self, ProSeedTramLines.actionEventSetTramlines, false, true, false, true, nil, nil, true)
            local _, actionEventIdToggleHalfSideShutoff = self:addActionEvent(spec.actionEvents, InputAction.PS_SET_HALF_SIDE_SHUTOFF, self, ProSeedTramLines.actionEventToggleHalfSideShutoff, false, true, false, true, nil, nil, true)

            local text = g_i18n:getText("action_setTramlineDistance")
            if spec.tramLineMode == ProSeedTramLines.TRAMLINE_MODE_MANUAL then
                text = g_i18n:getText("action_setTramline")
            end

            g_inputBinding:setActionEventText(actionEventIdSetTramlines, text)
            g_inputBinding:setActionEventTextVisibility(actionEventIdSetTramlines, true)
            g_inputBinding:setActionEventTextPriority(actionEventIdSetTramlines, GS_PRIO_HIGH)

            g_inputBinding:setActionEventText(actionEventIdToggleHalfSideShutoff, g_i18n:getText("action_toggleHalfSideShutoff"))
            g_inputBinding:setActionEventTextVisibility(actionEventIdToggleHalfSideShutoff, true)
            g_inputBinding:setActionEventTextPriority(actionEventIdToggleHalfSideShutoff, GS_PRIO_HIGH)
        end
    end
end

function ProSeedTramLines.actionEventSetTramlines(self, actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_proSeedTramLines

    if spec.tramLineMode ~= ProSeedTramLines.TRAMLINE_MODE_MANUAL then
        self:setTramLineDistance(spec.tramLineDistanceMultiplier + 1)
    else
        --Allow manual creation of tramlines.
        g_client:getServerConnection():sendEvent(ProSeedCreateTramLineEvent:new(self, not spec.createTramLines, spec.currentLane))
    end
end

function ProSeedTramLines.actionEventToggleHalfSideShutoff(self, actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_proSeedTramLines

    if self:canActivateHalfSideShutoff() then
        local mode = spec.shutoffMode + 1
        if mode > ProSeedTramLines.SHUTOFF_MODE_RIGHT then
            mode = ProSeedTramLines.SHUTOFF_MODE_OFF
        end

        self:setHalfSideShutoffMode(mode)
    end
end
