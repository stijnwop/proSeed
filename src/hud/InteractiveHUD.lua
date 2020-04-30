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

function InteractiveHUD:setVehicle(vehicle)
    self.vehicle = vehicle
    if self.base ~= nil then
        self.base:setVisible(vehicle ~= nil)
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
    self.icon = self:createIcon(self.uiFilename, posX, posY, iconWidth, iconHeight, InteractiveHUD.UV.TRAM_LINE)
    self.icon:setIsVisible(true)

    self.button = HUDButtonElement:new(self.icon)
    self.button:setBorders("0dp 1dp 1dp 0dp", InteractiveHUD.COLOR.BORDER)

    self.base:addChild(self.button)

    self.icon1 = self:createIcon(self.uiFilename, posX, posY + iconHeight, iconWidth, iconHeight, InteractiveHUD.UV.FERTILIZER)
    self.icon1:setIsVisible(true)

    self.button1 = HUDButtonElement:new(self.icon1)
    self.button1:setBorders("0dp 0dp 1dp 0dp", InteractiveHUD.COLOR.BORDER)
    self.base:addChild(self.button1)

    self:createSeederIcon(posX + iconWidth, posY)

    --SOUND ICON
    self.iconSound = self:createIcon(self.uiFilename, posX + boxWidth - iconWidth, posY, iconWidth, iconHeight, InteractiveHUD.UV.SOUND)
    self.iconSound:setIsVisible(true)

    self.buttonSound = HUDButtonElement:new(self.iconSound)
    self.buttonSound:setBorders("1dp 1dp 0dp 0dp", InteractiveHUD.COLOR.BORDER)
    self.buttonSound:setButtonCallback(self, self.toggleVehicleSound)
    self.buttonSound:setColor(unpack(InteractiveHUD.COLOR.ACTIVE)) -- TODO: remove
    self.base:addChild(self.buttonSound)

    self.iconGuidanceSteering = self:createIcon(self.uiFilename, posX + boxWidth - iconWidth, posY + iconHeight, iconWidth, iconHeight, InteractiveHUD.UV.GPS)
    self.iconGuidanceSteering:setIsVisible(true)

    self.buttonGuidanceSteering = HUDButtonElement:new(self.iconGuidanceSteering)
    self.buttonGuidanceSteering:setBorders("1dp 0dp 0dp 0dp", InteractiveHUD.COLOR.BORDER)
    self.buttonGuidanceSteering:setButtonCallback(self, self.toggleVehicleSound)
    self.buttonGuidanceSteering:setColor(unpack(InteractiveHUD.COLOR.ACTIVE)) -- TODO: remove
    self.base:addChild(self.buttonGuidanceSteering)

    local headerWidth, headerHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.HEADER)
    self.buttonHeader = HUDButtonElement:new(Overlay:new(nil, posX, posY + (boxHeight - headerHeight), headerWidth, headerHeight))
    self.buttonHeader:setBorders("0dp 0dp 0dp 1dp", InteractiveHUD.COLOR.BORDER)
    self.base:addChild(self.buttonHeader)

    self:createTramLineDistanceBox(posX, posY + (boxHeight - headerHeight))
end

--- Create the box with the HUD icons.
function InteractiveHUD:createBaseBox(hudAtlasPath, x, y)
    local uiScale = 1

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
    self.iconTramLineActive:setColor(0.9910, 0.3865, 0.0100, 1)

    self.tramLineActive = HUDElement:new(self.iconTramLineActive)

    local textX = posX + seederMarginWidth + (seederWidth * 0.5)
    local textY = posY + (seederHeight * 0.65)
    self.textElement = HUDTextDisplay:new(textX, textY, 22, RenderText.ALIGN_CENTER, InteractiveHUD.COLOR.TEXT, true)
    self.textElement:setText("12m")


    --self.headerElement = HUDTextDisplay:new(textX, posY + seederHeight, 25, RenderText.ALIGN_CENTER, InteractiveHUD.COLOR.INACTIVE, false)
    --self.headerElement:setText("SeedAssist")

    self.base:addChild(self.buttonSeeder)
    self.base:addChild(self.tramLineActive)
    self.base:addChild(self.textElement)
    --self.base:addChild(self.headerElement)
end

function InteractiveHUD:createTramLineDistanceBox(posX, posY)

    local iconWidth, iconHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.ICON_SMALL)
    local iconPlus = self:createIcon(self.uiFilename, posX + iconWidth, posY, iconWidth, iconHeight, InteractiveHUD.UV.BUTTON_PLUS)
    iconPlus:setIsVisible(true)
    self.buttonTramlinePlus = HUDButtonElement:new(iconPlus)
    self.base:addChild(self.buttonTramlinePlus)
    local iconMin = self:createIcon(self.uiFilename, posX, posY, iconWidth, iconHeight, InteractiveHUD.UV.BUTTON_MIN)
    iconMin:setIsVisible(true)
    self.buttonTramlineMin = HUDButtonElement:new(iconMin)
    self.base:addChild(self.buttonTramlineMin)
end

InteractiveHUD.SIZE = {
    BOX = { 308, 166 }, -- 4px border correction
    BOX_MARGIN = { 20, 40 },
    BOX_PADDING = { 0, 4 },
    ICON = { 54, 54 },
    ICON_SMALL = { 27, 27 },
    SEEDER = { 120, 120 },
    SEEDER_MARGIN = { 40, -2 },
    HEADER = { 308, 55 },
}

InteractiveHUD.UV = {
    TRAM_LINE = { 0, 0, 65, 65 },
    TRAM_LINE_ACTIVE = { 130, 0, 65, 65 },
    FILL = { 910, 65, 65, 65 },
    FERTILIZER = { 65, 0, 65, 65 },
    SOUND = { 65, 65, 65, 65 },
    GPS = { 650, 65, 65, 65 },
    SEEDER = { 455, 0, 130, 130 },
    BUTTON_PLUS = { 260, 0, 65, 65 },
    BUTTON_MIN = { 260, 65, 65, 65 },
}

InteractiveHUD.COLOR = {
    TEXT = { 0, 0, 0, 1 },
    INACTIVE = { 1, 1, 1, 0.75 },
    ACTIVE = { 0.0953, 1, 0.0685, 0.75 },
    BORDER = { 0.718, 0.716, 0.715, 0.25 },
}
