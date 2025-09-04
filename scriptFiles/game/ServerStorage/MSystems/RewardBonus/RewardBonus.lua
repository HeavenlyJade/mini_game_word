-- RewardBonus.lua
-- 奖励加成核心数据类
-- 使用新的云端多配置数据结构，舍弃旧版数据兼容

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local RewardBonusType = require(MainStorage.Code.Common.TypeConfig.RewardBonusType) ---@type RewardBonusType
local RewardBonusCloudDataMgr = require(ServerStorage.MSystems.RewardBonus.RewardBonusCloudDataMgr) ---@type RewardBonusCloudDataMgr

---@class RewardBonus : Class
---@field uin number 玩家ID
---@field cloudData RewardBonusCloudData 云端数据引用
local RewardBonus = ClassMgr.Class("RewardBonus")

--- 初始化
---@param uin number 玩家ID
---@param cloudData RewardBonusCloudData|nil 云端数据
function RewardBonus:OnInit(uin, cloudData)
    self.uin = uin
    -- 使用传入的云端数据或加载数据
    if not cloudData then
        return nil
    end    self.cloudData = cloudData

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
---@return number[] 可领取的等级索引列表
function RewardBonus:GetAvailableTiers(configName)
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
            if self:CheckTierCondition(tier.ConditionFormula, configName) then
                table.insert(availableTiers, tierIndex)
            end
        end
    end

    return availableTiers
end

--- 检查等级条件是否满足
---@param conditionFormula string 条件公式
---@param configName string|nil 配置名称（用于获取计算方式）
---@return boolean 是否满足条件
function RewardBonus:CheckTierCondition(conditionFormula, configName)
    local ShopMgr = require(game:GetService("ServerStorage").MSystems.Shop.ShopMgr) ---@type ShopMgr

    if not conditionFormula or conditionFormula == "" then
        return false -- 
    end

    -- 如果提供了配置名称，检查计算方式
    if configName then
        local config = ConfigLoader.GetRewardBonus(configName)
        if config and config:GetCalculationMethod() == "迷你币" then
            -- 获取玩家商城数据
            local shopData = ShopMgr.GetPlayerShop(self.uin)
            if not shopData then
                gg.log("错误：无法获取玩家商城数据", self.uin)
                return false
            end
            
            -- 使用迷你币验证方式
            local consumedMiniCoin = shopData.totalPurchaseValue or 0
            return config:ValidateMiniCoinConsumption({}, consumedMiniCoin)
        end
    end

    -- 构造伪等级对象用于条件检查
    local tier = { ConditionFormula = conditionFormula }
    
    -- 使用RewardBonusType的条件检测方法
    -- 这里需要从缓存中获取任一配置来调用方法（所有配置的检测逻辑相同）
    for _, config in pairs(self.configCache or {}) do
        return config:CheckTierCondition(tier, {}, nil)
    end
    
    -- 如果缓存为空，回退到简单检查
    gg.log("警告：配置缓存为空，使用简化条件检查", conditionFormula)
    return false
end

--- 领取指定等级的奖励
---@param configName string 配置名称
---@param tierIndex number 等级索引
---@return boolean 是否成功
---@return string 结果消息
---@return table|nil 奖励列表
function RewardBonus:ClaimTierReward(configName, tierIndex)
    -- 参数验证
    if not configName or not tierIndex then
        return false, "参数无效", nil
    end

    -- 检查配置是否存在
    if not self:HasConfig(configName) then
        return false, "配置不存在", nil
    end

    -- 检查是否已领取
    if self:IsTierClaimed(configName, tierIndex) then
        return false, "奖励已被领取", nil
    end

    local config = ConfigLoader.GetRewardBonus(configName)
    if not config or not config.RewardTierList[tierIndex] then
        return false, "等级配置不存在", nil
    end

    local tier = config.RewardTierList[tierIndex]

    -- 检查条件是否满足
    if not self:CheckTierCondition(tier.ConditionFormula, configName) then
        return false, "条件不满足", nil
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
    
    return true, "领取成功", rewardItems
end


--- 获取指定配置的状态信息
---@param configName string 配置名称
---@return table|nil 状态信息
function RewardBonus:GetConfigStatus(configName)
    if not self:HasConfig(configName) then
        return nil
    end

    local claimedTiers = self:GetClaimedTiers(configName)
    local availableTiers = self:GetAvailableTiers(configName)

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
---@return table 状态概览
function RewardBonus:GetAllConfigsStatus()
    local allStatus = {}
    local totalAvailableCount = 0

    for configName in pairs(self.cloudData.configs or {}) do
        local status = self:GetConfigStatus(configName)
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




--- 获取云端数据引用（用于管理器保存）
---@return RewardBonusCloudData 云端数据
function RewardBonus:GetCloudData()
    return self.cloudData
end



--- 调试信息：打印所有配置状态
function RewardBonus:DebugPrintStatus()
    gg.log("=== RewardBonus调试信息 ===", self.uin)
    gg.log("云端配置数量:", self:GetConfigCount())
    gg.log("缓存配置数量:", self:GetCachedConfigCount())
    
    -- 打印缓存的配置名称
    local cachedNames = {}
    for configName in pairs(self.configCache or {}) do
        table.insert(cachedNames, configName)
    end
    gg.log("缓存的配置:", table.concat(cachedNames, ", "))
    
    -- 打印各配置状态
    for configName in pairs(self.cloudData.configs or {}) do
        local status = self:GetConfigStatus(configName)
        if status then
            local configInfo = self:GetConfigInfo(configName)
            gg.log(string.format("配置[%s]: 已领取%d个, 可领取%d个, 总等级%d个", 
                configName, status.claimedTierCount, status.availableTierCount, 
                configInfo and configInfo.tierCount or 0))
        end
    end
end

return RewardBonus