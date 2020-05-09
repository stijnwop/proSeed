----------------------------------------------------------------------------------------------------
-- InteractiveHUD
----------------------------------------------------------------------------------------------------
-- Purpose: Base class for an interactive HUD.
--
-- Copyright (c) Wopster, 2020
----------------------------------------------------------------------------------------------------

---@class InteractiveHUD
InteractiveHUD = {}
InteractiveHUD.INPUT_CONTEXT_NAME = "INTERACTIVE_HUD"

local InteractiveHUD_mt = Class(InteractiveHUD)

local function isPlanterCategory(storeItem)
    return storeItem.categoryName ~= nil and storeItem.categoryName == "PLANTERS"
end

---Creates a new instance of the InteractiveHUD.
---@return InteractiveHUD
function InteractiveHUD:new(mission, i18n, inputBinding, gui, modDirectory, uiFilename)
    local instance = setmetatable({}, InteractiveHUD_mt)

    instance.mission = mission
    instance.gui = gui
    instance.inputBinding = inputBinding
    instance.i18n = i18n
    instance.modDirectory = modDirectory
    instance.uiFilename = uiFilename

    instance.speedMeterDisplay = mission.hud.speedMeter

    instance.vehicle = nil

    return instance
end

function InteractiveHUD:delete()
    if self.base ~= nil then
        self.base:delete()
    end
end

function InteractiveHUD:load()
    self.uiScale = self:getUIScale()

    self:createElements()
    self:setVehicle(nil)
end

---Toggle mouse cursor mode and go into a context to block any other input.
function InteractiveHUD:toggleMouseCursor()
    local isActive = not self.inputBinding:getShowMouseCursor()
    if not self.isCustomInputActive and self.inputBinding:getShowMouseCursor() then
        self.inputBinding:setShowMouseCursor(false)-- always reset
        isActive = false
    end

    self.inputBinding:setShowMouseCursor(isActive)

    if not self.isCustomInputActive and isActive then
        self.inputBinding:setContext(InteractiveHUD.INPUT_CONTEXT_NAME, true, false)

        local _, eventId = self.inputBinding:registerActionEvent(InputAction.PS_TOGGLE_MOUSE_CURSOR, self, self.toggleMouseCursor, false, true, false, true)
        self.inputBinding:setActionEventTextVisibility(eventId, false)

        self.isCustomInputActive = true
    elseif self.isCustomInputActive and not isActive then
        self.inputBinding:removeActionEventsByTarget(self)
        self.inputBinding:revertContext(true) -- revert and clear message context
        self.isCustomInputActive = false
    end

    --Make compatible with IC.
    if self.vehicle ~= nil then
        self.vehicle.isMouseActive = isActive
        local rootVehicle = self.vehicle:getRootVehicle()
        rootVehicle.isMouseActive = isActive
    end
end

function InteractiveHUD:isVehicleActive(vehicle)
    return vehicle == self.vehicle
end

function InteractiveHUD:setVehicle(vehicle)
    self.vehicle = vehicle
    if self.base ~= nil then
        local hasVehicle = vehicle ~= nil

        if hasVehicle then
            local storeItem = g_storeManager:getItemByXMLFilename(vehicle.configFileName)
            local uvs = isPlanterCategory(storeItem) and InteractiveHUD.UV.PLANTER or InteractiveHUD.UV.SEEDER
            self.iconSeeder:setUVs(getNormalizedUVs(uvs))

            local spec = vehicle.spec_proSeedTramLines
            self.textElementTramLineDistance:setText(("%sm"):format(spec.tramLineDistance))
            self.textElementWorkingWidth:setText(("%sm"):format(spec.workingWidthRounded))
            self.buttonPreMarkers:setSelected(spec.createPreMarkedTramLines)

            self:updateTramLineModeState(spec.tramLineMode)
            self:updateTramLineCountingState(spec.tramLineMode)

            spec = vehicle.spec_proSeedSowingExtension
            self.buttonSound:setSelected(spec.allowSound)
            self.buttonFertilizer:setSelected(spec.allowFertilizer)
        end

        self.base:setVisible(vehicle ~= nil)
    end
end

