--!strict
local Maid = {}
Maid.__index = Maid

function Maid.new()
    return setmetatable({ _tasks = {} }, Maid)
end

function Maid:GiveTask(taskItem)
    assert(taskItem ~= nil, "Maid:GiveTask cannot accept nil")
    table.insert(self._tasks, taskItem)
    return taskItem
end

local function cleanup(taskItem)
    local kind = typeof(taskItem)
    if kind == "RBXScriptConnection" then
        if taskItem.Connected then taskItem:Disconnect() end
    elseif kind == "Instance" then
        taskItem:Destroy()
    elseif type(taskItem) == "function" then
        taskItem()
    elseif kind == "thread" then
        pcall(task.cancel, taskItem)
    elseif type(taskItem) == "table" then
        if type(taskItem.Destroy) == "function" then
            taskItem:Destroy()
        elseif type(taskItem.Disconnect) == "function" then
            taskItem:Disconnect()
        elseif type(taskItem.Clean) == "function" then
            taskItem:Clean()
        end
    end
end

function Maid:Clean()
    local tasks = self._tasks
    self._tasks = {}
    for index = #tasks, 1, -1 do
        local ok, err = pcall(cleanup, tasks[index])
        if not ok then warn("[Maid] Cleanup failed: " .. tostring(err)) end
    end
end

function Maid:Destroy()
    self:Clean()
end

return Maid