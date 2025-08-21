-- RankingMgr.lua
-- 排行榜功能管理器（静态类）
-- 负责缓存在线排行榜实例并处理业务逻辑

local game = game
local pairs = pairs
local os = os

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

-- 引入相关系统
local Ranking = require(ServerStorage.MSystems.Ranking.Ranking) ---@type Ranking
local RankingCloudDataMgr = require(ServerStorage.MSystems.Ranking.RankingCloudDataMgr) ---@type RankingCloudDataMgr
local MPlayer = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer

---@class RankingMgr
local RankingMgr = {}

-- 排行榜实例缓存 {排行榜类型 = Ranking实例}
local server_ranking_instances = {} ---@type table<string, Ranking>

-- 排行榜缓存状态记录
local ranking_cache_status = {} ---@type table<string, boolean>

-- 定时器相关
local lastMaintenanceTime = 0
local maintenanceInterval = 300 -- 5分钟执行一次维护

--- 获取排行榜实例
---@param rankType string 排行榜类型
---@return Ranking|nil 排行榜实例
function RankingMgr.GetRankingInstance(rankType)
    if not rankType or type(rankType) ~= "string" then
        gg.log("获取排行榜实例失败：排行榜类型无效", rankType)
        return nil
    end
    
    return server_ranking_instances[rankType]
end

--- 获取或创建排行榜实例
---@param rankType string 排行榜类型
---@return Ranking|nil 排行榜实例
function RankingMgr.GetOrCreateRanking(rankType)
    if not rankType or type(rankType) ~= "string" then
        gg.log("获取或创建排行榜失败：排行榜类型无效", rankType)
        return nil
    end
    
    -- 检查缓存中是否已存在
    local rankingInstance = server_ranking_instances[rankType]
    if rankingInstance then
        return rankingInstance
    end
    
    -- 验证排行榜类型是否支持
    if not RankingCloudDataMgr.ValidateRankingType(rankType) then
        gg.log("创建排行榜失败：不支持的排行榜类型", rankType)
        return nil
    end
    
    -- 创建新的排行榜实例
    rankingInstance = Ranking.New(rankType)
    if not rankingInstance then
        gg.log("创建排行榜实例失败", rankType)
        return nil
    end
    
    -- 初始化排行榜
    local success = rankingInstance:Initialize()
    if not success then
        gg.log("初始化排行榜失败", rankType)
        return nil
    end
    
    -- 缓存实例
    server_ranking_instances[rankType] = rankingInstance
    ranking_cache_status[rankType] = true
    
    gg.log("创建并缓存排行榜实例成功", rankType)
    return rankingInstance
end

--- 更新玩家分数
---@param uin number 玩家UIN
---@param rankType string 排行榜类型
---@param playerName string 玩家名称
---@param score number 分数
---@return boolean 是否成功
function RankingMgr.UpdatePlayerScore(uin, rankType, playerName, score)
    if not uin or not rankType or not playerName or not score then
        gg.log("更新玩家分数失败：参数无效", uin, rankType, playerName, score)
        return false
    end
    
    if type(uin) ~= "number" or type(score) ~= "number" then
        gg.log("更新玩家分数失败：参数类型错误", uin, score)
        return false
    end
    
    -- 获取或创建排行榜实例
    local rankingInstance = RankingMgr.GetOrCreateRanking(rankType)
    if not rankingInstance then
        return false
    end
    
    -- 获取旧排名（用于变化通知）
    local oldRankInfo = rankingInstance:GetPlayerRank(uin)
    local oldRank = oldRankInfo.rank or -1
    
    -- 更新分数
    local success = rankingInstance:UpdatePlayerScore(uin, playerName, score)
    if not success then
        gg.log("更新玩家分数失败", uin, rankType, playerName, score)
        return false
    end
    
    -- 获取新排名
    local newRankInfo = rankingInstance:GetPlayerRank(uin)
    local newRank = newRankInfo.rank or -1
    
    -- 如果排名发生变化，触发通知
    if oldRank ~= newRank then
        RankingMgr.NotifyRankChange(uin, rankType, playerName, oldRank, newRank, score)
    end
    
    --gg.log("更新玩家分数成功", uin, rankType, playerName, score, "排名:", newRank)
    return true
