local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)  ---@type ClassMgr
local GameModeBase = require(ServerStorage.GameModes.GameModeBase) ---@type GameModeBase
local MPlayer             = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig
local VectorUtils = require(MainStorage.Code.Untils.VectorUtils) ---@type VectorUtils
local BonusManager = require(ServerStorage.BonusManager.BonusManager) ---@type BonusManager
local PlayerRewardDispatcher = require(ServerStorage.MiniGameMgr.PlayerRewardDispatcher) ---@type PlayerRewardDispatcher
local RaceGameEventManager = require(ServerStorage.GameModes.Modes.RaceGameEventManager) ---@type RaceGameEventManager

---@class RaceGameMode: GameModeBase
---@field participants MPlayer[]
---@field levelType LevelType 关卡配置的LevelType实例
---@field handlerId string 触发此模式的场景处理器的ID
---@field finishedPlayers table<number, boolean> 新增：用于记录已完成比赛的玩家 (uin -> true)
---@field flightData table<number, FlightPlayerData> 实时飞行数据 (uin -> FlightPlayerData)
---@field rankings table<number> 按飞行距离排序的玩家uin列表
---@field distanceTimer Timer|nil 距离计算定时器
---@field startPositions table<number, Vector3> 玩家起始位置记录 (uin -> Vector3)
---@field raceStartTime number 比赛开始时间戳
---@field contestUpdateTimer Timer|nil 比赛界面更新定时器
---@field realtimeRewardsGiven table<number, table<string, boolean>> 实时奖励发放记录 (uin -> {ruleId -> true})
---@field levelRewardsGiven table<number, table<string, boolean>> 关卡奖励发放记录 (uin -> {uniqueId -> true})
local RaceGameMode = ClassMgr.Class("RaceGameMode", GameModeBase)

-- 比赛状态
local RaceState = {
    WAITING = "WAITING",         -- 等待玩家加入
    PREPARING = "PREPARING",     -- 【新增】准备倒计时中
    RACING = "RACING",           -- 比赛进行中
    FINISHED = "FINISHED",   -- 比赛已结束
}

---@class FlightPlayerData
---@field uin number 玩家UIN
---@field name string 玩家名称
---@field startPosition Vector3 起始位置
---@field currentPosition Vector3 当前位置
---@field flightDistance number 飞行距离
---@field rank number 当前排名
---@field isFinished boolean 是否已完成比赛

function RaceGameMode:OnInit(instanceId, modeName, levelType)
    self.state = RaceState.WAITING
    self.participants = {} -- 存放所有参赛玩家的table, key: uin, value: MPlayer
    self.levelType = levelType -- 存储完整的LevelType实例
    self.modeName = modeName
    self.ModeType = "RaceGameMode"
    -- 【新增】倒计时控制
    self.prepareTimer = nil      -- 准备倒计时定时器
    self.isPreparing = false     -- 防止重复启动标志

    -- 调试信息：显示比赛模式初始化结果
     self.finishedPlayers = {} -- 【新增】初始化已完成玩家的记录表
    self.flightData = {} -- 实时飞行数据 (uin -> FlightPlayerData)
    self.rankings = {} -- 按飞行距离排序的玩家uin列表
    self.distanceTimer = nil -- 距离计算定时器
    self.startPositions = {} -- 玩家起始位置记录 (uin -> Vector3)
    self.raceStartTime = 0 -- 比赛开始时间戳
    self.contestUpdateTimer = nil -- 比赛界面更新定时器
    self.realtimeRewardsGiven = {} -- 实时奖励发放记录 (uin -> {ruleIndex -> true})
    self.levelRewardsGiven = {} -- 关卡奖励发放记录 (uin -> {uniqueId -> true})
    --gg.log(string.format("RaceGameMode 初始化完成 - 实例ID: %s, 关卡: %s", tostring(instanceId), levelType and (levelType.levelName or "未知") or "未知"))
end

--- 【修复】优化玩家进入逻辑，防止状态不一致
function RaceGameMode:OnPlayerEnter(player)
    if player and player.actor and player.actor.Position then
        gg.log(string.format("玩家 %s 进入比赛区域", player.name or player.uin))
    end

    -- 防重复加入
    if self.participants[player.uin] then
        --gg.log(string.format("玩家 %s 已在比赛中，跳过", player.name or player.uin))
        return
    end

    self.participants[player.uin] = player
    local participantCount = self:_getParticipantCount()

    --gg.log(string.format("玩家 %s 加入比赛，状态: %s，人数: %d",
        -- player.name or player.uin, self.state, participantCount))

    if self.state == RaceState.WAITING then
        -- 【修复】第一个玩家进入且未在准备中时才启动倒计时
        if participantCount == 1 and not self.isPreparing then
            self:Start()
        elseif self.isPreparing then
            -- 【新增】如果已在倒计时，向新加入玩家发送剩余时间
            self:_notifyJoinDuringCountdown(player)
        end
    elseif self.state == RaceState.PREPARING then
        -- 【新增】准备阶段处理新加入玩家
        self:_notifyJoinDuringCountdown(player)
    elseif self.state == RaceState.RACING then
        -- 比赛进行中，处理迟到玩家
        self:_handleLateJoinPlayer(player)
    else
        -- 比赛已结束
        player:SendHoverText("比赛已结束，请等待下一场")
    end
end
--- 当有玩家离开此游戏模式时调用
---@param player MPlayer
function RaceGameMode:OnPlayerLeave(player)
    if not player then return end

    local uin = player.uin

    -- 从参赛者列表中移除
    self.participants[uin] = nil

    -- 清理相关数据
    self:_cleanPlayerData(uin)

    local remainingCount = self:_getParticipantCount()
    gg.log(string.format("玩家 %s 离开比赛，剩余玩家: %d",
        player.name or uin, remainingCount))

    -- 【修复】根据当前状态和剩余人数决定后续操作
    if self.state == RaceState.WAITING or self.state == RaceState.PREPARING then
        if remainingCount == 0 then
            -- 没有玩家了，取消比赛
            self:_cancelRaceAndCleanup()
        elseif self.state == RaceState.PREPARING and remainingCount < 1 then
            -- 准备中人数不足，取消倒计时
            self:_cancelPrepareCountdown("人数不足")
        end
    elseif self.state == RaceState.RACING then
        if remainingCount < 1 then
            self:End()
        else
            -- 比赛进行中需要重新计算排名
            self:_updateRankings()
        end
    end
