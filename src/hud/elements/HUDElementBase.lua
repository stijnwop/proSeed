----------------------------------------------------------------------------------------------------
-- HUDElementBase
----------------------------------------------------------------------------------------------------
-- Purpose: Base class for a HUD element.
--
-- Copyright (c) Wopster, 2020
----------------------------------------------------------------------------------------------------

---@class HUDElementBase
HUDElementBase = {}

local HUDElementBase_mt = Class(HUDElementBase, HUDElement)

---Creates a new instance of the HUDElementBase.
---@return HUDElementBase
function HUDElementBase:new(overlay, mt)
    local instance = HUDElement.new(overlay, nil, mt or HUDElementBase_mt)

    instance.isElementActive = true

    instance.mouseDown = false
    instance.mouseEntered = false
    instance.target = nil
    instance.onClickCallback = nil
    instance.clickSoundName = GuiSoundPlayer.SOUND_SAMPLES.CLICK

    instance.hasBorders = false

    return instance
end

---Set target class.
function HUDElementBase:setTarget(target)
    self.target = target
end

---Returns current active state.
function HUDElementBase:isActive()
    return self.isElementActive
end

---Pass on method to have compatibility with the focus manager.
function HUDElementBase:getIsVisible()
    return self:getVisible()
end

---Set visibility of the HUD element.
function HUDElementBase:setVisible(isVisible)
    HUDElementBase:superClass().setVisible(self, isVisible)

    if self.hasBorders then
        for _, frameOverlay in pairs(self.frameOverlays) do
            frameOverlay:setIsVisible(isVisible)
        end
    end
end

---Check if sound have to suppressed.
function HUDElementBase:getSoundSuppressed()
    return false
end

---Set position of the HUD element.
function HUDElementBase:setPosition(x, y)
    HUDElementBase:superClass().setPosition(self, x, y)

    --Update borders when position is changed.
    if self.hasBorders then
        self:updateBordersPosition()
    end
end

---Function to handle callbacks for e.g. buttons.
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

---Called on mouse event by the HUD controller.
function HUDElementBase:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
    return eventUsed
end

---Called on draw
function HUDElementBase:draw()
    HUDElementBase:superClass().draw(self)

    if self.hasBorders then
        for _, frameOverlay in pairs(self.frameOverlays) do
            frameOverlay:render()
        end
    end
end

---Set element borders.
function HUDElementBase:setBorders(thickness, color)
    self.borderThickness = GuiUtils.getNormalizedValues(thickness)
    self.borderColor = color

    local leftOverlay = Overlay.new(g_baseUIFilename, 0, 0, 1, 1)
    leftOverlay:setColor(unpack(self.borderColor))
    leftOverlay:setAlignment(Overlay.ALIGN_VERTICAL_BOTTOM, Overlay.ALIGN_HORIZONTAL_LEFT)
    local topOverlay = Overlay.new(g_baseUIFilename, 0, 0, 1, 1)
    topOverlay:setColor(unpack(self.borderColor))
    topOverlay:setAlignment(Overlay.ALIGN_VERTICAL_TOP, Overlay.ALIGN_HORIZONTAL_LEFT)
    local rightOverlay = Overlay.new(g_baseUIFilename, 0, 0, 1, 1)
    rightOverlay:setColor(unpack(self.borderColor))
    rightOverlay:setAlignment(Overlay.ALIGN_VERTICAL_BOTTOM, Overlay.ALIGN_HORIZONTAL_RIGHT)
    local bottomOverlay = Overlay.new(g_baseUIFilename, 0, 0, 1, 1)
    bottomOverlay:setColor(unpack(self.borderColor))
    bottomOverlay:setAlignment(Overlay.ALIGN_VERTICAL_BOTTOM, Overlay.ALIGN_HORIZONTAL_LEFT)

    self.frameOverlays = { leftOverlay, topOverlay, rightOverlay, bottomOverlay }
    for _, frameOverlay in pairs(self.frameOverlays) do
        frameOverlay:setUVs(g_colorBgUVs)
    end

    self.hasBorders = true
    self:updateBordersPosition()
end

---Updates the position of the borders.
function HUDElementBase:updateBordersPosition()
    local x, y = self:getPosition()
    local width, height = self:getWidth(), self:getHeight()

    local left, top, right, bottom = 1, 2, 3, 4
    local partBorders = {
        [left] = { x = x, y = y, width = self.borderThickness[left], height = height },
        [top] = { x = x, y = y + height, width = width, height = self.borderThickness[top] },
        [right] = { x = x + width, y = y, width = self.borderThickness[right], height = height },
        [bottom] = { x = x, y = y, width = width, height = self.borderThickness[bottom] },
    }

    self:cutBordersHorizontal(partBorders[left], partBorders[top], true)
    self:cutBordersHorizontal(partBorders[left], partBorders[bottom], true)
    self:cutBordersHorizontal(partBorders[right], partBorders[top], false)
    self:cutBordersHorizontal(partBorders[right], partBorders[bottom], false)

    self:cutBordersVertical(partBorders[bottom], partBorders[left], true)
    self:cutBordersVertical(partBorders[bottom], partBorders[right], true)
    self:cutBordersVertical(partBorders[top], partBorders[left], false)
    self:cutBordersVertical(partBorders[top], partBorders[right], false)

    for side = left, bottom do
        -- from left to bottom in order
        self.frameOverlays[side]:setPosition(partBorders[side].x, partBorders[side].y)
        self.frameOverlays[side]:setDimension(partBorders[side].width, partBorders[side].height)
    end
end

---Cut horizontal borders to fit.
function HUDElementBase:cutBordersHorizontal(verticalPart, horizontalPart, isLeft)
    if verticalPart.width > horizontalPart.height then
        -- equals test for thickness
        if isLeft then
            horizontalPart.x = horizontalPart.x + verticalPart.width
        end

        horizontalPart.width = horizontalPart.width - verticalPart.width
    end
end

---Cut vertical borders to fit.
function HUDElementBase:cutBordersVertical(horizontalPart, verticalPart, isBottom)
    if horizontalPart.width >= verticalPart.height then
        -- test for greater or equals here to avoid overlaps when thickness is the same
        if isBottom then
            verticalPart.y = verticalPart.y + horizontalPart.height
        end

        verticalPart.height = verticalPart.height - horizontalPart.height
    end
end
