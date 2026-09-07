local signal = {}
signal.__index = signal

type handler = (...any) -> ()

type connection_data = {
	callback: handler,
	once: boolean,
	disconnected: boolean,
}

type signal_object = {
	_listeners: {connection_data},
	connect: (self: signal_object, fn: handler) -> connection_object,
	once: (self: signal_object, fn: handler) -> connection_object,
	fire: (self: signal_object, ...any) -> (),
	wait: (self: signal_object) -> ...any,
	disconnect_all: (self: signal_object) -> (),
}

type connection_object = {
	_owner: signal_object,
	_data: connection_data,
	disconnect: (self: connection_object) -> (),
}

local connection = {}
connection.__index = connection

function connection.new(owner: signal_object, data: connection_data): connection_object
	return setmetatable({
		_owner = owner,
		_data = data,
	}, connection) :: any
end

function connection:disconnect()
	self._data.disconnected = true
	local listeners = self._owner._listeners
	for idx = #listeners, 1, -1 do
		if listeners[idx] == self._data then
			table.remove(listeners, idx)
			break
		end
	end
end

function signal.new(): signal_object
	return setmetatable({
		_listeners = {},
	}, signal) :: any
end

function signal:connect(fn: handler): connection_object
	local data: connection_data = { callback = fn, once = false, disconnected = false }
	table.insert(self._listeners, data)
	return connection.new(self, data)
end

function signal:once(fn: handler): connection_object
	local data: connection_data = { callback = fn, once = true, disconnected = false }
	table.insert(self._listeners, data)
	return connection.new(self, data)
end

function signal:fire(...: any)
	local snapshot = table.clone(self._listeners)
	for _, data in snapshot do
		if not data.disconnected then
			if data.once then
				data.disconnected = true
				local listeners = self._listeners
				for idx = #listeners, 1, -1 do
					if listeners[idx] == data then
						table.remove(listeners, idx)
						break
					end
				end
			end
			task.spawn(data.callback, ...)
		end
	end
end

function signal:wait(): ...any
	local resume_thread = coroutine.running()
	local conn: connection_object
	conn = self:once(function(...: any)
		task.spawn(resume_thread, ...)
	end)
	return coroutine.yield()
end

function signal:disconnect_all()
	for _, data in self._listeners do
		data.disconnected = true
	end
	table.clear(self._listeners)
end

return signal