---Called on mouse event.
function InteractiveHUD:update(dt)
    if self.vehicle ~= nil and not self.gui:getIsGuiVisible() and self.base:getIsVisible() then
        local spec = self.vehicle.spec_proSeedTramLines
        self:visualizeTramLine(self.vehicle)
        --TODO: OPTIMIZE
        local lanesForDistance = spec.tramLineDistance / spec.workingWidthRounded
        self.textElementTramLineCount:setText(("%s / %s"):format(spec.currentLane, lanesForDistance))

        local spec_extension = self.vehicle.spec_proSeedSowingExtension
        self.textElementTotalWorkedHA:setText(("%.1fha"):format(spec_extension.totalHectares))
        self.textElementWorkedHA:setText(("%.2fha (%.1f ha/h)"):format(spec_extension.sessionHectares, spec_extension.hectarePerHour))
        self.textElementSeedUsage:setText(("%.2fl"):format(spec_extension.seedUsage))
    end
end

---Called on mouse event.
function InteractiveHUD:mouseEvent(posX, posY, isDown, isUp, button)
    if self.vehicle ~= nil and not self.gui:getIsGuiVisible() and self.inputBinding:getShowMouseCursor() then

        local eventUsed = false
        for _, child in ipairs(self.base.children) do
            if child.mouseEvent ~= nil then
                eventUsed = child:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
            end

            if eventUsed then
                break
            end
        end

        if not eventUsed then
            self.base:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
        end
    end
end

function InteractiveHUD:getUIScale()
    return self.speedMeterDisplay.uiScale
end

function InteractiveHUD:scalePixelToScreenVector(vector2D)
    return self.speedMeterDisplay:scalePixelToScreenVector(vector2D)
end

function InteractiveHUD:scalePixelToScreenHeight(pixel)
    return self.speedMeterDisplay:scalePixelToScreenHeight(pixel)
end

function InteractiveHUD:getCorrectedTextSize(size)
    return size * self.uiScale
end

function InteractiveHUD:toggleVehicleSound(buttonElement)
    if self.vehicle ~= nil then
        if self.vehicle.toggleSowingSounds ~= nil then
            local state = self.vehicle:toggleSowingSounds()
            buttonElement:setSelected(state)
        end
    end
end

function InteractiveHUD:toggleVehicleSowingFertilizer(buttonElement)
    if self.vehicle ~= nil then
        if self.vehicle.toggleSowingFertilizer ~= nil then
            local state = self.vehicle:toggleSowingFertilizer()
            buttonElement:setSelected(state)
        end
    end
end

function InteractiveHUD:toggleVehicleHalfSideShutoff(buttonElement)
    if self.vehicle ~= nil then
        if self.vehicle.setHalfSideShutoffMode ~= nil then
            if self.vehicle:canActivateHalfSideShutoff() then
                local spec = self.vehicle.spec_proSeedTramLines
                local mode = spec.shutoffMode + 1
                if mode > ProSeedTramLines.SHUTOFF_MODE_RIGHT then
                    mode = ProSeedTramLines.SHUTOFF_MODE_OFF
                end

                self.vehicle:setHalfSideShutoffMode(mode)
                --buttonElement:setSelected(state)
                self:visualizeHalfSideShutoff(mode)
            end
        end
    end
end

function InteractiveHUD:toggleVehiclePreMarkersState(buttonElement)
    if self.vehicle ~= nil then
        if self.vehicle.togglePreMarkersState ~= nil then
            local state = self.vehicle:togglePreMarkersState()
            buttonElement:setSelected(state)
        end
    end
end

function InteractiveHUD:increaseTramLineDistance(buttonElement)
    local vehicle = self.vehicle
    if vehicle ~= nil then
        if vehicle.setTramLineData ~= nil then
            local spec = vehicle.spec_proSeedTramLines
            vehicle:setTramLineDistance(spec.tramLineDistanceMultiplier + 1)

            self.textElementTramLineDistance:setText(("%sm"):format(spec.tramLineDistance))
        end
    end
end

function InteractiveHUD:decreaseTramLineDistance(buttonElement)
    local vehicle = self.vehicle
    if vehicle ~= nil then
        if vehicle.setTramLineData ~= nil then
            local spec = vehicle.spec_proSeedTramLines
            local tramLineDistanceMultiplier = math.max(spec.tramLineDistanceMultiplier - 1, 1)
            vehicle:setTramLineDistance(tramLineDistanceMultiplier)
            self.textElementTramLineDistance:setText(("%sm"):format(spec.tramLineDistance))
        end
    end
end

function InteractiveHUD:increaseTramLineMode(buttonElement)
    local vehicle = self.vehicle
    if vehicle ~= nil then
        if vehicle.setTramLineMode ~= nil then
            local spec = vehicle.spec_proSeedTramLines
            local tramLineMode = math.min(spec.tramLineMode + 1, ProSeedTramLines.TRAMLINE_MODE_MANUAL)
            vehicle:setTramLineMode(tramLineMode)

            self:updateTramLineModeState(tramLineMode)
            self:updateTramLineCountingState(tramLineMode)
        end
    end
