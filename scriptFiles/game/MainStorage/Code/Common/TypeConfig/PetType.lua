-- /TypeConfig/PetType.lua

local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class PetType:Class
---@field name string 宠物名称
---@field description string 宠物描述  
---@field petType string 宠物类型
---@field rarity string 稀有度
---@field minLevel number 初始等级
---@field maxLevel number 最大等级
---@field elementType string 元素类型
---@field baseAttributes table 基础属性列表
---@field growthRates table 成长率列表
---@field starUpgradeEffects table 升星效果列表
---@field starUpgradeCosts table 升星消耗列表
---@field carryingEffects table 携带效果列表
---@field skillList table 技能列表
---@field evolutionRequirement table 进化条件
---@field evolutionResult string 进化后形态
---@field obtainMethods table 获取方式
---@field modelResource string| nil 模型资源
---@field avatarResource string| nil 头像资源
---@field soundResource string| nil 音效资源
---@field specialTags table 特殊标签
---@field New fun(data:table):PetType
local PetType = ClassMgr.Class("PetType")

function PetType:OnInit(data)
    -- 基础信息
    self.name = data["宠物名称"] or "未知宠物"
    self.description = data["宠物描述"] or ""
    self.petType = data["宠物类型"] or "宠物"
    self.rarity = data["稀有度"] or "N"
    
    -- 等级系统
    self.minLevel = data["初始等级"] or 1
    self.maxLevel = data["最大等级"] or 100
    
    -- 元素属性
    self.elementType = data["元素类型"] or "无"
    
    -- 属性和成长系统
    self.baseAttributes = data["基础属性列表"] or {}
    self.growthRates = data["成长率列表"] or {}
    
    -- 星级系统
    self.starUpgradeCosts = data["升星消耗列表"] or {}
    self.maxStarLevel = data["最大星级"] or 5 -- 修复：重新添加最大星级初始化
    
    -- 功能系统
    self.carryingEffects = data["携带效果"] or {}
    self.skillList = data["技能列表"] or {}
    
    -- 进化系统
    self.evolutionRequirement = data["进化条件"] or {}
    self.evolutionResult = data["进化后形态"] or ""
    
    -- 获取方式
    self.obtainMethods = data["获取方式"] or {}
    
    -- 资源配置
    self.modelResource = data["模型资源"] or nil
    self.avatarResource = data["头像资源"] or nil
    self.soundResource = data["音效资源"] or nil
    
    -- 特殊标记
    self.specialTags = data["特殊标签"] or {}
end

-- 便利函数：获取指定属性的基础值
function PetType:GetBaseAttribute(attributeName)
    for _, attr in ipairs(self.baseAttributes) do
        if attr["属性名称"] == attributeName then
            return attr["属性数值"] or 0
        end
    end
    return 0
end

-- 便利函数：获取指定属性的成长公式
function PetType:GetGrowthFormula(attributeName)
    for _, growth in ipairs(self.growthRates) do
        if growth["属性名称"] == attributeName then
            return growth["成长公式"] or ""
        end
    end
    return ""
end

-- 便利函数：获取指定星级的携带效果
function PetType:GetCarryingEffectsByStarLevel(starLevel)
    local effects = {}
    for _, effect in ipairs(self.carryingEffects) do
        if effect["星级"] == starLevel then
            table.insert(effects, effect)
        end
    end
    return effects
end

-- 便利函数：获取升到指定星级的消耗
function PetType:GetStarUpgradeCost(targetStarLevel)
    for _, cost in ipairs(self.starUpgradeCosts) do
        if cost["星级"] == targetStarLevel then
            return cost
        end
    end
    return nil
end

--- 计算携带效果的显示数值
---@param starLevel number 星级
---@return table<string, table> 计算后的效果列表，格式：{变量名称: {描述: string, 数值: number, isPercentage: boolean}}
function PetType:CalculateCarryingEffectsByStarLevel(starLevel)
    local calculatedEffects = {}
    
    -- 获取宠物公式计算器
    local RewardManager = require(game.MainStorage.Code.GameReward.RewardManager)
    local calculator = RewardManager.GetCalculator("宠物公式")
    
    if not calculator then
        gg.log("错误: 无法获取宠物公式计算器")
        return calculatedEffects
    end
    
    for _, effect in ipairs(self.carryingEffects) do
        local variableType = effect["变量类型"] or ""
        local variableName = effect["变量名称"] or ""
        local effectValue = effect["效果数值"] or ""
        local bonusType = effect["加成类型"]
        local itemTarget = effect["物品目标"]
        
        if variableName ~= "" and effectValue ~= "" then
            -- 使用RewardCalc计算公式
            local calculatedValue = calculator:CalculateEffectValue(effectValue, starLevel, 1, self)
             
            if calculatedValue then
                -- 【修复】添加 isPercentage 标志位
                local isPercentage = string.find(variableName, "百分比") ~= nil
                
                calculatedEffects[variableName] = {
                    -- 【修复】传递 isPercentage 标志给格式化函数
                    description = self:FormatEffectDescription(variableName, calculatedValue, isPercentage),
                    value = calculatedValue, -- 存储原始计算值
                    isPercentage = isPercentage, -- 新增标志位
                    originalFormula = effectValue,
                    bonusType = bonusType,
                    itemTarget = itemTarget
                }
            end
        end
    end
    
    return calculatedEffects
end

--- 格式化效果描述
---@param variableName string 变量名称
---@param value number 计算后的数值
---@param isPercentage boolean 是否为百分比
---@return string 格式化后的描述
function PetType:FormatEffectDescription(variableName, value, isPercentage)
    local cleanName = variableName:gsub("加成_百分比_", ""):gsub("属性_固定值_", ""):gsub("_", " ")

    if isPercentage then
        -- 【修复】对于百分比，将原始值(如16.5)乘以100用于显示
        return string.format("%s: +%.0f%%", cleanName, value * 100)
    else
        -- 【修复】对于固定值，直接显示
        return string.format("%s: +%.0f", cleanName, value)
    end
end

-- 移除不再使用的旧方法
-- function PetType:EvaluateExpression(expression) ... end

return PetType