local Events = {}

Events.__index = function(self, index)
	local event = {Connections = {}}
	event.Connect = function(_, func)
		table.insert(event.Connections, func)
		return {
			Disconnect = function()
				local idx = table.find(event.Connections, func)
				if idx then table.remove(event.Connections, idx) end
			end
		}
	end
	event.Fire = function(_, ...)
		for _, v in event.Connections do
			task.spawn(v, ...)
		end
	end
	event.Destroy = function()
		table.clear(event.Connections)
	end
	rawset(self, index, event)
	return event
end

setmetatable(Events, Events)

return Events
