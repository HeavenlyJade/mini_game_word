local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)
local MPlayer = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer

---@class GameModeBase : Class
---@field participants table<string, MPlayer>
---@field timersNode SandboxNode
---@field instanceId string
---@field modeName string
local GameModeBase = ClassMgr.Class("GameModeBase")

--- 初始化游戏模式实例
---@param self GameModeBase
---@param instanceId string 实例的唯一ID
---@param modeName string 模式的名称
---@param rules table 具体的游戏规则
function GameModeBase.OnInit(self, instanceId, modeName, rules)
    self.instanceId = instanceId
    self.modeName = modeName
    self.rules = rules or {}
    self.participants = {} -- key: uin, value: MPlayer
    self.activeTimers = {} -- 存放所有活跃的定时器节点

    -- 为这个游戏模式实例创建一个专属的父节点，用于挂载所有定时器
    self.timersNode = SandboxNode.New("SandboxNode", game.WorkSpace)
    self.timersNode.Name = string.format("Timers_GameMode_%s", instanceId)
    self.timersNode.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE
end

--- 添加一个延迟执行的任务
---@param delay number 延迟的秒数
---@param callback function 回调函数
---@return Timer
function GameModeBase:AddDelay(delay, callback)
    local timer = SandboxNode.New("Timer", self.timersNode)
    timer.Delay = delay
    timer.Loop = false
    timer.Callback = callback
    timer:Start()
    return timer
end

--- 添加一个循环执行的任务
---@param interval number 循环间隔的秒数
---@param callback function 回调函数
---@return Timer
function GameModeBase:AddInterval(interval, callback)
    local timer = SandboxNode.New("Timer", self.timersNode)
    timer.Delay = interval
    timer.Loop = true
    timer.Callback = callback
    timer:Start()
    return timer
end

--- 移除一个定时器
---@param timer Timer
function GameModeBase:RemoveTimer(timer)
    if timer and timer.IsValid and timer:GetParent() == self.timersNode then
        timer:Destroy()
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

--- 销毁此游戏模式实例，清理所有资源
function GameModeBase:Destroy()
    if self.timersNode and self.timersNode.IsValid then
        self.timersNode:Destroy()
    end
    self.timersNode = nil
    self.participants = {}
end

--- 每帧更新 (已废弃，因为我们使用引擎定时器)
---@param dt number
function GameModeBase:Update(dt)
    -- self.scheduler:Update(dt)
end

return GameModeBase
