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

---Creates a new instance of the InteractiveHUD.
---@return InteractiveHUD
function InteractiveHUD:new(mission, i18n, inputBinding, gui, modDirectory, uiFilename)
    local instance = setmetatable({}, InteractiveHUD_mt)

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
    self:createElements()
    self:setVehicle(nil)
end

---Toggle mouse cursor mode and go into a context to block any other input.
function InteractiveHUD:toggleMouseCursor()
    local isActive = not g_inputBinding:getShowMouseCursor()
    g_inputBinding:setShowMouseCursor(isActive)

    if not self.isCustomInputActive and isActive then
        self.inputBinding:setContext(InteractiveHUD.INPUT_CONTEXT_NAME, true, false)

        local _, eventId = self.inputBinding:registerActionEvent(InputAction.GS_TOGGLE_MOUSE_CURSOR, self, self.toggleMouseCursor, false, true, false, true)
        self.inputBinding:setActionEventTextVisibility(eventId, false)

        self.isCustomInputActive = true
    elseif self.isCustomInputActive and not isActive then
        self.inputBinding:removeActionEventsByTarget(self)
        self.inputBinding:revertContext(true) -- revert and clear message context
        self.isCustomInputActive = false
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
            local spec = vehicle.spec_proSeedTramLines
            self.textElementTramLineDistance.text = (("%sm"):format(spec.tramLineDistance))
            self.textElementWorkingWidth.text = (("%sm"):format(spec.workingWidthRounded))
            self.buttonPreMarkers:setSelected(spec.createPreMarkedTramLines)

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
        local color = spec.createTramLines and InteractiveHUD.COLOR.ACTIVE or InteractiveHUD.COLOR.INACTIVE
        self.iconTramLineActive:setColor(unpack(color))

        local lanesForDistance = spec.tramLineDistance / spec.workingWidthRounded
        self.textElementTramLineCount.text = (("%s / %s"):format(spec.currentLane, lanesForDistance))
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

            self.textElementTramLineDistance.text = (("%sm"):format(spec.tramLineDistance))
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
            self.textElementTramLineDistance.text = (("%sm"):format(spec.tramLineDistance))
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
    self.iconPreMarkers:setIsVisible(true)

    self.buttonPreMarkers = HUDButtonElement:new(self.iconPreMarkers)
    self.buttonPreMarkers:setBorders("0dp 1dp 1dp 0dp", InteractiveHUD.COLOR.BORDER)
    self.buttonPreMarkers:setButtonCallback(self, self.toggleVehiclePreMarkersState)
    self.base:addChild(self.buttonPreMarkers)

    self.iconFertilizer = self:createIcon(self.uiFilename, posX, posY + iconHeight, iconWidth, iconHeight, InteractiveHUD.UV.FERTILIZER)
    self.iconFertilizer:setIsVisible(true)

    self.buttonFertilizer = HUDButtonElement:new(self.iconFertilizer)
    self.buttonFertilizer:setBorders("0dp 0dp 1dp 0dp", InteractiveHUD.COLOR.BORDER)
    self.buttonFertilizer:setButtonCallback(self, self.toggleVehicleSowingFertilizer)
    self.base:addChild(self.buttonFertilizer)

    self:createSeederIcon(posX + iconWidth, posY)

    --SOUND ICON
    self.iconSound = self:createIcon(self.uiFilename, posX + boxWidth - iconWidth, posY, iconWidth, iconHeight, InteractiveHUD.UV.SOUND)
    self.iconSound:setIsVisible(true)

    self.buttonSound = HUDButtonElement:new(self.iconSound)
    self.buttonSound:setBorders("1dp 1dp 0dp 0dp", InteractiveHUD.COLOR.BORDER)
    self.buttonSound:setButtonCallback(self, self.toggleVehicleSound)
    self.base:addChild(self.buttonSound)

    self.iconGuidanceSteering = self:createIcon(self.uiFilename, posX + boxWidth - iconWidth, posY + iconHeight, iconWidth, iconHeight, InteractiveHUD.UV.SHUTOFF)
    self.iconGuidanceSteering:setIsVisible(true)

    self.buttonGuidanceSteering = HUDButtonElement:new(self.iconGuidanceSteering)
    self.buttonGuidanceSteering:setBorders("1dp 0dp 0dp 0dp", InteractiveHUD.COLOR.BORDER)
    self.buttonGuidanceSteering:setButtonCallback(self, self.toggleVehicleSound)
    self.base:addChild(self.buttonGuidanceSteering)

    local headerWidth, headerHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.HEADER)
    self.buttonHeader = HUDButtonElement:new(Overlay:new(nil, posX, posY + (boxHeight - headerHeight), headerWidth, headerHeight))
    self.buttonHeader:setBorders("0dp 0dp 0dp 1dp", InteractiveHUD.COLOR.BORDER)
    self.base:addChild(self.buttonHeader)

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

    boxElement:setColor(0.013, 0.013, 0.013, 0.7)
    boxElement:setUVs(getNormalizedUVs(InteractiveHUD.UV.FILL))
    boxElement:setVisible(true)
    boxElement:setBorders("1dp 1dp 1dp 4dp", InteractiveHUD.COLOR.BORDER)

    return boxElement
