-- ActionCosteRewardCal.lua
-- 可配置成本计算器 - 根据 ActionCostConfig 的配置动态计算成本
-- 它解析包含特殊变量（如 $, {}, []）的公式，并处理分段条件逻辑。

local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local RewardBase = require(MainStorage.Code.GameReward.RewardBase) ---@type RewardBase
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class ActionCosteRewardCal : RewardBase
local ActionCosteRewardCal = ClassMgr.Class("ActionCosteRewardCal", RewardBase)

function ActionCosteRewardCal:OnInit()
    self.calcType = "可配置成本计算器"
end

--- 计算给定ActionCost配置的所有成本
---@param actionCostType table ActionCostType的实例
---@param playerData MPlayer 玩家数据，包含变量、属性等信息
---@param bagData Bag 背包数据，包含物品信息
---@param externalContext table | nil 外部上下文, 例如 { T_LVL = 5 }
---@return table<string, number> 一个映射表，键是消耗名称，值是计算出的数量
function ActionCosteRewardCal:CalculateCosts(actionCostType, playerData, bagData, externalContext)
    local calculatedCosts = {}

    if not actionCostType or not actionCostType.CostList then
        gg.log("错误: [ActionCosteRewardCal] 无效的 ActionCostType 或空的消耗列表。")
        return calculatedCosts
    end

    for _, costItem in ipairs(actionCostType.CostList) do
        local costAmount = self:_CalculateCostForItem(costItem, playerData, bagData, externalContext)
        if costAmount and costAmount > 0 then
            -- 使用消耗名称作为key，以避免重复
            calculatedCosts[costItem.Name] = (calculatedCosts[costItem.Name] or 0) + costAmount
        end
    end
    
    return calculatedCosts
end

--- 内部函数：为单个消耗项计算成本
--- 它会遍历分段，找到第一个满足条件的规则并计算其公式
---@param costItem table 单个成本项
---@param playerData table 玩家数据
---@param bagData table 背包数据
---@param externalContext table 外部上下文
---@return number | nil 计算出的成本数量
function ActionCosteRewardCal:_CalculateCostForItem(costItem, playerData, bagData, externalContext)
    for _, segment in ipairs(costItem.Segments) do
        if self:_CheckCondition(segment.Condition, playerData, bagData, externalContext) then
            local value = self:_CalculateValue(segment.Formula, playerData, bagData, externalContext)
            if value and type(value) == "number" and value >= 0 then
                return math.floor(value) -- 成本必须是非负整数
            end
            -- 如果公式计算失败，则停止此项的计算
            return nil
        end
    end
    return nil -- 没有匹配的条件
end

--- 检查条件表达式是否为真
---@param condition string | nil 条件表达式
---@param playerData table 玩家数据
---@param bagData table 背包数据
---@param externalContext table 外部上下文
---@return boolean
function ActionCosteRewardCal:_CheckCondition(condition, playerData, bagData, externalContext)
    if not condition or condition == "" then
        return true -- 条件为空，默认通过
    end
    
    local result = self:_CalculateValue(condition, playerData, bagData, externalContext)
    return result == true
end

--- 计算公式或条件的值
---@param expression string 表达式 (可以是公式或条件)
---@param playerData table 玩家数据
---@param bagData table 背包数据
---@param externalContext table 外部上下文
---@return any
function ActionCosteRewardCal:_CalculateValue(expression, playerData, bagData, externalContext)
    if not expression or type(expression) ~= "string" then
        return nil
    end

    local processedExpression = self:_ProcessExpression(expression, playerData, bagData, externalContext)
    
    local func, err = load("return " .. processedExpression, "expression", "t", {})
    if not func then
        gg.log("错误: [ActionCosteRewardCal] 表达式加载失败: '" .. tostring(processedExpression) .. "'. 错误: " .. err)
        return nil
    end

    local success, result = pcall(func)
    if not success then
        gg.log("错误: [ActionCosteRewardCal] 表达式计算失败: '" .. tostring(processedExpression) .. "'. 错误: " .. result)
        return nil
    end

    return result
end