end
--- 【新增】处理关卡奖励节点触发
---@param triggerPlayer MPlayer 触发的玩家
---@param evt table 事件数据
function RaceGameMode:HandleLevelRewardTrigger(triggerPlayer, evt)
    -- 【修复】严格验证触发者身份
    local uin = triggerPlayer.uin

    -- 【修复】用正确的遍历方式检查玩家是否在比赛中
    local playerInRace = self.participants[uin] ~= nil

    if not playerInRace then
        gg.log(string.format("玩家 %s 不在当前比赛中，忽略奖励触发", triggerPlayer.name or uin))
        return
    end

    -- 【修复】确保奖励只给触发者
    local uniqueId = evt.uniqueId
    if self.levelRewardsGiven[uin] and self.levelRewardsGiven[uin][uniqueId] then
        return -- 已经给过这个奖励
    end

    -- 【修复】调用正确存在的函数 GetLevelRewardConfig，并传入正确顺序的参数
    local rewardNode = self:GetLevelRewardConfig(evt.configName, uniqueId)
    if not rewardNode then
        return
    end

    local success = self:DistributeLevelReward(triggerPlayer, rewardNode, uniqueId)
    if success then
        if not self.levelRewardsGiven[uin] then
            self.levelRewardsGiven[uin] = {}
        end
        self.levelRewardsGiven[uin][uniqueId] = true

        -- 【修复】奖励通知也只发给触发者
        self:SendLevelRewardNotification(triggerPlayer, rewardNode, uniqueId)
    end
end


--- 【修改】获取关卡奖励配置 - 增加缓存支持
---@param configName string 配置名称
---@param uniqueId string 唯一ID
---@return table|nil 奖励配置项
function RaceGameMode:GetLevelRewardConfig(configName, uniqueId)
    -- 如果没有传入configName，尝试从levelType获取
    if not configName and self.levelType and self.levelType:HasSceneConfig() then
        configName = self.levelType:GetSceneConfig()
    end
    
    if not configName then
        return nil
    end

    -- 使用缓存的配置映射表
    local levelRewardConfigs = self:_getLevelRewardConfigs()
    if levelRewardConfigs then
        return levelRewardConfigs[uniqueId]
    end

    -- 回退到原有逻辑
    local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
    local levelRewardConfig = ConfigLoader.GetLevelNodeReward(configName)
    if not levelRewardConfig then
        return nil
    end

    if levelRewardConfig.GetRewardNodeById then
        return levelRewardConfig:GetRewardNodeById(uniqueId)
    end

    return nil
end

--- 【新增】分发关卡奖励
---@param player MPlayer 目标玩家
---@param rewardConfig LevelNodeRewardItem 奖励配置
---@param uniqueId string 唯一ID
---@return boolean 是否发放成功
function RaceGameMode:DistributeLevelReward(player, rewardConfig, uniqueId)
    if not player or not rewardConfig then
        return false
    end

    local rewardType = rewardConfig["奖励类型"] or ""
    local itemType = rewardConfig["物品类型"] or ""
    local itemCount = rewardConfig["物品数量"] or 0
    local rewardCondition = rewardConfig["奖励条件"] or ""

    -- 检查奖励条件（如果有的话）
    if rewardCondition ~= "" and not self:CheckRewardCondition(player, rewardCondition) then
        --gg.log(string.format("玩家 %s 不满足奖励条件:%s", player.name or player.uin, rewardCondition))
        return false
    end

    -- 【新增】应用玩家加成计算
    local finalItemCount = itemCount

    -- 1. 计算玩家所有物品加成（宠物、伙伴、翅膀、尾迹）
    local bonuses = BonusManager.CalculatePlayerItemBonuses(player)

    -- 2. 构建原始奖励数据
    local originalRewards = {
        [itemType] = itemCount
    }

    -- 3. 针对当前奖励物品名，追加聚合天赋定向加成（避免无关天赋误入）
    local targetedBonuses = BonusManager.CalculatePlayerItemBonuses(player, itemType)
    BonusManager.MergeBonuses(bonuses, targetedBonuses)
    local finalRewards = BonusManager.ApplyBonusesToRewards(originalRewards, bonuses)

    -- 4. 获取应用加成后的最终数量
    finalItemCount = finalRewards[itemType] or itemCount

    -- 记录加成计算日志
    if finalItemCount ~= itemCount then
        gg.log(string.format("关卡奖励加成计算: 玩家 %s, 物品 %s, 原始数量: %d, 加成后数量: %d",
            player.name or player.uin, itemType, itemCount, finalItemCount))
    end

    -- 使用现有的奖励发放系统，发放加成后的奖励
    if not PlayerRewardDispatcher then
        --gg.log("PlayerRewardDispatcher 未初始化，无法发放奖励")
        return false
    end

    -- 发放最终奖励（已应用加成）
    local success, errmsg = PlayerRewardDispatcher.DispatchSingleReward(player, "物品", itemType, finalItemCount)

    if success then

        return true
    else
        return false
    end
end


--- 【新增】检查奖励条件
---@param player MPlayer 玩家
---@param condition string 奖励条件
---@return boolean 是否满足条件
function RaceGameMode:CheckRewardCondition(player, condition)
    if not condition or condition == "" then
        return true
    end
    --gg.log(string.format("检查玩家 %s 的奖励条件:%s (暂时跳过检查)", player.name or player.uin, tostring(condition)))
    return true
end

--- 【新增】发送关卡奖励通知给客户端
---@param player MPlayer 玩家
---@param rewardConfig table 奖励配置
---@param uniqueId string 唯一ID
function RaceGameMode:SendLevelRewardNotification(player, rewardConfig, uniqueId)
    if not player or not player.uin then
        return
    end


    -- 从关卡奖励类型中获取音效资源字段并下发
    local triggerSound = nil
    if self.levelType and self.levelType.HasSceneConfig and self.levelType:HasSceneConfig() then
        local sceneConfigName = self.levelType:GetSceneConfig()
        if sceneConfigName and sceneConfigName ~= "" then
            local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader)
            local levelRewardType = ConfigLoader.GetLevelNodeReward(sceneConfigName)
            if levelRewardType and levelRewardType.soundNodeField and levelRewardType.soundNodeField ~= "" then
                triggerSound = levelRewardType.soundNodeField
            end
        end
    end

    if gg.network_channel and triggerSound and triggerSound ~= "" then
        gg.network_channel:fireClient(player.uin, {
            cmd = "PlaySound",
            soundAssetId = triggerSound,
            volume = 0.8,
            pitch = 1.0,
            mindistance = 400,
            maxdistance = 5000,
            range = 1000
        })
    end
end
--- 【新增】获取玩家的关卡奖励发放记录
---@param player MPlayer 玩家
---@return table<string, boolean>
function RaceGameMode:GetPlayerLevelRewardRecord(player)
    if not player or not player.uin then
        return {}
    end
    return self.levelRewardsGiven[player.uin] or {}
end

