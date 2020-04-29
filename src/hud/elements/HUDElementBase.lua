
---@class HUDElementBase
HUDElementBase = {}

local HUDElementBase_mt = Class(HUDElementBase, HUDElement)

---Creates a new instance of the HUDElementBase.
---@return HUDElementBase
function HUDElementBase:new(overlay, mt)
    local instance = HUDElement.new(mt or HUDElementBase_mt, overlay)

    instance.focusActive = false
    instance.mouseDown = false
    instance.mouseEntered = false
    instance.onClickCallback = nil
    instance.clickSoundName = GuiSoundPlayer.SOUND_SAMPLES.CLICK

    return instance
end

function HUDElementBase:getIsActive()
    return self.onClickCallback ~= nil
end

function HUDElementBase:raiseCallback(name, ...)
    if self[name] ~= nil then
        if self.target ~= nil then
            return self[name](self.target, ...)
        else
            return self[name](...)
        end
    end

    return nil
end

function HUDElementBase:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
    if self:getIsActive() then
        local x, y = self:getPosition()
        local cursorInElement = GuiUtils.checkOverlayOverlap(posX, posY, x, y, self:getWidth(), self:getHeight())

        if cursorInElement then
            if not self.mouseEntered and not self.focusActive then

                self.mouseEntered = true
            end
        else
            -- mouse event outside button
            --self:restoreOverlayState()
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
