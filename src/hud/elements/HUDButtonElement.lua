----------------------------------------------------------------------------------------------------
-- HUDButtonElement
----------------------------------------------------------------------------------------------------
-- Purpose: HUD element class for a button HUD element.
--
-- Copyright (c) Wopster, 2020
----------------------------------------------------------------------------------------------------

---@class HUDButtonElement
HUDButtonElement = {}

local HUDButtonElement_mt = Class(HUDButtonElement, HUDElementBase)

---Creates a new instance of the HUDButtonElement.
---@return HUDButtonElement
function HUDButtonElement:new(overlay)
    local instance = HUDElementBase:new(overlay, HUDButtonElement_mt)

    instance.mouseDown = false
    instance.mouseEntered = false
    instance.onClickCallback = nil
    instance.clickSoundName = GuiSoundPlayer.SOUND_SAMPLES.CLICK

    return instance
end

---Set the callback function
function HUDButtonElement:setButtonCallback(target, func)
    self.onClickCallback = func
    self:setTarget(target)
end

---Return false when no click callback is set, true otherwise.
function HUDButtonElement:isActive()
    if not HUDButtonElement:superClass().isActive(self) then
        return false
    end

    return self.onClickCallback ~= nil
end

---Called on mouse event.
function HUDButtonElement:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
    eventUsed = HUDButtonElement:superClass().mouseEvent(self, posX, posY, isDown, isUp, button)

    if self:isActive() then
        local x, y = self:getPosition()
        local cursorInElement = GuiUtils.checkOverlayOverlap(posX, posY, x, y, self:getWidth(), self:getHeight())

        if cursorInElement then
            if not self.mouseEntered then
                self.mouseEntered = true
            end
        else
            -- mouse event outside button
            -- self:restoreOverlayState()
            self.mouseDown = false
            self.mouseEntered = false
        end

        -- handle click/activate only if event has not been consumed, yet
        if not eventUsed then
            if cursorInElement and not FocusManager:isLocked() then
                if isDown and button == Input.MOUSE_BUTTON_LEFT then
                    eventUsed = true
                    self.mouseDown = true
                end

                -- if needed, set state to PRESSED and store current overlay state for restoration
                --if self.mouseDown and self:getOverlayState() ~= GuiOverlay.STATE_PRESSED then
                --self:storeOverlayState()
                --self:setOverlayState(GuiOverlay.STATE_PRESSED)
                --end

                if isUp and button == Input.MOUSE_BUTTON_LEFT and self.mouseDown then
                    g_gui.soundPlayer:playSample(self.clickSoundName)

                    --self:restoreOverlayState()
                    self.mouseDown = false
                    self:raiseCallback("onClickCallback", self)

                    eventUsed = true
                end
            end
        end
    end

    return eventUsed
end
