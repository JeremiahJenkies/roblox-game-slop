--!strict
local Signal = {}
Signal.__index = Signal

function Signal.new()
    local bindable = Instance.new("BindableEvent")
    return setmetatable({ _event = bindable, _destroyed = false }, Signal)
end

function Signal:Connect(callback)
    assert(not self._destroyed, "Cannot connect to a destroyed Signal")
    return self._event.Event:Connect(callback)
end

function Signal:Once(callback)
    assert(not self._destroyed, "Cannot connect to a destroyed Signal")
    return self._event.Event:Once(callback)
end

function Signal:Fire(...)
    if not self._destroyed then self._event:Fire(...) end
end

function Signal:Wait()
    assert(not self._destroyed, "Cannot wait on a destroyed Signal")
    return self._event.Event:Wait()
end

function Signal:Destroy()
    if self._destroyed then return end
    self._destroyed = true
    self._event:Destroy()
end

return Signal