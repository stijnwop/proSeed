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

    self:setOverlayState(GuiOverlay.STATE_NORMAL)
    self:loadOverlayColors(overlay)

    return instance
end

function HUDButtonElement:loadOverlayColors(overlay)
    local color = { 1, 1, 1, 0.8 }
    if color ~= nil then
        overlay.color = color
    end

    local color = { 1, 1, 1, 1 }
    if color ~= nil then
        overlay.colorFocused = color
    end

    local color = { 1, 1, 1, 1 }
    if color ~= nil then
        overlay.colorPressed = color
    end

    local color = { 0.9910, 0.3865, 0.0100, 1 }
    if color ~= nil then
        overlay.colorSelected = color
    end

    local color = { 0.4, 0.4, 0.4, 1 }
    if color ~= nil then
        overlay.colorDisabled = color
    end

    local color = { 0.9910, 0.3865, 0.0100, 1 }
    if color ~= nil then
        overlay.colorHighlighted = color
    end
end

function HUDButtonElement:setOverlayState(overlayState)
    self.overlayState = overlayState
end

function HUDButtonElement:getOverlayState()
    return self.overlayState
end

function HUDButtonElement:storeOverlayState()
    self.previousOverlayState = self:getOverlayState()
end

function HUDButtonElement:restoreOverlayState()
    if self.previousOverlayState then
        --Restore overlay state from before
        self:setOverlayState(self.previousOverlayState)
        self.previousOverlayState = nil
    end
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

---Called on draw
function HUDButtonElement:draw()
    local r, g, b, a = unpack(GuiOverlay.getOverlayColor(self.overlay, self.overlayState))
    if a ~= 0 then
        self.overlay:setColor(r, g, b, a)
    end

    HUDButtonElement:superClass().draw(self)
end

---Called on mouse event.
function HUDButtonElement:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
    eventUsed = HUDButtonElement:superClass().mouseEvent(self, posX, posY, isDown, isUp, button)

    if self:isActive() and self:getIsVisible() then
        local x, y = self:getPosition()
        local cursorInElement = GuiUtils.checkOverlayOverlap(posX, posY, x, y, self:getWidth(), self:getHeight()) and self:getOverlayState() ~= GuiOverlay.STATE_DISABLED

        if cursorInElement then
            if not self.mouseEntered and not self.focusActive then
                -- set highlight on mouse over without focus
                FocusManager:setHighlight(self)

                self.mouseEntered = true
            end
        else
            -- mouse event outside button
            self:restoreOverlayState()
            self.mouseDown = false
            self.mouseEntered = false
            --Reset highlight
            FocusManager:unsetHighlight(self)
        end

        -- handle click/activate only if event has not been consumed, yet
        if not eventUsed then
            if cursorInElement and not FocusManager:isLocked() then
                if isDown and button == Input.MOUSE_BUTTON_LEFT then
                    eventUsed = true
                    self.mouseDown = true
                end

                -- if needed, set state to PRESSED and store current overlay state for restoration
                if self.mouseDown and self:getOverlayState() ~= GuiOverlay.STATE_PRESSED then
                    self:storeOverlayState()
                    self:setOverlayState(GuiOverlay.STATE_PRESSED)
                end

                if isUp and button == Input.MOUSE_BUTTON_LEFT and self.mouseDown then
                    g_gui.soundPlayer:playSample(self.clickSoundName)

                    self:restoreOverlayState()
                    self.mouseDown = false
                    self:raiseCallback("onClickCallback", self)

                    eventUsed = true
                end
            end
        end
    end

    return eventUsed
end

function HUDButtonElement:setSelected(isSelected)
    if isSelected then
        self:setOverlayState(GuiOverlay.STATE_SELECTED)
    else
        self:setOverlayState(GuiOverlay.STATE_NORMAL)
    end
end

function HUDButtonElement:setDisabled(disabled)
    if disabled then
        FocusManager:unsetFocus(self)
        self.mouseEntered = false
        self:raiseCallback("onLeaveCallback", self)
        self.mouseDown = false
        self:setOverlayState(GuiOverlay.STATE_DISABLED)
    else
        self:setOverlayState(GuiOverlay.STATE_NORMAL)
    end
end

function HUDButtonElement:onHighlight()
    self:raiseCallback("onHighlightCallback", self)
end

function HUDButtonElement:onHighlightRemove()
    self:raiseCallback("onHighlightRemoveCallback", self)
end