--- 【新增】重置玩家的关卡奖励发放记录
---@param player MPlayer 玩家
function RaceGameMode:ResetPlayerLevelRewardRecord(player)
    if not player or not player.uin then
        return
    end
    if self.levelRewardsGiven[player.uin] then
        self.levelRewardsGiven[player.uin] = {}
        --gg.log(string.format("已重置玩家 %s 的关卡奖励发放记录", player.name or player.uin))
    end
end

--- 将玩家发射出去
-- 在 RaceGameMode.lua 中修复 LaunchPlayer 方法

--- 将玩家发射出去 - 修复版本，使用玩家的实际速度属性
---@param player MPlayer
---@param startPosOverride Vector3|nil
function RaceGameMode:LaunchPlayer(player, startPosOverride)
    if not player or not player.actor then
        gg.log("错误: LaunchPlayer - 玩家或Actor为空")
        return
    end

    -- 【修复】优先使用传入的起始点，避免竞态条件
    local startPos = startPosOverride
    if not startPos and player.actor then
        startPos = player.actor.Position
    end

    -- 记录玩家起始位置，用于计算飞行距离
    if startPos then
        self.startPositions[player.uin] = startPos
        -- 初始化飞行数据
        self.flightData[player.uin] = {
            uin = player.uin,
            name = player.name,
            startPosition = startPos,
            currentPosition = startPos,
            flightDistance = 0,
            rank = 1,
            isFinished = false
        }
    end

    -- 【关键修复】从玩家属性中获取实际计算的速度值，而不是使用固定值


    -- 获取其他参数（可以从levelType配置或使用默认值）
    local jumpSpeed = 200
    local jumpDuration = 0.5
    local recoveryDelay = self.levelType and self.levelType.raceTime or 60

    -- 获取重生点坐标
    local respawnPosition = nil
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local handler = serverDataMgr.getSceneNodeHandler(self.handlerId)
    if handler and handler.respawnNode and handler.respawnNode.Position then
        respawnPosition = handler.respawnNode.Position
    end
        -- 【新增】为当前发射的玩家执行游戏开始指令
    self:_executeGameStartCommandsForPlayer(player)
    local actualMoveSpeed = player:GetStat("速度")
    -- 【关键】发送包含实际速度值的网络消息
    local launchData = {
        cmd = EventPlayerConfig.NOTIFY.LAUNCH_PLAYER,
        moveSpeed = actualMoveSpeed,  -- 使用实际计算的速度值，而不是固定的400
        jumpSpeed = jumpSpeed,
        jumpDuration = jumpDuration,
        recoveryDelay = recoveryDelay,
        gameMode = EventPlayerConfig.GAME_MODES.RACE_GAME,
        respawnPosition = respawnPosition,
        variableData = player.variables or {} -- 同步玩家变量数据
    }

    self:PlaySceneMusic(player)
    gg.network_channel:fireClient(player.uin, launchData)
end
--- 【核心改造】处理玩家落地，由 RaceGameEventManager 调用
---@param player MPlayer 游戏结束事件处理
function RaceGameMode:OnPlayerLanded(player)
    -- 检查该玩家是否已经报告过落地
    if self.finishedPlayers[player.uin] then
        return -- 防止重复处理
    end

    -- 如果比赛已经结束，则不再处理后续的落地事件
    if self.state == RaceState.FINISHED then
        return
    end

    -- 记录该玩家已完成
    self.finishedPlayers[player.uin] = true

    -- 标记玩家为已完成状态（用于停止距离计算）
    self:_markPlayerFinished(player.uin)

    -- 【核心修正】手动计算已完成玩家的数量。
    -- 在 Lua 中，对以非连续数字（如uin）为键的 table 使用 '#' 操作符会返回 0，这是一个已知的语言特性。
    local finishedCount = 0
    for _ in pairs(self.finishedPlayers) do
        finishedCount = finishedCount + 1
    end

    -- 获取玩家当前排名信息
    local flightData = self:GetPlayerFlightData(player.uin)

    -- 使用正确的计数值检查是否所有人都已完成
    if finishedCount >= self:_getParticipantCount() then
        self:End()
    end

end



--- 开始比赛
function RaceGameMode:Start()
    -- 【修复】防止重复启动
    if self.state ~= RaceState.WAITING or self.isPreparing then
        --gg.log(string.format("比赛已在准备中，跳过重复启动。当前状态: %s, 准备标志: %s",
            -- self.state, tostring(self.isPreparing)))
        return
    end

    -- 【修复】标记为准备状态，防止重复启动
    self.state = RaceState.PREPARING
    self.isPreparing = true

    local prepareTime = self.levelType.prepareTime or 10
    --gg.log(string.format("开始比赛准备倒计时: %d秒", prepareTime))

    -- 【新增】记录倒计时开始时间，用于计算剩余时间
    self.prepareStartTime = os.time()
    self.totalPrepareTime = prepareTime

    -- 立即向所有参赛者发送准备倒计时通知
    RaceGameEventManager.BroadcastPrepareCountdown(self:_getParticipantList(), prepareTime)

    -- 【修复】使用可取消的定时器
    self.prepareTimer = self:AddDelay(prepareTime, function()
        self:_onPrepareCountdownFinished()
    end)
end

-- 【新增】倒计时完成回调
function RaceGameMode:_onPrepareCountdownFinished()
    -- 重新检查参赛人数
    if self:_getParticipantCount() < 1 then
        --gg.log("倒计时结束时无参赛者，取消比赛")
        self:_cancelRaceAndCleanup()
        return
    end

    --gg.log("准备倒计时结束，开始比赛！")

    -- 重置准备标志
    self.isPreparing = false
    self.prepareTimer = nil
    self.prepareStartTime = nil  -- 【新增】清理时间记录
    self.totalPrepareTime = nil  -- 【新增】清理时间记录
    self.state = RaceState.RACING

    -- 执行比赛开始逻辑
    self:_executeRaceStart()
end

-- 【新增】执行比赛开始的具体逻辑
function RaceGameMode:_executeRaceStart()
    -- 传送所有玩家到传送节点
    local teleportSuccess = self:TeleportAllPlayersToStartPosition()

    if teleportSuccess then
        -- 给传送一点时间完成，然后发射玩家
        self:AddDelay(0.5, function()
            for _, player in pairs(self.participants) do
                self:LaunchPlayer(player)
            end

            -- 启动实时追踪
            self:_startFlightDistanceTracking()
            self:_startContestUIUpdates()
            self.raceStartTime = os.time()
        end)
    else
        --gg.log("传送失败，比赛无法开始！")
        self:_cancelRaceAndCleanup()
    end
end

