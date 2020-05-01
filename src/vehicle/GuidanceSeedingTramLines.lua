----------------------------------------------------------------------------------------------------
-- GuidanceSeedingTramLines
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

---@class GuidanceSeedingTramLines
GuidanceSeedingTramLines = {}
GuidanceSeedingTramLines.MOD_NAME = g_currentModName

GuidanceSeedingTramLines.TRAMLINE_MAX_WIDTH = 72 -- m

GuidanceSeedingTramLines.TRAMLINE_SPACING = 1.6 -- m
GuidanceSeedingTramLines.TRAMELINE_WIDTH = 0.6 -- m
GuidanceSeedingTramLines.TRAMELINE_HEIGHT_OFFSET = 0.3 -- offset to drop our workArea behind the seeder

GuidanceSeedingTramLines.SHUTOFF_MODE_OFF = 0
GuidanceSeedingTramLines.SHUTOFF_MODE_LEFT = 1
GuidanceSeedingTramLines.SHUTOFF_MODE_RIGHT = 2

GuidanceSeedingTramLines.TRAMLINE_MIM_PERIODIC_SEQUENCE = 2 -- minimum sequence is 2.

function GuidanceSeedingTramLines.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(SowingMachine, specializations)
end

function GuidanceSeedingTramLines.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "createTramLineAreas", GuidanceSeedingTramLines.createTramLineAreas)
    SpecializationUtil.registerFunction(vehicleType, "setTramLineData", GuidanceSeedingTramLines.setTramLineData)
    SpecializationUtil.registerFunction(vehicleType, "setHalfSideShutoffMode", GuidanceSeedingTramLines.setHalfSideShutoffMode)
    SpecializationUtil.registerFunction(vehicleType, "isHalfSideShutoffActive", GuidanceSeedingTramLines.isHalfSideShutoffActive)
    SpecializationUtil.registerFunction(vehicleType, "canActivateHalfSideShutoff", GuidanceSeedingTramLines.canActivateHalfSideShutoff)
end

function GuidanceSeedingTramLines.registerOverwrittenFunctions(vehicleType)
end

function GuidanceSeedingTramLines.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", GuidanceSeedingTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", GuidanceSeedingTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", GuidanceSeedingTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", GuidanceSeedingTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", GuidanceSeedingTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", GuidanceSeedingTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", GuidanceSeedingTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", GuidanceSeedingTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onEndWorkAreaProcessing", GuidanceSeedingTramLines)
end

---Called onLoad.
function GuidanceSeedingTramLines:onLoad(savegame)
    self.spec_guidanceSeedingTramLines = self[("spec_%s.guidanceSeedingTramLines"):format(g_guidanceSeeding.modName)]
    local spec = self.spec_guidanceSeedingTramLines

    local width, center, workAreaIndex = GuidanceSeedingTramLines.getMaxWorkAreaWidth(self)

    spec.workingWidth = width
    spec.workingWidthRounded = MathUtil.round(width * 2) / 2 -- round to the nearest 0.5
    spec.tramlinesAreas, spec.tramlinesWorkAreaIndex = self:createTramLineAreas(center, workAreaIndex)

    spec.createTramLines = false
    spec.createTramLinesSent = false

    spec.currentLane = 0
    spec.shutoffMode = GuidanceSeedingTramLines.SHUTOFF_MODE_OFF

    spec.tramLinePeriodicSequence = GuidanceSeedingTramLines.TRAMLINE_MIM_PERIODIC_SEQUENCE
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

function GuidanceSeedingTramLines:onReadStream(streamId, connection)
    local spec = self.spec_guidanceSeedingTramLines
    spec.createTramLines = streamReadBool(streamId)

    local tramLineDistance = streamReadFloat32(streamId)
    local tramLinePeriodicSequence = streamReadInt8(streamId)
    self:setTramLineData(tramLineDistance, tramLinePeriodicSequence, true)

    local shutoffMode = streamReadUIntN(streamId, 2)
    self:setHalfSideShutoffMode(shutoffMode, true)
end

function GuidanceSeedingTramLines:onWriteStream(streamId, connection)
    local spec = self.spec_guidanceSeedingTramLines
    streamWriteBool(streamId, spec.createTramLines)

    streamWriteFloat32(streamId, spec.tramLineDistance)
    streamWriteInt8(streamId, spec.tramLinePeriodicSequence)

    --Send current halfside shutoff mode.
    streamWriteUIntN(streamId, spec.shutoffMode, 2)
end

function GuidanceSeedingTramLines:onReadUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then
        local spec = self.spec_guidanceSeedingTramLines

        if streamReadBool(streamId) then
            spec.createTramLines = streamReadBool(streamId)
        end
    end
end

function GuidanceSeedingTramLines:onWriteUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then
        local spec = self.spec_guidanceSeedingTramLines

        if streamWriteBool(streamId, bitAND(dirtyMask, spec.dirtyFlag) ~= 0) then
            streamWriteBool(streamId, spec.createTramLines)
        end
    end
end

