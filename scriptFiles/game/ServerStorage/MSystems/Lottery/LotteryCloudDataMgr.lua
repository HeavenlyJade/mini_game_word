-- LotteryCloudDataMgr.lua
-- 抽奖云数据结构管理器
-- 负责定义抽奖数据的存储格式、序列化和反序列化逻辑

local game = game
local os = os

local MainStorage = game:GetService("MainStorage")
local cloudService = game:GetService("CloudService")   ---@type CloudService
local gg = require(MainStorage.Code.Untils.MGlobal)    ---@type gg

---@class LotteryPoolData
---@field poolName string 抽奖池名称
---@field totalDraws number 总抽奖次数
---@field pityCount number 保底计数
---@field lastDrawTime number 最后抽奖时间戳

---@class LotteryRecord
---@field poolName string 抽奖池名称
---@field rewardType string 奖励类型
---@field rewardName string 奖励名称
---@field quantity number 奖励数量
---@field drawTime number 抽奖时间戳
---@field isPity boolean 是否为保底
---@field rarity string 稀有度

---@class LotteryPoolStats
---@field totalCost number 总消耗货币数量
---@field rarityStats table<string, number> 稀有度统计 {rarity = count}
---@field rewardTypeStats table<string, number> 奖励类型统计 {type = count}
---@field pityTriggerCount number 保底触发次数
---@field bestRewardTime number 最高价值奖励获得时间

---@class PlayerLotteryData
---@field lotteryPools table<string, LotteryPoolData> 各抽奖池数据 {poolName = poolData}
---@field drawHistory LotteryRecord[] 抽奖历史记录
---@field totalDrawCount number 总抽奖次数
---@field poolStats table<string, LotteryPoolStats> 各抽奖池统计数据 {poolName = statsData}

---@class LotteryCloudDataMgr
local LotteryCloudDataMgr = {
    -- 云存储key配置
    CLOUD_KEY_PREFIX = "lottery_player_key", -- 抽奖数据key前缀
}

--- 加载玩家抽奖数据
---@param uin number 玩家ID
---@return PlayerLotteryData 玩家抽奖数据
function LotteryCloudDataMgr.LoadPlayerLotteryData(uin)
    local ret, data = cloudService:GetTableOrEmpty(LotteryCloudDataMgr.CLOUD_KEY_PREFIX .. uin)

    if ret and data and data.lotteryPools then
        return data
    else
        -- 创建默认抽奖数据
        return {
            lotteryPools = {},
            drawHistory = {},
            totalDrawCount = 0,
            poolStats = {},
        }
    end
end

--- 保存玩家抽奖数据
---@param uin number 玩家ID
---@param lotteryData PlayerLotteryData
---@return boolean 是否成功
function LotteryCloudDataMgr.SavePlayerLotteryData(uin, lotteryData)
    if not lotteryData then
        return false
    end

    -- 保存到云存储
    cloudService:SetTableAsync(LotteryCloudDataMgr.CLOUD_KEY_PREFIX .. uin, lotteryData, function(success)
        if not success then
            --gg.log("保存玩家抽奖数据失败", uin)
        else
            -- --gg.log("保存玩家抽奖数据成功", uin)
        end
    end)

    return true
end

--- 获取指定抽奖池的统计数据
---@param uin number 玩家ID
---@param poolName string 抽奖池名称
---@return LotteryPoolStats|nil 抽奖池统计数据
function LotteryCloudDataMgr.GetPoolStats(uin, poolName)
    local data = LotteryCloudDataMgr.LoadPlayerLotteryData(uin)
    return data.poolStats[poolName]
end

--- 更新抽奖池统计数据
---@param uin number 玩家ID
---@param poolName string 抽奖池名称
---@param cost number 本次消耗
---@param rewards LotteryRecord[] 本次获得的奖励
function LotteryCloudDataMgr.UpdatePoolStats(uin, poolName, cost, rewards)
    local data = LotteryCloudDataMgr.LoadPlayerLotteryData(uin)

    -- 初始化统计数据
    if not data.poolStats[poolName] then
        data.poolStats[poolName] = {
            totalCost = 0,
            rarityStats = {},
            rewardTypeStats = {},
            pityTriggerCount = 0,
            bestRewardTime = 0,
        }
    end

    local stats = data.poolStats[poolName]
    stats.totalCost = stats.totalCost + cost

    -- 统计奖励数据
    for _, reward in ipairs(rewards) do
        -- 稀有度统计
        local rarity = reward.rarity or "N"
        stats.rarityStats[rarity] = (stats.rarityStats[rarity] or 0) + 1

        -- 奖励类型统计
        stats.rewardTypeStats[reward.rewardType] = (stats.rewardTypeStats[reward.rewardType] or 0) + 1

        -- 保底触发统计
        if reward.isPity then
            stats.pityTriggerCount = stats.pityTriggerCount + 1
        end

        -- 更新最佳奖励时间（SSR及以上）
        if rarity == "SSR" or rarity == "UR" then
            stats.bestRewardTime = reward.drawTime
        end
    end

    -- 保存更新后的数据
    LotteryCloudDataMgr.SavePlayerLotteryData(uin, data)
end

return LotteryCloudDataMgr
