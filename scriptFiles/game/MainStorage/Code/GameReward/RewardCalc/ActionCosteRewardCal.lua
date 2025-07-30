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
    gg.log("[诊断][CalculateCosts] === 开始计算成本 ===")
    gg.log("[诊断][CalculateCosts] 外部上下文 (T_LVL):", externalContext)
    gg.log("[诊断][CalculateCosts] 消耗列表 CostList:", actionCostType and actionCostType.CostList)

    if not actionCostType or not actionCostType.CostList then
        gg.log("错误: [ActionCosteRewardCal] 无效的 ActionCostType 或空的消耗列表。")
        return calculatedCosts
    end

    for i, costItem in ipairs(actionCostType.CostList) do
        gg.log("[诊断][CalculateCosts] 正在处理第 " .. i .. " 个消耗项:", costItem.Name)
        local costAmount = self:_CalculateCostForItem(costItem, playerData, bagData, externalContext)
        gg.log("[诊断][CalculateCosts] 第 " .. i .. " 个消耗项 '".. costItem.Name .."' 计算结果: " .. tostring(costAmount))
        if costAmount and costAmount > 0 then
            -- 使用消耗名称作为key，以避免重复
            calculatedCosts[costItem.Name] = (calculatedCosts[costItem.Name] or 0) + costAmount
        end
    end
    
    gg.log("[诊断][CalculateCosts] === 成本计算结束, 最终结果: ===", calculatedCosts)
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
    gg.log("[诊断][_CalculateCostForItem] 开始处理消耗项:", costItem.Name)
    for i, segment in ipairs(costItem.Segments) do
        gg.log("[诊断][_CalculateCostForItem] 正在检查第 " .. i .. " 个分段, 条件:", segment.Condition)
        if self:_CheckCondition(segment.Condition, playerData, bagData, externalContext) then
            gg.log("[诊断][_CalculateCostForItem] 第 " .. i .. " 个分段条件满足。开始计算公式:", segment.Formula)
            local value = self:_CalculateValue(segment.Formula, playerData, bagData, externalContext)
            gg.log("[诊断][_CalculateCostForItem] 公式计算结果:", value)
            if value and type(value) == "number" and value >= 0 then
                return math.floor(value) -- 成本必须是非负整数
            end
            -- 如果公式计算失败，则停止此项的计算
            return nil
        else
            gg.log("[诊断][_CalculateCostForItem] 第 " .. i .. " 个分段条件不满足。")
        end
    end
    gg.log("[诊断][_CalculateCostForItem] 所有分段条件均不满足，返回 nil。")
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

    -- 1. 替换变量，得到一个纯粹的表达式字符串
    gg.log("[诊断][_CalculateValue] 原始表达式:", expression)
    local processedExpression = self:_ProcessExpression(expression, playerData, bagData, externalContext)
    gg.log("[诊断][_CalculateValue] 变量替换后表达式:", processedExpression)
    
    -- 2. 使用新的安全解析器来代替 load()
    local success, result = xpcall(self._ParseAndEvaluate, gg.log, self, processedExpression)

    if not success then
        gg.log("错误: [ActionCosteRewardCal] 安全表达式解析失败: '" .. tostring(processedExpression) .. "'. 错误: " .. tostring(result))
        return nil
    end

    gg.log("[诊断][_CalculateValue] 表达式计算结果:", result)
    return result
end

--- 运算符优先级和执行函数的定义
ActionCosteRewardCal._operators = {
    ["<"]  = {prec = 1, func = function(a, b) return a < b end},
    ["<="] = {prec = 1, func = function(a, b) return a <= b end},
    [">"]  = {prec = 1, func = function(a, b) return a > b end},
    [">="] = {prec = 1, func = function(a, b) return a >= b end},
    ["=="] = {prec = 1, func = function(a, b) return a == b end},
    ["~="] = {prec = 1, func = function(a, b) return a ~= b end},
    ["+"]  = {prec = 2, func = function(a, b) return a + b end},
    ["-"]  = {prec = 2, func = function(a, b) return a - b end},
    ["*"]  = {prec = 3, func = function(a, b) return a * b end},
    ["/"]  = {prec = 3, func = function(a, b) return b == 0 and 0 or a / b end},
}

