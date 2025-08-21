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
        gg.log("排行榜事件缺少玩家参数")
        return nil
    end
    local uin = env_player.uin
    if not uin then
        gg.log("排行榜事件缺少玩家UIN参数")
        return nil
    end

    local player = MServerDataManager.getPlayerByUin(uin)
    if not player then
        gg.log("排行榜事件找不到玩家: " .. uin)
        return nil
    end

    return player
end

--- 处理获取排行榜列表请求
---@param evt table 事件数据 {args = {rankType: string, startRank: number, count: number}}
function RankingEventManager.HandleGetRankingList(evt)
    local player = RankingEventManager.ValidatePlayer(evt)
    if not player then return end

    local data = evt.args
    if not data then
        gg.log("获取排行榜列表失败：参数无效")
        return
    end
    
    local rankType = data.rankType
    local startRank = data.startRank or 1
    local count = data.count or 10
    
    -- 参数验证
    if not rankType or type(rankType) ~= "string" then
        gg.log("获取排行榜列表失败：排行榜类型无效", player.uin, rankType)
        RankingEventManager.NotifyError(player.uin, -1, "排行榜类型无效")
        return
    end
    
    if startRank <= 0 or count <= 0 or count > 100 then
        gg.log("获取排行榜列表失败：参数范围无效", player.uin, startRank, count)
        RankingEventManager.NotifyError(player.uin, -1, "参数范围无效")
        return
    end
    
    -- 获取排行榜数据
    local rankingList = RankingMgr.GetRankingList(rankType, startRank, count)
    
    -- 过滤掉uin=0的假数据
    local filteredRankingList = {}
    for _, rankData in pairs(rankingList) do
        if rankData and rankData.uin and rankData.uin ~= 0 then
            table.insert(filteredRankingList, rankData)
        end
    end
    
    -- 构造响应数据
    gg.network_channel:fireClient(player.uin, {
        cmd = RankingEvent.RESPONSE.GET_RANKING_LIST,
        success = true,
        rankType = rankType,
        startRank = startRank,
        count = count,
        actualCount = #filteredRankingList,
        rankingList = filteredRankingList,
        timestamp = os.time()
    })
    --gg.log("发送排行榜列表响应成功", player.uin, rankType, #rankingList)
end

--- 处理获取我的排名请求
---@param evt table 事件数据 {args = {rankType: string}}
function RankingEventManager.HandleGetMyRank(evt)
    local player = RankingEventManager.ValidatePlayer(evt)
    if not player then return end

    local data = evt.args
    if not data then
        gg.log("获取我的排名失败：参数无效")
        return
    end
    
    local rankType = data.rankType
    
    -- 参数验证
    if not rankType or type(rankType) ~= "string" then
        gg.log("获取我的排名失败：排行榜类型无效", player.uin, rankType)
        RankingEventManager.NotifyError(player.uin, -1, "排行榜类型无效")
        return
    end
    
    -- 获取玩家排名信息
    local rankInfo = RankingMgr.GetPlayerRank(player.uin, rankType)
    
    -- 构造响应数据
    gg.network_channel:fireClient(player.uin, {
        cmd = RankingEvent.RESPONSE.GET_MY_RANK,
        success = true,
        rankType = rankType,
        playerUin = player.uin,
        playerName = player.name or "",
        rank = rankInfo.rank or -1,
        score = rankInfo.score or 0,
        isOnRanking = rankInfo.rank and rankInfo.rank > 0,
        timestamp = os.time()
    })
    --gg.log("发送我的排名响应成功", player.uin, rankType, rankInfo.rank)
end

--- 处理获取指定玩家排名请求
---@param evt table 事件数据 {args = {rankType: string, targetUin: number}}
function RankingEventManager.HandleGetPlayerRank(evt)
    local player = RankingEventManager.ValidatePlayer(evt)
    if not player then return end

    local data = evt.args
    if not data then
        gg.log("获取玩家排名失败：参数无效")
        return
    end
    
    local rankType = data.rankType
    local targetUin = data.targetUin
    
    -- 参数验证
    if not rankType or type(rankType) ~= "string" then
        gg.log("获取玩家排名失败：排行榜类型无效", player.uin, rankType)
        RankingEventManager.NotifyError(player.uin, -1, "排行榜类型无效")
        return
    end
    
    if not targetUin or type(targetUin) ~= "number" then
        gg.log("获取玩家排名失败：目标玩家UIN无效", player.uin, targetUin)
        RankingEventManager.NotifyError(player.uin, -1, "目标玩家UIN无效")
        return
    end
    
    -- 获取目标玩家排名信息
    local rankInfo = RankingMgr.GetPlayerRank(targetUin, rankType)
    
    -- 构造响应数据
    gg.network_channel:fireClient(player.uin, {
        cmd = RankingEvent.RESPONSE.GET_PLAYER_RANK,
        success = true,
        rankType = rankType,
        targetUin = targetUin,
        requestPlayerUin = player.uin,
        rank = rankInfo.rank or -1,
        score = rankInfo.score or 0,
        playerName = rankInfo.playerName or "",
        isOnRanking = rankInfo.rank and rankInfo.rank > 0,
        timestamp = os.time()
    })
    --gg.log("发送玩家排名响应成功", player.uin, targetUin, rankType, rankInfo.rank)
end

--- 处理刷新排行榜请求
---@param evt table 事件数据 {args = {rankType: string}}
function RankingEventManager.HandleRefreshRanking(evt)
    local player = RankingEventManager.ValidatePlayer(evt)
    if not player then return end

    local data = evt.args
    if not data then
        gg.log("刷新排行榜失败：参数无效")
        return
    end
    
    local rankType = data.rankType
    
    -- 参数验证
    if not rankType or type(rankType) ~= "string" then
        gg.log("刷新排行榜失败：排行榜类型无效", player.uin, rankType)
        RankingEventManager.NotifyError(player.uin, -1, "排行榜类型无效")
        return
    end
    
    -- 刷新排行榜（实际上CloudKVStore是实时的，这里主要是重新获取数据）
    local success = RankingMgr.RefreshRanking(rankType)
    
    -- 构造响应数据
    gg.network_channel:fireClient(player.uin, {
        cmd = RankingEvent.RESPONSE.REFRESH_RANKING,
        success = success,
        rankType = rankType,
        message = success and "刷新成功" or "刷新失败",
        timestamp = os.time()
    })
    gg.log("发送排行榜刷新响应", player.uin, rankType, success)
end

--- 处理获取支持的排行榜类型请求
---@param evt table 事件数据
function RankingEventManager.HandleGetRankingTypes(evt)
    local player = RankingEventManager.ValidatePlayer(evt)
    if not player then return end
    
    -- 获取所有支持的排行榜类型
    local rankingTypes = RankingMgr.GetAllRankingTypes()
    
    -- 构造响应数据
    gg.network_channel:fireClient(player.uin, {
        cmd = RankingEvent.RESPONSE.GET_RANKING_TYPES,
        success = true,
        rankingTypes = rankingTypes,
        count = #rankingTypes,
        timestamp = os.time()
    })
    --gg.log("发送排行榜类型响应成功", player.uin, #rankingTypes)
end

--- 通知客户端错误信息
---@param uin number 玩家ID
---@param errorCode number 错误码
---@param errorMsg string 错误信息
function RankingEventManager.NotifyError(uin, errorCode, errorMsg)
    gg.network_channel:fireClient(uin, {
        cmd = RankingEvent.RESPONSE.ERROR,
        errorCode = errorCode,
        errorMsg = errorMsg
    })
    gg.log("发送排行榜错误响应", uin, errorMsg)
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
    --gg.log("广播排行榜更新通知", rankType, updateData.playerUin)
end

--- 向客户端同步所有排行榜数据
---@param uin number 玩家UIN
function RankingEventManager.NotifyAllDataToClient(uin)
    if not uin then
        gg.log("同步排行榜数据失败：玩家UIN无效")
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
        
        gg.log("发送排行榜数据", rankType, "原始条目数:", #rankingList, "过滤后条目数:", #filteredRankingList, "玩家排名:", playerRankInfo.rank)
    end
    
    -- 发送排行榜类型列表
    gg.network_channel:fireClient(uin, {
        cmd = RankingEvent.NOTIFY.RANKING_TYPES_SYNC,
        rankingTypes = rankingTypes,
        count = #rankingTypes,
        timestamp = os.time()
    })
    
    gg.log("排行榜数据同步完成", uin, "排行榜类型数量:", #rankingTypes)
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
    gg.log("推送排名变化通知", player.uin, rankType, oldRank, "->", newRank)
end

--- 注册所有排行榜相关事件
function RankingEventManager.RegisterEventHandlers()
    
    -- 注册客户端请求事件
    ServerEventManager.Subscribe(RankingEvent.REQUEST.GET_RANKING_LIST, function(evt) RankingEventManager.HandleGetRankingList(evt) end)
    ServerEventManager.Subscribe(RankingEvent.REQUEST.GET_MY_RANK, function(evt) RankingEventManager.HandleGetMyRank(evt) end)
    ServerEventManager.Subscribe(RankingEvent.REQUEST.GET_PLAYER_RANK, function(evt) RankingEventManager.HandleGetPlayerRank(evt) end)
    ServerEventManager.Subscribe(RankingEvent.REQUEST.REFRESH_RANKING, function(evt) RankingEventManager.HandleRefreshRanking(evt) end)
    ServerEventManager.Subscribe(RankingEvent.REQUEST.GET_RANKING_TYPES, function(evt) RankingEventManager.HandleGetRankingTypes(evt) end)
    
end

--- 系统初始化
function RankingEventManager.Init()
    RankingEventManager.RegisterEventHandlers()
end

return RankingEventManager