end

--- 异步更新玩家分数
---@param uin number 玩家UIN
---@param rankType string 排行榜类型
---@param playerName string 玩家名称
---@param score number 分数
---@param callback function|nil 回调函数
function RankingMgr.UpdatePlayerScoreAsync(uin, rankType, playerName, score, callback)
    if not uin or not rankType or not playerName or not score then
        gg.log("异步更新玩家分数失败：参数无效", uin, rankType, playerName, score)
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
    
    -- 异步更新分数
    rankingInstance:UpdatePlayerScoreAsync(uin, playerName, score, function(success)
        if success then
            -- 获取新排名并触发通知
            local newRankInfo = rankingInstance:GetPlayerRank(uin)
            local newRank = newRankInfo.rank or -1
            
            if oldRank ~= newRank then
                RankingMgr.NotifyRankChange(uin, rankType, playerName, oldRank, newRank, score)
            end
            
            --gg.log("异步更新玩家分数成功", uin, rankType, playerName, score, "排名:", newRank)
        else
            gg.log("异步更新玩家分数失败", uin, rankType, playerName, score)
        end
        
        if callback then
            callback(success)
        end
    end)
end

--- 获取排行榜列表
---@param rankType string 排行榜类型
---@param startRank number 起始排名
---@param count number 获取数量
---@return table 排行榜数据
function RankingMgr.GetRankingList(rankType, startRank, count)
    if not rankType then
        gg.log("获取排行榜列表失败：排行榜类型无效", rankType)
        return {}
    end
    
    -- 参数默认值和验证
    startRank = startRank or 1
    count = count or 10
    
    if startRank <= 0 or count <= 0 or count > 100 then
        gg.log("获取排行榜列表失败：参数范围无效", startRank, count)
        return {}
    end
    
    -- 获取或创建排行榜实例
    local rankingInstance = RankingMgr.GetOrCreateRanking(rankType)
    if not rankingInstance then
        return {}
    end
    
    -- 获取排行榜数据
    local rankingList = rankingInstance:GetRankingList(startRank, count)
    --gg.log("获取排行榜列表成功", rankType, startRank, count, "实际返回:", #rankingList)
    
    return rankingList
end

--- 获取玩家排名信息
---@param uin number 玩家UIN
---@param rankType string 排行榜类型
---@return table 排名信息 {rank: number, score: number, playerName: string}
function RankingMgr.GetPlayerRank(uin, rankType)
    if not uin or not rankType then
        gg.log("获取玩家排名失败：参数无效", uin, rankType)
        return {rank = -1, score = 0, playerName = ""}
    end
    
    -- 获取或创建排行榜实例
    local rankingInstance = RankingMgr.GetOrCreateRanking(rankType)
    if not rankingInstance then
        return {rank = -1, score = 0, playerName = ""}
    end
    
    -- 获取玩家排名信息
    local rankInfo = rankingInstance:GetPlayerRank(uin)
    --gg.log("获取玩家排名成功", uin, rankType, rankInfo.rank, rankInfo.score)
    
    return rankInfo
end

--- 刷新排行榜
---@param rankType string 排行榜类型
---@return boolean 是否成功
function RankingMgr.RefreshRanking(rankType)
    if not rankType then
        gg.log("刷新排行榜失败：排行榜类型无效", rankType)
        return false
    end
    
    local rankingInstance = server_ranking_instances[rankType]
    if not rankingInstance then
        gg.log("刷新排行榜失败：排行榜实例不存在", rankType)
        return false
    end
    
    -- CloudKVStore是实时的，这里主要是标记刷新状态
    local success = rankingInstance:Refresh()
    if success then
        gg.log("刷新排行榜成功", rankType)
    else
        gg.log("刷新排行榜失败", rankType)
    end
    
    return success
end

--- 清空排行榜
---@param rankType string 排行榜类型
---@return boolean 是否成功
function RankingMgr.ClearRanking(rankType)
    if not rankType then
        gg.log("清空排行榜失败：排行榜类型无效", rankType)
        return false
    end
    
    -- 获取或创建排行榜实例
    local rankingInstance = RankingMgr.GetOrCreateRanking(rankType)
    if not rankingInstance then
        return false
    end
    
    -- 清空排行榜数据
    local success = rankingInstance:ClearRanking()
    if success then
        gg.log("清空排行榜成功", rankType)
    else
        gg.log("清空排行榜失败", rankType)
    end
    
    return success
end

--- 移除玩家数据
---@param uin number 玩家UIN
---@param rankType string 排行榜类型
---@return boolean 是否成功
function RankingMgr.RemovePlayer(uin, rankType)
    if not uin or not rankType then
        gg.log("移除玩家数据失败：参数无效", uin, rankType)
        return false
    end
    
    local rankingInstance = server_ranking_instances[rankType]
    if not rankingInstance then
        gg.log("移除玩家数据失败：排行榜实例不存在", rankType)
        return false
    end
    
    -- 移除玩家数据
    local success = rankingInstance:RemovePlayer(uin)
    if success then
        gg.log("移除玩家排行榜数据成功", uin, rankType)
    else
        gg.log("移除玩家排行榜数据失败", uin, rankType)
    end
    
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

--- 批量更新多个玩家分数
---@param updates table 更新数据列表 {{uin, rankType, playerName, score}, ...}
---@return number 成功更新的数量
function RankingMgr.BatchUpdatePlayerScores(updates)
    if not updates or type(updates) ~= "table" then
        gg.log("批量更新玩家分数失败：参数无效")
        return 0
    end
    
    local successCount = 0
    
    for _, updateData in pairs(updates) do
        if updateData and type(updateData) == "table" then
            local uin = updateData.uin or updateData[1]
            local rankType = updateData.rankType or updateData[2]
            local playerName = updateData.playerName or updateData[3]
            local score = updateData.score or updateData[4]
            
            if RankingMgr.UpdatePlayerScore(uin, rankType, playerName, score) then
                successCount = successCount + 1
            end
        end
    end
    
    gg.log("批量更新玩家分数完成", "总数:", #updates, "成功:", successCount)
    return successCount
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
    
    --gg.log("排名变化通知", uin, rankType, oldRank, "->", newRank, "分数:", newScore)
end

--- 定期维护任务
function RankingMgr.PerformMaintenance()
    local currentTime = os.time()
    
    -- 检查是否到了维护时间
    if currentTime - lastMaintenanceTime < maintenanceInterval then
        return
    end
    
    lastMaintenanceTime = currentTime
    --gg.log("排行榜系统开始执行定期维护")
    
    -- 检查排行榜重置
    for rankType, rankingInstance in pairs(server_ranking_instances) do
        if rankingInstance then
            -- 检查是否需要重置
            if RankingCloudDataMgr.CheckNeedReset(rankType) then
                gg.log("检测到排行榜需要重置", rankType)
                RankingMgr.ClearRanking(rankType)
            end
        end
    end
    
    --gg.log("排行榜系统定期维护完成")
end

--- 系统初始化
function RankingMgr.SystemInit()
    gg.log("排行榜管理器初始化开始")
    
    -- 初始化云数据管理器
    RankingCloudDataMgr.SystemInit()
    
    -- 预加载常用排行榜类型（可选）
    local commonRankTypes = {"power_ranking", "recharge_ranking"}
    for _, rankType in pairs(commonRankTypes) do
        local rankingInstance = RankingMgr.GetOrCreateRanking(rankType)
        if rankingInstance then
            gg.log("预加载排行榜成功", rankType)
        else
            gg.log("预加载排行榜失败", rankType)
        end
    end
    
    -- 重置维护时间
    lastMaintenanceTime = os.time()
    
    gg.log("排行榜管理器初始化完成")
end

--- 系统关闭
function RankingMgr.SystemShutdown()
    gg.log("排行榜管理器关闭开始")
    
    -- 清理所有排行榜实例
    for rankType, rankingInstance in pairs(server_ranking_instances) do
        if rankingInstance then
            rankingInstance:Destroy()
            gg.log("清理排行榜实例", rankType)
        end
    end
    
    -- 清空缓存
    server_ranking_instances = {}
    ranking_cache_status = {}
    
    -- 关闭云数据管理器
    RankingCloudDataMgr.SystemShutdown()
    
    gg.log("排行榜管理器关闭完成")
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

return RankingMgr