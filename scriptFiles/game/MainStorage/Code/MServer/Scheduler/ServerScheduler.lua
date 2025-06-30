print("Hello world!")
local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal)            ---@type gg

---@class Task
---@field func function The function to execute
---@field delay number Delay in seconds before first execution
---@field repeatInterval number Repeat interval in seconds (0 for one-time execution)
---@field remaining number Remaining ticks before execution
---@field taskId number Unique identifier for the task
---@field rounds number For time wheel implementation (number of wheel rotations needed)
---@field key string|nil Optional key for task identification

---@class ServerScheduler
local ServerScheduler = {
    tasks = {},  -- All tasks by ID
    tasksByKey = {}, -- Tasks by key
    nextTaskId = 1,
    
    -- Time wheel configuration
    wheelSlots = 60,  -- Number of slots in the wheel (1 slot per second for 60 seconds)
    wheelPrecision = 1,  -- 1 second precision
    timeWheel = {},    -- The actual time wheel
    currentSlot = 1,   -- Current position in the wheel
    
    -- Timing statistics
    lastTime = gg.GetTimeStamp(),  -- 使用gg.GetTimeStamp()获取时间戳
    updateCount = 0,
    updatesPerSecond = 0,
    isRunning = false
}

-- Initialize the time wheel
for i = 1, ServerScheduler.wheelSlots do
    ServerScheduler.timeWheel[i] = {}
end

---Add a new scheduled task
---@param func function The function to execute
---@param delay number Delay in seconds before first execution
---@param repeatInterval? number Repeat interval in seconds (0 for one-time execution)
---@param key? string Optional key for task identification
---@return number taskId The ID of the created task
function ServerScheduler.add(func, delay, repeatInterval, key)
    -- 如果提供了key，取消同key的任务
    if key and ServerScheduler.tasksByKey[key] then
        ServerScheduler.cancel(ServerScheduler.tasksByKey[key])
    end

    local taskId = ServerScheduler.nextTaskId
    ServerScheduler.nextTaskId = ServerScheduler.nextTaskId + 1
    
    -- 移除乘以30的错误逻辑，直接使用秒为单位
    if not repeatInterval then
        repeatInterval = 0
    end
    
    -- Calculate rounds and slot for the time wheel
    local totalDelay = delay
    local rounds = math.floor(totalDelay / (ServerScheduler.wheelSlots * ServerScheduler.wheelPrecision))
    local slot = (ServerScheduler.currentSlot + math.floor(totalDelay / ServerScheduler.wheelPrecision) - 1) % ServerScheduler.wheelSlots + 1
    
    local task = {
        func = func,
        delay = delay,
        repeatInterval = repeatInterval,  -- 移除乘以30
        remaining = delay,
        taskId = taskId,
        rounds = rounds,
        key = key
    }
    
    ServerScheduler.tasks[taskId] = task
    if key then
        ServerScheduler.tasksByKey[key] = taskId
    end
    table.insert(ServerScheduler.timeWheel[slot], task)
    
    return taskId
end

---Cancel a scheduled task
---@param taskId number The ID of the task to cancel
---@return nil
function ServerScheduler.cancel(taskId)
    local task = ServerScheduler.tasks[taskId]
    if task then
        -- 如果任务有关联的key，清除key映射
        if task.key then
            ServerScheduler.tasksByKey[task.key] = nil
        end
        ServerScheduler.tasks[taskId] = nil
        -- 标记任务为已取消，在update时清理
        task.cancelled = true
    end
end

---Update all scheduled tasks
function ServerScheduler.update()
    local tasks = ServerScheduler.timeWheel[ServerScheduler.currentSlot]
    local remainingTasks = {}
    local tasksToReschedule = {}  -- 新增：收集需要重新调度的任务
    
    for _, task in ipairs(tasks) do
        if ServerScheduler.tasks[task.taskId] and not task.cancelled then  -- Check if task wasn't cancelled
            if task.rounds <= 0 then
                -- Execute the task
                local success, err = pcall(task.func)
                if not success then
                    gg.log("[ERROR] Scheduled task failed:", err)
                end
                
                -- Handle repeating tasks
                if task.repeatInterval > 0 then
                    -- 将需要重新调度的任务收集起来
                    local newRounds = math.floor(task.repeatInterval / (ServerScheduler.wheelSlots * ServerScheduler.wheelPrecision))
                    local newSlot = (ServerScheduler.currentSlot + math.floor(task.repeatInterval / ServerScheduler.wheelPrecision) - 1) % ServerScheduler.wheelSlots + 1
                    
                    task.rounds = newRounds
                    table.insert(tasksToReschedule, {task = task, slot = newSlot})
                else
                    -- Remove one-time tasks
                    ServerScheduler.tasks[task.taskId] = nil
                    if task.key then
                        ServerScheduler.tasksByKey[task.key] = nil
                    end
                end
            else
                -- Task needs more rounds, decrement and keep
                task.rounds = task.rounds - 1
                table.insert(remainingTasks, task)
            end
        end
        -- 已取消的任务会被自动丢弃，不会加入remainingTasks
    end
    
    -- 更新当前槽位的任务
    ServerScheduler.timeWheel[ServerScheduler.currentSlot] = remainingTasks
    
    -- 处理需要重新调度的任务
    for _, rescheduleInfo in ipairs(tasksToReschedule) do
        table.insert(ServerScheduler.timeWheel[rescheduleInfo.slot], rescheduleInfo.task)
    end
    
    ServerScheduler.currentSlot = ServerScheduler.currentSlot % ServerScheduler.wheelSlots + 1
end

-- ServerScheduler 现在由外部驱动（MServerMain.update），不需要自己的定时机制
-- tick 属性用于追踪当前服务器tick，由外部设置
ServerScheduler.tick = 0

-- 更新调度器的时间追踪（每秒调用一次）
function ServerScheduler.updateTiming()
    local currentTime = gg.GetTimeStamp()
    if currentTime - ServerScheduler.lastTime >= 1 then
        ServerScheduler.lastTime = currentTime
        ServerScheduler.updateCount = ServerScheduler.updateCount + 1
        return true -- 表示需要更新调度器
    end
    return false
end

return ServerScheduler