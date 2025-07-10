---
--- 全局定时任务调度器
--- 封装了引擎的 Timer 节点，提供了更便捷的全局调用接口。
--- 使用前必须先调用 Init() 进行初始化。
---
local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class ScheduledTask
local ScheduledTask = {}

---@type Folder
local timersNode = nil

---
--- 初始化模块
--- 该函数必须在客户端或服务端的主入口处调用一次。
--- 它会创建一个用于挂载所有定时器的节点。
---
function ScheduledTask.Init()
    if timersNode and not timersNode.isDestroyed then
        return
    end
    -- Timer 节点需要被挂载在场景中才能运行。
    -- 我们在 WorkSpace 下创建一个专用的文件夹来存放这些动态创建的 Timer。
    -- 这样可以避免场景混乱，也方便统一管理和调试。
    timersNode = SandboxNode.New("SandboxNode", game.WorkSpace) -- 【修正】 "Folder" 不是有效的节点类型，使用通用的 "SandboxNode" 作为容器
    timersNode.Name = "GlobalScheduledTasks"
    gg.log("全局任务调度器 ScheduledTask 已初始化。")
end

---
--- 添加一个延迟执行的任务
---@param delay number 延迟的秒数
---@param callback function 回调函数
---@return Timer|nil 返回创建的Timer实例，如果未初始化则返回nil
function ScheduledTask.AddDelay(delay, callback)
    if not timersNode or timersNode.isDestroyed then
        gg.log("ERROR: [ScheduledTask] 模块未初始化。请在启动脚本中调用 ScheduledTask.Init()。")
        return nil
    end
    local timer = SandboxNode.New("Timer", timersNode)
    timer.Delay = delay
    timer.Loop = false
    timer.Callback = callback
    timer:Start()
    return timer
end

---
--- 添加一个循环执行的任务
---@param interval number 循环间隔的秒数
---@param callback function 回调函数
---@return Timer|nil 返回创建的Timer实例，如果未初始化则返回nil
function ScheduledTask.AddInterval(interval, callback)
    if not timersNode or timersNode.isDestroyed then
        gg.log("ERROR: [ScheduledTask] 模块未初始化。请在启动脚本中调用 ScheduledTask.Init()。")
        return nil
    end
    local timer = SandboxNode.New("Timer", timersNode) ---@type Timer

    timer.Delay = interval -- 首次触发的延迟
    timer.Interval = interval -- 后续循环的间隔
    timer.Loop = true
    timer.Callback = callback
    timer:Start()
    return timer
end

---
--- 移除一个定时器
---@param timer Timer 要移除的定时器句柄
function ScheduledTask.Remove(timer)
    -- 确保timer是一个有效的、未被销毁的实例
    if timer and type(timer) == "userdata" and not timer.isDestroyed then
        timer:Stop()
        timer:Destroy()
    end
end

return ScheduledTask
