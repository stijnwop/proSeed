----------------------------------------------------------------------------------------------------
-- ProSeedTramLines
----------------------------------------------------------------------------------------------------
-- Purpose: Specialization for creation tramlines.
--
-- Copyright (c) Wopster, 2020
----------------------------------------------------------------------------------------------------

local function createGuideNode(name, linkNode, x, y, z)
    local node = createTransformGroup(name)
    link(linkNode, node)
    setTranslation(node, x or 0, y or 0, z or 0)
    return node
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

ProSeedTramLines.TRAMLINE_SPACING = 1.6 -- m
ProSeedTramLines.TRAMELINE_WIDTH = 0.6 -- m
ProSeedTramLines.TRAMELINE_HEIGHT_OFFSET = 0.3 -- offset to drop our workArea behind the seeder

ProSeedTramLines.SHUTOFF_MODE_OFF = 0
ProSeedTramLines.SHUTOFF_MODE_LEFT = 1
ProSeedTramLines.SHUTOFF_MODE_RIGHT = 2

ProSeedTramLines.TRAMLINE_MIM_PERIODIC_SEQUENCE = 2 -- minimum sequence is 1.

function ProSeedTramLines.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(SowingMachine, specializations)
end

function ProSeedTramLines.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "createTramLineAreas", ProSeedTramLines.createTramLineAreas)
    SpecializationUtil.registerFunction(vehicleType, "setTramLineDistance", ProSeedTramLines.setTramLineDistance)
    SpecializationUtil.registerFunction(vehicleType, "setTramLineData", ProSeedTramLines.setTramLineData)
    SpecializationUtil.registerFunction(vehicleType, "setHalfSideShutoffMode", ProSeedTramLines.setHalfSideShutoffMode)
    SpecializationUtil.registerFunction(vehicleType, "isHalfSideShutoffActive", ProSeedTramLines.isHalfSideShutoffActive)
    SpecializationUtil.registerFunction(vehicleType, "canActivateHalfSideShutoff", ProSeedTramLines.canActivateHalfSideShutoff)
    SpecializationUtil.registerFunction(vehicleType, "togglePreMarkersState", ProSeedTramLines.togglePreMarkersState)
end

function ProSeedTramLines.registerOverwrittenFunctions(vehicleType)
end

function ProSeedTramLines.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", ProSeedTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", ProSeedTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", ProSeedTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", ProSeedTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", ProSeedTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", ProSeedTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", ProSeedTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", ProSeedTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onEndWorkAreaProcessing", ProSeedTramLines)
end

---Called onLoad.
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

    spec.currentLane = 0
    spec.shutoffMode = ProSeedTramLines.SHUTOFF_MODE_OFF

    spec.tramLinePeriodicSequence = ProSeedTramLines.TRAMLINE_MIM_PERIODIC_SEQUENCE
    spec.tramLineDistanceMultiplier = 1
    spec.tramLineDistance = spec.workingWidthRounded * spec.tramLineDistanceMultiplier

    local originalAreas = {}
    local node = createGuideNode("width_node", self.rootNode)
    for _, workArea in ipairs(self.spec_workArea.workAreas) do
        local area = {}
        area.start = { localToLocal(workArea.start, node, 0, 0, 0) }
        area.width = { localToLocal(workArea.width, node, 0, 0, 0) }
        area.height = { localToLocal(workArea.height, node, 0, 0, 0) }

        originalAreas[workArea.index] = area
    end

    delete(node)

    spec.originalAreas = originalAreas
    spec.dirtyFlag = self:getNextDirtyFlag()
end

function ProSeedTramLines:onReadStream(streamId, connection)
    local spec = self.spec_proSeedTramLines
    spec.createTramLines = streamReadBool(streamId)

    local tramLineDistance = streamReadFloat32(streamId)
    local tramLinePeriodicSequence = streamReadInt8(streamId)
    local createPreMarkedTramLines = streamReadBool(streamId)
    self:setTramLineData(tramLineDistance, tramLinePeriodicSequence, createPreMarkedTramLines, true)

    local shutoffMode = streamReadUIntN(streamId, 2)
    self:setHalfSideShutoffMode(shutoffMode, true)
end

function ProSeedTramLines:onWriteStream(streamId, connection)
    local spec = self.spec_proSeedTramLines
    streamWriteBool(streamId, spec.createTramLines)

    streamWriteFloat32(streamId, spec.tramLineDistance)
    streamWriteInt8(streamId, spec.tramLinePeriodicSequence)
    streamWriteBool(streamId, spec.createPreMarkedTramLines)

    --Send current halfside shutoff mode.
    streamWriteUIntN(streamId, spec.shutoffMode, 2)
