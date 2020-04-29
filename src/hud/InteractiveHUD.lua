----------------------------------------------------------------------------------------------------
-- InteractiveHUD
----------------------------------------------------------------------------------------------------
-- Purpose: Base class for an interactive HUD.
--
-- Copyright (c) Wopster, 2020
----------------------------------------------------------------------------------------------------

---@class InteractiveHUD
InteractiveHUD = {}

local InteractiveHUD_mt = Class(InteractiveHUD)

---Creates a new instance of the InteractiveHUD.
---@return InteractiveHUD
function InteractiveHUD:new(mission, i18n, inputBinding, gui, uiFilename)
    local instance = setmetatable({}, InteractiveHUD_mt)

    instance.gui = gui
    instance.inputBinding = inputBinding
    instance.i18n = i18n
    instance.uiFilename = uiFilename

    instance.speedMeterDisplay = mission.hud.speedMeter

    instance.vehicle = nil
    instance.isMoving = false

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

function InteractiveHUD:setVehicle(vehicle)
    self.vehicle = vehicle
    if self.base ~= nil then
        self.base:setVisible(vehicle ~= nil)
    end
end

---Called on mouse event.
function InteractiveHUD:mouseEvent(posX, posY, isDown, isUp, button)
    if self.vehicle ~= nil and not self.gui:getIsGuiVisible() and self.inputBinding:getShowMouseCursor() then
        local isLeftButton = button == Input.MOUSE_BUTTON_LEFT
        if self.isDirty then
            if isLeftButton and isUp then
                self:setIsPositionDirty(false)
            else
                self:setPositionByMousePosition(posX, posY)
            end
        else
            local x, y = self:getPosition()
            if isLeftButton and isDown and GuiUtils.checkOverlayOverlap(posX, posY, x, y, self.base:getWidth(), self.base:getHeight()) then
                self:setIsPositionDirty(true, posX, posY)
            end
        end
    end
end

---Set position dirty and if it requires and update.
function InteractiveHUD:setIsPositionDirty(isDirty, mouseX, mouseY)
    self.isDirty = isDirty

    if isDirty then
        self.currentMouseX = mouseX
        self.currentMouseY = mouseY
    end
end

---Set base position based on the given mouse position.
function InteractiveHUD:setPositionByMousePosition(mouseX, mouseY)
    if self.isDirty then
        local moveX, moveY = mouseX - self.currentMouseX, mouseY - self.currentMouseY
        local x, y = self.base:getPosition()
        self:setPosition(x + moveX, y + moveY)
        self.currentMouseX = mouseX
        self.currentMouseY = mouseY
    end
end

---Set position of the HUD.
function InteractiveHUD:setPosition(x, y)
    self.base:setPosition(x, y)
end

---Get the position of the HUD.
function InteractiveHUD:getPosition()
    return self.base:getPosition()
end

function InteractiveHUD:scalePixelToScreenVector(vector2D)
    return self.speedMeterDisplay:scalePixelToScreenVector(vector2D)
end

function InteractiveHUD:createElements()
    local rightX = 1 - g_safeFrameOffsetX -- right of screen.
    local bottomY = g_safeFrameOffsetY

    local marginWidth, marginHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.BOX_MARGIN)
    local baseBox = self:createBaseBox(g_baseUIFilename, rightX - marginWidth, bottomY - marginHeight)

    self.base = baseBox
    self.base:setVisible(true)
    self.speedMeterDisplay:addChild(baseBox)
end

--- Create the box with the HUD icons.
function InteractiveHUD:createBaseBox(hudAtlasPath, x, y)
    local uiScale = 1

    local boxWidth, boxHeight = self:scalePixelToScreenVector(InteractiveHUD.SIZE.BOX)
    local posX = x - boxWidth
    local boxOverlay = Overlay:new(hudAtlasPath, posX, y, boxWidth, boxHeight)
    local boxElement = HUDElement:new(boxOverlay)

    boxElement:setColor(1, 1, 1, 0.8) -- TODO: remove later.
    boxElement:setUVs(getNormalizedUVs(HUDElement.UV.FILL))

    return boxElement
end

InteractiveHUD.SIZE = {
    BOX = { 300, 150 },
    BOX_MARGIN = { 20, 40 },
}
