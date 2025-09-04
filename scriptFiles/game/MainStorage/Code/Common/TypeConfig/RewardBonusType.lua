-- RewardBonusType.lua
-- 定义了奖励配置的数据结构和处理逻辑

local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class RewardItem
---@field RewardType string 奖励类型 (例如 "物品", "宠物", "伙伴", "翅膀")
---@field Item string|nil 物品名称
---@field WingConfig string|nil 翅膀配置名称
---@field PetConfig string|nil 宠物配置名称
---@field PartnerConfig string|nil 伙伴配置名称
---@field Quantity number 数量
---@field Star number 星级

---@class RewardTier
---@field ConditionFormula string 条件公式
---@field CostMiniCoin number 消耗迷你币数量
---@field Weight number 权重
---@field RewardItemList RewardItem[] 奖励物品列表

---@class RewardBonusType : Class
---@field ConfigName string 配置名称
---@field Description string 描述
---@field RewardType string 奖励类型
---@field ResetCycle string 重置周期
---@field CalculationMethod string 计算方式
---@field RewardTierList RewardTier[] 奖励等级列表
local RewardBonusType = ClassMgr.Class("RewardBonusType")

--- 初始化
---@param configData table<string, any> 从 RewardBonusConfig.lua 中读取的单条原始配置数据
function RewardBonusType:OnInit(configData)
    self.ConfigName = configData['配置名称'] or ""
    self.Description = configData['描述'] or ""
    self.RewardType = configData['奖励类型'] or ""
    self.ResetCycle = configData['重置周期'] or ""
    self.CalculationMethod = configData['计算方式'] or ""
    self.RewardTierList = {}

    -- 解析奖励等级列表
    local rawRewardTierList = configData['奖励列表'] or {}
    for _, tierData in ipairs(rawRewardTierList) do
        local rewardItemList = {}
        local rawRewardItemList = tierData['奖励物品列表'] or {}
        
        for _, itemData in ipairs(rawRewardItemList) do
            local rewardItem = {
                RewardType = itemData['奖励类型'] or "",
                Item = itemData['物品'],
                WingConfig = itemData['翅膀配置'],
                PetConfig = itemData['宠物配置'],
                PartnerConfig = itemData['伙伴配置'],
                Quantity = itemData['数量'] or 0,
                Stars = itemData['星级'] or 1
            }
            table.insert(rewardItemList, rewardItem)
        end

        ---@type RewardTier
        local rewardTier = {
            ConditionFormula = tierData['条件公式'] or "",
            CostMiniCoin = tierData['消耗迷你币'] or 0,
            Weight = tierData['权重'] or 1,
            RewardItemList = rewardItemList,
            Description = tierData['描述'] or "",

        }
        table.insert(self.RewardTierList, rewardTier)
    end
end

--- 获取配置名称
---@return string
function RewardBonusType:GetConfigName()
    return self.ConfigName
end

--- 获取奖励类型
---@return string
function RewardBonusType:GetRewardType()
    return self.RewardType
end

--- 获取重置周期
---@return string
function RewardBonusType:GetResetCycle()
    return self.ResetCycle
end

--- 获取计算方式
---@return string
function RewardBonusType:GetCalculationMethod()
    return self.CalculationMethod
end

--- 获取所有奖励等级列表
---@return RewardTier[]
function RewardBonusType:GetRewardTierList()
    return self.RewardTierList
end

--- 根据条件获取符合条件的奖励等级
---@param playerData table 玩家数据
---@param externalContext table|nil 外部上下文
---@return RewardTier[] 符合条件的奖励等级列表
function RewardBonusType:GetEligibleRewardTiers(playerData, externalContext)
    local eligibleTiers = {}
    
    for _, tier in ipairs(self.RewardTierList) do
        if self:CheckTierCondition(tier, playerData, externalContext) then
            table.insert(eligibleTiers, tier)
        end
    end
    
    return eligibleTiers
end

--- 检查奖励等级条件是否满足
---@param tier RewardTier 奖励等级
---@param playerData table 玩家数据
---@param externalContext table|nil 外部上下文
---@return boolean 是否满足条件
function RewardBonusType:CheckTierCondition(tier, playerData, externalContext)
    if not tier.ConditionFormula or tier.ConditionFormula == "" then
        return false -- 无条件限制，默认通过
    end
    
    -- 使用gg.eval计算条件公式
    local result = self:EvaluateCondition(tier.ConditionFormula, playerData, externalContext)
    return result == true