end

function InteractiveHUD:decreaseTramLineMode(buttonElement)
    local vehicle = self.vehicle
    if vehicle ~= nil then
        if vehicle.setTramLineMode ~= nil then
            local spec = vehicle.spec_proSeedTramLines
            local tramLineMode = math.max(spec.tramLineMode - 1, 0)
            vehicle:setTramLineMode(tramLineMode)

            self:updateTramLineModeState(tramLineMode)
            self:updateTramLineCountingState(tramLineMode)
        end
    end
end

function InteractiveHUD:increaseTramLinePassedCount(buttonElement)
    local vehicle = self.vehicle
    if vehicle ~= nil then
        if vehicle.setCurrentLane ~= nil then
            vehicle:setCurrentLane()
        end
    end
end

function InteractiveHUD:decreaseTramLinePassedCount(buttonElement)
    local vehicle = self.vehicle
    if vehicle ~= nil then
        if vehicle.setCurrentLane ~= nil then
            vehicle:setCurrentLane(-1)
        end
    end
end

function InteractiveHUD:createElements()
    local rightX = 1 - g_safeFrameOffsetX -- right of screen.
    local bottomY = g_safeFrameOffsetY

    local boxWidth, boxHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.BOX)
    local marginWidth, marginHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.BOX_MARGIN)
    local paddingWidth, paddingHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.BOX_PADDING)

    local iconWidth, iconHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.ICON)

    local baseBox = self:createBaseBox(self.uiFilename, rightX - marginWidth, bottomY - marginHeight)
    self.base = baseBox
    self.speedMeterDisplay:addChild(baseBox)

    local posX, posY = self.base:getPosition()
    posY = posY + paddingHeight
    self.iconPreMarkers = self:createIcon(self.uiFilename, posX, posY, iconWidth, iconHeight, InteractiveHUD.UV.TRAM_LINE)

    self.buttonPreMarkers = HUDButtonElement:new(self.iconPreMarkers)
    self.buttonPreMarkers:setBorders("0dp 1dp 1dp 0dp", InteractiveHUD.COLOR.BORDER)
    self.buttonPreMarkers:setButtonCallback(self, self.toggleVehiclePreMarkersState)
    self.base:addChild(self.buttonPreMarkers)

    self.iconFertilizer = self:createIcon(self.uiFilename, posX, posY + iconHeight, iconWidth, iconHeight, InteractiveHUD.UV.FERTILIZER)

    self.buttonFertilizer = HUDButtonElement:new(self.iconFertilizer)
    self.buttonFertilizer:setBorders("0dp 0dp 1dp 0dp", InteractiveHUD.COLOR.BORDER)
    self.buttonFertilizer:setButtonCallback(self, self.toggleVehicleSowingFertilizer)
    self.base:addChild(self.buttonFertilizer)

    self:createSeederIcon(posX + iconWidth, posY)

    --SOUND ICON
    self.iconSound = self:createIcon(self.uiFilename, posX + boxWidth - iconWidth, posY, iconWidth, iconHeight, InteractiveHUD.UV.SOUND)

    self.buttonSound = HUDButtonElement:new(self.iconSound)
    self.buttonSound:setBorders("1dp 1dp 0dp 0dp", InteractiveHUD.COLOR.BORDER)
    self.buttonSound:setButtonCallback(self, self.toggleVehicleSound)
    self.base:addChild(self.buttonSound)

    self.iconGuidanceSteering = self:createIcon(self.uiFilename, posX + boxWidth - iconWidth, posY + iconHeight, iconWidth, iconHeight, InteractiveHUD.UV.SHUTOFF)

    self.buttonHalfSideShutoff = HUDButtonElement:new(self.iconGuidanceSteering)
    self.buttonHalfSideShutoff:setBorders("1dp 0dp 0dp 0dp", InteractiveHUD.COLOR.BORDER)
    self.buttonHalfSideShutoff:setButtonCallback(self, self.toggleVehicleHalfSideShutoff)
    self.base:addChild(self.buttonHalfSideShutoff)

    local headerWidth, headerHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.HEADER)
    local headerY = posY + (boxHeight - headerHeight)
    self.buttonHeader = HUDButtonElement:new(Overlay:new(nil, posX, headerY, headerWidth, headerHeight))
    self.buttonHeader:setBorders("0dp 0dp 0dp 1dp", InteractiveHUD.COLOR.BORDER)
    self.base:addChild(self.buttonHeader)

    local headerTopWidth, headerTopHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.HEADER_TOP)
    local headerTopY = headerY + headerHeight - paddingHeight - headerTopHeight

    local headerTopOverlay = Overlay:new(self.uiFilename, posX, headerTopY, headerTopWidth, headerTopHeight)
    self.buttonTopHeader = HUDElementBase:new(headerTopOverlay)
    self.buttonTopHeader:setBorders("0dp 0dp 0dp 1dp", InteractiveHUD.COLOR.BORDER)
    self.buttonTopHeader:setUVs(getNormalizedUVs(InteractiveHUD.UV.FILL))
    self.buttonTopHeader:setColor(unpack(InteractiveHUD.COLOR.DARK_GLASS))

    self.base:addChild(self.buttonTopHeader)

    local iconSmallWidth, iconSmallHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.ICON_SMALL)
    local iconSmallMarginWidth, iconSmallMarginHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.ICON_SMALL_MARGIN)

    local iconClose = self:createIcon(self.uiFilename, posX + boxWidth - iconSmallWidth, headerTopY, iconSmallWidth, iconSmallHeight, InteractiveHUD.UV.BUTTON_CLOSE)
    self.buttonClose = HUDButtonElement:new(iconClose)
    --self.buttonClose:setButtonCallback(self, self.increaseTramLineMode)
    self.buttonClose:setBorders("1dp 0dp 0dp 0dp", InteractiveHUD.COLOR.BORDER)
    self.base:addChild(self.buttonClose)

    --HA counter.
    local textY = headerTopY
    local textSize = self:getCorrectedTextSize(InteractiveHUD.TEXT_SIZE.SMALL)

    self.iconSeederSeedUsage = self:createIcon(self.uiFilename, posX, textY, iconSmallWidth, iconSmallHeight, InteractiveHUD.UV.SEED_USAGE)
    self.seederSeedUsage = HUDElement:new(self.iconSeederSeedUsage)

    self.textElementSeedUsage = HUDTextElement:new(posX + iconSmallWidth, textY + iconSmallHeight * 0.33, textSize, RenderText.ALIGN_LEFT, InteractiveHUD.COLOR.TEXT_WHITE, false)
    self.textElementSeedUsage:setText("0l")

    local seedUsagePosX, seedUsagePosY = self.textElementSeedUsage:getPosition()
    seedUsagePosX = seedUsagePosX + iconSmallWidth + iconSmallMarginWidth

    self.iconSeederTotalWorkedHA = self:createIcon(self.uiFilename, seedUsagePosX, textY, iconSmallWidth, iconSmallHeight, InteractiveHUD.UV.TOTAL_WORKED_HA)
    self.seederTotalWorkedHA = HUDElement:new(self.iconSeederTotalWorkedHA)

    self.textElementTotalWorkedHA = HUDTextElement:new(seedUsagePosX + iconSmallWidth, textY + iconSmallHeight * 0.33, textSize, RenderText.ALIGN_LEFT, InteractiveHUD.COLOR.TEXT_WHITE, false)
    self.textElementTotalWorkedHA:setText("0ha")

    local workedHaPosX, workedHaPosY = self.textElementTotalWorkedHA:getPosition()
    workedHaPosX = workedHaPosX + iconSmallMarginWidth

    self.iconSeederWorkedHA = self:createIcon(self.uiFilename, workedHaPosX + iconSmallWidth + iconSmallMarginWidth, textY, iconSmallWidth, iconSmallHeight, InteractiveHUD.UV.WORKED_HA)
    self.seederWorkedHA = HUDElement:new(self.iconSeederWorkedHA)

    self.textElementWorkedHA = HUDTextElement:new(workedHaPosX + iconSmallWidth + iconSmallWidth + iconSmallMarginWidth, textY + iconSmallHeight * 0.33, textSize, RenderText.ALIGN_LEFT, InteractiveHUD.COLOR.TEXT_WHITE, false)
    self.textElementWorkedHA:setText("0ha (0.0 ha/h)")

    self.base:addChild(self.seederTotalWorkedHA)
    self.base:addChild(self.seederWorkedHA)
    self.base:addChild(self.seederSeedUsage)
    self.base:addChild(self.textElementTotalWorkedHA)
    self.base:addChild(self.textElementWorkedHA)
    self.base:addChild(self.textElementSeedUsage)

    local settingsY = posY + (boxHeight - headerHeight) + paddingHeight
    self:createTramLineDistanceBox(posX + (headerWidth * 0.5), settingsY)
    self:createTramLineCountBox(posX + (headerWidth), settingsY)
    self:createTramLineModeBox(posX, settingsY)
