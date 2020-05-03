----------------------------------------------------------------------------------------------------
-- ProSeedDataEvent
----------------------------------------------------------------------------------------------------
-- Purpose: Event for updating the data.
--
-- Copyright (c) Wopster, 2020
----------------------------------------------------------------------------------------------------

---@class ProSeedDataEvent
ProSeedDataEvent = {}

local ProSeedDataEvent_mt = Class(ProSeedDataEvent, Event)

InitEventClass(ProSeedDataEvent, "ProSeedDataEvent")

---@return ProSeedDataEvent
function ProSeedDataEvent:emptyNew()
    local self = Event:new(ProSeedDataEvent_mt)
    return self
end

function ProSeedDataEvent:new(object, allowSound, allowFertilizer)
    local self = ProSeedDataEvent:emptyNew()

    self.object = object
    self.allowSound = allowSound
    self.allowFertilizer = allowFertilizer

    return self
end

function ProSeedDataEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.allowSound = streamReadBool(streamId)
    self.allowFertilizer = streamReadBool(streamId)
    self:run(connection)
end

function ProSeedDataEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)

    streamWriteBool(streamId, self.allowSound)
    streamWriteBool(streamId, self.allowFertilizer)
end

function ProSeedDataEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end

    self.object:setSowingData(self.allowSound, self.allowFertilizer, true)
end

function ProSeedDataEvent.sendEvent(object, allowSound, allowFertilizer, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(ProSeedDataEvent:new(object, allowSound, allowFertilizer), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(ProSeedDataEvent:new(object, allowSound, allowFertilizer))
        end
    end
end
