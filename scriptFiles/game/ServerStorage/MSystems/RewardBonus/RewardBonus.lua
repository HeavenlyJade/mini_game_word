-- RewardBonus.lua
-- 奖励加成核心数据类
-- 使用新的云端多配置数据结构，舍弃旧版数据兼容

local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local RewardBonusType = require(MainStorage.Code.Common.TypeConfig.RewardBonusType) ---@type RewardBonusType
local RewardBonusCloudDataMgr = require(game:GetService("ServerStorage").MSystems.RewardBonus.RewardBonusCloudDataMgr) ---@type RewardBonusCloudDataMgr

---@class RewardBonus : Class
---@field uin number 玩家ID
---@field cloudData RewardBonusCloudData 云端数据引用
local RewardBonus = ClassMgr.Class("RewardBonus")

--- 初始化
---@param uin number 玩家ID
---@param cloudData RewardBonusCloudData|nil 云端数据
function RewardBonus:OnInit(uin, cloudData)
    if not uin then
        gg.log("错误：RewardBonus初始化时玩家ID无效")
        return
    end
    
    self.uin = uin
    
    -- 使用传入的云端数据或加载数据
    if cloudData then
        self.cloudData = cloudData
    else
        local ret, data = RewardBonusCloudDataMgr.LoadPlayerData(uin)
        if ret == 0 then
            self.cloudData = data
        else
            gg.log("错误：加载玩家奖励加成数据失败", uin)
            self.cloudData = RewardBonusCloudDataMgr.CreateDefaultData()
        end
    end
    
    gg.log("RewardBonus初始化完成", uin, "配置数量:", self:GetConfigCount())
end

--- 获取配置数量
---@return number 配置数量
function RewardBonus:GetConfigCount()
    if not self.cloudData or not self.cloudData.configs then
        return 0
    end
    
    local count = 0
    for _ in pairs(self.cloudData.configs) do
        count = count + 1
    end
    return count
end

--- 获取所有配置名称
---@return string[] 配置名称列表
function RewardBonus:GetAllConfigNames()
    local names = {}
    if self.cloudData and self.cloudData.configs then
        for configName in pairs(self.cloudData.configs) do
            table.insert(names, configName)
        end
    end
    return names
end

--- 检查配置是否存在
---@param configName string 配置名称
---@return boolean 是否存在
function RewardBonus:HasConfig(configName)
    return self.cloudData and 
           self.cloudData.configs and 
           self.cloudData.configs[configName] ~= nil
end

--- 获取指定配置的已领取等级记录
---@param configName string 配置名称
---@return table<number, RewardTierClaimed> 已领取等级记录
function RewardBonus:GetClaimedTiers(configName)
    if not self:HasConfig(configName) then
        gg.log("错误：配置不存在", self.uin, configName)
        return {}
    end
    
    return self.cloudData.configs[configName].claimedTiers or {}
end

--- 检查等级是否已被领取
---@param configName string 配置名称
---@param tierIndex number 等级索引
---@return boolean 是否已领取
function RewardBonus:IsTierClaimed(configName, tierIndex)
    local claimedTiers = self:GetClaimedTiers(configName)
    local claimed = claimedTiers[tierIndex]
    return claimed and claimed.isTier == true
end

--- 获取指定配置的可领取等级列表
---@param configName string 配置名称
---@param playerProgress table 玩家进度数据
---@return number[] 可领取的等级索引列表
function RewardBonus:GetAvailableTiers(configName, playerProgress)
    if not playerProgress then
        gg.log("错误：玩家进度数据为空", self.uin, configName)
        return {}
    end

    local config = ConfigLoader.GetRewardBonus(configName)
    if not config then
        gg.log("错误：奖励配置不存在", configName)
        return {}
    end

    local availableTiers = {}
    local claimedTiers = self:GetClaimedTiers(configName)

    -- 遍历所有奖励等级
    for tierIndex, tier in ipairs(config.RewardTierList) do
        -- 检查是否已领取
        if not self:IsTierClaimed(configName, tierIndex) then
            -- 检查条件是否满足
            if self:CheckTierCondition(tier.ConditionFormula, playerProgress) then
                table.insert(availableTiers, tierIndex)
            end
        end
    end

    return availableTiers
end

--- 检查等级条件是否满足
---@param conditionFormula string 条件公式
---@param playerProgress table 玩家进度数据
---@return boolean 是否满足条件
function RewardBonus:CheckTierCondition(conditionFormula, playerProgress)
    if not conditionFormula or conditionFormula == "" then
        return true -- 无条件限制，默认通过
    end

    -- 构造伪等级对象用于条件检查
    local tier = { ConditionFormula = conditionFormula }
    
    -- 使用RewardBonusType的条件检测方法
    -- 这里需要从缓存中获取任一配置来调用方法（所有配置的检测逻辑相同）
    for _, config in pairs(self.configCache) do
        return config:CheckTierCondition(tier, playerProgress, nil)
    end
    
    -- 如果缓存为空，回退到简单检查
    gg.log("警告：配置缓存为空，使用简化条件检查", conditionFormula)
    return false
end