end

--- Create the box with the HUD icons.
function InteractiveHUD:createBaseBox(hudAtlasPath, x, y)
    local boxWidth, boxHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.BOX)
    local posX = x - boxWidth
    local boxOverlay = Overlay:new(hudAtlasPath, posX, y, boxWidth, boxHeight)
    local boxElement = HUDMovableElement:new(boxOverlay)

    --boxElement:setColor(0.013, 0.013, 0.013, 0.7)
    boxElement:setColor(unpack(InteractiveHUD.COLOR.MEDIUM_GLASS))
    boxElement:setUVs(getNormalizedUVs(InteractiveHUD.UV.FILL))
    boxElement:setVisible(true)
    boxElement:setBorders("1dp 1dp 1dp 4dp", InteractiveHUD.COLOR.BORDER)

    return boxElement
end

function InteractiveHUD:createIcon(imagePath, baseX, baseY, width, height, uvs)
    local iconOverlay = Overlay:new(imagePath, baseX, baseY, width, height)
    iconOverlay:setColor(unpack(InteractiveHUD.COLOR.INACTIVE))
    iconOverlay:setUVs(getNormalizedUVs(uvs))
    iconOverlay:setIsVisible(true)

    return iconOverlay
end

function InteractiveHUD:createSeederIcon(posX, posY)
    local seederWidth, seederHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.SEEDER)
    local seederMarginWidth, seederMarginHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.SEEDER_MARGIN)
    self.iconSeeder = self:createIcon(self.uiFilename, posX + seederMarginWidth, posY + seederMarginHeight, seederWidth, seederHeight, InteractiveHUD.UV.SEEDER)

    self.buttonSeeder = HUDElement:new(self.iconSeeder)

    local seederWidthWidth, seederWidthHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.WIDTH)
    self.iconSeederWidth = self:createIcon(self.uiFilename, posX, posY + seederHeight + (seederWidthHeight * 0.25), seederWidthWidth, seederWidthHeight, InteractiveHUD.UV.WIDTH)

    local textX = posX + seederMarginWidth + (seederWidth * 0.5)
    local textY = posY + seederHeight + (seederWidthHeight * 0.5)
    self.seederWidth = HUDElement:new(self.iconSeederWidth)

    local textSize = self:getCorrectedTextSize(InteractiveHUD.TEXT_SIZE.HIGHLIGHT)
    self.textElementWorkingWidth = HUDTextElement:new(textX, textY, textSize, RenderText.ALIGN_CENTER, InteractiveHUD.COLOR.TEXT_WHITE, true)
    self.textElementWorkingWidth:setText("0m")

    local markerPosX = posX
    local markerPosY = posY + seederHeight
    self.markerLeft = self:createMarker(markerPosX, markerPosY, false)
    self.base:addChild(self.markerLeft)

    self.markerRight = self:createMarker(markerPosX, markerPosY, true)
    self.base:addChild(self.markerRight)

    self.base:addChild(self.buttonSeeder)
    self.base:addChild(self.seederWidth)
    self.base:addChild(self.textElementWorkingWidth)

    self:createWorkingAreaSegments(posX, posY)