end

function InteractiveHUD:createIcon(imagePath, baseX, baseY, width, height, uvs)
    local iconOverlay = Overlay:new(imagePath, baseX, baseY, width, height)
    iconOverlay:setColor(unpack(InteractiveHUD.COLOR.INACTIVE))
    iconOverlay:setUVs(getNormalizedUVs(uvs))

    return iconOverlay
end

function InteractiveHUD:createSeederIcon(posX, posY)
    local seederWidth, seederHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.SEEDER)
    local seederMarginWidth, seederMarginHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.SEEDER_MARGIN)
    self.iconSeeder = self:createIcon(self.uiFilename, posX + seederMarginWidth, posY + seederMarginHeight, seederWidth, seederHeight, InteractiveHUD.UV.SEEDER)
    self.iconSeeder:setIsVisible(true)

    self.buttonSeeder = HUDElement:new(self.iconSeeder)

    self.iconTramLineActive = self:createIcon(self.uiFilename, posX + seederMarginWidth, posY, seederWidth, seederHeight, InteractiveHUD.UV.TRAM_LINE_ACTIVE)
    self.iconTramLineActive:setIsVisible(true)

    self.tramLineActive = HUDElement:new(self.iconTramLineActive)

    local textX = posX + seederMarginWidth + (seederWidth * 0.5)
    local textY = posY + (seederHeight * 0.65)

    local textSize = 22 * self:getUIScale()
    self.textElementWorkingWidth = HUDTextDisplay:new(textX, textY, textSize, RenderText.ALIGN_CENTER, InteractiveHUD.COLOR.TEXT, true)
    self.textElementWorkingWidth:setText("0m")

    --self.headerElement = HUDTextDisplay:new(textX, posY + seederHeight, 25, RenderText.ALIGN_CENTER, InteractiveHUD.COLOR.INACTIVE, false)
    --self.headerElement:setText("SeedAssist")

    self.base:addChild(self.buttonSeeder)
    self.base:addChild(self.tramLineActive)
    self.base:addChild(self.textElementWorkingWidth)
    --self.base:addChild(self.headerElement)
end

function InteractiveHUD:createTramLineDistanceBox(posX, posY)
    local iconWidth, iconHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.ICON_SMALL)
    local iconMarginWidth, iconMarginHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.ICON_SMALL_MARGIN)

    local iconPlus = self:createIcon(self.uiFilename, posX + iconMarginWidth, posY + iconMarginHeight, iconWidth, iconHeight, InteractiveHUD.UV.BUTTON_PLUS)
    iconPlus:setIsVisible(true)
    self.buttonTramlinePlus = HUDButtonElement:new(iconPlus)
    self.buttonTramlinePlus:setButtonCallback(self, self.increaseTramLineDistance)
    self.buttonTramlinePlus:setBorders("1dp 1dp 1dp 1dp", InteractiveHUD.COLOR.BORDER)
    self.base:addChild(self.buttonTramlinePlus)

    local iconMin = self:createIcon(self.uiFilename, posX - iconWidth - iconMarginWidth + iconMarginHeight, posY, iconWidth, iconHeight, InteractiveHUD.UV.BUTTON_MIN)
    iconMin:setIsVisible(true)
    self.buttonTramlineMin = HUDButtonElement:new(iconMin)
    self.buttonTramlineMin:setButtonCallback(self, self.decreaseTramLineDistance)
    self.buttonTramlineMin:setBorders("1dp 1dp 1dp 1dp", InteractiveHUD.COLOR.BORDER)
    self.base:addChild(self.buttonTramlineMin)

    local textX = posX
    local textY = posY + iconHeight+ iconHeight * 0.5
    local textSize = 18 * self:getUIScale()
    self.textElementTramLineDistance = HUDTextDisplay:new(textX, textY, textSize, RenderText.ALIGN_CENTER, InteractiveHUD.COLOR.TEXT_WHITE, false)
    self.textElementTramLineDistance:setText("0m")
    self.base:addChild(self.textElementTramLineDistance)
end

