-- RankingMgr.lua
-- 排行榜功能管理器（静态类）
-- 负责缓存在线排行榜实例并处理业务逻辑

local game = game
local pairs = pairs
local os = os
local SandboxNode = SandboxNode

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local serverDataMgr = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
local RankingConfig = require(MainStorage.Code.Common.Config.RankingConfig) ---@type RankingConfig

-- 引入相关系统
local Ranking = require(ServerStorage.MSystems.Ranking.Ranking) ---@type Ranking
local RankingCloudDataMgr = require(ServerStorage.MSystems.Ranking.RankingCloudDataMgr) ---@type RankingCloudDataMgr
local MPlayer = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer

---@class RankingMgr
local RankingMgr = {}

-- 排行榜实例缓存 {排行榜类型 = Ranking实例}
local server_ranking_instances = {} ---@type table<string, Ranking>

-- 定时器相关
local lastMaintenanceTime = 0
local maintenanceInterval = 300 -- 5分钟执行一次维护

--- 获取排行榜实例
---@param rankType string 排行榜类型
---@return Ranking|nil 排行榜实例
function RankingMgr.GetRankingInstance(rankType)
    if not rankType or type(rankType) ~= "string" then
        return nil
    end
    
    return server_ranking_instances[rankType]
end

--- 获取或创建排行榜实例
---@param rankType string 排行榜类型
---@return Ranking|nil 排行榜实例
function RankingMgr.GetOrCreateRanking(rankType)
    if not rankType or type(rankType) ~= "string" then
        return nil
    end
    
    -- 检查缓存中是否已存在
    local rankingInstance = server_ranking_instances[rankType]
    if rankingInstance then
        return rankingInstance
    end
    
    -- 验证排行榜类型是否支持
    if not RankingCloudDataMgr.ValidateRankingType(rankType) then
        return nil
    end
    
    -- 创建新的排行榜实例
    rankingInstance = Ranking.New(rankType)
    if not rankingInstance then
        return nil
    end
    
    -- 初始化排行榜
    local success = rankingInstance:Initialize()
    if not success then
        return nil
    end
    
    -- 缓存实例
    server_ranking_instances[rankType] = rankingInstance
    
    return rankingInstance
end

--- 更新玩家分数（使用安全更新）
---@param uin number 玩家UIN
---@param rankType string 排行榜类型
---@param playerName string 玩家名称
---@param score number 分数
---@param forceUpdate boolean|nil 是否强制更新
---@return boolean 是否成功
function RankingMgr.UpdatePlayerScore(uin, rankType, playerName, score, forceUpdate)
    if not uin or not rankType or not playerName or not score then
        return false
    end
    
    if type(uin) ~= "number" or type(score) ~= "number" then
        return false
    end
    
    -- 获取或创建排行榜实例
    local rankingInstance = RankingMgr.GetOrCreateRanking(rankType)
    if not rankingInstance then
        return false
    end
    
    -- 获取旧排名（用于变化通知）
    local oldRankInfo = rankingInstance:GetPlayerRank(uin,playerName)
    local oldRank = oldRankInfo.rank or -1
    
    -- 使用安全更新分数
    local success, oldScore, newScore = RankingCloudDataMgr.SafeUpdatePlayerScore(
        rankType, tostring(uin), playerName, score, forceUpdate
    )
    
    if not success then
        return false
    end
    
    -- 获取新排名
    local newRankInfo = rankingInstance:GetPlayerRank(uin, playerName)
    local newRank = newRankInfo.rank or -1
    
    -- 如果排名发生变化，触发通知
    if oldRank ~= newRank then
        RankingMgr.NotifyRankChange(uin, rankType, playerName, oldRank, newRank, newScore)
    end
    
    return true
end

