-- File: SceneNodeHandlerBase.lua
-- Desc: 所有场景节点处理器的基类，定义了统一的接口和基础结构。

local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)
local ServerScheduler = require(MainStorage.Code.MServer.Scheduler.ServerScheduler)

---@class SceneNodeHandlerBase
local SceneNodeHandlerBase = ClassMgr.Class("SceneNodeHandlerBase")

---构造函数，由SceneNodeManager调用
---@param entity table 场景中找到的节点实体
---@param config table 该节点在SceneNodeConfig中的配置数据
function SceneNodeHandlerBase:Init(entity, config)
    self.entity = entity      -- 场景中的实体
    self.config = config      -- 节点的配置
    self.playersInZone = {}   -- [区域类型专用] 存储当前在区域内的玩家
    self.lastTriggerTime = {} -- [冷却时间专用] 存储每个玩家上次触发的时间
    self.pendingLeavePlayers = {} -- [新增] 用于处理TouchEnded的防抖动
    self.periodicTaskKey = nil  -- [新增] 用于存储定时任务的key
end

---[接口] 当处理器被销毁时调用
function SceneNodeHandlerBase:Destroy()
    -- 子类可以重写此方法来清理资源，例如停止定时器
    -- [新增] 确保在销毁时取消定时任务
    if self.periodicTaskKey then
        ServerScheduler.cancel(self.periodicTaskKey)
        self.periodicTaskKey = nil
    end
end

---[接口] 由SceneNodeManager每帧调用
---@param dt number 距离上一帧的时间(delta time)
function SceneNodeHandlerBase:Update(dt)
    -- 预留给需要持续更新逻辑的子类
end

---[接口] 当玩家进入节点的"区域"时调用
---@param player MPlayer 玩家实体
function SceneNodeHandlerBase:OnEnter(player)
    -- [新增] 借鉴TriggerZone.lua的防抖动逻辑
    if self.pendingLeavePlayers[player.uin] then
        self.pendingLeavePlayers[player.uin] = nil -- 如果玩家在待离开列表里，取消离开
        return
    end

    if self.playersInZone[player.uin] then return end -- 如果已在区域内，不重复执行

    self.playersInZone[player.uin] = player
    local commands = self.config["进入指令"]
    if commands and #commands > 0 then
        -- (此处可以添加冷却判断，如果需要的话)
        player:ExecuteCommands(commands)
    end
end

---[接口] 当玩家离开节点的"区域"时调用
---@param player MPlayer 玩家实体
function SceneNodeHandlerBase:OnLeave(player)
    -- [新增] 借鉴TriggerZone.lua的延迟确认离开逻辑
    if self.playersInZone[player.uin] then
        self.pendingLeavePlayers[player.uin] = player
        ServerScheduler.add(function()
            if self.pendingLeavePlayers[player.uin] then
                self.playersInZone[player.uin] = nil
                self.pendingLeavePlayers[player.uin] = nil
                
                local commands = self.config["离开指令"]
                if commands and #commands > 0 then
                    -- (此处可以添加冷却判断)
                    player:ExecuteCommands(commands)
                end
            end
        end, 0.1) -- 0.1秒延迟确认
    end
end

---[接口] 当玩家"碰撞"到节点时调用
---@param player MPlayer 玩家实体
function SceneNodeHandlerBase:OnTouch(player)
    -- 由子类重写
end

---[辅助函数] 检查指定玩家是否处于冷却中
---@param player MPlayer
---@return boolean 是否在冷却中
function SceneNodeHandlerBase:IsInCooldown(player)
    local cooldown = self.config["触发器参数"] and self.config["触发器参数"]["冷却时间"]
    if not cooldown or cooldown <= 0 then
        return false
    end

    local lastTime = self.lastTriggerTime[player.uin]
    if lastTime and (os.time() - lastTime) < cooldown then
        -- 仍在冷却中
        return true
    end

    return false
end

---[辅助函数] 记录玩家的触发时间，用于冷却计算
---@param player MPlayer
function SceneNodeHandlerBase:RecordTriggerTime(player)
    self.lastTriggerTime[player.uin] = os.time()
end

---[新增] 启动周期性指令的定时器
function SceneNodeHandlerBase:StartPeriodicCommands()
    local interval = self.config["定时间隔"] or 1
    local commands = self.config["定时指令列表"]

    if commands and #commands > 0 and not self.periodicTaskKey then
        self.periodicTaskKey = ServerScheduler.add(function()
            -- 对所有在区域内的玩家执行定时指令
            for _, player in pairs(self.playersInZone) do
                if player and player.ExecuteCommands then
                    player:ExecuteCommands(commands)
                end
            end
        end, interval, interval)
    end
end

return SceneNodeHandlerBase 