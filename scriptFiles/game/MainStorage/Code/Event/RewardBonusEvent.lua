-- RewardBonusEvent.lua
-- 奖励加成系统事件定义 - 定义客户端与服务端的通信协议

---@class RewardBonusEvent
local RewardBonusEvent = {}

-- ==================== 客户端请求事件 ====================
RewardBonusEvent.REQUEST = {
    -- 获取奖励加成数据
    GET_REWARD_BONUS_DATA = "RewardBonus_GetData",
    
    -- 获取指定配置数据
    GET_CONFIG_DATA = "RewardBonus_GetConfig",
    -- 参数: {configName = "配置名称"}
    
    -- 领取指定等级奖励
    CLAIM_TIER_REWARD = "RewardBonus_ClaimTier",
    -- 参数: {configName = "配置名称", uniqueId = "ID1"}
    
    -- 获取红点状态
    GET_RED_DOT_STATUS = "RewardBonus_GetRedDot",
    -- 参数: {configName = "配置名称"} -- 可选，不传则查询全部
    
    -- 重置配置数据（调试用）
    RESET_CONFIG = "RewardBonus_ResetConfig",
    -- 参数: {configName = "配置名称"}
}

-- ==================== 服务端响应事件 ====================
RewardBonusEvent.RESPONSE = {
    -- 奖励加成数据响应
    REWARD_BONUS_DATA = "RewardBonus_Data_Response",
    -- 数据: {
    --     success = true,
    --     data = {
    --         configs = {
    --             ["配置名称1"] = {
    --                 claimedTierCount = 3,
    --                 availableTierCount = 2,
    --                 totalTierCount = 10,
    --                 availableTiers = {4, 5},
    --                 hasAvailableRewards = true
    --             }
    --         },
    --         totalAvailableCount = 5,
    --         hasAnyAvailableRewards = true
    --     },
    --     errorMsg = nil
    -- }
    
    -- 指定配置数据响应
    CONFIG_DATA = "RewardBonus_Config_Response",
    -- 数据: {
    --     success = true,
    --     configName = "配置名称",
    --     data = {
    --         claimedTierCount = 3,
    --         availableTierCount = 2,
    --         totalTierCount = 10,
    --         availableTiers = {4, 5},
    --         hasAvailableRewards = true
    --     },
    --     errorMsg = nil
    -- }
    
    -- 领取奖励响应
    CLAIM_TIER_RESULT = "RewardBonus_ClaimResult_Response",
    -- 数据: {
    --     success = true,
    --     configName = "配置名称",
    --     uniqueId = "ID1",
    --     reward = {type = "物品", itemName = "金币", amount = 100},
    --     errorMsg = nil
    -- }
    
    -- 红点状态响应
    RED_DOT_STATUS = "RewardBonus_RedDot_Response",
    -- 数据: {
    --     configName = "配置名称", -- 指定配置时返回，否则为nil
    --     hasAvailable = true,
    --     totalAvailableCount = 5 -- 全局查询时返回
    -- }
    
    -- 重置配置响应
    RESET_CONFIG_RESULT = "RewardBonus_ResetConfig_Response",
    -- 数据: {
    --     success = true,
    --     configName = "配置名称",
    --     errorMsg = nil
    -- }
}

-- ==================== 服务端通知事件 ====================
RewardBonusEvent.NOTIFY = {
    -- 数据同步通知（主动推送）
    DATA_SYNC = "RewardBonus_DataSync",
    -- 数据: {
    --     configs = {...},  -- 完整的配置状态
    --     totalAvailableCount = 5,
    --     hasAnyAvailableRewards = true
    -- }
    
    -- 新奖励可领取通知
    NEW_AVAILABLE = "RewardBonus_NewAvailable",
    -- 数据: {
    --     configName = "配置名称", -- 可选，指定配置
    --     hasAvailable = true,
    --     totalAvailableCount = 5
    -- }
    
    -- 奖励已领取通知（用于多端同步）
    REWARD_CLAIMED = "RewardBonus_Claimed_Notify",
    -- 数据: {
    --     configName = "配置名称",
    --     uniqueId = "ID1",
    --     reward = {...}
    -- }
    
    -- 配置重置通知
    CONFIG_RESET = "RewardBonus_ConfigReset_Notify",
    -- 数据: {
    --     configName = "配置名称",
    --     reason = "debug" -- 重置原因
    -- }
}

return RewardBonusEvent