end

function ProSeedTramLines:onReadUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then
        local spec = self.spec_proSeedTramLines

        if streamReadBool(streamId) then
            spec.createTramLines = streamReadBool(streamId)
        end
    end
end

function ProSeedTramLines:onWriteUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then
        local spec = self.spec_proSeedTramLines

        if streamWriteBool(streamId, bitAND(dirtyMask, spec.dirtyFlag) ~= 0) then
            streamWriteBool(streamId, spec.createTramLines)
        end
    end
end

function ProSeedTramLines:onUpdate(dt)
    local spec = self.spec_proSeedTramLines

    if self.isClient then
        if spec.actionEvents ~= nil then
            local actionEvent = spec.actionEvents[InputAction.PS_SET_HALF_SIDE_SHUTOFF]
            if actionEvent ~= nil then
                g_inputBinding:setActionEventActive(actionEvent.actionEventId, self:canActivateHalfSideShutoff())
            end
        end

        if self:getIsActiveForInput() then
            local data = {
                { name = "working width", value = spec.workingWidth },
                { name = "rounded width", value = spec.workingWidthRounded },
                { name = "currentLane", value = spec.currentLane },
                { name = "tramLineDistance", value = spec.tramLineDistance },
                { name = "tramLinePeriodicSequence", value = spec.tramLinePeriodicSequence },
                { name = "shutoff (0=off)", value = spec.shutoffMode },
                { name = "createTramLine", value = tostring(spec.createTramLines) },
            }
            DebugUtil.renderTable(0.5, 0.95, 0.012, data, 0.1)
        end
    end
end

function ProSeedTramLines:onUpdateTick(dt)
    local spec = self.spec_proSeedTramLines

    local lanesForDistance = spec.tramLineDistance / spec.workingWidthRounded
    if self.isServer then

        local rootVehicle = self:getRootVehicle()
        --Get GuidanceSteering information when active.
        if rootVehicle.getHasGuidanceSystem ~= nil and rootVehicle:getHasGuidanceSystem() then
            local data = rootVehicle:getGuidanceData()
            spec.currentLane = (math.abs(data.currentLane) % lanesForDistance) + 1
        end

        --Offset currentLane with 1 cause we don't want to start at the first lane.
        local lanesPassed = (spec.currentLane + 1) % spec.tramLinePeriodicSequence
        spec.createTramLines = lanesPassed == 0 --We create lines when we can divide.

        if spec.createTramLines then
            --Turnoff half side shutoff when we create tramlines.
            if self:isHalfSideShutoffActive() then
                self:setHalfSideShutoffMode(ProSeedTramLines.SHUTOFF_MODE_OFF)
            end
        end

        if spec.createTramLines ~= spec.createTramLinesSent then
            spec.createTramLinesSent = spec.createTramLines
            self:raiseDirtyFlags(spec.dirtyFlag)
        end
    end
end

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

function ProSeedTramLines.getMaxWorkAreaWidth(object)
    local workAreaSpec = object.spec_workArea
    local maxWidth, minWidth = 0, 0

    local node = createGuideNode("width_node", object.rootNode)

    -- Exclude ridged markers from workArea calculation
    local skipWorkAreas = {
        ["processRidgeMarkerArea"] = true
    }

    local function isWorkAreaValid(workArea)
        if skipWorkAreas[workArea.functionName] ~= nil then
            return false
        end

        return workArea.type ~= WorkAreaType.AUXILIARY
    end

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

            g_inputBinding:setActionEventText(actionEventIdSetTramlines, g_i18n:getText("function_setTramlineDistance"))
            g_inputBinding:setActionEventTextVisibility(actionEventIdSetTramlines, true)
            g_inputBinding:setActionEventTextPriority(actionEventIdSetTramlines, GS_PRIO_HIGH)

            g_inputBinding:setActionEventText(actionEventIdToggleHalfSideShutoff, g_i18n:getText("function_toggleHalfSideShutoff"))
            g_inputBinding:setActionEventTextVisibility(actionEventIdToggleHalfSideShutoff, true)
            g_inputBinding:setActionEventTextPriority(actionEventIdToggleHalfSideShutoff, GS_PRIO_HIGH)
        end
    end
end

function ProSeedTramLines.actionEventSetTramlines(self, actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_proSeedTramLines
    self:setTramLineDistance(spec.tramLineDistanceMultiplier + 1)
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
