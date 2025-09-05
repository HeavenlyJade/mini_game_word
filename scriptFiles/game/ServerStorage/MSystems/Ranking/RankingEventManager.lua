-- RankingEventManager.lua
-- 排行榜事件管理器（静态类）
-- 负责处理客户端排行榜相关请求和响应

local game = game
local pairs = pairs

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local MS = require(MainStorage.Code.Untils.MS) ---@type MS
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local RankingEvent = require(MainStorage.Code.Event.EventRanking) ---@type EventRanking
local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager

-- 引入相关管理器
local RankingMgr = require(ServerStorage.MSystems.Ranking.RankingMgr) ---@type RankingMgr
local MPlayer = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer

---@class RankingEventManager
local RankingEventManager = {}

--- 验证玩家
---@param evt table 事件参数
---@return MPlayer|nil 玩家对象
function RankingEventManager.ValidatePlayer(evt)
    local env_player = evt.player
    if not env_player then
        --gg.log("排行榜事件缺少玩家参数")
        return nil
    end
    local uin = env_player.uin
    if not uin then
        --gg.log("排行榜事件缺少玩家UIN参数")
        return nil
    end

    local player = MServerDataManager.getPlayerByUin(uin)
    if not player then
        --gg.log("排行榜事件找不到玩家: " .. uin)
        return nil
    end

    return player
end













--- 广播排行榜更新通知
---@param rankType string 排行榜类型
---@param updateData table 更新数据
function RankingEventManager.BroadcastRankingUpdate(rankType, updateData)
    if not rankType or not updateData then
        return
    end
    
    -- 构造通知数据
    local notifyData = {
        cmd = RankingEvent.NOTIFY.RANKING_UPDATE,
        rankType = rankType,
        updateType = updateData.updateType or "score_update", -- score_update, rank_change, new_record等
        playerUin = updateData.playerUin,
        playerName = updateData.playerName,
        newScore = updateData.newScore,
        newRank = updateData.newRank,
        oldRank = updateData.oldRank,
        timestamp = os.time()
    }
    
    -- 广播给所有在线玩家（这里可以根据需要优化为只广播给关注该排行榜的玩家）
    local players = MS.Players:GetPlayers()
    for _, player in ipairs(players) do
        if player and player.uin then
            gg.network_channel:fireClient(player.uin, notifyData)
        end
    end
    ----gg.log("广播排行榜更新通知", rankType, updateData.playerUin)
end

--- 在预加载的排行榜列表中查找玩家排名信息
---@param uin number 玩家UIN
---@param rankingList table 预加载的排行榜列表
---@return table 玩家排名信息
function RankingEventManager.FindPlayerRankInList(uin, rankingList)
    local rankInfo = {
        playerUin = uin,
        rank = -1,
        score = 0,
        playerName = "",
        isOnRanking = false
    }

    if not rankingList or not uin then
        return rankInfo
    end

    for _, data in pairs(rankingList) do
        if data and data.uin == uin then
            rankInfo.rank = data.rank
            rankInfo.score = data.score
            rankInfo.playerName = data.playerName
            rankInfo.isOnRanking = true
            return rankInfo -- 找到后立即返回
        end
    end

    -- 如果在列表中没找到，说明玩家未上榜
    return rankInfo
end

--- 向客户端同步所有排行榜数据（优化版，使用预加载数据）
---@param uin number 玩家UIN
---@param allRankingsDataCache table|nil 预加载的所有排行榜数据 (可选)
function RankingEventManager.NotifyAllDataToClient(uin, allRankingsDataCache)
    if not uin then
        --gg.log("同步排行榜数据失败：玩家UIN无效")
        return
    end

    -- 如果没有传入缓存数据，则从RankingMgr获取或加载
    if not allRankingsDataCache then
        --gg.log("未提供缓存，从RankingMgr获取或加载...", uin)
        allRankingsDataCache = RankingMgr.GetOrLoadAllRankingsData()
    end

    if not allRankingsDataCache then
        --gg.log("同步排行榜数据失败：无法获取排行榜数据", uin)
        return
    end

    local rankingTypesForClient = {}

    -- 遍历预加载的排行榜数据
    for rankType, cachedData in pairs(allRankingsDataCache) do
        local rankingList = cachedData.list or {}
        local rankTypeData = cachedData.config or {}
        
        -- 过滤掉uin=0的假数据
        local filteredRankingList = {}
        for _, rankData in pairs(rankingList) do
            if rankData and rankData.uin and rankData.uin ~= 0 then
                table.insert(filteredRankingList, rankData)
            end
        end
        
        -- 从预加载的列表中查找玩家排名，避免云端读取
        local playerRankInfo = RankingEventManager.FindPlayerRankInList(uin, filteredRankingList)
        
        -- 如果没找到玩家信息，尝试从 MServerDataManager 获取玩家名字
        if not playerRankInfo.playerName or playerRankInfo.playerName == "" then
             local player = MServerDataManager.getPlayerByUin(uin)
             if player then
                 playerRankInfo.playerName = player.name or ""
             end
        end

        -- 发送单个排行榜数据到客户端
        gg.network_channel:fireClient(uin, {
            cmd = RankingEvent.NOTIFY.RANKING_DATA_SYNC,
            rankType = rankType,
            rankingConfig = rankTypeData,
            rankingList = filteredRankingList,
            playerRankInfo = playerRankInfo,
            count = #filteredRankingList,
            timestamp = os.time()
        })
        
        --gg.log("发送缓存的排行榜数据", rankType, "列表数量:", #filteredRankingList, "玩家排名:", playerRankInfo.rank)

        -- 收集排行榜类型信息，用于最后的类型同步
        table.insert(rankingTypesForClient, rankTypeData)
    end
    
    -- 发送排行榜类型列表
    gg.network_channel:fireClient(uin, {
        cmd = RankingEvent.NOTIFY.RANKING_TYPES_SYNC,
        rankingTypes = rankingTypesForClient,
        count = #rankingTypesForClient,
        timestamp = os.time()
    })
    
    --gg.log("所有排行榜数据同步完成", uin, "排行榜类型数量:", #rankingTypesForClient)
end

--- 推送玩家排名变化通知
---@param player MPlayer 玩家对象
---@param rankType string 排行榜类型
---@param oldRank number 旧排名
---@param newRank number 新排名
---@param newScore number 新分数
function RankingEventManager.NotifyPlayerRankChange(player, rankType, oldRank, newRank, newScore)
    if not player or not rankType then
        return
    end
    
    -- 只有排名发生变化时才通知
    if oldRank == newRank then
        return
    end
    
    local notifyData = {
        cmd = RankingEvent.NOTIFY.RANKING_UPDATE,
        rankType = rankType,
        playerUin = player.uin,
        playerName = player.name or "",
        oldRank = oldRank,
        newRank = newRank,
        newScore = newScore,
        isImprovement = newRank > 0 and (oldRank <= 0 or newRank < oldRank),
        timestamp = os.time()
    }
    
    gg.network_channel:fireClient(player.uin, notifyData)
    --gg.log("推送排名变化通知", player.uin, rankType, oldRank, "->", newRank)
end

--- 注册所有排行榜相关事件
function RankingEventManager.RegisterEventHandlers()
    -- 不再注册客户端请求事件，只保留服务端主动推送功能
end

--- 系统初始化
function RankingEventManager.Init()
    RankingEventManager.RegisterEventHandlers()
end

return RankingEventManager