--- 异步更新玩家分数（使用安全更新）
---@param uin number 玩家UIN
---@param rankType string 排行榜类型
---@param playerName string 玩家名称
---@param score number 分数
---@param forceUpdate boolean|nil 是否强制更新
---@param callback function|nil 回调函数
function RankingMgr.UpdatePlayerScoreAsync(uin, rankType, playerName, score, forceUpdate, callback)
    if not uin or not rankType or not playerName or not score then
        ----gg.log("异步更新玩家分数失败：参数无效", uin, rankType, playerName, score)
        if callback then callback(false) end
        return
    end
    
    -- 获取或创建排行榜实例
    local rankingInstance = RankingMgr.GetOrCreateRanking(rankType)
    if not rankingInstance then
        if callback then callback(false) end
        return
    end
    
    -- 获取旧排名
    local oldRankInfo = rankingInstance:GetPlayerRank(uin)
    local oldRank = oldRankInfo.rank or -1
    
    -- 异步安全更新分数
    RankingCloudDataMgr.SafeUpdatePlayerScoreAsync(
        rankType, tostring(uin), playerName, score, forceUpdate,
        function(success, oldScore, newScore)
            if success then
                -- 获取新排名并触发通知
                local newRankInfo = rankingInstance:GetPlayerRank(uin)
                local newRank = newRankInfo.rank or -1
                
                if oldRank ~= newRank then
                    RankingMgr.NotifyRankChange(uin, rankType, playerName, oldRank, newRank, newScore)
                end
                
                if oldScore ~= newScore then
                    ----gg.log("异步更新玩家分数成功", uin, rankType, playerName, oldScore, "->", newScore, "排名:", newRank)
                end
            else
                if newScore == oldScore then
                    -- 分数没有变化，这是正常的
                else
                    ----gg.log("异步更新玩家分数失败", uin, rankType, playerName, score)
                end
            end
            
            if callback then
                callback(success)
            end
        end
    )
end

--- 获取排行榜列表
---@param rankType string 排行榜类型
---@param startRank number 起始排名
---@param count number 获取数量
---@return table 排行榜数据
function RankingMgr.GetRankingList(rankType, startRank, count)
    if not rankType then
        return {}
    end
    
    -- 参数默认值和验证
    startRank = startRank or 1
    count = count or 10
    
    if startRank <= 0 or count <= 0 or count > 100 then
        return {}
    end
    
    -- 获取或创建排行榜实例
    local rankingInstance = RankingMgr.GetOrCreateRanking(rankType)
    if not rankingInstance then
        return {}
    end
    
    -- 获取排行榜数据
    local rankingList = rankingInstance:GetRankingList(startRank, count)
    
    return rankingList
end

--- 获取玩家排名信息
---@param uin number 玩家UIN
---@param rankType string 排行榜类型
---@return table 排名信息 {rank: number, score: number, playerName: string}
function RankingMgr.GetPlayerRank(uin, rankType)
    if not uin or not rankType then
        return {rank = -1, score = 0, playerName = ""}
    end
    
    -- 获取或创建排行榜实例
    local rankingInstance = RankingMgr.GetOrCreateRanking(rankType)
    if not rankingInstance then
        return {rank = -1, score = 0, playerName = ""}
    end
    
    -- 获取玩家排名信息
    local rankInfo = rankingInstance:GetPlayerRank(uin)
    
    return rankInfo
end

--- 刷新排行榜
---@param rankType string 排行榜类型
---@return boolean 是否成功
function RankingMgr.RefreshRanking(rankType)
    if not rankType then
        return false
    end
    
    local rankingInstance = server_ranking_instances[rankType]
    if not rankingInstance then
        return false
    end
    
    -- CloudKVStore是实时的，这里主要是标记刷新状态
    local success = rankingInstance:Refresh()
    
    return success
end

--- 清空排行榜
---@param rankType string 排行榜类型
---@return boolean 是否成功
function RankingMgr.ClearRanking(rankType)
    if not rankType then
        return false
    end
    
    -- 获取或创建排行榜实例
    local rankingInstance = RankingMgr.GetOrCreateRanking(rankType)
    if not rankingInstance then
        return false
    end
    
    -- 清空排行榜数据
    local success = rankingInstance:ClearRanking()
    
    return success
end

--- 移除玩家数据
---@param uin number 玩家UIN
---@param rankType string 排行榜类型
---@return boolean 是否成功
function RankingMgr.RemovePlayer(uin, rankType)
    if not uin or not rankType then
        return false
    end
    
    local rankingInstance = server_ranking_instances[rankType]
    if not rankingInstance then
        return false
    end
    
    -- 移除玩家数据
    local success = rankingInstance:RemovePlayer(uin)
    
    return success
end

--- 获取所有支持的排行榜类型
---@return table 排行榜类型配置列表
function RankingMgr.GetAllRankingTypes()
    local allTypes = RankingCloudDataMgr.GetAllRankingTypes()
    local result = {}
    
    for _, rankType in pairs(allTypes) do
        local config = RankingCloudDataMgr.GetRankingConfig(rankType)
        if config then
            table.insert(result, {
                rankType = rankType,
                name = config.name,
                displayName = config.displayName,
                maxDisplayCount = config.maxDisplayCount,
                resetType = config.resetType
            })
        end
    end
    
    return result
