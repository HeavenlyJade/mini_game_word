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

--- 向客户端同步所有排行榜数据
---@param uin number 玩家UIN
function RankingEventManager.NotifyAllDataToClient(uin)
    if not uin then
        --gg.log("同步排行榜数据失败：玩家UIN无效")
        return
    end
    -- 获取所有支持的排行榜类型
    local rankingTypes = RankingMgr.GetAllRankingTypes()
    
    -- 为每个排行榜类型获取完整的排行榜数据
    for _, rankTypeData in pairs(rankingTypes) do
        local rankType = rankTypeData.rankType
        
        -- 获取该排行榜的完整数据（前100名）
        local rankingList = RankingMgr.GetRankingList(rankType, 1, 100)
        
        -- 过滤掉uin=0的假数据
        local filteredRankingList = {}
        for _, rankData in pairs(rankingList) do
            if rankData and rankData.uin and rankData.uin ~= 0 then
                table.insert(filteredRankingList, rankData)
            end
        end
        
        -- 获取玩家在该排行榜的排名信息
        local playerRankInfo = RankingMgr.GetPlayerRank(uin, rankType)
        
        -- 发送完整排行榜数据到客户端
        gg.network_channel:fireClient(uin, {
            cmd = RankingEvent.NOTIFY.RANKING_DATA_SYNC,
            rankType = rankType,
            rankingConfig = rankTypeData, -- 排行榜配置信息
            rankingList = filteredRankingList, -- 过滤后的排行榜数据
            playerRankInfo = { -- 玩家排名信息
                playerUin = uin,
                rank = playerRankInfo.rank or -1,
                score = playerRankInfo.score or 0,
                playerName = playerRankInfo.playerName or "",
                isOnRanking = playerRankInfo.rank and playerRankInfo.rank > 0
            },
            count = #filteredRankingList,
            timestamp = os.time()
        })
        
        --gg.log("发送排行榜数据", rankType, "原始条目数:", #rankingList, "过滤后条目数:", #filteredRankingList, "玩家排名:", playerRankInfo.rank)
    end
    
    -- 发送排行榜类型列表
    gg.network_channel:fireClient(uin, {
        cmd = RankingEvent.NOTIFY.RANKING_TYPES_SYNC,
        rankingTypes = rankingTypes,
        count = #rankingTypes,
        timestamp = os.time()
    })
    
    --gg.log("排行榜数据同步完成", uin, "排行榜类型数量:", #rankingTypes)
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