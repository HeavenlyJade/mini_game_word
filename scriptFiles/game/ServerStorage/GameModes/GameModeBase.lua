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

function GameModeBase:OnInit(instanceId, modeName)
    self.participants = {}
    self.instanceId = instanceId
    self.modeName = modeName

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
