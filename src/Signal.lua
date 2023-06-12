local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Signal.new()
	return setmetatable({
		Connections = {},
		Yields = {},
	}, Signal)
end

function Signal:Fire(...)
	for _, v in ipairs(self.Connections) do
		coroutine.wrap(v.func)(...)
	end

	for k, v in ipairs(self.Yields) do
		coroutine.resume(v, ...)
		table.remove(self.Yields, k)
	end
end

function Signal:Connect(func)
	local connection = setmetatable({
		func = func;
		orgSelf = self;
	}, Connection)

	table.insert(self.Connections, connection)
	return connection
end

function Signal:Wait()
	table.insert(self.Yields, coroutine.running())
	return coroutine.yield()
end

function Connection:Disconnect()
	for k, v in ipairs(self.orgSelf.Connections) do
		if v == self then
			table.remove(self.orgSelf.Connections, k)
		end
	end
	setmetatable(self, nil)
end

function Signal:Destroy()
	for _, v in ipairs(self.Connections) do
		v:Disconnect()
	end

	for _, v in ipairs(self.Yields) do
		coroutine.resume(v)
	end

	setmetatable(self, nil)
end

return Signal
