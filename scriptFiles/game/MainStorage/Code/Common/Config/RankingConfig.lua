-- RankingConfig.lua
-- 存放所有排行榜相关的配置

---@class RankingConfig
local RankingConfig = {}

-- 排行榜类型定义
RankingConfig.TYPES = {
    POWER = "power_ranking_cloud",        -- 战力排行榜
    RECHARGE = "recharge_ranking_cloud",  -- 充值排行榜
    REBIRTH = "rebirth_ranking_cloud",    -- 重生排行榜
}

-- 排行榜详细配置
RankingConfig.CONFIGS = {
    [RankingConfig.TYPES.POWER] = {
        name = "战力排行榜",
        displayName = "战力榜",
        maxDisplayCount = 100,
        resetType = "none", -- never, daily, weekly, monthly
        weight = 1,
    },
    [RankingConfig.TYPES.RECHARGE] = {
        name = "充值排行榜",
        displayName = "充值榜",
        maxDisplayCount = 100,
        resetType = "monthly",
        weight = 3,
    },
    [RankingConfig.TYPES.REBIRTH] = {
        name = "重生排行榜",
        displayName = "重生榜",
        maxDisplayCount = 100,
        resetType = "weekly",
        weight = 2,
    },
}

return RankingConfig
