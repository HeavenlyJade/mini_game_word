-- EventRanking.lua
-- 定义排行榜系统所有客户端-服务器通信事件

---@class EventRanking
local EventRanking = {}

-- 客户端 -> 服务器的请求事件
EventRanking.REQUEST = {
    GET_RANKING_LIST = "Ranking:GetRankingList",
    GET_MY_RANK = "Ranking:GetMyRank",
    GET_PLAYER_RANK = "Ranking:GetPlayerRank",
    REFRESH_RANKING = "Ranking:RefreshRanking",
    GET_RANKING_TYPES = "Ranking:GetRankingTypes",
}

-- 服务器 -> 客户端的响应事件
EventRanking.RESPONSE = {
    GET_RANKING_LIST = "Ranking:ResponseGetRankingList",
    GET_MY_RANK = "Ranking:ResponseGetMyRank",
    GET_PLAYER_RANK = "Ranking:ResponseGetPlayerRank",
    REFRESH_RANKING = "Ranking:ResponseRefreshRanking",
    GET_RANKING_TYPES = "Ranking:ResponseGetRankingTypes",
    ERROR = "Ranking:Error",
}

-- 服务器 -> 客户端的通知事件
EventRanking.NOTIFY = {
    RANKING_UPDATE = "Ranking:NotifyRankingUpdate",
}

return EventRanking
