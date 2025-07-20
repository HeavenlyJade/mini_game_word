local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr 
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
---@class VariableSystem:Class
---@field variables table<string, number> 变量存储
---@field entity MPlayer 所属实体
local VariableSystem = ClassMgr.Class("VariableSystem")

-- 初始化变量系统
function VariableSystem:OnInit(entity)
    self.entity = entity -- 所属实体
    -- 自动从实体中获取variables数据
    if entity and entity.variables then
        self.variables = entity.variables -- 直接引用实体的variables
    else
        self.variables = {} -- 如果没有数据则初始化为空
    end
end

-- 变量管理 --------------------------------------------------------

--- 设置变量
---@param key string 变量名
---@param value number 变量值
function VariableSystem:SetVariable(key, value)
    local oldValue = self.variables[key] or 0
    self.variables[key] = value
    
    -- 触发变量变化事件
    self:TriggerVariableEvent("VariableChanged", key, oldValue, value)
end

--- 获取变量
---@param key string 变量名
---@param defaultValue number|nil 默认值，默认为0
---@return number 变量值
function VariableSystem:GetVariable(key, defaultValue)
    defaultValue = defaultValue or 0

    -- 返回普通变量值
    return self.variables[key] or defaultValue
end

--- 增加变量值
---@param key string 变量名
---@param value number 增加值
---@return number 新的变量值
function VariableSystem:AddVariable(key, value)
    local oldValue = self.variables[key] or 0
    local newValue = oldValue + value
    self.variables[key] = newValue
    
    -- 触发变量变化事件
    self:TriggerVariableEvent("VariableChanged", key, oldValue, newValue)
    
    return newValue
end

--- 减少变量值
---@param key string 变量名
---@param value number 减少值
---@param minValue number|nil 最小值，默认无限制
---@return number 新的变量值
function VariableSystem:SubtractVariable(key, value, minValue)
    local oldValue = self.variables[key] or 0
    local newValue = oldValue - value
    
    if minValue and newValue < minValue then
        newValue = minValue
    end
    
    self.variables[key] = newValue
    
    -- 触发变量变化事件
    self:TriggerVariableEvent("VariableChanged", key, oldValue, newValue)
    
    return newValue
end

--- 乘以变量值
---@param key string 变量名
---@param multiplier number 乘数
---@return number 新的变量值
function VariableSystem:MultiplyVariable(key, multiplier)
    local oldValue = self.variables[key] or 0
    local newValue = oldValue * multiplier
    self.variables[key] = newValue
    
    -- 触发变量变化事件
    self:TriggerVariableEvent("VariableChanged", key, oldValue, newValue)
    
    return newValue
end

--- 移除变量
---@param key string 变量名或部分名
function VariableSystem:RemoveVariable(key)
    local keysToRemove = {}
    local removedVars = {}

    for k, v in pairs(self.variables) do
        if string.find(k, key) then
            table.insert(keysToRemove, k)
            removedVars[k] = v
        end
    end

    for _, k in ipairs(keysToRemove) do
        self.variables[k] = nil
        -- 触发变量移除事件
        self:TriggerVariableEvent("VariableRemoved", k, removedVars[k], nil)
    end
end

--- 检查变量是否存在
---@param key string 变量名
---@return boolean
function VariableSystem:HasVariable(key)
    return self.variables[key] ~= nil
end

--- 获取所有变量
---@return table<string, number>
function VariableSystem:GetAllVariables()
    return self.variables
end

--- 清空所有变量
function VariableSystem:ClearAllVariables()
    local oldVariables = {}
    for k, v in pairs(self.variables) do
        oldVariables[k] = v
    end
    
    self.variables = {}
    
    -- 触发清空事件
    for k, v in pairs(oldVariables) do
        self:TriggerVariableEvent("VariableRemoved", k, v, nil)
    end
end

--- 复制变量到另一个变量
---@param fromKey string 源变量名
---@param toKey string 目标变量名
function VariableSystem:CopyVariable(fromKey, toKey)
    local value = self:GetVariable(fromKey)
    self:SetVariable(toKey, value)
end

