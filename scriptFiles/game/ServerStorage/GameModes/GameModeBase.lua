local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)
local MPlayer = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer
local ScheduledTask = require(MainStorage.Code.Untils.scheduled_task) ---@type ScheduledTask

---@class GameModeBase : Class
---@field participants table<string, MPlayer>
---@field instanceId string
---@field modeName string
---@field activeTimers table<Timer, boolean>
local GameModeBase = ClassMgr.Class("GameModeBase")

--- 初始化游戏模式实例
---@param self GameModeBase
---@param instanceId string 实例的唯一ID
---@param modeName string 模式的名称
---@param levelType LevelType|table 关卡配置LevelType实例或具体的游戏规则（向后兼容）
function GameModeBase.OnInit(self, instanceId, modeName, levelType)
    self.instanceId = instanceId
    self.modeName = modeName
    self.levelType = levelType -- 改为存储LevelType实例，子类可以重写此属性
    self.participants = {} -- key: uin, value: MPlayer
    self.activeTimers = {} -- 存放所有由本实例创建的、活跃的定时器句柄
end

--- 添加一个延迟执行的任务
--- (使用全局调度器，并自动追踪句柄以便在实例销毁时清理)
---@param delay number 延迟的秒数
---@param callback function 回调函数
---@return Timer
function GameModeBase:AddDelay(delay, callback)
    local timer
    local wrappedCallback = function()
        -- 在回调执行后，从 activeTimers 表中移除自己，防止内存泄漏
        if timer and self.activeTimers[timer] then
            self.activeTimers[timer] = nil
        end
        callback()
    end
    
    timer = ScheduledTask.AddDelay(delay, "GameModeBase_Delay_" .. delay, wrappedCallback)
    if timer then
        self.activeTimers[timer] = true
    end
    return timer
end

--- 添加一个循环执行的任务
--- (使用全局调度器，并自动追踪句柄以便在实例销毁时清理)
---@param interval number 循环间隔的秒数
---@param callback function 回调函数
---@return Timer
function GameModeBase:AddInterval(interval, callback)
    local timer = ScheduledTask.AddInterval(interval, "GameModeBase_Interval_" .. interval, callback)
    if timer then
        self.activeTimers[timer] = true
    end
    return timer
end

--- 移除一个由本实例创建的定时器
---@param timer Timer
function GameModeBase:RemoveTimer(timer)
    if timer and self.activeTimers[timer] then
        ScheduledTask.Remove(timer)
        self.activeTimers[timer] = nil -- 从追踪表中移除
    end
end

--- 当有玩家进入此游戏模式时调用
---@param player MPlayer
function GameModeBase:OnPlayerEnter(player)
    self.participants[player.uin] = player
end

--- 当有玩家离开此游戏模式时调用
---@param player MPlayer
function GameModeBase:OnPlayerLeave(player)
    self.participants[player.uin] = nil
end

--- 销毁此游戏模式实例，清理所有相关资源
function GameModeBase:Destroy()
    -- 遍历并销毁所有由该游戏模式实例创建的、仍在活动的定时器
    for timer, _ in pairs(self.activeTimers) do
        ScheduledTask.Remove(timer)
    end
    
    -- 清空追踪表和参与者列表
    self.activeTimers = {}
    self.participants = {}
end

--- 每帧更新 (已废弃，因为我们使用引擎定时器)
---@param dt number
function GameModeBase:Update(dt)
    -- self.scheduler:Update(dt)
end

return GameModeBase
