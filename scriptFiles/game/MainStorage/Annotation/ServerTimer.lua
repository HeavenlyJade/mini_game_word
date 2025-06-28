---@enum RUNSTATE
local RUNSTATE = {
    STOP = 0,       -- 停止状态
    RUNNING = 1,    -- 运行状态
    PAUSED = 2      -- 暂停状态
}

---@class Timer : SandboxNode
---@field Callback function lua回调方法
---@field Delay number 首次延迟执行的时间（秒）
---@field Loop boolean 是否循环执行
---@field Interval number 计时间隔时间（秒）
local Timer = {}

---开始执行定时器
---@return void
function Timer:Start() end

---暂停定时器。需要在开始执行后调用
---@return void
function Timer:Pause() end

---恢复定时器。需要在暂停后调用
---@return void
function Timer:Resume() end

---停止定时器。需要在开始执行后调用
---@return void
function Timer:Stop() end

---获取定时器运行状态
---@return RUNSTATE 定时器运行状态
function Timer:GetRunState() end

---开始执行。附带初始化的参数
---@param delay number 延迟时间（秒）
---@param loop boolean 是否循环
---@param interval number 间隔时间（秒）
---@param cb function 回调函数
---@return void
function Timer:StartEx(delay, loop, interval, cb) end

return Timer 