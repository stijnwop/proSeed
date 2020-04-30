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
        self:setPosition(x + moveX, y + moveY)
        self.currentMouseX = mouseX
        self.currentMouseY = mouseY
    end
end