--- 交换两个变量的值
---@param key1 string 变量1
---@param key2 string 变量2
function VariableSystem:SwapVariables(key1, key2)
    local value1 = self:GetVariable(key1)
    local value2 = self:GetVariable(key2)
    self:SetVariable(key1, value2)
    self:SetVariable(key2, value1)
end

-- 变量计算 --------------------------------------------------------

--- 获取变量总和
---@param keys string[] 变量名列表
---@return number 总和
function VariableSystem:GetVariableSum(keys)
    local sum = 0
    for _, key in ipairs(keys) do
        sum = sum + self:GetVariable(key)
    end
    return sum
end

--- 获取变量平均值
---@param keys string[] 变量名列表
---@return number 平均值
function VariableSystem:GetVariableAverage(keys)
    if #keys == 0 then return 0 end
    return self:GetVariableSum(keys) / #keys
end

--- 获取变量最大值
---@param keys string[] 变量名列表
---@return number, string 最大值和对应的变量名
function VariableSystem:GetVariableMax(keys)
    local maxValue = nil
    local maxKey = ""
    
    for _, key in ipairs(keys) do
        local value = self:GetVariable(key)
        if maxValue == nil or value > maxValue then
            maxValue = value
            maxKey = key
        end
    end
    
    return maxValue or 0, maxKey
end

--- 获取变量最小值
---@param keys string[] 变量名列表
---@return number, string 最小值和对应的变量名
function VariableSystem:GetVariableMin(keys)
    local minValue = nil
    local minKey = ""
    
    for _, key in ipairs(keys) do
        local value = self:GetVariable(key)
        if minValue == nil or value < minValue then
            minValue = value
            minKey = key
        end
    end
    
    return minValue or 0, minKey
end

--- 变量条件检查
---@param key string 变量名
---@param operator string 操作符 (">", "<", ">=", "<=", "==", "!=")
---@param value number 比较值
---@return boolean 是否满足条件
function VariableSystem:CheckVariableCondition(key, operator, value)
    local varValue = self:GetVariable(key)
    
    if operator == ">" then
        return varValue > value
    elseif operator == "<" then
        return varValue < value
    elseif operator == ">=" then
        return varValue >= value
    elseif operator == "<=" then
        return varValue <= value
    elseif operator == "==" then
        return varValue == value
    elseif operator == "!=" then
        return varValue ~= value
    else
        gg.log("未知的操作符: " .. operator)
        return false
    end
end

--- 设置变量限制
---@param key string 变量名
---@param value number 变量值
---@param minValue number|nil 最小值
---@param maxValue number|nil 最大值
function VariableSystem:SetVariableWithLimits(key, value, minValue, maxValue)
    if minValue and value < minValue then
        value = minValue
    end
    if maxValue and value > maxValue then
        value = maxValue
    end
    self:SetVariable(key, value)
end

-- 变量模式匹配 --------------------------------------------------------

--- 根据模式匹配获取变量
---@param pattern string 模式字符串
---@return table<string, number> 匹配的变量
function VariableSystem:GetVariablesByPattern(pattern)
    local matches = {}
    for key, value in pairs(self.variables) do
        if string.find(key, pattern) then
            matches[key] = value
        end
    end
    return matches
end

--- 根据模式匹配设置变量
---@param pattern string 模式字符串
---@param value number 设置的值
function VariableSystem:SetVariablesByPattern(pattern, value)
    for key in pairs(self.variables) do
        if string.find(key, pattern) then
            self:SetVariable(key, value)
        end
    end
end

--- 根据模式匹配增加变量
---@param pattern string 模式字符串
---@param value number 增加的值
function VariableSystem:AddVariablesByPattern(pattern, value)
    for key in pairs(self.variables) do
        if string.find(key, pattern) then
            self:AddVariable(key, value)
        end
    end
end

-- 事件系统 --------------------------------------------------------

--- 触发变量事件
---@param eventType string 事件类型
---@param key string 变量名
---@param oldValue number|nil 旧值
---@param newValue number|nil 新值
function VariableSystem:TriggerVariableEvent(eventType, key, oldValue, newValue)
    local evt = {
        eventType = eventType,
        entity = self.entity,
        key = key,
        oldValue = oldValue,
        newValue = newValue
    }
    ServerEventManager.Publish("VariableSystemEvent", evt)