function GuidanceSeedingTramLines:onUpdate(dt)
    local spec = self.spec_guidanceSeedingTramLines

    if self.isClient then
        if spec.actionEvents ~= nil then
            local actionEvent = spec.actionEvents[InputAction.GS_SET_HALF_SIDE_SHUTOFF]
            if actionEvent ~= nil then
                g_inputBinding:setActionEventActive(actionEvent.actionEventId, self:canActivateHalfSideShutoff())
            end
        end

        if self:getIsActiveForInput() then
            local lanesForDistance = spec.tramLineDistance / spec.workingWidthRounded
            local data = {
                { name = "working width", value = spec.workingWidth },
                { name = "rounded width", value = spec.workingWidthRounded },
                { name = "currentLane", value = spec.currentLane },
                { name = "tramLineDistance", value = spec.tramLineDistance },
                { name = "lanesForDistance", value = lanesForDistance },
                { name = "tramLinePeriodicSequence", value = spec.tramLinePeriodicSequence },
                { name = "shutoff (0=off)", value = spec.shutoffMode },
                { name = "createTramLine", value = tostring(spec.createTramLines) },
            }
            DebugUtil.renderTable(0.5, 0.95, 0.012, data, 0.1)
        end
    end
end

function GuidanceSeedingTramLines:onUpdateTick(dt)
    local spec = self.spec_guidanceSeedingTramLines

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
                self:setHalfSideShutoffMode(GuidanceSeedingTramLines.SHUTOFF_MODE_OFF)
            end
        end

        if spec.createTramLines ~= spec.createTramLinesSent then
            spec.createTramLinesSent = spec.createTramLines
            self:raiseDirtyFlags(spec.dirtyFlag)
        end
    end
end

function GuidanceSeedingTramLines:onEndWorkAreaProcessing(dt, hasProcessed)
    local spec = self.spec_guidanceSeedingTramLines
    if self.isServer and spec.createTramLines then
        local params = self.spec_sowingMachine.workAreaParameters

        for _, area in ipairs(spec.tramlinesAreas) do
            local xs, _, zs = getWorldTranslation(area.start)
            local xw, _, zw = getWorldTranslation(area.width)
            local xh, _, zh = getWorldTranslation(area.height)
            FSDensityMapUtil.updateCultivatorArea(xs, zs, xw, zw, xh, zh, false, false, params.angle, nil)

            if VehicleDebug.state == VehicleDebug.DEBUG_ATTRIBUTES then
                drawArea(area, 0, 0, 1, 1)
            end
        end
    end
end

---Sets the half side shutoff mode.
function GuidanceSeedingTramLines:setHalfSideShutoffMode(mode, noEventSend)
    local spec = self.spec_guidanceSeedingTramLines

    if mode ~= spec.shutoffMode then
        GuidanceSeedingHalfSideShutoffEvent.sendEvent(self, mode, noEventSend)

        for workAreaIndex, area in ipairs(spec.originalAreas) do
            local workArea = self:getWorkAreaByIndex(workAreaIndex)
            local sx, sy, sz = unpack(area.start)
            local wx, wy, wz = unpack(area.width)
            local hx, hy, hz = unpack(area.height)

            -- Always reset
            setTranslation(workArea.start, sx, sy, sz)
            setTranslation(workArea.width, wx, wy, wz)
            setTranslation(workArea.height, hx, hy, hz)

            if mode ~= GuidanceSeedingTramLines.SHUTOFF_MODE_OFF then
                local shutOffLeft = mode == GuidanceSeedingTramLines.SHUTOFF_MODE_LEFT
                local shutOffRight = mode == GuidanceSeedingTramLines.SHUTOFF_MODE_RIGHT
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
function GuidanceSeedingTramLines:isHalfSideShutoffActive()
    return self.spec_guidanceSeedingTramLines.shutoffMode ~= GuidanceSeedingTramLines.SHUTOFF_MODE_OFF
end

---Returns true when we're not creating tramlines, false otherwise.
function GuidanceSeedingTramLines:canActivateHalfSideShutoff()
    return not self.spec_guidanceSeedingTramLines.createTramLines
end

---Creates the tram lines centered in the workArea.
function GuidanceSeedingTramLines:createTramLineAreas(center, workAreaIndex)
    local lineAreas = {}
    local workArea = self:getWorkAreaByIndex(workAreaIndex)
    local _, start, _ = worldToLocal(self.rootNode, getWorldTranslation(workArea.start))
    local _, _, height = worldToLocal(self.rootNode, getWorldTranslation(workArea.height))

    local x = center + GuidanceSeedingTramLines.TRAMLINE_SPACING
    local y = start
    local z = height - GuidanceSeedingTramLines.TRAMELINE_HEIGHT_OFFSET --Put ourselves 0.3 meter behind the seed workArea
    local hz = z - GuidanceSeedingTramLines.TRAMELINE_WIDTH

    local linkNode = self.rootNode

    --We only need 2 lanes.
    for i = 1, 2 do
        local startNode = createGuideNode(("startNode(%d)"):format(i), linkNode, x, y, z)
        local heightNode = createGuideNode(("heightNode(%d)"):format(i), linkNode, x, y, hz)
        x = x - GuidanceSeedingTramLines.TRAMELINE_WIDTH
        local widthNode = createGuideNode(("widthNode(%d)"):format(i), linkNode, x, y, hz)
        x = center - (GuidanceSeedingTramLines.TRAMLINE_SPACING - GuidanceSeedingTramLines.TRAMELINE_WIDTH)
        table.insert(lineAreas, { start = startNode, height = heightNode, width = widthNode })
    end

    return lineAreas, workArea.index
