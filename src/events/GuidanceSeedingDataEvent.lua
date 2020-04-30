----------------------------------------------------------------------------------------------------
-- GuidanceSeedingDataEvent
----------------------------------------------------------------------------------------------------
-- Purpose: Event for updating the data.
--
-- Copyright (c) Wopster, 2020
----------------------------------------------------------------------------------------------------

---@class GuidanceSeedingDataEvent
GuidanceSeedingDataEvent = {}

local GuidanceSeedingDataEvent_mt = Class(GuidanceSeedingDataEvent, Event)

InitEventClass(GuidanceSeedingDataEvent, "GuidanceSeedingDataEvent")

---@return GuidanceSeedingDataEvent
function GuidanceSeedingDataEvent:emptyNew()
    local self = Event:new(GuidanceSeedingDataEvent_mt)
    return self
end

function GuidanceSeedingDataEvent:new(object, allowSound, allowFertilizer)
    local self = GuidanceSeedingDataEvent:emptyNew()

    self.object = object
    self.allowSound = allowSound
    self.allowFertilizer = allowFertilizer

    return self
end

function GuidanceSeedingDataEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.allowSound = streamReadBool(streamId)
    self.allowFertilizer = streamReadBool(streamId)
    self:run(connection)
end

function GuidanceSeedingDataEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)

    streamWriteBool(streamId, self.allowSound)
    streamWriteBool(streamId, self.allowFertilizer)
end

function GuidanceSeedingDataEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end

    self.object:setSowingData(self.allowSound, self.allowFertilizer, true)
end

function GuidanceSeedingDataEvent.sendEvent(object, allowSound, allowFertilizer, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(GuidanceSeedingDataEvent:new(object, allowSound, allowFertilizer), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(GuidanceSeedingDataEvent:new(object, allowSound, allowFertilizer))
        end
    end
end
