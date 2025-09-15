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
---@field timerCounter number 定时器计数器，确保同一实例内的定时器名称唯一
---@field levelType table|any 关卡配置LevelType实例或规则表
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
    self.timerCounter = 0 -- 初始化定时器计数器
end

--- 生成定时器名称
--- 使用模式名称、实例ID和计数器确保名称唯一性
---@param taskType string 任务类型："Delay"|"Interval"
---@param duration number 时间参数（延迟时间或间隔时间）
---@return string 生成的定时器名称
function GameModeBase:_generateTimerName(taskType, duration)
    self.timerCounter = self.timerCounter + 1
    
    -- 获取关卡名称，优先使用 levelType 中的名称
    local levelName = ""
    if self.levelType and type(self.levelType) == "table" then
        if self.levelType.name then
            levelName = self.levelType.name
        elseif self.levelType.levelName then
            levelName = self.levelType.levelName
        elseif self.levelType.modeName then
            levelName = self.levelType.modeName
        end
    end
    
    -- 如果没有找到关卡名称，使用模式名称
    if levelName == "" then
        levelName = self.modeName or "Unknown"
    end
    
    -- 生成格式：关卡名称_任务类型_时长_实例ID_计数器
    return string.format("%s_%s_%s_%s_%d", 
        levelName, 
        taskType, 
        tostring(duration), 
        self.instanceId, 
        self.timerCounter
    )
end

--- 添加一个延迟执行的任务
--- (使用全局调度器，并自动追踪句柄以便在实例销毁时清理)
---@param delay number 延迟的秒数
---@param callback function 回调函数
---@param customName string|nil 自定义名称（可选）
---@return Timer|nil
function GameModeBase:AddDelay(delay, callback, customName)
    local timer
    local wrappedCallback = function()
        -- 在回调执行后，从 activeTimers 表中移除自己，防止内存泄漏
        if timer and self.activeTimers[timer] then
            self.activeTimers[timer] = nil
        end
        callback()
    end

    local timerName = customName or self:_generateTimerName("Delay", delay)
    timer = ScheduledTask.AddDelay(delay, timerName, wrappedCallback)
    
    if timer then
        self.activeTimers[timer] = true
    end
    return timer
end

--- 添加一个循环执行的任务
--- (使用全局调度器，并自动追踪句柄以便在实例销毁时清理)
---@param interval number 循环间隔的秒数
---@param callback function 回调函数
---@param customName string|nil 自定义名称（可选）
---@return Timer|nil
function GameModeBase:AddInterval(interval, callback, customName)
    local timerName = customName or self:_generateTimerName("Interval", interval)
    local timer = ScheduledTask.AddInterval(interval, timerName, callback)
    
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
        gg.log((logPrefix or "GameModeBase") .. ": 传送失败 - 目标位置为空")
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
            gg.log(string.format("%s: 已传送玩家 %s 到位置 %s",logPrefix or "GameModeBase", player.name, tostring(targetPosition)))
        end
    end

    gg.log(string.format("%s: 传送完成 - 成功: %d/%d",logPrefix or "GameModeBase", successCount, totalCount))

    return successCount > 0
end

--- 传送所有参赛者到指定的处理器节点
---@param nodeType string 节点类型："respawn"|"teleport"
---@param logPrefix string|nil 日志前缀
---@return boolean 是否成功传送
function GameModeBase:TeleportAllPlayersToHandlerNode(nodeType, logPrefix)
    -- gg.log(string.format("传送所有参赛者到指定的处理器节点: %s", nodeType))
    -- 延迟加载，避免循环依赖
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local handler = serverDataMgr.getSceneNodeHandler(self.handlerId)

    if not handler then
        gg.log((logPrefix or "GameModeBase") .. ": 传送失败 - 无法找到处理器实例")
        return false
    end

    local targetNode
    if nodeType == "respawn" then
        targetNode = handler.respawnNode
    elseif nodeType == "teleport" then
        targetNode = handler.teleportNode
    else
        gg.log((logPrefix or "GameModeBase") .. ": 传送失败 - 未知节点类型: " .. tostring(nodeType))
        return false
    end

    if not targetNode or not targetNode.Position then
        gg.log((logPrefix or "GameModeBase") .. ": 传送失败 - " .. nodeType .. "节点不存在或无位置信息")
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

    -- 标注玩家当前所在的游戏模式实例
    player.currentGameModeInstanceId = self.instanceId
    player.currentGameModeName = self.modeName
    gg.log("设置了玩家的游戏模式", player.currentGameModeInstanceId, player.currentGameModeName)
end

--- 当有玩家离开此游戏模式时调用
---@param player MPlayer
function GameModeBase:OnPlayerLeave(player)
    self.participants[player.uin] = nil
    
    -- 清理玩家的游戏模式标记
    player.currentGameModeInstanceId = nil
    player.currentGameModeName = nil
    gg.log("清除了玩家的游戏模式", player.currentGameModeInstanceId, player.currentGameModeName)
  
end

--- 【新增】获取参赛者数量
---@return number
function GameModeBase:_getParticipantCount()
    local count = 0
    if self.participants then
        for _ in pairs(self.participants) do
            count = count + 1
        end
    end
    return count
end

--- 【新增】获取参赛者列表（数组形式）
---@return MPlayer[]
function GameModeBase:_getParticipantList()
    local list = {}
    if self.participants then
        for _, player in pairs(self.participants) do
            table.insert(list, player)
        end
    end
    return list
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



--- 获取参赛者列表
---@return table<string, MPlayer> 参赛者列表
function GameModeBase:GetParticipantsList()
    return self.participants
end

---@param player MPlayer 玩家
---@param volume number|nil 音量 (0.0-1.0)，默认0.8
function GameModeBase:PlaySceneMusic(player, volume)
    if not self.handlerId then
        gg.log("警告: GameModeBase:PlaySceneMusic - handlerId 为空，无法获取场景音效配置")
        return
    end
    
    -- 延迟加载，避免循环依赖
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local handler = serverDataMgr.getSceneNodeHandler(self.handlerId)
    
    if not handler or not handler.config then
        gg.log("警告: GameModeBase:PlaySceneMusic - 无法获取场景处理器或其配置")
        return
    end
    
    -- 获取场景配置中的音效资源
    local soundAssetId = handler.config.soundAsset
    if not soundAssetId or soundAssetId == "" then
        gg.log("信息: GameModeBase:PlaySceneMusic - 场景未配置音效资源")
        return
    end
    
    volume = volume or 0.8
    gg.log(string.format("GameModeBase: 场景音乐开始播放: %s (音量: %s)", soundAssetId, volume))

    -- 使用新的背景音乐播放器
    local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
    local musicData = {
        cmd = 'PlayBackgroundMusic',
        soundAssetId = soundAssetId,
        musicKey = "SceneMusic_" .. self.instanceId, -- 修改：使用musicKey替代priority
        volume = volume
    }
    ServerEventManager.SendToClient(player.uin, musicData)
    gg.log(string.format("GameModeBase: 已向玩家 %s 发送场景音乐播放事件", player.name or player.uin))
end

--- 【新增】停止场景背景音乐
---@param player MPlayer 玩家
function GameModeBase:StopSceneMusic(player)
    local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
    local musicData = {
        cmd = 'StopBackgroundMusic',
        musicKey = "SceneMusic_" .. self.instanceId -- 使用相同的musicKey
    }
    
    
    ServerEventManager.SendToClient(player.uin, musicData)
    gg.log(string.format("GameModeBase: 已向玩家 %s 发送停止场景音乐事件", player.name or player.uin))
end

return GameModeBase
