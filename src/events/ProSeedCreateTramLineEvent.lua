----------------------------------------------------------------------------------------------------
-- ProSeedCreateTramLineEvent
----------------------------------------------------------------------------------------------------
-- Purpose: Event setting the creating of tramline flag on server.
--
-- Copyright (c) Wopster, 2020
----------------------------------------------------------------------------------------------------

---@class ProSeedCreateTramLineEvent
ProSeedCreateTramLineEvent = {}

local ProSeedCreateTramLineEvent_mt = Class(ProSeedCreateTramLineEvent, Event)

InitEventClass(ProSeedCreateTramLineEvent, "ProSeedCreateTramLineEvent")

---@return ProSeedCreateTramLineEvent
function ProSeedCreateTramLineEvent:emptyNew()
    local self = Event.new(ProSeedCreateTramLineEvent_mt)
    return self
end

function ProSeedCreateTramLineEvent:new(object, createTramLines, currentLane)
    local self = ProSeedCreateTramLineEvent:emptyNew()

    self.object = object
    self.createTramLines = createTramLines
    self.currentLane = currentLane

    return self
end

function ProSeedCreateTramLineEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.createTramLines = streamReadBool(streamId)
    self.currentLane = streamReadInt8(streamId)

    self:run(connection)
end

function ProSeedCreateTramLineEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
    streamWriteBool(streamId, self.createTramLines)
    streamWriteInt8(streamId, self.currentLane)
end

function ProSeedCreateTramLineEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end

    local spec = self.object.spec_proSeedTramLines
    spec.createTramLines = self.createTramLines
    spec.currentLane = self.currentLane
end