end

--- 计算公式或条件
---@param expression string 表达式
---@param playerData table 玩家数据
---@param externalContext table|nil 外部上下文
---@return any 计算结果
function RewardBonusType:EvaluateCondition(expression, playerData, externalContext)
    if not expression or type(expression) ~= "string" then
        return false
    end

    -- 预处理表达式，替换变量
    local processedExpression = self:ProcessExpression(expression, playerData, externalContext)
    
    -- 判断是条件表达式还是数值表达式
    local hasComparison = processedExpression:match("[<>=~]")
    
    if hasComparison then
        -- 条件表达式：使用全局的条件检测器
        return gg.evaluateCondition(processedExpression)
    else
        -- 数值表达式：使用 gg.eval
        local result = gg.eval(processedExpression)
        return result and result ~= 0
    end
end

--- 预处理表达式，将所有变量替换为实际数值
---@param expression string 原始表达式
---@param playerData table 玩家数据
---@param externalContext table|nil 外部上下文
---@return string 处理后的表达式
function RewardBonusType:ProcessExpression(expression, playerData, externalContext)
    local processed = expression

    -- 替换玩家变量: $变量名$
    processed = string.gsub(processed, "%$([^$]+)%$", function(varName)
        local varValue = self:GetPlayerVariable(playerData, varName)
        return gg.numberToString(varValue)
    end)

    -- 替换玩家属性: {属性名}
    processed = string.gsub(processed, "{([^}]+)}", function(varName)
        local attrValue = self:GetPlayerAttribute(playerData, varName)
        return gg.numberToString(attrValue)
    end)

    -- 替换外部上下文变量
    if externalContext then
        for varName, varValue in pairs(externalContext) do
            local pattern = "%f[%w_]" .. varName .. "%f[^%w_]"
            processed = string.gsub(processed, pattern, gg.numberToString(varValue))
        end
    end

    return processed
end

--- 获取玩家变量值
---@param playerData table 玩家数据
---@param varName string 变量名
---@return number
function RewardBonusType:GetPlayerVariable(playerData, varName)
    if not playerData or not varName then
        return 0
    end
    
    local varData = playerData[varName]
    
    if type(varData) == "string" then
        return tonumber(varData) or 0
    elseif type(varData) == "number" then
        return varData
    else
        return 0
    end
end


