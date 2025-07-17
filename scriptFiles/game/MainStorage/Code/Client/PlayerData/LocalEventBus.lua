---
--- 本地事件总线，用于客户端内部各模块间解耦通信。
---@class LocalEventBus
local LocalEventBus = {
    listeners = {}
}

--- 订阅事件
---@param eventName string 事件名称
---@param callback function 事件回调
function LocalEventBus.Subscribe(eventName, callback)
    if not LocalEventBus.listeners[eventName] then
        LocalEventBus.listeners[eventName] = {}
    end
    table.insert(LocalEventBus.listeners[eventName], callback)
end

--- 取消订阅事件
---@param eventName string 事件名称
---@param callback function 事件回调
function LocalEventBus.Unsubscribe(eventName, callback)
    if not LocalEventBus.listeners[eventName] then
        return
    end

    for i = #LocalEventBus.listeners[eventName], 1, -1 do
        if LocalEventBus.listeners[eventName][i] == callback then
            table.remove(LocalEventBus.listeners[eventName], i)
        end
    end
end

--- 发布事件
---@param eventName string 事件名称
---@param ... any 传递给回调的参数
function LocalEventBus.Publish(eventName, ...)
    if LocalEventBus.listeners[eventName] then
        -- 为防止在回调中修改监听器列表导致迭代出错，创建一个回调副本进行遍历
        local callbacksToCall = {}
        for _, cb in ipairs(LocalEventBus.listeners[eventName]) do
            table.insert(callbacksToCall, cb)
        end

        for _, cb in ipairs(callbacksToCall) do
            cb(...)
        end
    end
end

return LocalEventBus