--- 预处理表达式，将所有变量替换为实际数值
---@param expression string 原始表达式
---@param playerData table 玩家数据
---@param bagData table 背包数据
---@param externalContext table 外部上下文
---@return string 处理后的表达式
function ActionCosteRewardCal:_ProcessExpression(expression, playerData, bagData, externalContext)
    local processed = expression

    -- 1. 替换玩家变量: $变量名$
    processed = string.gsub(processed, "%$([%w_]+)%", function(varName)
        return tostring(self:_GetPlayerVariable(playerData, varName))
    end)

    -- 2. 替换玩家属性: {变量名}
    processed = string.gsub(processed, "{([%w_]+)}", function(varName)
        return tostring(self:_GetPlayerAttribute(playerData, varName))
    end)

    -- 3. 替换物品数量: [物品名]
    processed = string.gsub(processed, "%[([^%]]+)%]", function(itemName)
        return tostring(self:_GetItemCount(bagData, itemName))
    end)

    -- 4. 替换特殊关键字 T_LVL
    if externalContext and externalContext.T_LVL then
        processed = string.gsub(processed, "T_LVL", tostring(externalContext.T_LVL))
    end

    return processed
end

--- 获取玩家变量值
---@param playerData table 玩家数据
---@param varName string 变量名
---@return number
function ActionCosteRewardCal:_GetPlayerVariable(playerData, varName)
    -- 优先从 variableSystem 中获取变量值
    if playerData and playerData.variableSystem then
        -- 如果传入的是完整的 variableSystem 对象，直接调用其方法
        if type(playerData.variableSystem.GetVariable) == "function" then
            return playerData.variableSystem:GetVariable(varName, 0)
        end
    end
    
    -- 从原始 variables 数据中获取（兼容处理）
    if playerData and playerData.variables then
        -- 如果是新的 VariableSystem 数据结构
        if type(playerData.variables) == "table" and playerData.variables[varName] then
            local varData = playerData.variables[varName]
            if type(varData) == "table" and varData.base then
                -- 计算最终值：基础值 + 所有来源的值
                local baseValue = varData.base or 0
                local flatSum = 0
                local percentSum = 0
                
                if varData.sources then
                    for _, sourceData in pairs(varData.sources) do
                        if sourceData.type == "百分比" then
                            percentSum = percentSum + sourceData.value
                        else -- "固定值"
                            flatSum = flatSum + sourceData.value
                        end
                    end
                end
                
                return baseValue + flatSum + (baseValue * percentSum / 100)
            else
                -- 简单数值结构
                return varData
            end
        elseif type(playerData.variables[varName]) == "number" then
            -- 直接数值
            return playerData.variables[varName]
        end
    end
    
    -- gg.log("警告: [ActionCosteRewardCal] 无法获取玩家变量 '" .. varName .. "' 的值。")
    return 0
end

--- 获取玩家属性值
---@param playerData table 玩家数据
---@param attrName string 属性名
---@return number
function ActionCosteRewardCal:_GetPlayerAttribute(playerData, attrName)
    -- 优先从 variableSystem 中获取属性值（属性也可能存储在变量系统中）
    if playerData and playerData.variableSystem then
        if type(playerData.variableSystem.GetVariable) == "function" then
            local value = playerData.variableSystem:GetVariable(attrName, nil)
            if value ~= nil then
                return value
            end
        end
    end
    
    return 0
end

--- 获取玩家背包中物品的数量
---@param bagData table 背包数据
---@param itemName string 物品名
---@return number
function ActionCosteRewardCal:_GetItemCount(bagData, itemName)
    -- 从背包数据中获取物品数量
    if bagData then
        -- 如果背包数据有 GetItemAmount 方法（参考 BagMgr 的接口）
        if type(bagData.GetItemAmount) == "function" then
            return bagData:GetItemAmount(itemName) or 0
        end
        
        -- 如果是简单的 items 映射结构
        if bagData.items and bagData.items[itemName] then
            return bagData.items[itemName] or 0
        end
        
        -- 如果背包数据是数组结构的物品列表（参考 Bag.lua 的结构）
        if bagData.itemList then
            local totalCount = 0
            for _, item in ipairs(bagData.itemList) do
                if item and item.name == itemName then
                    totalCount = totalCount + (item.amount or item.count or 1)
                end
            end
            return totalCount
        end
    end
    
    -- gg.log("警告: [ActionCosteRewardCal] 无法获取物品 '" .. itemName .. "' 的数量。")
    return 0
end

return ActionCosteRewardCal