end

--- 批量更新多个玩家分数（使用安全更新）
---@param updates table 更新数据列表 {{uin, rankType, playerName, score}, ...}
---@param forceUpdate boolean|nil 是否强制更新
---@return number 成功更新的数量
function RankingMgr.BatchUpdatePlayerScores(updates, forceUpdate)
    if not updates or type(updates) ~= "table" then
        return 0
    end
    
    -- 按排行榜类型分组更新数据
    local updatesByRankType = {}
    
    for _, updateData in pairs(updates) do
        if updateData and type(updateData) == "table" then
            local uin = updateData.uin or updateData[1]
            local rankType = updateData.rankType or updateData[2]
            local playerName = updateData.playerName or updateData[3]
            local score = updateData.score or updateData[4]
            
            if uin and rankType and playerName and score then
                if not updatesByRankType[rankType] then
                    updatesByRankType[rankType] = {}
                end
                table.insert(updatesByRankType[rankType], {uin, playerName, score})
            end
        end
    end
    
    local totalSuccessCount = 0
    
    -- 按排行榜类型批量更新
    for rankType, typeUpdates in pairs(updatesByRankType) do
        local successCount, results = RankingCloudDataMgr.BatchSafeUpdatePlayerScore(rankType, typeUpdates, forceUpdate)
        totalSuccessCount = totalSuccessCount + successCount
        
        -- 处理排名变化通知
        for _, result in pairs(results) do
            if result.success and result.scoreChanged then
                -- 获取排行榜实例来查询排名
                local rankingInstance = RankingMgr.GetOrCreateRanking(rankType)
                if rankingInstance then
                    local newRankInfo = rankingInstance:GetPlayerRank(result.uin)
                    local newRank = newRankInfo.rank or -1
                    
                    -- 这里简化处理，假设旧排名为-1（因为批量更新时难以高效获取所有玩家的旧排名）
                    RankingMgr.NotifyRankChange(result.uin, rankType, result.playerName, -1, newRank, result.newScore)
                end
            end
        end
    end
    
    return totalSuccessCount
end

--- 获取排行榜统计信息
---@param rankType string 排行榜类型
---@return table 统计信息
function RankingMgr.GetRankingStats(rankType)
    if not rankType then
        return {}
    end
    
    local rankingInstance = server_ranking_instances[rankType]
    if not rankingInstance then
        return {}
    end
    
    return rankingInstance:GetStats()
end

--- 排名变化通知处理
---@param uin number 玩家UIN
---@param rankType string 排行榜类型
---@param playerName string 玩家名称
---@param oldRank number 旧排名
---@param newRank number 新排名
---@param newScore number 新分数
function RankingMgr.NotifyRankChange(uin, rankType, playerName, oldRank, newRank, newScore)
    -- 这里可以触发其他系统的处理，比如成就、任务等
    -- 也可以推送给RankingEventManager进行客户端通知
    
    local updateData = {
        updateType = "rank_change",
        playerUin = uin,
        playerName = playerName,
        newScore = newScore,
        newRank = newRank,
        oldRank = oldRank
    }
    
    -- 广播排行榜更新（这里可以根据需要决定是否立即通知）
    -- 注意：避免循环引用，可以通过事件系统解耦
    --[[
    local RankingEventManager = require(ServerStorage.MSystems.Ranking.RankingEventManager)
    RankingEventManager.BroadcastRankingUpdate(rankType, updateData)
    --]]
end

--- 定期维护任务
function RankingMgr.PerformMaintenance()
    local currentTime = os.time()
    
    -- 检查是否到了维护时间
    if currentTime - lastMaintenanceTime < maintenanceInterval then
        return
    end
    
    lastMaintenanceTime = currentTime
    
    -- 检查排行榜重置
    for rankType, rankingInstance in pairs(server_ranking_instances) do
        if rankingInstance then
            -- 检查是否需要重置
            if RankingCloudDataMgr.CheckNeedReset(rankType) then
                RankingMgr.ClearRanking(rankType)
            end
        end
    end
end

