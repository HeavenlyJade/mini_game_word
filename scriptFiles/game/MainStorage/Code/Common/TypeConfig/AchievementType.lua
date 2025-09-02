-- AchievementType.lua
-- 成就类型类 - 封装成就的元数据和行为逻辑

local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local AchievementRewardCal = require(MainStorage.Code.GameReward.RewardCalc.AchievementRewardCal) ---@type AchievementRewardCal

---@class LevelEffect
---@field 效果类型 string 效果类型（如“玩家变量”）
---@field 效果字段名称 string 效果字段名称（如“加成_百分比_双倍训练”）
---@field 基础数值 number 基础数值
---@field 效果数值 string 效果数值公式（如“T_LVL*0.2”）
---@field 效果描述 string 效果描述
---@field 等级 number|nil 适用等级，可选

---@class UpgradeCondition
---@field 消耗名称 string 物品名称
---@field 消耗数量 string 消耗数量公式（如“T_LVL*2+10”）
---@field 消耗类型 string|nil 消耗类型 (例如 "物品", "玩家变量")

---@class AchievementType : Class
---@field id string 成就唯一ID
---@field name string 成就名称
---@field type string 成就类型 ("普通成就" 或 "天赋成就")
---@field description string 成就描述
---@field icon string 成就图标路径
---@field unlockConditions table[] 解锁条件列表
---@field unlockRewards table[] 解锁奖励列表
---@field maxLevel number|nil 最大等级 (天赋成就专用)
---@field upgradeConditions UpgradeCondition[]|nil 升级条件列表 (天赋成就专用)
---@field costConfigName string|nil 消耗配置名称，关联到ActionCostConfig
---@field actionCostType ActionCostType|nil 对应的消耗配置实例
---@field levelEffects LevelEffect[]|nil 等级效果列表 (天赋成就专用)
local AchievementType = ClassMgr.Class("AchievementType")

--- 初始化成就类型
---@param data table 配置数据
function AchievementType:OnInit(data)
   local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader)
   -- 基本信息
   self.id = data["名字"]
   self.name = data["名字"]
   self.type = data["类型"] or "普通成就"
   self.description = data["描述"] or ""
   self.icon = data["图标"] or ""
   self.sort = data["排序"] or 1
   -- 解锁相关
   self.unlockConditions = data["解锁条件"] or {}
   self.unlockRewards = data["解锁奖励"] or {}

   -- 天赋成就专用字段
   self.maxLevel = data["最大等级"]
   self.upgradeConditions = data["升级条件"]
   self.levelEffects = data["等级效果"]
   self.costConfigName = data["消耗配置"]
   if self.costConfigName then
       self.actionCostType = ConfigLoader.GetActionCost(self.costConfigName)
   else
       self.actionCostType = nil
   end
   self._rewardCalculator = AchievementRewardCal.New() ---@type AchievementRewardCal
end

--- 是否为天赋成就
---@return boolean
function AchievementType:IsTalentAchievement()
   return self.type == "天赋成就" and self.maxLevel ~= nil
end

--- 是否为普通成就
---@return boolean
function AchievementType:IsNormalAchievement()
   return self.type == "普通成就" or self.maxLevel == nil
end

--- 获取最大等级
---@return number
function AchievementType:GetMaxLevel()
   return self.maxLevel or 1
end

--- 获取指定等级的效果
---@param level number 等级
---@return table|nil 效果配置
function AchievementType:GetLevelEffect(level)
   if not self.levelEffects then
       return nil
   end

   for _, effect in ipairs(self.levelEffects) do
       if effect["等级"] == level or not effect["等级"] then
           -- 如果没有指定等级，说明是通用效果公式
           return effect
       end
   end

   return nil
end

--- 获取等级效果数值
---@param level number 天赋等级
---@return table[] 计算后的效果值列表，每个元素是 {["效果类型"]=string, ["效果字段名称"]=string, ["数值"]=any}
function AchievementType:GetLevelEffectValue(level)
    local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader)
    
    local results = {}
    if not self.levelEffects or #self.levelEffects == 0 then
        return results
    end

    for _, effectConfig in ipairs(self.levelEffects) do
        local formula = effectConfig["效果数值"]
        local effectLevelConfigName = effectConfig["效果等级配置"]
        local calculatedValue = nil
        -- 如果效果数值为空字符串或nil，且配置了效果等级配置，则从效果等级配置中获取
        if (not formula or formula == "") and effectLevelConfigName then
            local effectLevelConfig = ConfigLoader.GetEffectLevel(effectLevelConfigName)
            calculatedValue = effectLevelConfig:GetEffectValue(level)
            
        else
            -- 使用原有的公式计算逻辑
            calculatedValue = self._rewardCalculator:CalculateEffectValue(formula, level, self)
        end
        
        if calculatedValue then
            table.insert(results, {
                ["效果类型"] = effectConfig["效果类型"],
                ["效果字段名称"] = effectConfig["效果字段名称"],
                ["数值"] = calculatedValue
            })
        end
    end
    return results
end

--- 获取升级消耗
---@param currentLevel number 当前等级
---@return {item: string, amount: number}[] 消耗列表
function AchievementType:GetUpgradeCosts(currentLevel)
    local costsDict = {}

    if self.upgradeConditions then
        for _, condition in ipairs(self.upgradeConditions) do
            local itemName = condition["消耗名称"]
            local costFormula = condition["消耗数量"]
            local costType = condition["消耗类型"] 

            if itemName and costFormula and itemName ~= "" and costFormula ~= "" then
                local amount = self:GetUpgradeCostValue(costFormula, currentLevel)
                if amount and amount > 0 then
                    if not costsDict[itemName] then
                        costsDict[itemName] = {
                            item = itemName,
                            amount = 0,
                            costType = costType
                        }
                    end
                    costsDict[itemName].amount = costsDict[itemName].amount + amount
                end
            end
        end
    end

    local finalCostsArray = {}
    for _, costData in pairs(costsDict) do
        table.insert(finalCostsArray, costData)
    end

    return finalCostsArray