-- 【新增】取消准备倒计时
function RaceGameMode:_cancelPrepareCountdown(reason)
    if not self.isPreparing then return end

    --gg.log(string.format("取消准备倒计时，原因: %s", reason or "未知"))

    -- 取消定时器
    if self.prepareTimer then
        self:RemoveTimer(self.prepareTimer)
        self.prepareTimer = nil
    end

    -- 重置状态
    self.isPreparing = false
    self.state = RaceState.WAITING

    -- 通知所有参赛者停止倒计时
    RaceGameEventManager.BroadcastStopPrepareCountdown(self:_getParticipantList(), reason)
end

-- 【新增】计算倒计时剩余时间的方法
---@return number 剩余倒计时时间（秒）
function RaceGameMode:GetRemainingPrepareTime()
   if not self.isPreparing or not self.prepareStartTime or not self.totalPrepareTime then
       return 0
   end

   local currentTime = os.time()
   local elapsedTime = currentTime - self.prepareStartTime
   local remainingTime = self.totalPrepareTime - elapsedTime
   gg.log("currentTime", currentTime, "elapsedTime", elapsedTime, "remainingTime", remainingTime, "totalPrepareTime", self.totalPrepareTime)
   return math.max(0, remainingTime)
end

-- 【修复】向准备中加入的玩家发送当前倒计时状态
function RaceGameMode:_notifyJoinDuringCountdown(player)
   if not player or not self.isPreparing then return end

   -- 【关键修复】计算并发送剩余倒计时时间，而不是完整时间
   local remainingTime = self:GetRemainingPrepareTime()

   -- 如果剩余时间不足1秒，不发送倒计时通知
   if remainingTime < 1 then
       return
   end

   local eventData = {
       cmd = EventPlayerConfig.NOTIFY.RACE_PREPARE_COUNTDOWN,
       gameMode = EventPlayerConfig.GAME_MODES.RACE_GAME,
       prepareTime = remainingTime,  -- 【修复】发送剩余时间而不是总时间
       playerScene = player.currentScene
   }

   if gg.network_channel then
       gg.network_channel:fireClient(player.uin, eventData)
   end
end

--- 结束比赛
function RaceGameMode:End()
    if self.state ~= RaceState.RACING then
        return
    end

    --gg.log(string.format("结束比赛 %s", self.instanceId))
    self.state = RaceState.FINISHED

    -- 停止所有定时器和追踪
    self:_stopFlightDistanceTracking()
    self:_stopContestUIUpdates()

    -- 执行结算逻辑
    self:_executeGameEndCommands()
    self:_updateRankings()
    self:_calculateAndDistributeRewards()

    -- 通知玩家结果
    for _, uin in ipairs(self.rankings) do
        local flightData = self.flightData[uin]
        if flightData then
            local rankText = string.format("第 %d 名: %s (%.1f米)",
                flightData.rank, flightData.name, flightData.flightDistance)

            for _, player in pairs(self.participants) do
                if player.uin == uin then
                    player:SendHoverText(rankText)
                    break
                end
            end
        end
    end

    -- 清理GameModeManager中的记录
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local GameModeManager = serverDataMgr.GameModeManager

    if GameModeManager then
        -- 清理玩家记录
        for _, player in pairs(self.participants) do
            if player then
                GameModeManager.playerModes[player.uin] = nil
                self:StopSceneMusic(player)
            end
        end
        -- 清理实例记录
        GameModeManager.activeModes[self.instanceId] = nil
    end

    -- 清理自身数据
    self.participants = {}
    self.finishedPlayers = {}
    self.flightData = {}
    self.rankings = {}
    self.startPositions = {}
    self.realtimeRewardsGiven = {}
    self.levelRewardsGiven = {}

    -- 销毁自身
    self:Destroy()

    --gg.log(string.format("比赛 %s 已结束并清理完成", self.instanceId))
end

--- 【简化】传送所有参赛者到复活点（使用基类方法）
function RaceGameMode:_teleportAllPlayersToRespawn()
    return self:TeleportAllPlayersToRespawn()
end