end

function InteractiveHUD:createMarker(posX, posY, invert)
    local width, height = self:scalePixelToScreenVector(InteractiveHUD.SIZE.MARKER)
    local marginWidth, marginHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.MARKER_MARGIN)

    posX = invert and posX + width or posX
    local markerIcon = self:createIcon(self.uiFilename, posX + marginWidth, posY + marginHeight, width, height, InteractiveHUD.UV.MARKER_UP)

    if invert then
        markerIcon:setInvertX(true)
    end

    return HUDElement:new(markerIcon)
end

function InteractiveHUD:createWorkingAreaSegments(posX, posY)
    local fillWidth, fillHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.SEGMENT)
    local segmentMarginWidth, segmentMarginHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.SEGMENT_MARGIN)
    self.segments = {}
    for i = 1, 20, 1 do
        local segmentX = posX + ((fillWidth + segmentMarginWidth) * (i - 1))
        local icon = self:createIcon(self.uiFilename, segmentX, posY + segmentMarginHeight, fillWidth, fillHeight, InteractiveHUD.UV.FILL)

        local element = HUDElement:new(icon)
        element:setColor(unpack(InteractiveHUD.COLOR.ACTIVE))

        table.insert(self.segments, element)
        self.base:addChild(element)
    end
end

function InteractiveHUD:visualizeHalfSideShutoff(mode)
    local numberOfSegments = #self.segments
    --Reset
    for i = 1, numberOfSegments, 1 do
        local element = self.segments[i]
        element:setColor(unpack(InteractiveHUD.COLOR.ACTIVE))
    end

    if mode ~= ProSeedTramLines.SHUTOFF_MODE_OFF then
        local shutOffLeft = mode == ProSeedTramLines.SHUTOFF_MODE_LEFT
        local shutOffRight = mode == ProSeedTramLines.SHUTOFF_MODE_RIGHT

        local startIndex = shutOffLeft and (numberOfSegments * 0.5) + 1 or 1
        local endIndex = shutOffRight and numberOfSegments * 0.5 or numberOfSegments

        for i = startIndex, endIndex, 1 do
            local element = self.segments[i]
            element:setColor(unpack(InteractiveHUD.COLOR.RED))
        end
    end
