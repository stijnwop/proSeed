----------------------------------------------------------------------------------------------------
-- HUDMovableElement
----------------------------------------------------------------------------------------------------
-- Purpose: HUD element class for a movable HUD element.
--
-- Copyright (c) Wopster, 2020
----------------------------------------------------------------------------------------------------

---@class HUDMovableElement
HUDMovableElement = {}

local HUDMovableElement_mt = Class(HUDMovableElement, HUDElementBase)

---Creates a new instance of the HUDMovableElement.
---@return HUDMovableElement
function HUDMovableElement:new(overlay)
    local instance = HUDElementBase:new(overlay, HUDMovableElement_mt)

    instance.positionIsDirty = false

    return instance
end

function HUDMovableElement:loadFromXMLFile(xmlFile, key)
    local x = getXMLFloat(xmlFile, key .. ".position#x")
    local y = getXMLFloat(xmlFile, key .. ".position#y")

    if x ~= nil and y ~= nil then
        x = MathUtil.clamp(x, 0, 1)
        y = MathUtil.clamp(y, 0, 1)

        local height = self:getHeight()
        local _, parentY = self.parent:getPosition()
        local _, marginHeight = self.parent:scalePixelToScreenVector(InteractiveHUD.SIZE.BOX_MARGIN)

        --Do height correction based on the parent position.
        self:setPosition(x, y + (height * 0.5) + parentY - marginHeight)
    end
end

function HUDMovableElement:saveToXMLFile(xmlFile, key)
    local x, y = self:getPosition()
    if x ~= nil and y ~= nil then
        setXMLFloat(xmlFile, key .. ".position#x", MathUtil.clamp(x, 0, 1))
        setXMLFloat(xmlFile, key .. ".position#y", MathUtil.clamp(y, 0, 1))
    end
end

---Called on mouse event.
function HUDMovableElement:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
    eventUsed = HUDMovableElement:superClass().mouseEvent(self, posX, posY, isDown, isUp, button)

    if not eventUsed then
        local isLeftButton = button == Input.MOUSE_BUTTON_LEFT
        if self.positionIsDirty then
            if isLeftButton and isUp then
                eventUsed = true
                self:setIsPositionDirty(false)
            else
                self:setPositionByMousePosition(posX, posY)
            end
        else
            if isLeftButton and isDown then
                local x, y = self:getPosition()
                local cursorInElement = GuiUtils.checkOverlayOverlap(posX, posY, x, y, self:getWidth(), self:getHeight())
                if cursorInElement then
                    eventUsed = true
                    self:setIsPositionDirty(true, posX, posY)
                end
            end
        end
    end

    return eventUsed
end

---Set position dirty and if it requires and update.
function HUDMovableElement:setIsPositionDirty(isDirty, mouseX, mouseY)
    self.positionIsDirty = isDirty

    if isDirty then
        self.currentMouseX = mouseX
        self.currentMouseY = mouseY
    end
end

---Set base position based on the given mouse position.
function HUDMovableElement:setPositionByMousePosition(mouseX, mouseY)
    if self.positionIsDirty then
        local moveX, moveY = mouseX - self.currentMouseX, mouseY - self.currentMouseY
        local x, y = self:getPosition()
        local boundaryMin = 0
        local boundaryMax = 1
        local newX = MathUtil.clamp(x + moveX, boundaryMin, boundaryMax)
        local newY = MathUtil.clamp(y + moveY, boundaryMin, boundaryMax)

        local width = self:getWidth()
        if newX + width > boundaryMax then
            newX = boundaryMax - width
        end

        local height = self:getHeight()
        if newY + height > boundaryMax then
            newY = boundaryMax - height
        end

        self:setPosition(newX, newY)
        self.currentMouseX = mouseX
        self.currentMouseY = mouseY
    end
end
