-- LotteryEvent.lua
-- 抽奖系统事件定义 - 定义客户端与服务端的通信协议

---@class LotteryEvent
local LotteryEvent = {}

-- ==================== 客户端请求事件 ====================
LotteryEvent.REQUEST = {
    -- 获取抽奖数据
    GET_LOTTERY_DATA = "cmd_lottery_get_data",

    -- 单次抽奖
    SINGLE_DRAW = "cmd_lottery_single_draw",

    -- 五连抽
    FIVE_DRAW = "cmd_lottery_five_draw",

    -- 十连抽
    TEN_DRAW = "cmd_lottery_ten_draw",

    -- 获取抽奖历史
    GET_DRAW_HISTORY = "cmd_lottery_get_history",

    -- 获取可用抽奖池
    GET_AVAILABLE_POOLS = "cmd_lottery_get_pools",

    -- 获取抽奖池统计
    GET_POOL_STATS = "cmd_lottery_get_stats",
}

-- ==================== 服务端响应事件 ====================
LotteryEvent.RESPONSE = {
    -- 抽奖数据响应
    LOTTERY_DATA = "LotteryResponse_Data",

    -- 抽奖结果响应
    DRAW_RESULT = "LotteryResponse_DrawResult",

    -- 抽奖历史响应
    DRAW_HISTORY = "LotteryResponse_History",

    -- 可用抽奖池响应
    AVAILABLE_POOLS = "LotteryResponse_AvailablePools",

    -- 抽奖池统计响应
    POOL_STATS = "LotteryResponse_PoolStats",

    -- 错误响应
    ERROR = "LotteryResponse_Error",
}

-- ==================== 服务端通知事件 ====================
LotteryEvent.NOTIFY = {
    -- 保底进度更新通知
    PITY_UPDATE = "LotteryNotify_PityUpdate",

    -- 新抽奖池可用通知
    NEW_POOL_AVAILABLE = "LotteryNotify_NewPool",

    -- 抽奖成功通知
    DRAW_SUCCESS = "LotteryNotify_DrawSuccess",

    -- 数据同步通知
    DATA_SYNC = "LotteryNotify_DataSync",
}

return LotteryEvent
