----------------------------------------------------------------------------------------------------
-- ProSeedHalfSideShutoffEvent
----------------------------------------------------------------------------------------------------
-- Purpose: Event for setting the half side shutoff mode.
--
-- Copyright (c) Wopster, 2020
----------------------------------------------------------------------------------------------------

---@class ProSeedHalfSideShutoffEvent
ProSeedHalfSideShutoffEvent = {}

local ProSeedHalfSideShutoffEvent_mt = Class(ProSeedHalfSideShutoffEvent, Event)

InitEventClass(ProSeedHalfSideShutoffEvent, "ProSeedHalfSideShutoffEvent")

---@return ProSeedHalfSideShutoffEvent
function ProSeedHalfSideShutoffEvent:emptyNew()
    local self = Event.new(ProSeedHalfSideShutoffEvent_mt)
    return self
end

function ProSeedHalfSideShutoffEvent:new(object, mode)
    local self = ProSeedHalfSideShutoffEvent:emptyNew()

    self.object = object
    self.mode = mode

    return self
end

function ProSeedHalfSideShutoffEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.mode = streamReadUIntN(streamId, 2)
    self:run(connection)
end

function ProSeedHalfSideShutoffEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
    streamWriteUIntN(streamId, self.mode, 2)
end

function ProSeedHalfSideShutoffEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end

    self.object:setHalfSideShutoffMode(self.mode, true)
end

function ProSeedHalfSideShutoffEvent.sendEvent(object, mode, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(ProSeedHalfSideShutoffEvent:new(object, mode), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(ProSeedHalfSideShutoffEvent:new(object, mode))
        end
    end
end
