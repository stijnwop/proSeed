----------------------------------------------------------------------------------------------------
-- GuidanceSeedingTramLineDataEvent
----------------------------------------------------------------------------------------------------
-- Purpose: Event for updating the tramline data.
--
-- Copyright (c) Wopster, 2020
----------------------------------------------------------------------------------------------------

---@class GuidanceSeedingTramLineDataEvent
GuidanceSeedingTramLineDataEvent = {}

local GuidanceSeedingTramLineDataEvent_mt = Class(GuidanceSeedingTramLineDataEvent, Event)

InitEventClass(GuidanceSeedingTramLineDataEvent, "GuidanceSeedingTramLineDataEvent")

---@return GuidanceSeedingTramLineDataEvent
function GuidanceSeedingTramLineDataEvent:emptyNew()
    local self = Event:new(GuidanceSeedingTramLineDataEvent_mt)
    return self
end

function GuidanceSeedingTramLineDataEvent:new(object, tramLineDistance, tramLinePeriodicSequence, createPreMarkedTramLines)
    local self = GuidanceSeedingTramLineDataEvent:emptyNew()

    self.object = object
    self.tramLineDistance = tramLineDistance
    self.tramLinePeriodicSequence = tramLinePeriodicSequence
    self.createPreMarkedTramLines = createPreMarkedTramLines

    return self
end

function GuidanceSeedingTramLineDataEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.tramLineDistance = streamReadFloat32(streamId)
    self.tramLinePeriodicSequence = streamReadInt8(streamId)
    self.createPreMarkedTramLines = streamReadBool(streamId)
    self:run(connection)
end

function GuidanceSeedingTramLineDataEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)

    streamWriteFloat32(streamId, self.tramLineDistance)
    streamWriteInt8(streamId, self.tramLinePeriodicSequence)
    streamWriteBool(streamId, self.createPreMarkedTramLines)
end

function GuidanceSeedingTramLineDataEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end

    self.object:setTramLineData(self.tramLineDistance, self.tramLinePeriodicSequence, self.createPreMarkedTramLines, true)
end

function GuidanceSeedingTramLineDataEvent.sendEvent(object, tramLineDistance, tramLinePeriodicSequence, createPreMarkedTramLines, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(GuidanceSeedingTramLineDataEvent:new(object, tramLineDistance, tramLinePeriodicSequence, createPreMarkedTramLines), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(GuidanceSeedingTramLineDataEvent:new(object, tramLineDistance, tramLinePeriodicSequence, createPreMarkedTramLines))
        end
    end
end