function InteractiveHUD:createTramLineCountBox(posX, posY)
    local iconWidth, iconHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.ICON_SMALL)
    local iconMarginWidth, iconMarginHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.ICON_SMALL_MARGIN)

    posX = posX - (iconWidth + iconMarginWidth) * 2

    local iconPlus = self:createIcon(self.uiFilename, posX + iconMarginWidth, posY + iconMarginHeight, iconWidth, iconHeight, InteractiveHUD.UV.BUTTON_PLUS)
    iconPlus:setIsVisible(true)
    self.buttonTramLineCountPlus = HUDButtonElement:new(iconPlus)
    self.buttonTramLineCountPlus:setButtonCallback(self, self.increaseTramLineDistance)
    self.buttonTramLineCountPlus:setBorders("1dp 1dp 1dp 1dp", InteractiveHUD.COLOR.BORDER)
    self.base:addChild(self.buttonTramLineCountPlus)

    local iconMin = self:createIcon(self.uiFilename, posX - iconWidth - iconMarginWidth + iconMarginHeight, posY, iconWidth, iconHeight, InteractiveHUD.UV.BUTTON_MIN)
    iconMin:setIsVisible(true)
    self.buttonTramLineCountMin = HUDButtonElement:new(iconMin)
    self.buttonTramLineCountMin:setButtonCallback(self, self.decreaseTramLineDistance)
    self.buttonTramLineCountMin:setBorders("1dp 1dp 1dp 1dp", InteractiveHUD.COLOR.BORDER)
    self.base:addChild(self.buttonTramLineCountMin)

    local textX = posX
    local textY = posY + iconHeight + iconHeight * 0.5
    local textSize = 18 * self:getUIScale()
    self.textElementTramLineCount = HUDTextDisplay:new(textX, textY, textSize, RenderText.ALIGN_CENTER, InteractiveHUD.COLOR.TEXT_WHITE, false)
    self.textElementTramLineCount:setText("0 / 0")
    self.base:addChild(self.textElementTramLineCount)
end


function InteractiveHUD:createTramLineModeBox(posX, posY)
    local iconWidth, iconHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.ICON_SMALL)
    local iconMarginWidth, iconMarginHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.ICON_SMALL_MARGIN)

    posX = posX + (iconWidth + iconMarginWidth) * 2

    local iconPlus = self:createIcon(self.uiFilename, posX + iconMarginWidth, posY + iconMarginHeight, iconWidth, iconHeight, InteractiveHUD.UV.BUTTON_PLUS)
    iconPlus:setIsVisible(true)
    self.buttonTramLineModePlus = HUDButtonElement:new(iconPlus)
    self.buttonTramLineModePlus:setButtonCallback(self, self.increaseTramLineDistance)
    self.buttonTramLineModePlus:setBorders("1dp 1dp 1dp 1dp", InteractiveHUD.COLOR.BORDER)
    self.base:addChild(self.buttonTramLineModePlus)

    local iconMin = self:createIcon(self.uiFilename, posX - iconWidth - iconMarginWidth + iconMarginHeight, posY, iconWidth, iconHeight, InteractiveHUD.UV.BUTTON_MIN)
    iconMin:setIsVisible(true)
    self.buttonTramLineModeMin = HUDButtonElement:new(iconMin)
    self.buttonTramLineModeMin:setButtonCallback(self, self.decreaseTramLineDistance)
    self.buttonTramLineModeMin:setBorders("1dp 1dp 1dp 1dp", InteractiveHUD.COLOR.BORDER)
    self.base:addChild(self.buttonTramLineModeMin)

    local textX = posX
    local textY = posY + iconHeight + iconHeight * 0.5
    local textSize = 18 * self:getUIScale()
    self.textElementTramLineMode = HUDTextDisplay:new(textX, textY, textSize, RenderText.ALIGN_CENTER, InteractiveHUD.COLOR.TEXT_WHITE, false)
    self.textElementTramLineMode:setText("Auto")
    self.base:addChild(self.textElementTramLineMode)
end

InteractiveHUD.SIZE = {
    BOX = { 308, 176 }, -- 4px border correction
    BOX_MARGIN = { 20, 40 },
    BOX_PADDING = { 0, 4 },
    ICON = { 54, 54 },
    ICON_SMALL = { 22, 22 },
    ICON_SMALL_MARGIN = { 5, 0 },
    SEEDER = { 120, 120 },
    SEEDER_MARGIN = { 40, -2 },
    HEADER = { 308, 69 },
}

InteractiveHUD.UV = {
    TRAM_LINE = { 0, 0, 65, 65 },
    TRAM_LINE_ACTIVE = { 130, 0, 65, 65 },
    FILL = { 910, 65, 65, 65 },
    FERTILIZER = { 65, 0, 65, 65 },
    SOUND = { 65, 65, 65, 65 },
    SHUTOFF = { 585, 0, 65, 65 },
    SEEDER = { 455, 0, 130, 130 },
    BUTTON_PLUS = { 260, 0, 65, 65 },
    BUTTON_MIN = { 260, 65, 65, 65 },
}

InteractiveHUD.COLOR = {
    TEXT = { 0, 0, 0, 1 },
    TEXT_WHITE = { 1, 1, 1, 0.75 },
    INACTIVE = { 1, 1, 1, 0.75 },
    ACTIVE = { 0.9910, 0.3865, 0.0100, 1 },
    BORDER = { 0.718, 0.716, 0.715, 0.25 },
}