--- 【核心重构】计算并发放奖励，直接使用 LevelType 实例
function RaceGameMode:_calculateAndDistributeRewards()
    if not self.levelType then
        --gg.log("错误: [RaceGameMode] 关卡实例(levelType)为空，无法发放奖励。")
        return
    end

    --gg.log(string.format("信息: [RaceGameMode] 开始计算奖励，参与玩家数: %d", self:_getParticipantCount()))

    -- 【新增】清理已离开玩家的排名数据
    for i = #self.rankings, 1, -1 do
        local uin = self.rankings[i]
        local playerStillInRace = false

        -- 检查玩家是否还在参赛者列表中
        for _, participant in pairs(self.participants) do
            if participant.uin == uin then
                playerStillInRace = true
                break
            end
        end

        -- 如果玩家已不在比赛中，从排名中移除
        if not playerStillInRace then
            table.remove(self.rankings, i)
            if self.flightData then
                self.flightData[uin] = nil
            end
        end
    end

    -- 按照真实排名顺序处理奖励
    for _, uin in ipairs(self.rankings) do
        local flightData = self.flightData[uin]
        if flightData then
            local player = self:GetPlayerByUin(uin)

            if player then
                -- 准备要传递给 LevelType 计算方法的数据
                local playerData = {
                    rank = flightData.rank,
                    distance = flightData.flightDistance,
                    playerName = flightData.name,
                    uin = flightData.uin
                }

                --gg.log(string.format("信息: [RaceGameMode] 开始为玩家 %s (第%d名) 计算奖励...", playerData.playerName, playerData.rank))

                -- 1. 计算原始奖励
                local baseRewards = self.levelType:CalculateBaseRewards(playerData)
                local rankRewardsArray = self.levelType:GetRankRewards(playerData.rank)

                -- 2. 计算玩家所有物品加成
                local bonuses = BonusManager.CalculatePlayerItemBonuses(player)
                gg.log("关卡排名加成计算 ",bonuses )
                -- 3. 应用加成到基础奖励
                local finalBaseRewards = BonusManager.ApplyBonusesToRewards(baseRewards, bonuses)
                --gg.log("奖励加成计算 ",finalBaseRewards )

                -- 4. 应用加成到排名奖励
                local rankRewardsDict = {}
                if rankRewardsArray and #rankRewardsArray > 0 then
                    for _, rewardItem in ipairs(rankRewardsArray) do
                        local itemName = rewardItem["物品"]
                        local amount = rewardItem["数量"]
                        if itemName and amount then
                            rankRewardsDict[itemName] = (rankRewardsDict[itemName] or 0) + amount
                        end
                    end
                end
                local finalRankRewards = BonusManager.ApplyBonusesToRewards(rankRewardsDict, bonuses)

                -- 5. 发放最终奖励
                -- a. 发放基础奖励
                if finalBaseRewards and next(finalBaseRewards) then
                    --gg.log(" -> 开始发放基础奖励...")
                    for itemName, amount in pairs(finalBaseRewards) do
                        if amount > 0 then
                            self:_giveItemToPlayer(player, itemName, amount)
                        end
                    end
                else
                    --gg.log(" -> 无基础奖励可发放。")
                end

                -- b. 发放排名奖励
                if finalRankRewards and next(finalRankRewards) then
                    --gg.log(" -> 开始发放排名奖励...")
                    for itemName, amount in pairs(finalRankRewards) do
                        if amount > 0 then
                            self:_giveItemToPlayer(player, itemName, amount)
                        end
                    end
                else
                    if not (rankRewardsArray and #rankRewardsArray > 0) then
                        --gg.log(string.format(" -> 玩家 %s (第%d名) 无排名奖励可发放。", playerData.playerName, playerData.rank))
                    end
                end
            else
                --gg.log(string.format("警告: [RaceGameMode] 未找到 UIN %d 对应的玩家实例，无法发放奖励。", uin))
            end
        end
    end
end

--- 【新增】给玩家发放物品
---@param player MPlayer
---@param itemName string 物品名称
---@param amount number 物品数量
function RaceGameMode:_giveItemToPlayer(player, itemName, amount)
    if not player or not itemName or amount <= 0 then
        --gg.log(string.format("RaceGameMode: 发放物品失败，参数无效 - player: %s, itemName: %s, amount: %s",tostring(player), tostring(itemName), tostring(amount)))
        return
    end

    --gg.log(string.format("RaceGameMode: 尝试给玩家 %s 发放物品 %s x%d", player.name or "未知", itemName, amount))

    -- 使用统一奖励分发器发放物品
    local success, errorMsg = PlayerRewardDispatcher.DispatchSingleReward(player, "物品", itemName, amount)

    if success then
        --gg.log(string.format("RaceGameMode: 物品发放成功 - %s x%d", itemName, amount))
        -- 向玩家发送奖励通知
        --player:SendHoverText(string.format("获得 %s x%d", itemName, amount))
    else
        --gg.log(string.format("RaceGameMode: 物品发放失败 - %s x%d, 错误: %s", itemName, amount, errorMsg or "未知错误"))
        -- 发送失败提示
        --player:SendHoverText(string.format("获得物品失败: %s x%d", itemName, amount))
    end
end

--- 【新增】启动实时飞行距离追踪
function RaceGameMode:_startFlightDistanceTracking()
    if self.distanceTimer then
        self:RemoveTimer(self.distanceTimer)
    end

    -- 每0.2秒更新一次飞行距离和排名
    self.distanceTimer = self:AddInterval(0.2, function()
        self:_updateFlightDistances()
        self:_updateRankings()
    end)
end

--- 【新增】停止实时飞行距离追踪
function RaceGameMode:_stopFlightDistanceTracking()
    if self.distanceTimer then
        self:RemoveTimer(self.distanceTimer)
        self.distanceTimer = nil
    end
end

--- 【新增】更新所有玩家的飞行距离
function RaceGameMode:_updateFlightDistances()
    -- 只在比赛进行中才更新距离
    if self.state ~= RaceState.RACING then
        return
    end

    for _, player in pairs(self.participants) do
        if player and player.actor and self.flightData[player.uin] then
            local flightData = self.flightData[player.uin]

            -- 只处理未完成的玩家
            if not flightData.isFinished then
                -- 获取当前位置
                local currentPos = player.actor.Position
                if currentPos then
                    flightData.currentPosition = currentPos

                    -- 计算从起始位置到当前位置的距离
                    local startPos = flightData.startPosition
                    local distance = self:_calculateDistance(currentPos, startPos)

                    -- 更新飞行距离（只增不减，取最大值）
                    if distance then
                        local oldDistance = flightData.flightDistance
                        flightData.flightDistance = math.max(flightData.flightDistance, distance)

                        -- 【新增】检查并发放实时奖励
                        if flightData.flightDistance > oldDistance then
                            self:_checkAndGiveRealtimeRewards(player, flightData)
                            self:_checkAndGiveLevelRewards(player, flightData)

                        end
                    end
                end
            end
        end
    end
end

--- 【新增】检查并发放关卡奖励
---@param player MPlayer 玩家实例
---@param flightData FlightPlayerData 玩家飞行数据
function RaceGameMode:_checkAndGiveLevelRewards(player, flightData)
    if not player or not flightData then
        return
    end

    -- 获取当前关卡的关卡奖励配置
    local levelRewardConfigs = self:_getLevelRewardConfigs()
    if not levelRewardConfigs then
        return
    end

    local playerDistance = flightData.flightDistance
    local playerUin = player.uin
    
    -- 确保玩家奖励记录存在
    if not self.levelRewardsGiven[playerUin] then
        self.levelRewardsGiven[playerUin] = {}
    end
    
    local playerRewards = self.levelRewardsGiven[playerUin]

    -- 遍历所有关卡奖励配置
    for uniqueId, rewardNode in pairs(levelRewardConfigs) do
        local triggerDistance = rewardNode["生成的距离配置"] or 0
        
        -- 检查触发条件：距离达到 且 未发放过
        if playerDistance >= triggerDistance and not playerRewards[uniqueId] then
            -- 发放奖励
            local success = self:DistributeLevelReward(player, rewardNode, uniqueId)
            if success then
                -- 记录已发放
                playerRewards[uniqueId] = true
                -- 发送通知
                self:SendLevelRewardNotification(player, rewardNode, uniqueId)
                
                gg.log(string.format("距离奖励发放: 玩家 %s 飞行 %.1f 米，获得奖励 %s", 
                    player.name or playerUin, playerDistance, uniqueId))
            end
        end
    end
end

--- 【新增】获取当前关卡的关卡奖励配置
---@return table<string, LevelNodeRewardItem>|nil 关卡奖励配置映射表
function RaceGameMode:_getLevelRewardConfigs()
    if not self.levelType or not self.levelType.HasSceneConfig or not self.levelType:HasSceneConfig() then
        return nil
    end

    local sceneConfigName = self.levelType:GetSceneConfig()
    if not sceneConfigName then
        return nil
    end

    local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
    local levelRewardConfig = ConfigLoader.GetLevelNodeReward(sceneConfigName)
    if not levelRewardConfig then
        return nil
    end

    -- 返回 _idMap，这是按 uniqueId 索引的奖励节点映射表
    return levelRewardConfig._idMap
end

--- 【新增】根据飞行距离更新排名
function RaceGameMode:_updateRankings()
    -- 创建一个包含所有玩家飞行数据的临时表
    local playerList = {}
    for uin, flightData in pairs(self.flightData) do
        table.insert(playerList, flightData)
    end

    -- 按飞行距离降序排序（距离越远排名越高）
    table.sort(playerList, function(a, b)
        return a.flightDistance > b.flightDistance
    end)

    -- 更新排名和rankings列表
    self.rankings = {}
    for i, flightData in ipairs(playerList) do
        flightData.rank = i
        table.insert(self.rankings, flightData.uin)
    end
end

--- 【新增】获取玩家当前排名信息
---@param uin number 玩家UIN
---@return FlightPlayerData|nil
function RaceGameMode:GetPlayerFlightData(uin)
    return self.flightData[uin]
end

--- 【新增】根据UIN获取玩家实例
---@param uin number
---@return MPlayer|nil
function RaceGameMode:GetPlayerByUin(uin)
    return self.participants[uin]
end

--- 【新增】获取当前排名列表
---@return table<number> 按排名顺序的玩家UIN列表
function RaceGameMode:GetCurrentRankings()
    return self.rankings
end

-- 【移除】_getParticipantCount 和 _getParticipantList 已移至 GameModeBase 中，此处继承使用

--- 【新增】标记玩家为已完成状态
---@param uin number 玩家UIN
function RaceGameMode:_markPlayerFinished(uin)
    if self.flightData[uin] then
        self.flightData[uin].isFinished = true
    end
end

--- 【简化】计算两个Vector3之间的距离
---@param pos1 Vector3 位置1
---@param pos2 Vector3 位置2
---@return number|nil 距离值，失败时返回nil
function RaceGameMode:_calculateDistance(pos1, pos2)
    if not pos1 or not pos2 then
        return nil
    end

    -- 【更新】使用 VectorUtils 模块的距离计算函数
    local success, distance = pcall(function()
        return VectorUtils.Vec.Distance3(pos1, pos2)
    end)

    if success and type(distance) == "number" then
        return distance
    else
        -- 静默处理错误，避免日志干扰
        return nil
    end
end

--- 【新增】检查并发放实时奖励
---@param player MPlayer 玩家实例
---@param flightData FlightPlayerData 玩家飞行数据
function RaceGameMode:_checkAndGiveRealtimeRewards(player, flightData)
    if not self.levelType or not self.levelType:HasRealTimeRewardRules() then
        return
    end

    -- 构建玩家数据用于条件检查
    local playerData = {
        distance = flightData.flightDistance,
        rank = flightData.rank,
        uin = player.uin,
        playerName = player.name,
        speed = flightData.speed or 0,
        time = os.time() - self.raceStartTime
    }

    -- 获取所有实时奖励规则
    local realTimeRewardRules = self.levelType:GetRealTimeRewardRules()

    -- 检查每个实时奖励规则
    for _, rule in ipairs(realTimeRewardRules) do
        -- 如果这个玩家已经获得过这个规则的奖励，跳过
        if self.realtimeRewardsGiven[player.uin] and self.realtimeRewardsGiven[player.uin][rule.ruleId] then
            -- 跳过已发放的奖励规则
        else
            -- 检查是否满足触发条件
            if self.levelType:CheckRealTimeRewardTrigger(rule.triggerCondition, playerData) then
                -- 计算奖励数量
                local rewardAmount = self:_calculateRealtimeRewardAmount(rule.rewardFormula, playerData)

                if rewardAmount and rewardAmount > 0 then
                    -- 发放奖励
                    local success = self:_giveRealtimeReward(player, rule.rewardItem, rewardAmount)

                    if success then
                        -- 标记这个奖励已发放（使用规则ID）
                        if not self.realtimeRewardsGiven[player.uin] then
                            self.realtimeRewardsGiven[player.uin] = {}
                        end
                        self.realtimeRewardsGiven[player.uin][rule.ruleId] = true

                        -- 记录日志（包含规则ID）
                        -- --gg.log(string.format("实时奖励发放成功: 玩家 %s [规则ID:%s] 达到条件 '%s'，获得 %s x%d",
                        --player.name or player.uin, rule.ruleId, rule.triggerCondition, rule.rewardItem, rewardAmount))

                        -- 向玩家发送实时奖励通知
                        --player:SendHoverText(string.format("实时奖励: %s x%d！", rule.rewardItem, rewardAmount))
                    end
                end
            end
        end
    end
end

--- 【新增】计算实时奖励数量
---@param rewardFormula string|number 奖励公式或固定数值
---@param playerData table 玩家数据
---@return number|nil 奖励数量
function RaceGameMode:_calculateRealtimeRewardAmount(rewardFormula, playerData)
    if not rewardFormula then
        return nil
    end

    -- 如果是数字，直接返回
    if type(rewardFormula) == "number" then
        return rewardFormula
    end

    -- 如果是字符串，使用关卡类型的计算方法
    if type(rewardFormula) == "string" then
        return self.levelType:_evaluateFormulaWithCalculator(rewardFormula, playerData)
    end

    return nil
end

--- 【新增】发放实时奖励物品
---@param player MPlayer 玩家实例
---@param itemName string 物品名称
---@param amount number 物品数量（这里是已经通过公式计算的数量，PlayerRewardDispatcher内部还会再次应用加成）
---@return boolean 是否发放成功
function RaceGameMode:_giveRealtimeReward(player, itemName, amount)
    if not player or not itemName or amount <= 0 then
        return false
    end

    -- 计算并应用加成
    local bonuses = BonusManager.CalculatePlayerItemBonuses(player, itemName)
    local itemBonus = bonuses[itemName]
    if itemBonus and (itemBonus.fixed > 0 or itemBonus.percentage > 0) then
        gg.log(string.format("实时奖励将应用加成: 玩家 %s, 物品 %s, 基础数量 %d, 加成情况(固定:+%d, 百分比:+%d%%)",
            player.name or player.uin, itemName, amount, itemBonus.fixed or 0, itemBonus.percentage or 0))
    end
    local finalRewards = BonusManager.ApplyBonusesToRewards({[itemName]=amount}, bonuses)
    local finalAmount = finalRewards[itemName] or amount

    -- 发放已应用加成后的数量
    local success, errorMsg = PlayerRewardDispatcher.DispatchSingleReward(player, "物品", itemName, finalAmount)

    if success then
        --gg.log(string.format("实时奖励发放成功: 玩家 %s 获得 %s x%d", player.name or "未知", itemName, amount))
        return true
    else
        --gg.log(string.format("实时奖励发放失败: 玩家 %s, 物品 %s x%d, 错误: %s", player.name or "未知", itemName, amount, errorMsg or "未知错误"))
        return false
    end
end


--- 【新增】启动比赛界面更新
function RaceGameMode:_startContestUIUpdates()
    if self.contestUpdateTimer then
        self:RemoveTimer(self.contestUpdateTimer)
    end

    --gg.log(string.format("RaceGameMode: 启动比赛界面更新，参赛者数量: %d", self:_getParticipantCount()))

    -- 通知所有玩家显示比赛界面
    self:_broadcastContestUIShow()

    -- 每1秒更新一次比赛界面数据
    self.contestUpdateTimer = self:AddInterval(1, function()
        self:_updateContestUIData()
    end)
end

--- 【新增】停止比赛界面更新
function RaceGameMode:_stopContestUIUpdates()
    if self.contestUpdateTimer then
        self:RemoveTimer(self.contestUpdateTimer)
        self.contestUpdateTimer = nil
    end

    -- 通知所有玩家隐藏比赛界面
    self:_broadcastContestUIHide()
end

--- 【新增】向所有参赛者广播显示比赛界面
function RaceGameMode:_broadcastContestUIShow()
    local raceTime = self.levelType.raceTime or 60
    local eventData = {
        raceTime = raceTime
    }

    RaceGameEventManager.BroadcastRaceEvent(
        self:_getParticipantList(),
        EventPlayerConfig.NOTIFY.RACE_CONTEST_SHOW,
        eventData
    )
end

--- 【新增】向所有参赛者广播隐藏比赛界面
function RaceGameMode:_broadcastContestUIHide()
    RaceGameEventManager.BroadcastRaceEvent(
        self:_getParticipantList(),
        EventPlayerConfig.NOTIFY.RACE_CONTEST_HIDE,
        {}
    )
end


--- 【新增】获取前三名玩家数据（包含头像信息）
---@return table 前三名玩家的详细数据
function RaceGameMode:_getTopThreePlayersData()
    local topThree = {}

    -- 确保排名是最新的
    self:_updateRankings()

    -- 获取前三名的数据
    for i = 1, math.min(3, #self.rankings) do
        local uin = self.rankings[i]
        local flightData = self.flightData[uin]

        if flightData then
            -- 查找对应的玩家实例获取更多信息
            local player = self:GetPlayerByUin(uin)
            if player then
                local playerData = {
                    rank = i,
                    uin = uin,
                    name = flightData.name,
                    flightDistance = flightData.flightDistance,
                    isFinished = flightData.isFinished,
                    userId = player.uin
                }
                table.insert(topThree, playerData)
            end
        end
    end

    return topThree
end

--- 【新增】获取所有玩家的飞行数据
---@return table<table<string, any>> 所有玩家的详细数据
function RaceGameMode:_getAllPlayersFlightData()
    local allPlayers = {}

    -- 确保排名是最新的
    self:_updateRankings()

    for i, uin in ipairs(self.rankings) do
        local flightData = self.flightData[uin]
        if flightData then
            local player = self:GetPlayerByUin(uin)
            if player then
                local playerData = {
                    rank = i,
                    uin = uin,
                    name = flightData.name,
                    flightDistance = flightData.flightDistance,
                    isFinished = flightData.isFinished,
                    userId = player.uin
                }
                allPlayers[#allPlayers+1] = playerData
            end
        end
    end

    return allPlayers
end

--- 【修复】处理迟到加入的玩家（比赛进行中）
---@param player MPlayer 迟到加入的玩家
function RaceGameMode:_handleLateJoinPlayer(player)
    if not player or not player.actor then
        --gg.log("错误: 迟到玩家数据无效")
        return
    end

    self:AddDelay(1, function()
        -- 【修复】传送到开始位置，并获取目标坐标以避免竞态条件
        local teleportSuccess, targetPos = self:_teleportPlayerToStartPosition(player)
        if not teleportSuccess then
            --gg.log(string.format("玩家 %s 传送失败", player.name or player.uin))
            return
        end

        if self.state == RaceState.RACING and player.actor then
            -- 【修复】传入正确的起始坐标进行初始化
            if targetPos then
                self:_initializeLateJoinPlayerState(player, targetPos)

                -- 【修复】传入正确的起始坐标来发射玩家
                self:LaunchPlayer(player, targetPos)
                self:_executeGameStartCommandsForPlayer(player)

                -- 发送界面数据
                self:_sendRaceUIToLateJoinPlayer(player)
                player.actor:StopNavigate()

                --gg.log(string.format("迟到玩家 %s 加入成功", player.name or player.uin))
            end
        end
    end)

end

--- 【新增】初始化迟到加入玩家的比赛状态数据
---@param player MPlayer 迟到加入的玩家
---@param startPos Vector3 玩家的比赛起始位置
function RaceGameMode:_initializeLateJoinPlayerState(player, startPos)
    if not player or not player.actor or not startPos then return end

    local uin = player.uin

    -- 初始化所有必要的数据
    self.flightData[uin] = {
        uin = uin,
        name = player.name or tostring(uin),
        startPosition = startPos,
        currentPosition = startPos,
        flightDistance = 0,
        rank = self:_getParticipantCount(),
        isFinished = false
    }

    self.startPositions[uin] = startPos
    self.realtimeRewardsGiven[uin] = {}
    self.levelRewardsGiven[uin] = {}

    -- 添加到排名列表
    table.insert(self.rankings, uin)

    --gg.log(string.format("已初始化迟到玩家 %s 的状态数据", player.name or uin))
end
--- 【新增】向迟到加入的玩家发送比赛界面数据
---@param player MPlayer 迟到加入的玩家
function RaceGameMode:_sendRaceUIToLateJoinPlayer(player)
    if not player then return end

    -- 发送比赛开始通知
    local raceTime = self.levelType and self.levelType.raceTime or 60
    RaceGameEventManager.SendRaceStartNotification(player, raceTime)

    -- 发送当前比赛状态
    self:AddDelay(0.2, function()
        if self.state == RaceState.RACING then
            self:_updateContestUIData()
        end
    end)
end

--- 【新增】为单个玩家传送到开始位置的辅助方法
---@param player MPlayer 目标玩家
---@return boolean, Vector3|nil #是否传送成功, 目标位置
function RaceGameMode:_teleportPlayerToStartPosition(player)
    if not player or not player.actor then return false, nil end

    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local handler = serverDataMgr.getSceneNodeHandler(self.handlerId)

    if not handler or not handler.teleportNode or not handler.teleportNode.Position then
        --gg.log(string.format("错误: 无法获取传送位置，玩家 %s", player.name or player.uin))
        return false, nil
    end

    local targetPosition = handler.teleportNode.Position
    --gg.log(string.format("正在传送玩家 %s 到 %s", player.name or player.uin, tostring(targetPosition)))

    -- 使用引擎内置 TeleportService
    local TeleportService = game:GetService("TeleportService")
    TeleportService:Teleport(player.actor, targetPosition)

    return true, targetPosition
end
--- 【新增】取消比赛并完全清理实例（用于准备阶段所有玩家离开）
function RaceGameMode:_cancelRaceAndCleanup()
    --gg.log(string.format("取消比赛并清理实例: %s", self.instanceId))

    -- 取消准备倒计时（如果正在进行）
    self:_cancelPrepareCountdown("比赛已取消")

    -- 设置状态为已结束，防止其他逻辑继续执行
    self.state = RaceState.FINISHED

    -- 停止所有定时器
    self:_stopFlightDistanceTracking()
    self:_stopContestUIUpdates()

    -- 通知剩余玩家
    for _, player in pairs(self.participants) do
        if player and player.SendHoverText then
            player:SendHoverText("比赛已取消")
        end
    end

    -- 清理GameModeManager中的记录
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local GameModeManager = serverDataMgr.GameModeManager

    if GameModeManager then
        -- 清理玩家记录
        for _, player in pairs(self.participants) do
            if player then
                GameModeManager.playerModes[player.uin] = nil
                self:StopSceneMusic(player)
            end
        end
        -- 清理实例记录
        GameModeManager.activeModes[self.instanceId] = nil
    end

    -- 清理自身数据
    self:_cleanAllData()

    -- 销毁自身
    self:Destroy()
end

-- 【新增】清理单个玩家数据的辅助方法
function RaceGameMode:_cleanPlayerData(uin)
    -- 从排名列表中移除
    for i, rankUin in ipairs(self.rankings) do
        if rankUin == uin then
            table.remove(self.rankings, i)
            break
        end
    end

    -- 清理所有相关数据
    self.finishedPlayers[uin] = nil
    self.flightData[uin] = nil
    self.startPositions[uin] = nil
    self.realtimeRewardsGiven[uin] = nil
    self.levelRewardsGiven[uin] = nil
end

-- 【新增】清理所有数据的辅助方法
function RaceGameMode:_cleanAllData()
    self.participants = {}
    self.finishedPlayers = {}
    self.flightData = {}
    self.rankings = {}
    self.startPositions = {}
    self.realtimeRewardsGiven = {}
    self.levelRewardsGiven = {}

    -- 清理定时器
    self.prepareTimer = nil
    self.isPreparing = false
    self.prepareStartTime = nil      -- 【新增】清理倒计时开始时间
    self.totalPrepareTime = nil      -- 【新增】清理总倒计时时间
end

--- 【新增】为单个玩家执行游戏开始指令
---@param player MPlayer 目标玩家
function RaceGameMode:_executeGameStartCommandsForPlayer(player)
    if not self.levelType then
        --gg.log("警告: [RaceGameMode] 关卡配置为空，无法执行游戏开始指令")
        return
    end

    local startCommands = self.levelType:GetGameStartCommands()
    if not startCommands or #startCommands == 0 then
        return -- 静默返回，避免日志干扰
    end

    --gg.log(string.format("信息: [RaceGameMode] 为玩家 %s 执行 %d 条游戏开始指令", player.name or player.uin, #startCommands))

    -- 遍历执行每条指令
    for i, command in ipairs(startCommands) do
        if command and type(command) == "string" then
            --gg.log(string.format("信息: [RaceGameMode] 为玩家 %s 执行游戏开始指令 %d: %s", player.name or player.uin, i, command))
            self:_executeCommandForPlayer(command, "游戏开始", player)
        end
    end
end



--- 【新增】执行游戏结算指令
function RaceGameMode:_executeGameEndCommands()
    if not self.levelType then
        --gg.log("警告: [RaceGameMode] 关卡配置为空，无法执行游戏结算指令")
        return
    end

    local endCommands = self.levelType:GetGameEndCommands()
    if not endCommands or #endCommands == 0 then
        --gg.log("信息: [RaceGameMode] 该关卡没有配置游戏结算指令")
        return
    end

    --gg.log(string.format("信息: [RaceGameMode] 开始执行 %d 条游戏结算指令", #endCommands))

    -- 遍历执行每条指令，为所有参赛玩家执行
    for i, command in ipairs(endCommands) do
        if command and type(command) == "string" then
            --gg.log(string.format("信息: [RaceGameMode] 执行游戏结算指令 %d: %s", i, command))

            -- 为所有参赛玩家执行结算指令
            for _, player in pairs(self.participants) do
                if player then
                    self:_executeCommandForPlayer(command, "游戏结算", player)
                end
            end
        end
    end
end

--- 【新增】只为单个玩家执行游戏结算指令
---@param player MPlayer 目标玩家
function RaceGameMode:_executeGameEndCommandsForPlayer(player)
    if not self.levelType or not player then
        return
    end

    local endCommands = self.levelType:GetGameEndCommands()
    if not endCommands or #endCommands == 0 then
        return
    end

    for _, command in ipairs(endCommands) do
        if command and type(command) == "string" then
            self:_executeCommandForPlayer(command, "游戏结算", player)
        end
    end
end

--- 【新增】为单个玩家执行单条指令的辅助方法
---@param command string 指令字符串
---@param commandType string 指令类型（用于日志标识）
---@param player MPlayer 目标玩家
function RaceGameMode:_executeCommandForPlayer(command, commandType, player)
    if not command or type(command) ~= "string" then
        --gg.log(string.format("警告: [RaceGameMode] 无效的%s指令: %s", commandType, tostring(command)))
        return
    end

    if not player then
        --gg.log(string.format("警告: [RaceGameMode] 目标玩家为空，无法执行%s指令", commandType))
        return
    end

    -- 使用现有的CommandManager执行指令
    local CommandManager = require(ServerStorage.CommandSys.MCommandMgr) ---@type CommandManager

    local success = CommandManager.ExecuteCommand(command, player, true) -- silent = true 避免重复日志
end

function RaceGameMode:_updateContestUIData()
    if self.state ~= RaceState.RACING then
        return
    end

    -- 计算当前时间和剩余时间
    local currentTime = os.time()
    local elapsedTime = currentTime - self.raceStartTime
    local raceTime = self.levelType.raceTime or 60
    local remainingTime = math.max(0, raceTime - elapsedTime)

    -- 【核心修复】时间到了就结束比赛
    if remainingTime <= 0 then
        --gg.log(string.format("比赛 %s 时间到期，自动结束", self.instanceId))
        self:End()
        return
    end

    -- 正常的界面数据更新
    local topThreeRankings = self:_getTopThreePlayersData()
    local allPlayersData = self:_getAllPlayersFlightData()

    local eventData = {
        raceTime = raceTime,
        elapsedTime = elapsedTime,
        remainingTime = remainingTime,
        topThree = topThreeRankings,
        allPlayersData = allPlayersData,
        totalPlayers = self:_getParticipantCount()
    }

    RaceGameEventManager.BroadcastRaceEvent(
        self:_getParticipantList(),
        EventPlayerConfig.NOTIFY.RACE_CONTEST_UPDATE,
        eventData
    )
end

return RaceGameMode
