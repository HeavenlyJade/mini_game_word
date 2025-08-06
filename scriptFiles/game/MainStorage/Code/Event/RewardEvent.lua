-- RewardEvent.lua
-- 奖励系统事件定义 - 定义客户端与服务端的通信协议

---@class RewardEvent
local RewardEvent = {}

-- ==================== 客户端请求事件 ====================
RewardEvent.REQUEST = {
    -- 获取在线奖励数据
    GET_ONLINE_REWARD_DATA = "Reward_GetOnlineData",
    
    -- 领取单个在线奖励
    CLAIM_ONLINE_REWARD = "Reward_ClaimOnline",
    -- 参数: {index = 1}  -- 奖励索引
    
    -- 一键领取所有在线奖励
    CLAIM_ALL_ONLINE_REWARDS = "Reward_ClaimAllOnline",
    -- 参数: {}
    
    -- 获取红点状态
    GET_RED_DOT_STATUS = "Reward_GetRedDot",
    -- 参数: {}
    
    -- 切换奖励配置（用于活动切换）
    SWITCH_CONFIG = "Reward_SwitchConfig",
    -- 参数: {configName = "在线奖励初级"}
}

-- ==================== 服务端响应事件 ====================
RewardEvent.RESPONSE = {
    -- 在线奖励数据响应
    ONLINE_REWARD_DATA = "Reward_OnlineData_Response",
    -- 数据: {
    --     success = true,
    --     data = {
    --         currentRound = 1,
    --         todayOnlineTime = 3600,
    --         roundOnlineTime = 1800,
    --         totalRewards = 12,
    --         claimedCount = 3,
    --         availableCount = 2,
    --         nextRewardTime = 120,
    --         rewards = {...}
    --     },
    --     errorMsg = nil
    -- }
    
    -- 领取奖励响应
    CLAIM_REWARD_RESULT = "Reward_ClaimResult_Response",
    -- 数据: {
    --     success = true,
    --     index = 1,
    --     reward = {type = "物品", itemName = "金币", amount = 100},
    --     errorMsg = nil
    -- }
    
    -- 一键领取响应
    CLAIM_ALL_RESULT = "Reward_ClaimAllResult_Response",
    -- 数据: {
    --     success = true,
    --     count = 3,
    --     rewards = {...},
    --     errorMsg = nil
    -- }
    
    -- 红点状态响应
    RED_DOT_STATUS = "Reward_RedDot_Response",
    -- 数据: {
    --     hasAvailable = true
    -- }
    
    -- 配置切换响应
    SWITCH_CONFIG_RESULT = "Reward_SwitchConfig_Response",
    -- 数据: {
    --     success = true,
    --     newConfig = "在线奖励初级",
    --     errorMsg = nil
    -- }
}

-- ==================== 服务端通知事件 ====================
RewardEvent.NOTIFY = {
    -- 数据同步通知（主动推送）
    DATA_SYNC = "Reward_DataSync",
    -- 数据: {
    --     onlineStatus = {...},  -- 完整的在线奖励状态
    --     hasAvailable = true
    -- }
    
    -- 新奖励可领取通知
    NEW_AVAILABLE = "Reward_NewAvailable",
    -- 数据: {
    --     hasAvailable = true,
    --     availableIndices = {4, 5}  -- 新可领取的索引
    -- }
    
    -- 奖励已领取通知（用于多端同步）
    REWARD_CLAIMED = "Reward_Claimed_Notify",
    -- 数据: {
    --     type = "online",
    --     index = 1,
    --     reward = {...}
    -- }
    
    -- 轮次重置通知
    ROUND_RESET = "Reward_RoundReset",
    -- 数据: {
    --     newRound = 2,
    --     reason = "all_claimed"  -- 重置原因
    -- }
    
    -- 每日重置通知
    DAILY_RESET = "Reward_DailyReset",
    -- 数据: {
    --     date = "2024-01-01",
    --     todayOnlineTime = 0
    -- }
}

return RewardEvent