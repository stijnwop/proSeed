
---@class HUDButtonElement
HUDButtonElement = {}

local HUDButtonElement_mt = Class(HUDButtonElement, HUDElementBase)

---Creates a new instance of the HUDButtonElement.
---@return HUDButtonElement
function HUDButtonElement:new(overlay)
    local instance = HUDElementBase:new(overlay, HUDButtonElement_mt)

    return instance
end

---Set the callback function
function HUDButtonElement:setButtonCallback(target, func)
    self.target = target
    self.onClickCallback = func
end

