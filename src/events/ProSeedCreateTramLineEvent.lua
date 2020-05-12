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
    local self = Event:new(ProSeedCreateTramLineEvent_mt)
    return self
end

function ProSeedCreateTramLineEvent:new(object, createTramLines)
    local self = ProSeedCreateTramLineEvent:emptyNew()

    self.object = object
    self.createTramLines = createTramLines

    return self
end

function ProSeedCreateTramLineEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.createTramLines = streamReadBool(streamId)
    self:run(connection)
end

function ProSeedCreateTramLineEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
    streamWriteBool(streamId, self.createTramLines)
end

function ProSeedCreateTramLineEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end

    local spec = self.object.spec_proSeedTramLines
    spec.createTramLines = self.createTramLines
end