--- 领取指定等级的奖励
---@param configName string 配置名称
---@param tierIndex number 等级索引
---@param playerProgress table 玩家进度数据
---@return RewardItem[]|nil, string|nil 奖励列表, 错误信息
function RewardBonus:ClaimTierReward(configName, tierIndex, playerProgress)
    -- 参数验证
    if not configName or not tierIndex or not playerProgress then
        return nil, "参数无效"
    end

    -- 检查配置是否存在
    if not self:HasConfig(configName) then
        return nil, "配置不存在"
    end

    -- 检查是否已领取
    if self:IsTierClaimed(configName, tierIndex) then
        return nil, "奖励已被领取"
    end

    local config = ConfigLoader.GetRewardBonus(configName)
    if not config or not config.RewardTierList[tierIndex] then
        return nil, "等级配置不存在"
    end

    local tier = config.RewardTierList[tierIndex]

    -- 检查条件是否满足
    if not self:CheckTierCondition(tier.ConditionFormula, playerProgress) then
        return nil, "条件不满足"
    end

    -- 标记为已领取
    if not self.cloudData.configs[configName] then
        self.cloudData.configs[configName] = RewardBonusCloudDataMgr.CreateDefaultConfigData(configName)
    end
    
    self.cloudData.configs[configName].claimedTiers[tierIndex] = {
        collectionTime = gg.GetTimeStamp(),
        isTier = true
    }

    -- 返回奖励物品
    local rewardItems = self:SelectRewardsByWeight(tier.RewardItemList, tier.Weight)
    
    gg.log("领取奖励等级成功", self.uin, configName, tierIndex, "奖励数量:", #rewardItems)
    
    return rewardItems, nil
end

--- 根据权重选择奖励
---@param rewardItemList RewardItem[] 奖励列表
---@param weight number 权重
---@return RewardItem[] 选中的奖励
function RewardBonus:SelectRewardsByWeight(rewardItemList, weight)
    -- 简化实现：返回所有奖励
    return rewardItemList or {}
end

--- 获取指定配置的状态信息
---@param configName string 配置名称
---@param playerProgress table 玩家进度数据
---@return table|nil 状态信息
function RewardBonus:GetConfigStatus(configName, playerProgress)
    if not self:HasConfig(configName) then
        return nil
    end

    local claimedTiers = self:GetClaimedTiers(configName)
    local availableTiers = self:GetAvailableTiers(configName, playerProgress)

    -- 统计已领取数量
    local claimedCount = 0
    for _ in pairs(claimedTiers) do
        claimedCount = claimedCount + 1
    end

    return {
        configName = configName,
        claimedTierCount = claimedCount,
        availableTierCount = #availableTiers,
        availableTiers = availableTiers,
        hasAvailableRewards = #availableTiers > 0
    }
end

--- 获取所有配置的状态概览
---@param playerProgress table 玩家进度数据
---@return table 状态概览
function RewardBonus:GetAllConfigsStatus(playerProgress)
    local allStatus = {}
    local totalAvailableCount = 0

    for configName in pairs(self.cloudData.configs or {}) do
        local status = self:GetConfigStatus(configName, playerProgress)
        if status then
            allStatus[configName] = status
            totalAvailableCount = totalAvailableCount + status.availableTierCount
        end
    end

    return {
        configs = allStatus,
        totalAvailableCount = totalAvailableCount,
        hasAnyAvailableRewards = totalAvailableCount > 0
    }
end

--- 重置指定配置的数据
---@param configName string 配置名称
function RewardBonus:ResetConfig(configName)
    if not self:HasConfig(configName) then
        gg.log("错误：尝试重置不存在的配置", self.uin, configName)
        return
    end

    self.cloudData.configs[configName] = RewardBonusCloudDataMgr.CreateDefaultConfigData(configName)
    gg.log("重置配置数据", self.uin, configName)
end

--- 添加新配置（自动检测）
function RewardBonus:UpdateConfigsFromLoader()
    local allConfigs = ConfigLoader.GetAllRewardBonuses()
    if not allConfigs then
        return
    end

    local addedCount = 0
    for configName in pairs(allConfigs) do
        if not self:HasConfig(configName) then
            self.cloudData.configs[configName] = RewardBonusCloudDataMgr.CreateDefaultConfigData(configName)
            addedCount = addedCount + 1
            gg.log("自动添加新配置", self.uin, configName)
        end
    end

    if addedCount > 0 then
        gg.log("检测到新配置，已自动添加", self.uin, addedCount)
    end
end

--- 保存数据到云端
---@return boolean 是否保存成功
function RewardBonus:SaveToCloud()
    return RewardBonusCloudDataMgr.SavePlayerData(self.uin, self.cloudData)
end

--- 获取云端数据引用（用于管理器保存）
---@return RewardBonusCloudData 云端数据
function RewardBonus:GetCloudData()
    return self.cloudData
end

--- 调试信息：打印所有配置状态
---@param playerProgress table 玩家进度数据
function RewardBonus:DebugPrintStatus(playerProgress)
    gg.log("=== RewardBonus调试信息 ===", self.uin)
    gg.log("云端配置数量:", self:GetConfigCount())
    gg.log("缓存配置数量:", self:GetCachedConfigCount())
    
    -- 打印缓存的配置名称
    local cachedNames = {}
    for configName in pairs(self.configCache) do
        table.insert(cachedNames, configName)
    end
    gg.log("缓存的配置:", table.concat(cachedNames, ", "))
    
    -- 打印各配置状态
    for configName in pairs(self.cloudData.configs or {}) do
        local status = self:GetConfigStatus(configName, playerProgress)
        if status then
            local configInfo = self:GetConfigInfo(configName)
            gg.log(string.format("配置[%s]: 已领取%d个, 可领取%d个, 总等级%d个", 
                configName, status.claimedTierCount, status.availableTierCount, 
                configInfo and configInfo.tierCount or 0))
        end
    end
end

return RewardBonus