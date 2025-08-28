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
---@field distanceTimer Timer 距离计算定时器
---@field startPositions table<number, Vector3> 玩家起始位置记录 (uin -> Vector3)
---@field raceStartTime number 比赛开始时间戳
---@field contestUpdateTimer Timer 比赛界面更新定时器
---@field realtimeRewardsGiven table<number, table<string, boolean>> 实时奖励发放记录 (uin -> {ruleId -> true})
---@field levelRewardsGiven table<number, table<string, boolean>> 关卡奖励发放记录 (uin -> {uniqueId -> true})
local RaceGameMode = ClassMgr.Class("RaceGameMode", GameModeBase)

-- 比赛状态
local RaceState = {
    WAITING = "WAITING",     -- 等待玩家加入
    RACING = "RACING",       -- 比赛进行中
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
    self.participants = {} -- 存放所有参赛玩家的table, 使用数组形式
    self.levelType = levelType -- 存储完整的LevelType实例

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

--- 当有玩家进入此游戏模式时调用
---@param player MPlayer
function RaceGameMode:OnPlayerEnter(player)
    -- 【核心修正】检查玩家是否已在比赛中，防止因触发器抖动等问题导致重复加入
    for _, p in ipairs(self.participants) do
        if p.uin == player.uin then
            return -- 如果已存在，则直接返回，不执行任何操作
        end
    end

    -- 而比赛模式需要一个有序的列表来决定排名
    table.insert(self.participants, player)

    -- 如果是第一个加入的玩家，可以启动一个定时器开始比赛
    if #self.participants == 1 then
        self:Start()
    elseif self.state == RaceState.RACING then
        -- 【新增】比赛进行中：立即传送新玩家到开始位置并发射
        --gg.log(string.format("比赛进行中，新玩家 %s 加入，立即传送并发射", player.name or player.uin))
        self:_handleLateJoinPlayer(player)
    end

    -- 【新增】初始化玩家的关卡奖励发放记录
    if not self.levelRewardsGiven[player.uin] then
        self.levelRewardsGiven[player.uin] = {}
    end
    --gg.log(string.format("玩家 %s 加入比赛，关卡奖励记录已初始化", player.name or player.uin))
end

--- 当有玩家离开此游戏模式时调用
--- (重写父类方法，因为这里 participants 是数组)
---@param player MPlayer
function RaceGameMode:OnPlayerLeave(player)
    if not player then return end

    -- 从参赛者列表中移除玩家
    for i, p in ipairs(self.participants) do
        if p.uin == player.uin then
            table.remove(self.participants, i)
            break -- 找到并移除后即可退出循环
        end
    end
    
    -- 【新增】清理玩家相关的比赛数据
    if self.finishedPlayers then
        self.finishedPlayers[player.uin] = nil
    end
    
    if self.flightData then
        self.flightData[player.uin] = nil
    end
    
    if self.startPositions then
        self.startPositions[player.uin] = nil
    end
    
    -- 【新增】清理玩家的实时奖励发放记录
    if self.realtimeRewardsGiven then
        self.realtimeRewardsGiven[player.uin] = nil
    end

    -- 【新增】清理玩家的关卡奖励发放记录
    if self.levelRewardsGiven and self.levelRewardsGiven[player.uin] then
        self.levelRewardsGiven[player.uin] = nil
    end
    --gg.log(string.format("玩家 %s 离开比赛，关卡奖励记录已清理", player.name or player.uin))
    
    -- 【核心优化】处理玩家离开后的比赛状态
    if self.state == "WAITING" then
        -- 准备阶段：如果所有玩家都离开了，直接清理比赛实例
        if #self.participants == 0 then
            ----gg.log(string.format("比赛实例 %s：所有玩家在准备阶段离开，取消比赛并清理实例。", self.instanceId))
            self:_cancelRaceAndCleanup()
            return
        end
    elseif self.state == "RACING" then
        -- 比赛进行中：如果剩余玩家不足，结束比赛
        if #self.participants <= 1 then
            ----gg.log(string.format("比赛实例 %s：参赛玩家不足，提前结束比赛。", self.instanceId))
            self:End()
            return
        end
    end
end

--- 【新增】处理关卡奖励节点触发
---@param player MPlayer 触发的玩家
---@param eventData table 事件数据
function RaceGameMode:HandleLevelRewardTrigger(player, eventData)
    if not player or not eventData then return end

    local uniqueId = eventData.uniqueId
    local configName = eventData.configName
    local mapName = eventData.mapName
    local rewardType = eventData.rewardType or ""
    local itemType = eventData.itemType or ""
    local itemCount = eventData.itemCount or 0
    local rewardCondition = eventData.rewardCondition or ""


    if not uniqueId or not configName then
        return
    end

    -- 防重复：检查是否已发放
    if self.levelRewardsGiven[player.uin] and self.levelRewardsGiven[player.uin][uniqueId] then
        --gg.log(string.format("玩家 %s 已获得过关卡奖励 %s，跳过发放", player.name or player.uin, tostring(uniqueId)))
        return
    end

    -- 获取关卡奖励配置
    local rewardConfig = self:GetLevelRewardConfig(configName, uniqueId)
    if not rewardConfig then
        --gg.log(string.format("找不到关卡奖励配置 - 配置名:%s, ID:%s", tostring(configName), tostring(uniqueId)))
        return
    end

    -- 发放奖励
    local success = self:DistributeLevelReward(player, rewardConfig, uniqueId)
    if success then
        if not self.levelRewardsGiven[player.uin] then
            self.levelRewardsGiven[player.uin] = {}
        end
        self.levelRewardsGiven[player.uin][uniqueId] = true
        --gg.log(string.format("关卡奖励发放成功 - 玩家:%s, ID:%s", player.name or player.uin, tostring(uniqueId)))
    else
        --gg.log(string.format("关卡奖励发放失败 - 玩家:%s, ID:%s", player.name or player.uin, tostring(uniqueId)))
    end
end

--- 【新增】获取关卡奖励配置
---@param configName string 配置名称
---@param uniqueId string 唯一ID
---@return table|nil 奖励配置项
function RaceGameMode:GetLevelRewardConfig(configName, uniqueId)
    if not self.levelType or not self.levelType.HasSceneConfig or not self.levelType:HasSceneConfig() then
        --gg.log("当前关卡没有场景配置")
        return nil
    end

    local sceneConfigName = self.levelType.GetSceneConfig and self.levelType:GetSceneConfig() or nil
    if sceneConfigName and configName and sceneConfigName ~= configName then
        --gg.log(string.format("场景配置名称不匹配 - 期望:%s, 实际:%s", tostring(sceneConfigName), tostring(configName)))
        return nil
    end

    local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
    local levelRewardConfig = ConfigLoader.GetLevelNodeReward and ConfigLoader.GetLevelNodeReward(configName) or nil
    if not levelRewardConfig then
        --gg.log(string.format("找不到关卡奖励配置:%s", tostring(configName)))
        return nil
    end

    if levelRewardConfig.GetRewardNodeById then
        local rewardNode = levelRewardConfig:GetRewardNodeById(uniqueId)
        if not rewardNode then
            --gg.log(string.format("在配置 %s 中找不到ID为 %s 的奖励节点", tostring(configName), tostring(uniqueId)))
            return nil
        end
        return rewardNode
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
    
    -- 3. 应用加成到奖励
    local finalRewards = BonusManager.ApplyBonusesToRewards(originalRewards, bonuses)
    
    -- 4. 获取应用加成后的最终数量
    finalItemCount = finalRewards[itemType] or itemCount
    
    -- 记录加成计算日志
    if finalItemCount ~= itemCount then
        -- gg.log(string.format("关卡奖励加成计算: 玩家 %s, 物品 %s, 原始数量: %d, 加成后数量: %d", 
        --     player.name or player.uin, itemType, itemCount, finalItemCount))
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

    local itemType = rewardConfig["物品类型"] or ""
    local itemCount = rewardConfig["物品数量"] or 0
    local rewardType = rewardConfig["奖励类型"] or ""

    if gg.network_channel then
        local eventData = {
            cmd = "LevelRewardReceived",
            uniqueId = uniqueId,
            rewardType = rewardType,
            itemType = itemType,
            itemCount = itemCount,
            message = string.format("获得关卡奖励: %s x%d", tostring(itemType), tonumber(itemCount) or 0),
            timestamp = os.time()
        }
        gg.network_channel:fireClient(player.uin, eventData)
        --gg.log(string.format("已向玩家 %s 发送关卡奖励通知", player.name or player.uin))
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
---@param player MPlayer
function RaceGameMode:LaunchPlayer(player)
    if not player or not player.actor then
        return
    end

    -- 记录玩家起始位置，用于计算飞行距离
    if player.actor and player.actor.Position then
        self.startPositions[player.uin] = player.actor.Position
        -- 初始化飞行数据
        self.flightData[player.uin] = {
            uin = player.uin,
            name = player.name,
            startPosition = player.actor.Position,
            currentPosition = player.actor.Position,
            flightDistance = 0,
            rank = #self.participants, -- 初始排名为最后一名
            isFinished = false
        }
        
        -- 【新增】初始化玩家的实时奖励发放记录
        self.realtimeRewardsGiven[player.uin] = {}
    end

    -- 【规范化】从配置中读取事件名称和参数，避免硬编码
    local eventName = EventPlayerConfig.NOTIFY.LAUNCH_PLAYER
    local launchParams = EventPlayerConfig.GetActionParams(eventName)

    -- 获取关卡配置的比赛时长
    local raceTime = self.levelType.raceTime or 60

    -- 克隆参数表（launchParams 可能为 nil，需先判空）
    local clonedParams = {}
    if type(launchParams) == "table" then
        clonedParams = gg.clone(launchParams) or {}
    end
    local eventData = clonedParams
    eventData.cmd = eventName
    eventData.gameMode = EventPlayerConfig.GAME_MODES.RACE_GAME
    eventData.gravity = 0
    eventData.recoveryDelay = raceTime  -- 传送关卡配置的比赛时长作为客户端的恢复延迟

    -- 【新增】获取并添加重生点位置
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local handler = serverDataMgr.getSceneNodeHandler(self.handlerId)
    if handler and handler.respawnNode and handler.respawnNode.Position then
        eventData.respawnPosition = handler.respawnNode.Position
    else
        --gg.log("警告: [RaceGameMode] 无法为比赛实例 " .. self.instanceId .. " 找到有效的重生点位置。")
    end


    eventData.variableData = player.variableSystem:GetAllVariables()
    --gg.log("飞行比赛事件",eventData)
    -- 【核心改造】通过网络通道向指定客户端发送事件
    gg.network_channel:fireClient(player.uin, eventData)
    
    
    -- 【新增】为当前发射的玩家执行游戏开始指令
    self:_executeGameStartCommandsForPlayer(player)
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
    local rankInfo = flightData and string.format("第%d名，飞行距离%.1f米", flightData.rank, flightData.flightDistance) or "排名计算中"

    --player:SendHoverText(string.format("已落地！%s 等待其他玩家...", rankInfo))

    -- 使用正确的计数值检查是否所有人都已完成
    if finishedCount >= #self.participants then
        self:End()
    end
end



--- 开始比赛
function RaceGameMode:Start()
    if self.state ~= RaceState.WAITING then return end

    -- 从LevelType实例获取玩法规则
    local prepareTime = self.levelType.prepareTime or 10

    -- 【新增】立即向所有参赛者发送准备倒计时通知
    RaceGameEventManager.BroadcastPrepareCountdown(self.participants, prepareTime)

    -- 准备阶段
    self:AddDelay(prepareTime, function()
        if self.state == RaceState.WAITING then
            self.state = RaceState.RACING
            --gg.log("比赛开始准备！")

            -- 1. 先传送所有玩家到传送节点
            local teleportSuccess = self:TeleportAllPlayersToStartPosition()
            --gg.log("玩家传送结束",teleportSuccess)
            if teleportSuccess then
                -- 2. 给传送一点时间完成，然后发射玩家
                self:AddDelay(0.5, function()
                    --gg.log("传送完成，开始发射玩家！")
                    for _, player in ipairs(self.participants) do
                        self:LaunchPlayer(player)
                    end
                    
                    -- 启动实时飞行距离计算
                    self:_startFlightDistanceTracking()
                    -- 启动比赛界面更新
                    self:_startContestUIUpdates()
                    -- 记录比赛开始时间
                    self.raceStartTime = os.time()
                end)
            else
                --gg.log("传送失败，比赛无法开始！")
            end
        end
    end)
end

--- 结束比赛
function RaceGameMode:End()
    if self.state ~= RaceState.RACING then return end
    self.state = RaceState.FINISHED

    -- 先停止追踪和界面更新
    self:_stopFlightDistanceTracking()
    self:_stopContestUIUpdates()
    
    -- 执行游戏结算指令
    self:_executeGameEndCommands()
    
    -- 最终排名确认（基于实际飞行距离）
    self:_updateRankings()
    
    -- 结算基础奖励和排名奖励
    self:_calculateAndDistributeRewards()

    -- 打印基础的结算信息，并通知玩家（按真实排名顺序）
    for _, uin in ipairs(self.rankings) do
        local flightData = self.flightData[uin]
        if flightData then
            local rankText = string.format("第 %d 名: %s (%.1f米)",
                                          flightData.rank, flightData.name, flightData.flightDistance)

            -- 找到对应的玩家实例发送消息
            for _, player in ipairs(self.participants) do
                if player.uin == uin then
                    player:SendHoverText(rankText)
                    break
                end
            end
        end
    end

    -- 【修复】直接清理 GameModeManager 中的玩家记录，避免循环调用
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local GameModeManager = serverDataMgr.GameModeManager
    
    if GameModeManager then
        -- 直接清理玩家模式记录，避免调用 OnPlayerLeave 造成的循环
        for _, player in ipairs(self.participants) do
            if player then
                GameModeManager.playerModes[player.uin] = nil
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

    --gg.log(string.format("信息: [RaceGameMode] 开始计算奖励，参与玩家数: %d", #self.participants))

    -- 【新增】清理已离开玩家的排名数据
    for i = #self.rankings, 1, -1 do
        local uin = self.rankings[i]
        local playerStillInRace = false
        
        -- 检查玩家是否还在参赛者列表中
        for _, participant in ipairs(self.participants) do
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
                --gg.log("奖励加成计算 ",bonuses )
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

    -- 每0.5秒更新一次飞行距离和排名
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

    for _, player in ipairs(self.participants) do
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
                        end
                    end
                end
            end
        end
    end
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
    for _, p in ipairs(self.participants) do
        if p.uin == uin then
            return p
        end
    end
    return nil
end

--- 【新增】获取当前排名列表
---@return table<number> 按排名顺序的玩家UIN列表
function RaceGameMode:GetCurrentRankings()
    return self.rankings
end

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
                        --gg.log(string.format("实时奖励发放成功: 玩家 %s [规则ID:%s] 达到条件 '%s'，获得 %s x%d", 
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

    -- 【新增】记录实时奖励的加成情况（用于调试）
    local bonuses = BonusManager.CalculatePlayerItemBonuses(player)
    local itemBonus = bonuses[itemName]
    if itemBonus and (itemBonus.fixed > 0 or itemBonus.percentage > 0) then
        gg.log(string.format("实时奖励将应用加成: 玩家 %s, 物品 %s, 基础数量 %d, 加成情况(固定:+%d, 百分比:+%d%%)", 
            player.name or player.uin, itemName, amount, itemBonus.fixed or 0, itemBonus.percentage or 0))
    end

    -- 使用统一奖励分发器发放物品（内部会自动应用加成）
    local success, errorMsg = PlayerRewardDispatcher.DispatchSingleReward(player, "物品", itemName, amount)
    
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

    --gg.log(string.format("RaceGameMode: 启动比赛界面更新，参赛者数量: %d", #self.participants))

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
        self.participants, 
        EventPlayerConfig.NOTIFY.RACE_CONTEST_SHOW, 
        eventData
    )
end

--- 【新增】向所有参赛者广播隐藏比赛界面
function RaceGameMode:_broadcastContestUIHide()
    RaceGameEventManager.BroadcastRaceEvent(
        self.participants, 
        EventPlayerConfig.NOTIFY.RACE_CONTEST_HIDE,
        {}
    )
end

--- 【新增】更新比赛界面数据
function RaceGameMode:_updateContestUIData()
    if self.state ~= RaceState.RACING then
        return
    end

    -- 计算当前时间和剩余时间
    local currentTime = os.time()
    local elapsedTime = currentTime - self.raceStartTime
    local raceTime = self.levelType.raceTime or 60
    local remainingTime = math.max(0, raceTime - elapsedTime)

    -- 获取前三名玩家数据
    local topThreeRankings = self:_getTopThreePlayersData()
    -- 【新增】获取所有玩家数据
    local allPlayersData = self:_getAllPlayersFlightData()

    local eventData = {
        raceTime = raceTime,
        elapsedTime = elapsedTime,
        remainingTime = remainingTime,
        topThree = topThreeRankings,
        allPlayersData = allPlayersData, -- 【新增】
        totalPlayers = #self.participants
    }

    -- 使用RaceGameEventManager向所有参赛者发送更新数据
    RaceGameEventManager.BroadcastRaceEvent(
        self.participants, 
        EventPlayerConfig.NOTIFY.RACE_CONTEST_UPDATE, 
        eventData
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

--- 【新增】处理迟到加入的玩家（比赛进行中）
---@param player MPlayer 迟到加入的玩家
function RaceGameMode:_handleLateJoinPlayer(player)
    if not player or not player.actor then
        --gg.log("错误: [RaceGameMode] 迟到玩家数据无效，无法处理")
        return
    end

    -- 1. 立即传送玩家到比赛开始位置
    local teleportSuccess = self:_teleportPlayerToStartPosition(player)
    if not teleportSuccess then
        --gg.log(string.format("警告: [RaceGameMode] 玩家 %s 传送失败，无法参与比赛", player.name or player.uin))
        return
    end

    -- 2. 给传送一点时间完成，然后发射玩家
    self:AddDelay(0.5, function()
        if self.state == RaceState.RACING and player.actor then
            --gg.log(string.format("迟到玩家 %s 传送完成，开始发射", player.name or player.uin))
            self:LaunchPlayer(player)
            
            -- 3. 通知其他玩家有新玩家加入
            self:_notifyOtherPlayersNewPlayerJoined(player)
        end
    end)
end

--- 【新增】传送单个玩家到比赛开始位置
---@param player MPlayer
---@return boolean 是否成功传送
function RaceGameMode:_teleportPlayerToStartPosition(player)
    if not player or not player.actor then
        return false
    end

    -- 通过handlerId获取场景处理器
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local handler = serverDataMgr.getSceneNodeHandler(self.handlerId)
    
    if not handler or not handler.teleportNode or not handler.teleportNode.Position then
        --gg.log("错误: [RaceGameMode] 无法找到有效的传送节点位置")
        return false
    end

    local targetPosition = handler.teleportNode.Position
    local TeleportService = game:GetService('TeleportService')
    
    -- 执行传送
    TeleportService:Teleport(player.actor, targetPosition)
    --gg.log(string.format("玩家 %s 已传送到比赛开始位置", player.name or player.uin))
    
    return true
end

--- 【新增】通知其他玩家有新玩家加入
---@param newPlayer MPlayer 新加入的玩家
function RaceGameMode:_notifyOtherPlayersNewPlayerJoined(newPlayer)
    if not newPlayer then return end
    
    -- 向其他参赛者发送新玩家加入通知
    for _, player in ipairs(self.participants) do
        if player.uin ~= newPlayer.uin then
            --player:SendHoverText(string.format("新玩家 %s 加入了比赛！", newPlayer.name or newPlayer.uin))
        end
    end
end

--- 【新增】取消比赛并完全清理实例（用于准备阶段所有玩家离开）
function RaceGameMode:_cancelRaceAndCleanup()
    -- 【新增】向剩余玩家发送停止倒计时事件（如果还有的话）
    if #self.participants > 0 then
        local RaceGameEventManager = require(ServerStorage.GameModes.Modes.RaceGameEventManager) ---@type RaceGameEventManager
        RaceGameEventManager.BroadcastStopPrepareCountdown(self.participants, "比赛已取消")
    end
    
    -- 设置状态为已结束，防止其他逻辑继续执行
    self.state = RaceState.FINISHED
    
    -- 停止所有定时器
    self:_stopFlightDistanceTracking()
    self:_stopContestUIUpdates()
    
    -- 清理所有数据
    self.participants = {}
    self.finishedPlayers = {}
    self.flightData = {}
    self.rankings = {}
    self.startPositions = {}
    self.realtimeRewardsGiven = {}
    
    -- 通知GameModeManager清理此实例
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local GameModeManager = serverDataMgr.GameModeManager  ---@type GameModeManager
    
    if GameModeManager and GameModeManager.activeModes then
        GameModeManager.activeModes[self.instanceId] = nil
        ----gg.log(string.format("比赛实例 %s 已被取消并从GameModeManager中移除。", self.instanceId))
    end
    
    -- 清理自身资源
    self:Destroy()
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
            for _, player in ipairs(self.participants) do
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




return RaceGameMode
