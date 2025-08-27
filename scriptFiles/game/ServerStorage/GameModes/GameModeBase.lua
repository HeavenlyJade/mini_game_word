local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)
local MPlayer = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer
local ScheduledTask = require(MainStorage.Code.Untils.scheduled_task) ---@type ScheduledTask
local gg = require(MainStorage.Code.Untils.MGlobal)

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

--- 传送所有参赛者到指定位置
---@param targetPosition Vector3 目标位置
---@param logPrefix string|nil 日志前缀，用于调试
---@return boolean 是否成功传送至少一个玩家
function GameModeBase:TeleportAllPlayersToPosition(targetPosition, logPrefix)
    if not targetPosition then
        --gg.log((logPrefix or "GameModeBase") .. ": 传送失败 - 目标位置为空")
        return false
    end

    local TeleportService = game:GetService('TeleportService')
    local successCount = 0
    local totalCount = 0

    -- 遍历所有参赛者进行传送
    for _, player in pairs(self.participants) do
        if player and player.actor then
            totalCount = totalCount + 1
            TeleportService:Teleport(player.actor, targetPosition)
            successCount = successCount + 1
            --gg.log(string.format("%s: 已传送玩家 %s 到位置 %s",logPrefix or "GameModeBase", player.name, tostring(targetPosition)))
        end
    end

    --gg.log(string.format("%s: 传送完成 - 成功: %d/%d",logPrefix or "GameModeBase", successCount, totalCount))

    return successCount > 0
end

--- 传送所有参赛者到指定的处理器节点
---@param nodeType string 节点类型："respawn"|"teleport"
---@param logPrefix string|nil 日志前缀
---@return boolean 是否成功传送
function GameModeBase:TeleportAllPlayersToHandlerNode(nodeType, logPrefix)

    -- 延迟加载，避免循环依赖
    local serverDataMgr = require(game:GetService("ServerStorage").Manager.MServerDataManager)
    local handler = serverDataMgr.getSceneNodeHandler(self.handlerId)

    if not handler then
        --gg.log((logPrefix or "GameModeBase") .. ": 传送失败 - 无法找到处理器实例")
        return false
    end

    local targetNode
    if nodeType == "respawn" then
        targetNode = handler.respawnNode
    elseif nodeType == "teleport" then
        targetNode = handler.teleportNode
    else
        --gg.log((logPrefix or "GameModeBase") .. ": 传送失败 - 未知节点类型: " .. tostring(nodeType))
        return false
    end

    if not targetNode or not targetNode.Position then
        --gg.log((logPrefix or "GameModeBase") .. ": 传送失败 - " .. nodeType .. "节点不存在或无位置信息")
        return false
    end

    return self:TeleportAllPlayersToPosition(targetNode.Position, logPrefix)
end

--- 传送所有参赛者到传送节点（比赛起始位置）
---@return boolean 是否成功传送
function GameModeBase:TeleportAllPlayersToStartPosition()
    return self:TeleportAllPlayersToHandlerNode("teleport", self.modeName)
end

--- 传送所有参赛者到复活节点
---@return boolean 是否成功传送
function GameModeBase:TeleportAllPlayersToRespawn()
    return self:TeleportAllPlayersToHandlerNode("respawn", self.modeName)
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

--- 【新增】停止游戏模式音乐
---@param musicKey string|nil 音乐键值，默认为模式实例ID
function GameModeBase:StopGameModeMusic(musicKey)
    local key = musicKey or ("GameModeMusic_" .. self.instanceId)
    
    local RaceGameEventManager = require(ServerStorage.GameModes.Modes.RaceGameEventManager) ---@type RaceGameEventManager
    
    -- 通过发送空音效来停止音乐
    local stopMusicData = {
        cmd = "PlaySound",
        soundAssetId = "",
        key = key,
        volume = 0
    }

    -- 通知所有玩家停止音乐
    RaceGameEventManager.BroadcastRaceEvent(
        self:GetParticipantsList(), 
        "PlaySound", 
        stopMusicData
    )
    
    --gg.log("游戏模式音乐已停止: " .. key)
end


--- 【新增】播放游戏模式音乐
---@param musicAssetId string 音乐资源ID
---@param volume number|nil 音量 (0.0-1.0)
---@param musicKey string|nil 音乐键值，默认为模式实例ID
function GameModeBase:PlayGameModeMusic(musicAssetId, volume, musicKey)
    if not musicAssetId or musicAssetId == "" then
        return
    end
    
    local key = musicKey or ("GameModeMusic_" .. self.instanceId)
    volume = volume or 0.6
    
    local RaceGameEventManager = require(ServerStorage.GameModes.Modes.RaceGameEventManager) ---@type RaceGameEventManager
    
    local musicData = {
        cmd = "PlaySound",
        soundAssetId = musicAssetId,
        key = key,
        volume = volume,
        pitch = 1.0,
        range = 15000  -- 大范围确保全场都能听到
    }

    -- 向所有参赛者播放音乐
    RaceGameEventManager.BroadcastRaceEvent(
        self:GetParticipantsList(), 
        "PlaySound", 
        musicData
    )
    
    --gg.log(string.format("游戏模式音乐播放: %s (音量: %s)", musicAssetId, volume))
end



return GameModeBase