end

---Set current tram line data and sync to server and clients.
function GuidanceSeedingTramLines:setTramLineData(tramLineDistance, tramLinePeriodicSequence, noEventSend)
    local spec = self.spec_guidanceSeedingTramLines

    GuidanceSeedingTramLineDataEvent.sendEvent(self, tramLineDistance, tramLinePeriodicSequence, noEventSend)
    spec.tramLineDistance = tramLineDistance
    spec.tramLinePeriodicSequence = tramLinePeriodicSequence
end

function GuidanceSeedingTramLines.getMaxWorkAreaWidth(object)
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

function GuidanceSeedingTramLines:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if self.isClient then
        local spec = self.spec_guidanceSeedingTramLines

        self:clearActionEventsTable(spec.actionEvents)

        if isActiveForInput then
            local _, actionEventIdToggleTramlines = self:addActionEvent(spec.actionEvents, InputAction.TOGGLE_PIPE, self, GuidanceSeedingTramLines.actionEventToggleTramlines, false, true, false, true, nil, nil, true)
            local _, actionEventIdSetTramlines = self:addActionEvent(spec.actionEvents, InputAction.GS_SET_LANES_TILL_TRAMLINE, self, GuidanceSeedingTramLines.actionEventSetTramlines, false, true, false, true, nil, nil, true)
            local _, actionEventIdToggleHalfSideShutoff = self:addActionEvent(spec.actionEvents, InputAction.GS_SET_HALF_SIDE_SHUTOFF, self, GuidanceSeedingTramLines.actionEventToggleHalfSideShutoff, false, true, false, true, nil, nil, true)

            g_inputBinding:setActionEventText(actionEventIdToggleTramlines, g_i18n:getText("function_setTramlineDistance"))
            g_inputBinding:setActionEventTextVisibility(actionEventIdToggleTramlines, true)
            g_inputBinding:setActionEventTextPriority(actionEventIdToggleTramlines, GS_PRIO_HIGH)

            g_inputBinding:setActionEventText(actionEventIdSetTramlines, g_i18n:getText("function_setLinesTillTramline"))
            g_inputBinding:setActionEventTextVisibility(actionEventIdSetTramlines, true)
            g_inputBinding:setActionEventTextPriority(actionEventIdSetTramlines, GS_PRIO_HIGH)

            g_inputBinding:setActionEventText(actionEventIdToggleHalfSideShutoff, g_i18n:getText("function_toggleHalfSideShutoff"))
            g_inputBinding:setActionEventTextVisibility(actionEventIdToggleHalfSideShutoff, true)
            g_inputBinding:setActionEventTextPriority(actionEventIdToggleHalfSideShutoff, GS_PRIO_HIGH)
        end
    end
end

function GuidanceSeedingTramLines.actionEventToggleTramlines(self, actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_guidanceSeedingTramLines
    spec.tramLineDistanceMultiplier = spec.tramLineDistanceMultiplier + 1

    local tramLineDistance = spec.workingWidthRounded * spec.tramLineDistanceMultiplier
    if tramLineDistance >= GuidanceSeedingTramLines.TRAMLINE_MAX_WIDTH then
        spec.tramLineDistanceMultiplier = 1
        tramLineDistance = spec.workingWidthRounded * spec.tramLineDistanceMultiplier
    end

    self:setTramLineData(tramLineDistance, spec.tramLinePeriodicSequence)
end

function GuidanceSeedingTramLines.actionEventSetTramlines(self, actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_guidanceSeedingTramLines
    local tramLinePeriodicSequence = spec.tramLinePeriodicSequence + 1

    local lanesForDistance = spec.tramLineDistance / spec.workingWidthRounded
    if tramLinePeriodicSequence > lanesForDistance then
        tramLinePeriodicSequence = GuidanceSeedingTramLines.TRAMLINE_MIM_PERIODIC_SEQUENCE
    end

    self:setTramLineData(spec.tramLineDistance, tramLinePeriodicSequence)
end

function GuidanceSeedingTramLines.actionEventToggleHalfSideShutoff(self, actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_guidanceSeedingTramLines

    if self:canActivateHalfSideShutoff() then
        local mode = spec.shutoffMode + 1
        if mode > GuidanceSeedingTramLines.SHUTOFF_MODE_RIGHT then
            mode = GuidanceSeedingTramLines.SHUTOFF_MODE_OFF
        end

        self:setHalfSideShutoffMode(mode)
    end
end