end

--- 获取动作消耗（专门用于天赋动作，如重生）
---@param targetLevel number 目标动作等级
---@param playerData table 玩家数据
---@param bagData table 背包数据
---@return {item: string, amount: number}[] 消耗列表
function AchievementType:GetActionCosts(targetLevel, playerData, bagData)
    local costsDict = {}

    -- 只处理'消耗配置' (actionCostType)
    if self.actionCostType then
        local externalContext = { T_LVL = targetLevel }
        local actionCosts = self.actionCostType:GetActionCosts(playerData, bagData, externalContext)
 
        for name, amount in pairs(actionCosts) do
            costsDict[name] = (costsDict[name] or 0) + amount
        end
    end
    
    local finalCostsArray = {}
    for name, amount in pairs(costsDict) do
        -- 在构建最终数组时，使用新方法获取消耗类型

        
        table.insert(finalCostsArray, {
            item = name,
            amount = amount,
            costType = self.actionCostType:GetCostTypeByName(name) 
        })
    end
 
    return finalCostsArray
end

--- 获取升级消耗数值
---@param formula string 消耗公式
---@param level number 当前等级
---@return number|nil 消耗数量
function AchievementType:GetUpgradeCostValue(formula, level)
    return self._rewardCalculator:CalculateUpgradeCost(formula, level, self)
end

--- 计算玩家可执行某个天赋动作的最大次数
---@param variableData table 玩家的变量数据字典
---@param bagData Bag|nil 玩家的背包数据
---@param currentTalentLevel number 当前天赋等级
---@return number maxActions可以执行的最大次数
function AchievementType:CalculateMaxActionExecutions(variableData, bagData, currentTalentLevel)
    --gg.log("【重生计算】开始:数据计算=", variableData, bagData, currentTalentLevel)

    if not self:IsTalentAchievement() or currentTalentLevel == 0 then
        --gg.log("【重生计算】失败: 不是天赋或等级为0. IsTalent:", self:IsTalentAchievement(), "Level:", currentTalentLevel)
        return 0
    end

    if not self.actionCostType then
        --gg.log("【重生计算】失败: 天赋 " .. self.name .. " 没有找到有效的 actionCostType 配置。")
        return 0
    end
    --gg.log("【重生计算】actionCostType.CostList:", self.actionCostType.CostList)


    local costsForLevel1 = self:GetActionCosts(1, variableData, bagData)
    --gg.log("【重生计算】等级1的单次消耗 (costsForLevel1):", costsForLevel1)
    
    if not costsForLevel1 or #costsForLevel1 == 0 then
        --gg.log("【重生计算】失败: 无法计算天赋动作等级1的消耗。")
        return 0
    end

    local costsMap = {}
    for _, cost in ipairs(costsForLevel1) do
        costsMap[cost.item] = cost.amount
    end
    --gg.log("【重生计算】消耗映射表 (costsMap):", costsMap)


    local maxExecutions = math.huge

    for i, costConfigItem in ipairs(self.actionCostType.CostList) do
        --gg.log(string.format("【重生计算】循环 %d/%d:", i, #self.actionCostType.CostList))
        local resourceName = costConfigItem.Name
        local resourceSource = costConfigItem.CostType
        --gg.log(string.format("  - 资源名: '%s', 来源: '%s'", tostring(resourceName), tostring(resourceSource)))

        local singleCostAmount = costsMap[resourceName]
        --gg.log(string.format("  - 单次消耗 (from costsMap): %s", tostring(singleCostAmount)))


        if singleCostAmount and singleCostAmount > 0 then
            local playerTotalAmount = 0
            if resourceSource == "玩家变量" then
                if variableData and variableData[resourceName] then
                    local var = variableData[resourceName]
                    --gg.log("  - 找到玩家变量:", resourceName, var)
                    -- 兼容客户端和服务端的数据结构
                    if type(var) == "table" and var.base then
                        playerTotalAmount = var.base
                    elseif type(var) == "number" then
                         playerTotalAmount = var
                    end
                else
                    --gg.log("  - 玩家变量数据中未找到:", resourceName)
                end
            elseif bagData and bagData.GetItemAmount then
                playerTotalAmount = bagData:GetItemAmount(resourceName)
            end
            --gg.log(string.format("  - 玩家拥有总量: %s", playerTotalAmount))


            local maxForThisResource = math.floor(playerTotalAmount / singleCostAmount)
            --gg.log(string.format("  - 此资源可支持次数: floor(%s / %s) = %d", playerTotalAmount, singleCostAmount, maxForThisResource))

            maxExecutions = math.min(maxExecutions, maxForThisResource)
            --gg.log(string.format("  - 当前最小可执行次数 (maxExecutions): %d", maxExecutions))

        else
            --gg.log("  - 单次消耗为0或未找到，跳过此资源瓶颈计算。")
        end
    end

    if maxExecutions == math.huge then
        --gg.log("【重生计算】最终结果: maxExecutions从未更新，返回0")
        return 0
    end

    --gg.log("【重生计算】最终结果: ", maxExecutions)
    return maxExecutions
end



return AchievementType

