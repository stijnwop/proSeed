----------------------------------------------------------------------------------------------------
-- GuidanceSeedingHalfSideShutoffEvent
----------------------------------------------------------------------------------------------------
-- Purpose: Event for setting the half side shutoff mode.
--
-- Copyright (c) Wopster, 2020
----------------------------------------------------------------------------------------------------

---@class GuidanceSeedingHalfSideShutoffEvent
GuidanceSeedingHalfSideShutoffEvent = {}

local GuidanceSeedingHalfSideShutoffEvent_mt = Class(GuidanceSeedingHalfSideShutoffEvent, Event)

InitEventClass(GuidanceSeedingHalfSideShutoffEvent, "GuidanceSeedingHalfSideShutoffEvent")

---@return GuidanceSeedingHalfSideShutoffEvent
function GuidanceSeedingHalfSideShutoffEvent:emptyNew()
    local self = Event:new(GuidanceSeedingHalfSideShutoffEvent_mt)
    return self
end

function GuidanceSeedingHalfSideShutoffEvent:new(object, mode)
    local self = GuidanceSeedingHalfSideShutoffEvent:emptyNew()

    self.object = object
    self.mode = mode

    return self
end

function GuidanceSeedingHalfSideShutoffEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.mode = streamReadUIntN(streamId, 2)
    self:run(connection)
end

function GuidanceSeedingHalfSideShutoffEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
    streamWriteUIntN(streamId, self.mode, 2)
end

function GuidanceSeedingHalfSideShutoffEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end

    self.object:setHalfSideShutoffMode(self.mode, true)
end

function GuidanceSeedingHalfSideShutoffEvent.sendEvent(object, mode, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(GuidanceSeedingHalfSideShutoffEvent:new(object, mode), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(GuidanceSeedingHalfSideShutoffEvent:new(object, mode))
        end
    end
end