end

---Visualize the tramlines by marking 2 segments red on both sides or the middle segment.
function InteractiveHUD:visualizeTramLine(vehicle)
    local spec = vehicle.spec_proSeedTramLines
    local isActive = spec.createTramLines

    if isActive ~= self.tramLineVisualState then
        self:visualizeHalfSideShutoff(spec.shutoffMode)

        if isActive then
            local startIndex = #self.segments * 0.5
            local amountOfLanes = 2
            for i = startIndex + 1, startIndex + amountOfLanes, 1 do
                local element = self.segments[i]
                element:setColor(unpack(InteractiveHUD.COLOR.RED))
            end

            for i = startIndex - 1, startIndex - amountOfLanes, -1 do
                local element = self.segments[i]
                element:setColor(unpack(InteractiveHUD.COLOR.RED))
            end
        end

        self.buttonHalfSideShutoff:setDisabled(isActive)
        self.tramLineVisualState = isActive
    end
end

function InteractiveHUD:updateTramLineModeState(mode)
    local isAuto = mode == ProSeedTramLines.TRAMLINE_MODE_AUTO
    local isManual = mode == ProSeedTramLines.TRAMLINE_MODE_MANUAL
    self.buttonTramLineModePlus:setDisabled(isManual)
    self.buttonTramLineModeMin:setDisabled(isAuto)

    local key = ProSeedTramLines.TRAMLINE_MODE_TO_KEY[mode]
    self.textElementTramLineMode:setText(self.i18n:getText(("info_mode_%s"):format(key)))

    if isAuto then
        if self.vehicle ~= nil then
            local rootVehicle = self.vehicle:getRootVehicle()
            --Get GuidanceSteering information when active.
            if rootVehicle.getHasGuidanceSystem == nil or not rootVehicle:getHasGuidanceSystem() then
                self.mission:showBlinkingWarning(self.i18n:getText("warning_gpsNotActive"), 2000)
            end
        end
    end
end

function InteractiveHUD:updateTramLineCountingState(mode)
    local isActive = mode == ProSeedTramLines.TRAMLINE_MODE_AUTO
    self.buttonTramLineCountPlus:setDisabled(isActive)
    self.buttonTramLineCountMin:setDisabled(isActive)
end

function InteractiveHUD:createTramLineDistanceBox(posX, posY)
    local iconWidth, iconHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.ICON_SMALL)
    local iconMarginWidth, iconMarginHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.ICON_SMALL_MARGIN)
    local centerX = posX

    local iconPlus = self:createIcon(self.uiFilename, centerX + iconMarginWidth, posY + iconMarginHeight, iconWidth, iconHeight, InteractiveHUD.UV.BUTTON_PLUS)
    self.buttonTramLinePlus = HUDButtonElement:new(iconPlus)
    self.buttonTramLinePlus:setButtonCallback(self, self.increaseTramLineDistance)
    self.buttonTramLinePlus:setBorders("2dp 2dp 2dp 2dp", InteractiveHUD.COLOR.BORDER)

    local iconMin = self:createIcon(self.uiFilename, centerX - iconWidth - iconMarginWidth, posY, iconWidth, iconHeight, InteractiveHUD.UV.BUTTON_MIN)
    self.buttonTramLineMin = HUDButtonElement:new(iconMin)
    self.buttonTramLineMin:setButtonCallback(self, self.decreaseTramLineDistance)
    self.buttonTramLineMin:setBorders("2dp 2dp 2dp 2dp", InteractiveHUD.COLOR.BORDER)

    local textX = centerX
    local textY = posY + iconHeight + iconHeight * 0.25
    local textSize = self:getCorrectedTextSize(InteractiveHUD.TEXT_SIZE.HEADER)
    self.textElementTramLineDistance = HUDTextElement:new(textX, textY, textSize, RenderText.ALIGN_CENTER, InteractiveHUD.COLOR.TEXT_WHITE, false)
    self.textElementTramLineDistance:setText("0m")

    local textSizeHeader = self:getCorrectedTextSize(InteractiveHUD.TEXT_SIZE.SMALL)
    self.textElementTramLineDistanceHeader = HUDTextElement:new(textX, textY + iconHeight * 0.8, textSizeHeader, RenderText.ALIGN_CENTER, InteractiveHUD.COLOR.TEXT_WHITE, false)
    self.textElementTramLineDistanceHeader:setText(self.i18n:getText("info_tramline_distance_header"))

    self.base:addChild(self.buttonTramLinePlus)
    self.base:addChild(self.buttonTramLineMin)
    self.base:addChild(self.textElementTramLineDistance)
    self.base:addChild(self.textElementTramLineDistanceHeader)
