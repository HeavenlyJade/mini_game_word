-- RewardBonusCloudDataMgr.lua
-- 奖励加成云数据管理器
-- 负责多配置数据结构定义、序列化、云存储格式
-- 只包含读取和存储功能

local MainStorage = game:GetService("MainStorage")
local cloudService = game:GetService("CloudService") ---@type CloudService
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader

---@class RewardTierClaimed
---@field collectionTime number 领取时间戳
---@field isTier boolean 是否为有效等级

---@class RewardConfigData
---@field claimedTiers table<number, RewardTierClaimed> 已领取等级记录

---@class RewardBonusCloudData
---@field lastSaveTime number 最后保存时间戳
---@field configs table<string, RewardConfigData> 配置数据字典 key为configName

---@class RewardBonusCloudDataMgr
local RewardBonusCloudDataMgr = {
    -- 云存储key配置
    CLOUD_KEY_PREFIX = "reward_bonus_cloud", -- 奖励加成数据key前缀


}

--- 读取玩家的奖励加成数据
---@param uin number 玩家ID
---@return number, RewardBonusCloudData 返回码(0成功,1失败), 奖励加成数据
function RewardBonusCloudDataMgr.LoadPlayerData(uin)
    if not uin then
        gg.log("错误：玩家ID无效")
        return 1, RewardBonusCloudDataMgr.CreateDefaultData()
    end

    local cloudKey = RewardBonusCloudDataMgr.GetCloudKey(uin)
    local success, cloudData = cloudService:GetTableOrEmpty(cloudKey)
        
    gg.log("读取玩家奖励加成数据", cloudKey, success, cloudData ~= nil)

    if success then
        if cloudData then
            -- 检查并更新配置数据
            cloudData = RewardBonusCloudDataMgr.UpdateConfigsIfNeeded(cloudData)
            gg.log("从云端加载奖励加成数据成功", uin)
            return 0, cloudData
        else
            gg.log("云端无奖励加成数据，创建默认数据", uin)
            return 0, RewardBonusCloudDataMgr.CreateDefaultData()
        end
    else
        gg.log("读取云端奖励加成数据失败，创建默认数据", uin)
        return 1, RewardBonusCloudDataMgr.CreateDefaultData()
    end
end

--- 保存玩家奖励加成数据
---@param uin number 玩家ID
---@param rewardBonusData RewardBonusCloudData 奖励加成数据
---@return boolean 是否保存成功
function RewardBonusCloudDataMgr.SavePlayerData(uin, rewardBonusData)
    if not uin or not rewardBonusData then
        gg.log("错误：保存奖励加成数据参数无效", uin, rewardBonusData ~= nil)
        return false
    end

    -- 更新保存时间
    rewardBonusData.lastSaveTime = gg.GetTimeStamp()

    local cloudKey = RewardBonusCloudDataMgr.GetCloudKey(uin)
        
    -- 同步保存
    cloudService:SetTableAsync(cloudKey, rewardBonusData, function(result)
        if result then
            gg.log("奖励加成数据同步保存成功", uin)
        else
            gg.log("奖励加成数据同步保存失败", uin)
        end
    end)
      
    return true
end

--- 创建默认数据
---@return RewardBonusCloudData 默认奖励加成数据
function RewardBonusCloudDataMgr.CreateDefaultData()
    local defaultConfigs = {}
    local allBonusConfigs = ConfigLoader.GetAllRewardBonuses()

    if allBonusConfigs then
        for configName, _ in pairs(allBonusConfigs) do
            defaultConfigs[configName] = RewardBonusCloudDataMgr.CreateDefaultConfigData(configName)
        end
    end

    return {
        lastSaveTime = gg.GetTimeStamp(),
        configs = defaultConfigs
    }
end

--- 创建默认配置数据
---@param configName string 配置名称
---@return table 默认配置数据
function RewardBonusCloudDataMgr.CreateDefaultConfigData(configName)
    return {
        claimedTiers = {} -- {UniqueId = {collectionTime=时间戳, isTier=true}}
    }
end

--- 检查并更新配置数据，如果存在新的奖励配置则自动添加
---@param cloudData RewardBonusCloudData 云端数据
function RewardBonusCloudDataMgr.UpdateConfigsIfNeeded(cloudData)
    if not cloudData or not cloudData.configs then
        return cloudData
    end

    local allBonusConfigs = ConfigLoader.GetAllRewardBonuses()
    if not allBonusConfigs then
        return cloudData
    end

    
    -- 检查是否有新的配置需要添加
    for configName, _ in pairs(allBonusConfigs) do
        if not cloudData.configs[configName] then
            cloudData.configs[configName] = RewardBonusCloudDataMgr.CreateDefaultConfigData(configName)
            gg.log("检测到新的奖励配置，已自动添加", configName)
        end
    end

    return cloudData
end



--- 获取云存储键名
---@param uin number 玩家ID
---@return string 云存储键名
function RewardBonusCloudDataMgr.GetCloudKey(uin)
    return RewardBonusCloudDataMgr.CLOUD_KEY_PREFIX .. uin
end

return RewardBonusCloudDataMgr