end

-- 工具方法 --------------------------------------------------------

--- 获取变量数量
---@return number
function VariableSystem:GetVariableCount()
    local count = 0
    for _ in pairs(self.variables) do
        count = count + 1
    end
    return count
end

--- 变量序列化
---@return string JSON字符串
function VariableSystem:SerializeVariables()
    local json = require(MainStorage.Code.Common.Untils.json)
    return json.encode(self.variables)
end

--- 变量反序列化
---@param data string JSON字符串
function VariableSystem:DeserializeVariables(data)
    local json = require(MainStorage.Code.Common.Untils.json)
    local success, variables = pcall(json.decode, data)
    if success and type(variables) == "table" then
        self.variables = variables
    else
        gg.log("变量反序列化失败: " .. tostring(data))
    end
end

--- 检查单个变量条件（使用>=运算符）
---@param variableName string 变量名
---@param requiredValue number 需求值
---@return boolean 是否满足条件
function VariableSystem:CheckCondition(variableName, requiredValue)
    local currentValue = self:GetVariable(variableName, 0)
    return currentValue >= requiredValue
end

--- 批量检查多个变量条件（全部满足才返回true）
---@param conditions table[] 条件列表，格式：{{variableName, requiredValue}, ...}
---@return boolean 是否全部满足条件
function VariableSystem:CheckConditions(conditions)
    if not conditions or #conditions == 0 then
        return true
    end
    
    for _, condition in ipairs(conditions) do
        local variableName = condition[1] or condition.variableName
        local requiredValue = condition[2] or condition.requiredValue
        
        if not self:CheckCondition(variableName, requiredValue) then
            return false
        end
    end
    
    return true
end

-- 三段式变量名解析 --------------------------------------------------------

--- 解析三段式变量名：操作类型_加成方式_变量名称
---@param variableName string 三段式变量名
---@return table|nil 解析结果 {operation, method, name} 或 nil
function VariableSystem:ParseVariableName(variableName)
    local parts = {}
    for part in string.gmatch(variableName, "([^_]+)") do
        table.insert(parts, part)
    end
    
    if #parts == 3 then
        return {
            operation = parts[1],   -- 操作类型：解锁、加成、计数、状态等
            method = parts[2],      -- 加成方式：百分比、绝对值、固定值等
            name = parts[3]         -- 变量名称：攻击力、生命值、经验倍率等
        }
    end
    
    return nil -- 不是三段式格式
end

--- 智能应用变量值（支持三段式解析）
---@param variableName string 变量名
---@param value number 变量值
function VariableSystem:ApplyVariableValue(variableName, value)
    local parsed = self:ParseVariableName(variableName)
    
    if parsed then
        -- 三段式变量处理
        self:_ApplyParsedVariable(parsed, variableName, value)
    else
        -- 不是三段式格式，直接设置变量
        self:SetVariable(variableName, value)
    end
end

--- 处理三段式变量
---@param parsed table 解析结果
---@param variableName string 完整变量名
---@param value number 变量值
---@private
function VariableSystem:_ApplyParsedVariable(parsed, variableName, value)
    local operation = parsed.operation
    local method = parsed.method
    
    -- 根据加成方式处理数值
    local finalValue = self:_CalculateValueByMethod(variableName, value, method)
    
    -- 根据操作类型应用变量
    if operation == "加成" or operation == "计数" then
        self:AddVariable(variableName, finalValue)
    else
        self:SetVariable(variableName, finalValue)
    end
end

--- 根据加成方式计算最终数值
---@param variableName string 变量名
---@param value number 原始值
---@param method string 加成方式
---@return number 计算后的值
---@private
function VariableSystem:_CalculateValueByMethod(variableName, value, method)
    if method == "百分比" then
        -- 百分比加成：当前值 * (1 + 百分比值/100)
        local currentValue = self:GetVariable(variableName, 0)
        return currentValue * value / 100
    else
        -- 固定值/绝对值：直接使用原始值
        return value
    end
end


return VariableSystem 