end

function InteractiveHUD:createTramLineCountBox(posX, posY)
    local iconWidth, iconHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.ICON_SMALL)
    local iconMarginWidth, iconMarginHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.ICON_SMALL_MARGIN)
    local centerX = posX - (iconWidth * 2) - iconWidth * 0.5

    local iconPlus = self:createIcon(self.uiFilename, centerX + iconMarginWidth, posY + iconMarginHeight, iconWidth, iconHeight, InteractiveHUD.UV.BUTTON_PLUS)
    self.buttonTramLineCountPlus = HUDButtonElement:new(iconPlus)
    self.buttonTramLineCountPlus:setButtonCallback(self, self.increaseTramLinePassedCount)
    self.buttonTramLineCountPlus:setBorders("2dp 2dp 2dp 2dp", InteractiveHUD.COLOR.BORDER)
    self.buttonTramLineCountPlus:setDisabled(true)

    local iconMin = self:createIcon(self.uiFilename, centerX - iconWidth - iconMarginWidth, posY + iconMarginHeight, iconWidth, iconHeight, InteractiveHUD.UV.BUTTON_MIN)
    self.buttonTramLineCountMin = HUDButtonElement:new(iconMin)
    self.buttonTramLineCountMin:setButtonCallback(self, self.decreaseTramLinePassedCount)
    self.buttonTramLineCountMin:setBorders("2dp 2dp 2dp 2dp", InteractiveHUD.COLOR.BORDER)
    self.buttonTramLineCountMin:setDisabled(true)

    local textX = centerX
    local textY = posY + iconHeight + iconHeight * 0.25
    local textSize = self:getCorrectedTextSize(InteractiveHUD.TEXT_SIZE.HEADER)
    self.textElementTramLineCount = HUDTextElement:new(textX, textY, textSize, RenderText.ALIGN_CENTER, InteractiveHUD.COLOR.TEXT_WHITE, false)
    self.textElementTramLineCount:setText("0 / 0")

    local textSizeHeader = self:getCorrectedTextSize(InteractiveHUD.TEXT_SIZE.SMALL)
    self.textElementTramLineCountHeader = HUDTextElement:new(textX, textY + iconHeight * 0.8, textSizeHeader, RenderText.ALIGN_CENTER, InteractiveHUD.COLOR.TEXT_WHITE, false)
    self.textElementTramLineCountHeader:setText(self.i18n:getText("info_line_number_header"))

    self.base:addChild(self.buttonTramLineCountPlus)
    self.base:addChild(self.buttonTramLineCountMin)
    self.base:addChild(self.textElementTramLineCount)
    self.base:addChild(self.textElementTramLineCountHeader)
end

