----------------------------------------------------------------------------------------------------
-- GuidanceSeedingTramLines
----------------------------------------------------------------------------------------------------
-- Purpose: Specialization for creation tramlines.
--
-- Copyright (c) Wopster, 2020
----------------------------------------------------------------------------------------------------

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

GuidanceSeedingTramLines = {}
GuidanceSeedingTramLines.MOD_NAME = g_currentModName

GuidanceSeedingTramLines.MAX_CTF_WIDTH = 72 -- m

GuidanceSeedingTramLines.LINE_WIDTH = 1.6
GuidanceSeedingTramLines.LANE_WIDTH = 0.6
GuidanceSeedingTramLines.LANE_HEIGHT_OFFSET = 0.3 -- offset to drop our workArea behind the seeder

function GuidanceSeedingTramLines.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(SowingMachine, specializations)
end

function GuidanceSeedingTramLines.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "processSowingMachineArea", GuidanceSeedingTramLines.processSowingMachineArea)
end
function GuidanceSeedingTramLines.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "processSowingMachineArea", GuidanceSeedingTramLines.processSowingMachineArea)
end

function GuidanceSeedingTramLines.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", GuidanceSeedingTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", GuidanceSeedingTramLines)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", GuidanceSeedingTramLines)
end

---Called onLoad.
function GuidanceSeedingTramLines:onLoad(savegame)
    self.spec_guidanceSeedingTramLines = self[("spec_%s.guidanceSeedingTramLines"):format(g_guidanceSeeding.modName)]
    local spec = self.spec_guidanceSeedingTramLines
    spec.createTramLines = false

    local width, center, workAreaIndex = GuidanceSeedingTramLines.getMaxWorkAreaWidth(self)
    spec.workingWidth = width
    spec.currentLane = 1
    spec.lanesTillTramLine = 3
    spec.lanesDistanceMultiplier = 1
    spec.lanesDistance = width * spec.lanesDistanceMultiplier
    spec.tramlinesAreas, spec.tramlinesWorkAreaIndex = GuidanceSeedingTramLines.createTramLineAreas(self, width, center, workAreaIndex)
end

function GuidanceSeedingTramLines:onUpdate(dt)
    local spec = self.spec_guidanceSeedingTramLines

    if self:getIsActiveForInput() then
        local rootVehicle = self:getRootVehicle()
        if rootVehicle.getGuidanceData ~= nil then
            local data = rootVehicle:getGuidanceData()
            spec.currentLane = math.abs(data.currentLane)

            if spec.workingWidth ~= data.width then
                spec.workingWidth = data.width
            end
        end

        local lanesForDistance = spec.lanesDistance / spec.workingWidth

        --Offset currentLane with 1 cause we don't want to start at the first lane.
        local lanesPassed = (spec.currentLane + 1) % spec.lanesTillTramLine
        spec.createTramLines = lanesPassed == 0 --We create lines when we can divide.
        local data = {
            { name = "working width", value = spec.workingWidth },
            { name = "currentLane", value = spec.currentLane },
            { name = "lanesPassed", value = lanesPassed },
            { name = "lanesDistance", value = spec.lanesDistance },
            { name = "lanesForDistance", value = lanesForDistance },
            { name = "lanesTillTramLine", value = spec.lanesTillTramLine },
            { name = "createTramLine", value = tostring(spec.createTramLines) },
        }
        DebugUtil.renderTable(0.5, 0.95, 0.012, data, 0.1)
    end
end

function GuidanceSeedingTramLines:processSowingMachineArea(superFunc, workArea, dt)
    local changedArea, totalArea = superFunc(self, workArea, dt)

    local spec = self.spec_guidanceSeedingTramLines
    if spec.createTramLines and spec.tramlinesWorkAreaIndex == workArea.index then
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

    return changedArea, totalArea
end

function GuidanceSeedingTramLines.createTramLineAreas(object, width, center, workAreaIndex)
    local lineAreas = {}
    local workArea = object.spec_workArea.workAreas[workAreaIndex]
    local _, start, _ = worldToLocal(object.rootNode, getWorldTranslation(workArea.start))
    local _, _, height = worldToLocal(object.rootNode, getWorldTranslation(workArea.height))

    local x = center + GuidanceSeedingTramLines.LINE_WIDTH
    local y = start
    local z = height - GuidanceSeedingTramLines.LANE_HEIGHT_OFFSET --Put ourselves 0.3 meter behind the seed workArea
    local hz = z - GuidanceSeedingTramLines.LANE_WIDTH

    local function createLineAreaNode(name, linkNode, lx, ly, lz)
        local node = createTransformGroup(name)
        link(linkNode, node)
        setTranslation(node, lx, ly, lz)
        return node
    end

    local linkNode = object.components[1].node

    --We only need 2 lanes.
    for i = 1, 2 do
        local startNode = createLineAreaNode(("startNode(%d)"):format(i), linkNode, x, y, z)
        local heightNode = createLineAreaNode(("heightNode(%d)"):format(i), linkNode, x, y, hz)
        x = x - GuidanceSeedingTramLines.LANE_WIDTH
        local widthNode = createLineAreaNode(("widthNode(%d)"):format(i), linkNode, x, y, hz)
        x = center - (GuidanceSeedingTramLines.LINE_WIDTH - GuidanceSeedingTramLines.LANE_WIDTH)
        table.insert(lineAreas, { start = startNode, height = heightNode, width = widthNode })
    end

    return lineAreas, workArea.index
end

function GuidanceSeedingTramLines.getMaxWorkAreaWidth(object)
    local workAreaSpec = object.spec_workArea
    local maxWidth, minWidth = 0, 0

    local function createGuideNode(name, linkNode)
        local node = createTransformGroup(name)
        link(linkNode, node)
        setTranslation(node, 0, 0, 0)
        return node
    end

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

            g_inputBinding:setActionEventText(actionEventIdToggleTramlines, "trammies")
            g_inputBinding:setActionEventTextVisibility(actionEventIdToggleTramlines, true)
            g_inputBinding:setActionEventTextPriority(actionEventIdToggleTramlines, GS_PRIO_HIGH)

            g_inputBinding:setActionEventText(actionEventIdSetTramlines, "set num")
            g_inputBinding:setActionEventTextVisibility(actionEventIdSetTramlines, true)
            g_inputBinding:setActionEventTextPriority(actionEventIdSetTramlines, GS_PRIO_HIGH)
        end
    end
end

function GuidanceSeedingTramLines.actionEventToggleTramlines(self, actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_guidanceSeedingTramLines
    spec.lanesDistanceMultiplier = spec.lanesDistanceMultiplier + 1

    local distance = spec.workingWidth * spec.lanesDistanceMultiplier
    if distance >= GuidanceSeedingTramLines.MAX_CTF_WIDTH then
        spec.lanesDistanceMultiplier = 0
    end

    spec.lanesDistance = distance
    log("lanesDistance: " .. tostring(distance))
end

function GuidanceSeedingTramLines.actionEventSetTramlines(self, actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_guidanceSeedingTramLines
    spec.lanesTillTramLine = spec.lanesTillTramLine + 1

    local lanesForDistance = spec.lanesDistance / spec.workingWidth
    if spec.lanesTillTramLine > lanesForDistance then
        spec.lanesTillTramLine = 1
    end

    log("lanesTillTramLine: " .. tostring(spec.lanesTillTramLine))
end
