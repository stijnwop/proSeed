----------------------------------------------------------------------------------------------------
-- HUDTextElement
----------------------------------------------------------------------------------------------------
-- Purpose: HUD element class for a text HUD element.
--
-- Copyright (c) Wopster, 2020
----------------------------------------------------------------------------------------------------

---@class HUDTextElement
HUDTextElement = {}

local HUDTextElement_mt = Class(HUDTextElement, HUDElementBase)

---Creates a new instance of the HUDTextElement.
---@return HUDTextElement
function HUDTextElement:new(posX, posY, textSize, textAlignment, textColor, textBold)
    local backgroundOverlay = Overlay:new(nil, 0, 0, 0, 0)
    backgroundOverlay:setColor(1, 1, 1, 1)

    local instance = HUDElementBase:new(backgroundOverlay, HUDTextElement_mt)

    instance:setPosition(posX, posY)
    instance.correctionX, instance.correctionY = 0, 0

    instance.text = "" -- must be set in a separate call which will correctly set up boundaries and position
    instance.textSize = textSize or 0
    instance.screenTextSize = instance:scalePixelToScreenHeight(instance.textSize)
    instance.textAlignment = textAlignment or RenderText.ALIGN_LEFT
    instance.textColor = textColor or { 1, 1, 1, 1 }
    instance.textBold = textBold or false

    instance.hasShadow = false
    instance.shadowColor = { 0, 0, 0, 1 }

    return instance
end

---Called on draw
function HUDTextElement:draw()
    HUDTextElement:superClass().draw(self)
end

---Set text and do position correction.
function HUDTextElement:setText(text, textSize, textAlignment, textColor, textBold)
    -- assign values with initial values as defaults
    self.text = text or self.text
    self.textSize = textSize or self.textSize
    self.screenTextSize = self:scalePixelToScreenHeight(self.textSize)
    self.textAlignment = textAlignment or self.textAlignment
    self.textColor = textColor or self.textColor
    self.textBold = textBold or self.textBold

    local width, height = getTextWidth(self.screenTextSize, self.text), getTextHeight(self.screenTextSize, self.text)
    self:setDimension(width, height)

    local posX, posY = self:getPosition()

    --Set back based on correction
    posX = posX + self.correctionX
    posY = posY + self.correctionY

    if self.textAlignment == RenderText.ALIGN_CENTER then
        self.correctionX = width * 0.5
    elseif self.textAlignment == RenderText.ALIGN_RIGHT then
        self.correctionX = width
    end

    posX = posX - self.correctionX

    self:setPosition(posX, posY)
end

function HUDTextElement:setScale(uiScale)
    HUDTextElement:superClass().setScale(self, uiScale)

    self.screenTextSize = self:scalePixelToScreenHeight(self.textSize)
end

function HUDTextElement:setVisible(isVisible, animate)
    -- shadow parent behavior which includes repositioning
    HUDElement.setVisible(self, isVisible)

    if animate then
        if not isVisible or not self.animation:getFinished() then
            self.animation:reset()
        end

        if isVisible then
            self.animation:start()
        end
    end
end

function HUDTextElement:setAlpha(alpha)
    self:setColor(nil, nil, nil, alpha)
end

function HUDTextElement:setTextColorChannels(r, g, b, a)
    self.textColor[1] = r
    self.textColor[2] = g
    self.textColor[3] = b
    self.textColor[4] = a
end

function HUDTextElement:setTextShadow(isShadowEnabled, shadowColor)
    self.hasShadow = isShadowEnabled or self.hasShadow
    self.shadowColor = shadowColor or self.shadowColor
end

function HUDTextElement:setAnimation(animationTween)
    self:storeOriginalPosition()
    self.animation = animationTween or TweenSequence.NO_SEQUENCE
end

---Called on element update.
function HUDTextElement:update(dt)
    if self:getVisible() then
        HUDTextElement:superClass().update(self, dt)
    end
end

---Called on element draw.
function HUDTextElement:draw()
    setTextBold(self.textBold)
    local posX, posY = self:getPosition()
    -- NOTE: alignment is factored into background overlay position, use left alignment now
    setTextAlignment(RenderText.ALIGN_LEFT)

    if self.hasShadow then
        local offset = self.screenTextSize * HUDTextElement.SHADOW_OFFSET_FACTOR
        local r, g, b, a = unpack(self.shadowColor)
        setTextColor(r, g, b, a * self.overlay.a)
        renderText(posX + offset, posY - offset, self.screenTextSize, self.text)
    end

    local r, g, b, a = unpack(self.textColor)
    setTextColor(r, g, b, a * self.overlay.a)
    renderText(posX, posY, self.screenTextSize, self.text)

    setTextBold(false)
    setTextColor(1, 1, 1, 1)
end
