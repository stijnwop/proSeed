----------------------------------------------------------------------------------------------------
-- ProSeedResetHectareSessionEvent
----------------------------------------------------------------------------------------------------
-- Purpose: Event for resetting the current hectare session.
--
-- Copyright (c) Wopster, 2020
----------------------------------------------------------------------------------------------------

---@class ProSeedResetHectareSessionEvent
ProSeedResetHectareSessionEvent = {}

local ProSeedResetHectareSessionEvent_mt = Class(ProSeedResetHectareSessionEvent, Event)

InitEventClass(ProSeedResetHectareSessionEvent, "ProSeedResetHectareSessionEvent")

---@return ProSeedResetHectareSessionEvent
function ProSeedResetHectareSessionEvent:emptyNew()
    local self = Event:new(ProSeedResetHectareSessionEvent_mt)
    return self
end

function ProSeedResetHectareSessionEvent:new(object)
    local self = ProSeedResetHectareSessionEvent:emptyNew()

    self.object = object

    return self
end

function ProSeedResetHectareSessionEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self:run(connection)
end

function ProSeedResetHectareSessionEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
end

function ProSeedResetHectareSessionEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end

    self.object:resetVehicleHectareSession(true)
end

function ProSeedResetHectareSessionEvent.sendEvent(object, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(ProSeedResetHectareSessionEvent:new(object), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(ProSeedResetHectareSessionEvent:new(object))
        end
    end
end