function InteractiveHUD:createTramLineModeBox(posX, posY)
    local iconWidth, iconHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.ICON_SMALL)
    local iconMarginWidth, iconMarginHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.ICON_SMALL_MARGIN)
    local centerX = posX + (iconWidth * 2) + iconWidth * 0.5

    local iconPlus = self:createIcon(self.uiFilename, centerX + iconMarginWidth, posY + iconMarginHeight, iconWidth, iconHeight, InteractiveHUD.UV.BUTTON_ARROW)
    self.buttonTramLineModePlus = HUDButtonElement:new(iconPlus)
    self.buttonTramLineModePlus:setButtonCallback(self, self.increaseTramLineMode)
    self.buttonTramLineModePlus:setBorders("2dp 2dp 2dp 2dp", InteractiveHUD.COLOR.BORDER)

    local iconMin = self:createIcon(self.uiFilename, centerX - iconWidth - iconMarginWidth, posY + iconMarginHeight, iconWidth, iconHeight, InteractiveHUD.UV.BUTTON_ARROW)
    iconMin:setRotation(math.rad(180), iconWidth * 0.5, iconHeight * 0.5)

    self.buttonTramLineModeMin = HUDButtonElement:new(iconMin)
    self.buttonTramLineModeMin:setButtonCallback(self, self.decreaseTramLineMode)
    self.buttonTramLineModeMin:setBorders("2dp 2dp 2dp 2dp", InteractiveHUD.COLOR.BORDER)

    local textX = centerX
    local textY = posY + iconHeight + iconHeight * 0.25
    local textSize = self:getCorrectedTextSize(InteractiveHUD.TEXT_SIZE.HEADER)
    self.textElementTramLineMode = HUDTextElement:new(textX, textY, textSize, RenderText.ALIGN_CENTER, InteractiveHUD.COLOR.TEXT_WHITE, false)

    local textSizeHeader = self:getCorrectedTextSize(InteractiveHUD.TEXT_SIZE.SMALL)
    self.textElementTramLineModeHeader = HUDTextElement:new(textX, textY + iconHeight * 0.8, textSizeHeader, RenderText.ALIGN_CENTER, InteractiveHUD.COLOR.TEXT_WHITE, false)
    self.textElementTramLineModeHeader:setText(self.i18n:getText("info_mode_header"))

    self.base:addChild(self.buttonTramLineModePlus)
    self.base:addChild(self.buttonTramLineModeMin)
    self.base:addChild(self.textElementTramLineMode)
    self.base:addChild(self.textElementTramLineModeHeader)
end

InteractiveHUD.TEXT_SIZE = {
    HEADER = 18,
    HIGHLIGHT = 22,
    SMALL = 12
}

InteractiveHUD.SIZE = {
    BOX = { 308, 196 }, -- 4px border correction
    BOX_MARGIN = { 20, 40 },
    BOX_PADDING = { 0, 4 },
    ICON = { 54, 54 },
    ICON_SMALL = { 22, 22 },
    ICON_SMALL_MARGIN = { 5, 0 },
    SEEDER = { 200, 60 },
    WIDTH = { 200, 50 },
    SEGMENT = { 10, 5 },
    SEGMENT_MARGIN = { 0, 0 },
    SEEDER_MARGIN = { 0, 0 },
    HEADER = { 308, 89 },
    HEADER_TOP = { 308, 22 },
    MARKER = { 100, 50 },
    MARKER_MARGIN = { 0, -5 },
}

InteractiveHUD.UV = {
    TRAM_LINE = { 0, 0, 65, 65 },
    TRAM_LINE_ACTIVE = { 130, 0, 65, 65 },
    FILL = { 910, 65, 65, 65 },
    FERTILIZER = { 65, 0, 65, 65 },
    SOUND = { 65, 65, 65, 65 },
    SHUTOFF = { 0, 65, 65, 65 },
    SEEDER = { 325, 0, 260, 65 },
    PLANTER = { 325, 65, 260, 65 },
    WIDTH = { 130, 65, 130, 65 },
    BUTTON_PLUS = { 260, 0, 65, 65 },
    BUTTON_MIN = { 260, 65, 65, 65 },
    BUTTON_ARROW = { 195, 0, 65, 65 },
    TOTAL_WORKED_HA = { 585, 0, 65, 65 },
    WORKED_HA = { 585, 65, 65, 65 },
    SEED_USAGE = { 650, 65, 65, 65 },
    BUTTON_CLOSE = { 650, 0, 65, 65 },
    MARKER = { 715, 0, 130, 65 },
    MARKER_UP = { 715, 65, 130, 65 },
}

InteractiveHUD.COLOR = {
    TEXT = { 0, 0, 0, 1 },
    TEXT_WHITE = { 1, 1, 1, 0.75 },
    INACTIVE = { 1, 1, 1, 0.75 },
    ACTIVE = { 0.9910, 0.3865, 0.0100, 1 },
    BORDER = { 0.718, 0.716, 0.715, 0.25 },
    RED = { 0.718, 0, 0, 0.75 },
    DARK_GLASS = { 0.018, 0.016, 0.015, 0.9 },
    MEDIUM_GLASS = { 0.018, 0.016, 0.015, 0.8 },
}
