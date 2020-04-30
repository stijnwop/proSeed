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
        local eventUsed = self.base:mouseEvent(posX, posY, isDown, isUp, button, false)
        for _, child in ipairs(self.base.children) do
            if child.mouseEvent ~= nil then
                eventUsed = child:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
            end

            if eventUsed then
                break
            end
        end
    end
end

function InteractiveHUD:scalePixelToScreenVector(vector2D)
    return self.speedMeterDisplay:scalePixelToScreenVector(vector2D)
end

function InteractiveHUD:toggleVehicleSound(buttonElement)
    if self.vehicle ~= nil then
        if self.vehicle.toggleSowingSounds ~= nil then
            local state = self.vehicle:toggleSowingSounds()
            local color = state and InteractiveHUD.COLOR.ACTIVE or InteractiveHUD.COLOR.INACTIVE
            buttonElement:setColor(unpack(color))
        end
    end
end

function InteractiveHUD:createElements()
    local rightX = 1 - g_safeFrameOffsetX -- right of screen.
    local bottomY = g_safeFrameOffsetY

    local boxWidth, boxHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.BOX)
    local marginWidth, marginHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.BOX_MARGIN)

    local iconWidth, iconHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.ICON)

    local baseBox = self:createBaseBox(self.uiFilename, rightX - marginWidth, bottomY - marginHeight)

    self.base = baseBox
    self.base:setVisible(true)
    self.speedMeterDisplay:addChild(baseBox)

    local posX, posY = self.base:getPosition()
    self.icon = self:createIcon(self.uiFilename, posX, posY, iconWidth, iconHeight, InteractiveHUD.UV.TRAM_LINE)
    self.icon:setIsVisible(true)

    self.button = HUDButtonElement:new(self.icon)

    self.base:addChild(self.button)

    self.icon1 = self:createIcon(self.uiFilename, posX, posY + iconHeight, iconWidth, iconHeight, InteractiveHUD.UV.FERTILIZER)
    self.icon1:setIsVisible(true)

    self.button1 = HUDButtonElement:new(self.icon1)
    self.base:addChild(self.button1)

    self:createSeederIcon(posX + iconWidth, posY)

    --SOUND ICON
    self.iconSound = self:createIcon(self.uiFilename, posX + boxWidth - iconWidth, posY, iconWidth, iconHeight, InteractiveHUD.UV.SOUND)
    self.iconSound:setIsVisible(true)

    self.buttonSound = HUDButtonElement:new(self.iconSound)
    self.buttonSound:setButtonCallback(self, self.toggleVehicleSound)
    self.buttonSound:setColor(unpack(InteractiveHUD.COLOR.ACTIVE)) -- TODO: remove
    self.base:addChild(self.buttonSound)

    self.iconGuidanceSteering = self:createIcon(self.uiFilename, posX + boxWidth - iconWidth, posY + iconHeight, iconWidth, iconHeight, InteractiveHUD.UV.GPS)
    self.iconGuidanceSteering:setIsVisible(true)

    self.buttonGuidanceSteering = HUDButtonElement:new(self.iconGuidanceSteering)
    self.buttonGuidanceSteering:setButtonCallback(self, self.toggleVehicleSound)
    self.buttonGuidanceSteering:setColor(unpack(InteractiveHUD.COLOR.ACTIVE)) -- TODO: remove
    self.base:addChild(self.buttonGuidanceSteering)
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
    self.base:addChild(self.buttonSeeder)
    self.base:addChild(self.tramLineActive)
end

InteractiveHUD.SIZE = {
    BOX = { 308, 150 },
    BOX_MARGIN = { 20, 40 },
    ICON = { 54, 54 },
    SEEDER = { 100, 100 },
    SEEDER_MARGIN = { 50, 8 },
}

InteractiveHUD.UV = {
    TRAM_LINE = { 0, 0, 65, 65 },
    TRAM_LINE_ACTIVE = { 130, 0, 65, 65 },
    FILL = { 0, 65, 65, 65 },
    FERTILIZER = { 65, 0, 65, 65 },
    SOUND = { 65, 65, 65, 65 },
    GPS = { 650, 65, 65, 65 },
    SEEDER = { 455, 0, 130, 130 },
}

InteractiveHUD.COLOR = {
    INACTIVE = { 1, 1, 1, 0.75 },
    ACTIVE = { 0.0953, 1, 0.0685, 0.75 }
}
