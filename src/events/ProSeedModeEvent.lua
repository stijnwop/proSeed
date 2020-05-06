----------------------------------------------------------------------------------------------------
-- ProSeedModeEvent
----------------------------------------------------------------------------------------------------
-- Purpose: Event for setting the tram line mode.
--
-- Copyright (c) Wopster, 2020
----------------------------------------------------------------------------------------------------

---@class ProSeedModeEvent
ProSeedModeEvent = {}

local ProSeedModeEvent_mt = Class(ProSeedModeEvent, Event)

InitEventClass(ProSeedModeEvent, "ProSeedModeEvent")

---@return ProSeedModeEvent
function ProSeedModeEvent:emptyNew()
    local self = Event:new(ProSeedModeEvent_mt)
    return self
end

function ProSeedModeEvent:new(object, mode)
    local self = ProSeedModeEvent:emptyNew()

    self.object = object
    self.mode = mode

    return self
end

function ProSeedModeEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.mode = streamReadUIntN(streamId, 2)
    self:run(connection)
end

function ProSeedModeEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
    streamWriteUIntN(streamId, self.mode, 2)
end

function ProSeedModeEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end

    self.object:setTramLineMode(self.mode, true)
end

function ProSeedModeEvent.sendEvent(object, mode, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(ProSeedModeEvent:new(object, mode), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(ProSeedModeEvent:new(object, mode))
        end
    end
end