--- 修改：UpdateRebirthRanking - 简化为核心功能
function RankingMgr.UpdateRebirthRanking()
    local rankType = RankingConfig.TYPES.REBIRTH
    if not rankType then return end

    local players = serverDataMgr.getAllPlayers()
    local updates = {}

    for uin, player in pairs(players) do
        if player and player.variableSystem then
            local rebirthCount = player.variableSystem:GetVariable("数据_固定值_重生次数", 0)
            if rebirthCount and rebirthCount > 0 then
                table.insert(updates, {uin, player.name, rebirthCount})
            end
        end
    end

    if #updates > 0 then
        RankingCloudDataMgr.BatchSafeUpdatePlayerScore(rankType, updates, false)
    end
end

--- 修改：UpdateRechargeRanking - 简化为核心功能
function RankingMgr.UpdateRechargeRanking()
    local ShopMgr = require(ServerStorage.MSystems.Shop.ShopMgr) ---@type ShopMgr

    local rankType = RankingConfig.TYPES.RECHARGE
    if not rankType then return end

    local players = serverDataMgr.getAllPlayers()
    local updates = {}

    for uin, player in pairs(players) do
        if player then
            local shopInstance = ShopMgr.GetPlayerShop(uin)
            if shopInstance then
                local totalPurchaseValue = shopInstance.totalPurchaseValue or 0
                if totalPurchaseValue > 0 then
                    table.insert(updates, {uin, player.name, totalPurchaseValue})
                end
            end
        end
    end

    if #updates > 0 then
        RankingCloudDataMgr.BatchSafeUpdatePlayerScore(rankType, updates, false)
    end
end

--- 修改：UpdatePowerRanking - 简化为核心功能
function RankingMgr.UpdatePowerRanking()
    local rankType = RankingConfig.TYPES.POWER
    if not rankType then return end

    local players = serverDataMgr.getAllPlayers()
    local updates = {}

    for uin, player in pairs(players) do
        if player and player.variableSystem then
            local maxPowerValue = player.variableSystem:GetVariable("数据_固定值_历史最大战力值", 0)
            if maxPowerValue and maxPowerValue > 0 then
                table.insert(updates, {uin, player.name, maxPowerValue})
            end
        end
    end

    if #updates > 0 then
        RankingCloudDataMgr.BatchSafeUpdatePlayerScore(rankType, updates, false)
    end
end

--- 系统初始化
function RankingMgr.SystemInit()
    -- 初始化云数据管理器
    RankingCloudDataMgr.SystemInit()
    
    -- 重置维护时间
    lastMaintenanceTime = os.time()
    
    -- 创建定时器来更新排行榜
    local timer = SandboxNode.New("Timer", game.WorkSpace)
    timer.Name = "RankingUpdateTimer"
    timer.Delay = 10 -- 延迟10秒开始
    timer.Loop = true
    timer.Interval = 60 -- 每60秒更新一次
    timer.Callback = RankingMgr.UpdateRanking
    timer:Start()
end

--- 系统关闭
function RankingMgr.SystemShutdown()
    -- 清理所有排行榜实例
    for rankType, rankingInstance in pairs(server_ranking_instances) do
        if rankingInstance then
            rankingInstance:Destroy()
        end
    end
    
    -- 清空缓存
    server_ranking_instances = {}
    
    -- 关闭云数据管理器
    RankingCloudDataMgr.SystemShutdown()
end

--- 获取系统状态信息
---@return table 系统状态
function RankingMgr.GetSystemStatus()
    local status = {
        loadedRankingCount = 0,
        rankingTypes = {},
        lastMaintenanceTime = lastMaintenanceTime,
        nextMaintenanceTime = lastMaintenanceTime + maintenanceInterval
    }
    
    for rankType, _ in pairs(server_ranking_instances) do
        status.loadedRankingCount = status.loadedRankingCount + 1
        table.insert(status.rankingTypes, rankType)
    end
    
    return status
end

--- 重构：UpdateRanking - 简化为核心功能
function RankingMgr.UpdateRanking()
    -- 更新三个排行榜
    RankingMgr.UpdateRebirthRanking()
    RankingMgr.UpdateRechargeRanking()
    RankingMgr.UpdatePowerRanking()
    
    -- 通知客户端
    local RankingEventManager = require(ServerStorage.MSystems.Ranking.RankingEventManager) ---@type RankingEventManager
    local players = serverDataMgr.getAllPlayers()
    
    for uin, player in pairs(players) do
        RankingEventManager.NotifyAllDataToClient(uin)
    end
end
return RankingMgr