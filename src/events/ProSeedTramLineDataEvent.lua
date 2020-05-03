----------------------------------------------------------------------------------------------------
-- ProSeedTramLineDataEvent
----------------------------------------------------------------------------------------------------
-- Purpose: Event for updating the tramline data.
--
-- Copyright (c) Wopster, 2020
----------------------------------------------------------------------------------------------------

---@class ProSeedTramLineDataEvent
ProSeedTramLineDataEvent = {}

local ProSeedTramLineDataEvent_mt = Class(ProSeedTramLineDataEvent, Event)

InitEventClass(ProSeedTramLineDataEvent, "ProSeedTramLineDataEvent")

---@return ProSeedTramLineDataEvent
function ProSeedTramLineDataEvent:emptyNew()
    local self = Event:new(ProSeedTramLineDataEvent_mt)
    return self
end

function ProSeedTramLineDataEvent:new(object, tramLineDistance, tramLinePeriodicSequence, createPreMarkedTramLines)
    local self = ProSeedTramLineDataEvent:emptyNew()

    self.object = object
    self.tramLineDistance = tramLineDistance
    self.tramLinePeriodicSequence = tramLinePeriodicSequence
    self.createPreMarkedTramLines = createPreMarkedTramLines

    return self
end

function ProSeedTramLineDataEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.tramLineDistance = streamReadFloat32(streamId)
    self.tramLinePeriodicSequence = streamReadInt8(streamId)
    self.createPreMarkedTramLines = streamReadBool(streamId)
    self:run(connection)
end

function ProSeedTramLineDataEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)

    streamWriteFloat32(streamId, self.tramLineDistance)
    streamWriteInt8(streamId, self.tramLinePeriodicSequence)
    streamWriteBool(streamId, self.createPreMarkedTramLines)
end

function ProSeedTramLineDataEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end

    self.object:setTramLineData(self.tramLineDistance, self.tramLinePeriodicSequence, self.createPreMarkedTramLines, true)
end

function ProSeedTramLineDataEvent.sendEvent(object, tramLineDistance, tramLinePeriodicSequence, createPreMarkedTramLines, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(ProSeedTramLineDataEvent:new(object, tramLineDistance, tramLinePeriodicSequence, createPreMarkedTramLines), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(ProSeedTramLineDataEvent:new(object, tramLineDistance, tramLinePeriodicSequence, createPreMarkedTramLines))
        end
    end
end