--- 安全地解析和计算表达式，取代 load()
---@param expression string 只包含数字和运算符的字符串
function ActionCosteRewardCal:_ParseAndEvaluate(expression)
    -- 1. 更健壮的分词 (Tokenizer)
    local tokens = {}
    for token in expression:gmatch("%S+") do
        local num = tonumber(token)
        table.insert(tokens, num or token)
    end
    
    -- 如果没有任何 token，说明表达式为空或无效
    if #tokens == 0 then return nil end

    -- 2. 特殊情况处理: 链式比较 (A op B op C)
    if #tokens == 5 and type(tokens[1]) == 'number' and type(tokens[3]) == 'number' and type(tokens[5]) == 'number' then
        local op1, op2 = tokens[2], tokens[4]
        -- 确保两个都是比较运算符
        if self._operators[op1] and self._operators[op1].prec == 1 and self._operators[op2] and self._operators[op2].prec == 1 then
            local a, b, c = tokens[1], tokens[3], tokens[5]
            local res1 = self._operators[op1].func(a, b)
            local res2 = self._operators[op2].func(b, c)
            return res1 and res2
        end
    end

    -- 3. 标准表达式求值 (Shunting-yard based)
    local values = {} -- 输出栈
    local ops = {}    -- 操作符栈

    local function applyOp()
        if #ops > 0 and #values >= 2 then
            local op = table.remove(ops)
            local b = table.remove(values)
            local a = table.remove(values)
            table.insert(values, self._operators[op].func(a, b))
        else
            error("无效的表达式，操作符或操作数不匹配")
        end
    end

    for _, token in ipairs(tokens) do
        if type(token) == "number" then
            table.insert(values, token)
        elseif self._operators[token] then
            local o1_prec = self._operators[token].prec
            while #ops > 0 and self._operators[ops[#ops]] and o1_prec <= self._operators[ops[#ops]].prec do
                applyOp()
            end
            table.insert(ops, token)
        else
            error("未知的标记: " .. tostring(token))
        end
    end

    while #ops > 0 do
        applyOp()
    end

    if #values == 1 then
        return values[1]
    elseif #values == 0 and #tokens > 0 then
         error("表达式 '"..expression.."' 解析后无结果, 请检查配置")
    else
        return values[#values] -- 处理只有一个数字的表达式
    end
end


--- 预处理表达式，将所有变量替换为实际数值
---@param expression string 原始表达式
---@param playerData table 玩家数据
---@param bagData table 背包数据
---@param externalContext table 外部上下文
---@return string 处理后的表达式
function ActionCosteRewardCal:_ProcessExpression(expression, playerData, bagData, externalContext)
    local processed = expression

    -- 1. 替换玩家变量: $变量名$ (修正了正则表达式以支持中文)
    processed = string.gsub(processed, "%$([^$]+)%$", function(varName)
        return tostring(self:_GetPlayerVariable(playerData, varName))
    end)

    -- 2. 替换玩家属性: {属性名} (修正了正则表达式以支持中文)
    processed = string.gsub(processed, "{([^}]+)}", function(varName)
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
    if playerData and playerData.variableData and type(playerData.variableData[varName]) == "number" then
        return playerData.variableData[varName]
    end
    return 0
end

--- 获取玩家属性值
---@param playerData table 玩家数据
---@param attrName string 属性名
---@return number
function ActionCosteRewardCal:_GetPlayerAttribute(playerData, attrName)
    if playerData and playerData.playerAttribute and type(playerData.playerAttribute[attrName]) == "number" then
        return playerData.playerAttribute[attrName]
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