--- 根据权重随机选择一个奖励等级
---@param eligibleTiers RewardTier[] 符合条件的奖励等级列表
---@return RewardTier|nil 选中的奖励等级
function RewardBonusType:SelectRewardTierByWeight(eligibleTiers)
    if not eligibleTiers or #eligibleTiers == 0 then
        return nil
    end
    
    if #eligibleTiers == 1 then
        return eligibleTiers[1]
    end
    
    -- 计算总权重
    local totalWeight = 0
    for _, tier in ipairs(eligibleTiers) do
        totalWeight = totalWeight + tier.Weight
    end
    
    if totalWeight <= 0 then
        return eligibleTiers[1] -- 如果权重都为0，返回第一个
    end
    
    -- 随机选择
    local randomValue = math.random() * totalWeight
    local currentWeight = 0
    
    for _, tier in ipairs(eligibleTiers) do
        currentWeight = currentWeight + tier.Weight
        if randomValue <= currentWeight then
            return tier
        end
    end
    
    return eligibleTiers[#eligibleTiers] -- 兜底返回最后一个
end

--- 获取指定消耗迷你币数量的奖励等级
---@param costMiniCoin number 消耗的迷你币数量
---@return RewardTier|nil 匹配的奖励等级
function RewardBonusType:GetRewardTierByCost(costMiniCoin)
    if not costMiniCoin or costMiniCoin < 0 then
        return nil
    end
    
    for _, tier in ipairs(self.RewardTierList) do
        if tier.CostMiniCoin == costMiniCoin then
            return tier
        end
    end
    
    return nil
end

--- 获取所有奖励物品的汇总信息
---@return table<string, number> 物品名称 -> 总数量的映射表
function RewardBonusType:GetAllRewardItemsSummary()
    local summary = {}
    
    for _, tier in ipairs(self.RewardTierList) do
        for _, item in ipairs(tier.RewardItemList) do
            local itemKey = self:GetItemKey(item)
            if itemKey then
                summary[itemKey] = (summary[itemKey] or 0) + item.Quantity
            end
        end
    end
    
    return summary
end

--- 获取奖励物品的唯一标识
---@param item RewardItem 奖励物品
---@return string|nil 物品唯一标识
function RewardBonusType:GetItemKey(item)
    if not item then
        return nil
    end
    
    if item.RewardType == "物品" and item.Item then
        return "物品:" .. item.Item
    elseif item.RewardType == "宠物" and item.PetConfig then
        return "宠物:" .. item.PetConfig
    elseif item.RewardType == "伙伴" and item.PartnerConfig then
        return "伙伴:" .. item.PartnerConfig
    elseif item.RewardType == "翅膀" and item.WingConfig then
        return "翅膀:" .. item.WingConfig
    end
    
    return nil
end

--- 验证玩家是否满足消耗迷你币条件
---@param playerData table 玩家数据
---@param consumedMiniCoin number 玩家已消耗的迷你币数量
---@return boolean 是否满足条件
function RewardBonusType:ValidateMiniCoinConsumption(playerData, consumedMiniCoin)
    -- 只有计算方式为迷你币时才进行验证
    if self.CalculationMethod ~= "迷你币" then
        return false
    end
    
    if not consumedMiniCoin or consumedMiniCoin < 0 then
        gg.log("错误：[RewardBonus] 消耗迷你币数量无效")
        return false
    end
    
    -- 检查是否有任何奖励等级满足消耗迷你币条件
    for _, tier in ipairs(self.RewardTierList) do
        if consumedMiniCoin >= tier.CostMiniCoin then
            return true
        end
    end
    
    return false
end

--- 获取玩家可领取的奖励等级列表（基于消耗迷你币）
---@param playerData table 玩家数据
---@param consumedMiniCoin number 玩家已消耗的迷你币数量
---@return RewardTier[] 可领取的奖励等级列表
function RewardBonusType:GetAvailableRewardTiers(playerData, consumedMiniCoin)
    local availableTiers = {}
    
    -- 只有计算方式为迷你币时才进行验证
    if self.CalculationMethod ~= "迷你币" then
        return self:GetEligibleRewardTiers(playerData, {consumedMiniCoin = consumedMiniCoin})
    end
    
    if not consumedMiniCoin or consumedMiniCoin < 0 then
        return availableTiers
    end
    
    for _, tier in ipairs(self.RewardTierList) do
        if consumedMiniCoin >= tier.CostMiniCoin then
            table.insert(availableTiers, tier)
        end
    end
    
    return availableTiers
end

--- 验证奖励配置的有效性
---@return boolean 配置是否有效
function RewardBonusType:ValidateConfig()
    if not self.ConfigName or self.ConfigName == "" then
        gg.log("错误：[RewardBonus] 配置名称不能为空")
        return false
    end
    
    if not self.RewardType or self.RewardType == "" then
        gg.log("错误：[RewardBonus] 奖励类型不能为空")
        return false
    end
    
    if not self.RewardTierList or #self.RewardTierList == 0 then
        gg.log("错误：[RewardBonus] 奖励等级列表不能为空")
        return false
    end
    
    -- 验证每个奖励等级
    for i, tier in ipairs(self.RewardTierList) do
        if not tier.RewardItemList or #tier.RewardItemList == 0 then
            gg.log(string.format("错误：[RewardBonus] 第%d个奖励等级的奖励物品列表不能为空", i))
            return false
        end
        
        if tier.CostMiniCoin < 0 then
            gg.log(string.format("错误：[RewardBonus] 第%d个奖励等级的消耗迷你币不能为负数", i))
            return false
        end
        
        if tier.Weight <= 0 then
            gg.log(string.format("错误：[RewardBonus] 第%d个奖励等级的权重必须大于0", i))
            return false
        end
    end
    
    return true
end

return RewardBonusType
