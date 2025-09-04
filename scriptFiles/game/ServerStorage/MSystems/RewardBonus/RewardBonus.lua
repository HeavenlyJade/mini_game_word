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
---@param uniqueId string 奖励等级唯一ID
---@return boolean 是否已领取
function RewardBonus:IsTierClaimed(configName, uniqueId)
    local claimedTiers = self:GetClaimedTiers(configName)
    local claimed = claimedTiers[uniqueId]
    return claimed and claimed.isTier == true
end

--- 获取指定配置的可领取等级列表
---@param configName string 配置名称
---@return string[] 可领取的等级唯一ID列表
function RewardBonus:GetAvailableTiers(configName)
    local config = ConfigLoader.GetRewardBonus(configName)
    if not config then
        gg.log("错误：奖励配置不存在", configName)
        return {}
    end

    local availableTiers = {}
    local claimedTiers = self:GetClaimedTiers(configName)

    -- 遍历所有奖励等级
    for uniqueId, tier in pairs(config:GetRewardTierMap()) do
        -- 检查是否已领取
        if not self:IsTierClaimed(configName, uniqueId) then
            -- 检查条件是否满足
            if self:CheckTierCondition(tier.ConditionFormula, configName) then
                table.insert(availableTiers, uniqueId)
            end
        end
    end

    return availableTiers
end

--- 检查等级条件是否满足
---@param conditionFormula string 条件公式
---@param configName string 配置名称（用于获取计算方式）
---@return boolean 是否满足条件
function RewardBonus:CheckTierCondition(conditionFormula, configName)
    local ShopMgr = require(ServerStorage.MSystems.Shop.ShopMgr) ---@type ShopMgr

    gg.log("=== CheckTierCondition 开始检查 ===")
    gg.log("玩家ID:", self.uin)
    gg.log("条件公式:", conditionFormula)
    gg.log("配置名称:", configName)


    -- 如果提供了配置名称，检查计算方式

    local config = ConfigLoader.GetRewardBonus(configName)
    gg.log("获取到的配置:", config ~= nil)
    if config then
        local calculationMethod = config:GetCalculationMethod()
        gg.log("计算方式:", calculationMethod)
        
        if calculationMethod == "迷你币" then
            -- 获取玩家商城数据
            local shopData = ShopMgr.GetPlayerShop(self.uin)
            gg.log("商城数据:", shopData ~= nil)
            if not shopData then
                gg.log("错误：无法获取玩家商城数据", self.uin)
                return false
            end
            
            local consumedMiniCoin = shopData.totalPurchaseValue or 0
            gg.log("玩家已消耗迷你币:", consumedMiniCoin)
            
            -- 使用迷你币验证方式
            local isValid = config:ValidateMiniCoinConsumption({}, consumedMiniCoin)
            gg.log("迷你币验证结果:", isValid)
            return isValid
        else
            gg.log("计算方式不是迷你币，跳过迷你币验证")
        end
    else
        gg.log("错误：无法获取配置", configName)
    end
    
    if not conditionFormula or conditionFormula == "" then
        gg.log("条件公式为空，返回false")
        return false -- 
    end

    -- 构造伪等级对象用于条件检查
    local tier = { ConditionFormula = conditionFormula }
    gg.log("构造的等级对象:", tier)
    
    -- 使用RewardBonusType的条件检测方法
    -- 这里需要从缓存中获取任一配置来调用方法（所有配置的检测逻辑相同）
    gg.log("配置缓存:", self.configCache)
    for _, config in pairs(self.configCache or {}) do
        gg.log("使用缓存配置进行条件检查")
        local result = config:CheckTierCondition(tier, {}, nil)
        gg.log("条件检查结果:", result)
        return result
    end
    
    -- 如果缓存为空，回退到简单检查
    gg.log("警告：配置缓存为空，使用简化条件检查", conditionFormula)
    return false
end

--- 领取指定等级的奖励
---@param configName string 配置名称
---@param uniqueId string 奖励等级唯一ID
---@return boolean 是否成功
---@return string 结果消息
---@return table|nil 奖励列表
function RewardBonus:ClaimTierReward(configName, uniqueId)
    -- 参数验证
    if not configName or not uniqueId then
        return false, "参数无效", nil
    end
    gg.log("领取奖励等级", configName, uniqueId,self.cloudData.configs)
    -- 检查配置是否存在
    if not self:HasConfig(configName) then
        return false, "配置不存在", nil
    end

    -- -- 检查是否已领取
    if self:IsTierClaimed(configName, uniqueId) then
        return false, "奖励已被领取", nil
    end

    local config = ConfigLoader.GetRewardBonus(configName)
    if not config then
        gg.log("错误：找不到奖励配置", configName, "所有可用配置:", ConfigLoader.GetAllRewardBonuses())
        return false, "奖励配置不存在", nil
    end

    local tier = config:GetRewardTierById(uniqueId)
    if not tier then
        return false, "等级配置不存在", nil
    end

    -- 检查条件是否满足
    if not self:CheckTierCondition(tier.ConditionFormula, configName) then
        return false, "条件不满足", nil
    end

    -- 标记为已领取
    if not self.cloudData.configs[configName] then
        self.cloudData.configs[configName] = RewardBonusCloudDataMgr.CreateDefaultConfigData(configName)
    end
    
    self.cloudData.configs[configName].claimedTiers[uniqueId] = {
        collectionTime = gg.GetTimeStamp(),
        isTier = true
    }

    -- 转换奖励物品格式为PlayerRewardDispatcher期望的格式
    local convertedRewards = {}
    for _, rewardItem in ipairs(tier.RewardItemList) do
                local convertedReward = {
            itemType = rewardItem.RewardType,
            amount = rewardItem.Quantity,
            stars = rewardItem.Stars or 1
        }
        
        -- 根据奖励类型设置不同的字段
        if rewardItem.RewardType == "物品" then
            convertedReward.itemName = rewardItem.Item
        elseif rewardItem.RewardType == "宠物" then
            convertedReward.itemName = rewardItem.PetConfig
        elseif rewardItem.RewardType == "伙伴" then
            convertedReward.itemName = rewardItem.PartnerConfig
        elseif rewardItem.RewardType == "翅膀" then
            convertedReward.itemName = rewardItem.WingConfig
        end
        
        table.insert(convertedRewards, convertedReward)
    end
    
    gg.log("领取奖励等级成功", self.uin, configName, uniqueId, "奖励数量:", #convertedRewards)
    gg.log("转换后的奖励格式:", convertedRewards)
    
    return true, "领取成功", convertedRewards
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
        claimedTiers = claimedTiers, -- 添加已领取的奖励列表
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