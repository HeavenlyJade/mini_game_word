local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr 
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager

---@class VariableSystem:Class
---@field variables table<string, VariableData> 变量存储
---@field entity MPlayer 所属实体
local VariableSystem = ClassMgr.Class("VariableSystem")

---@class VariableData
---@field base number 基础值（百分比计算基准）
---@field sources table<string, SourceValue> 来源值映射

---@class SourceValue
---@field value number 数值
---@field type string 类型："固定值" | "百分比"

-- 初始化变量系统
function VariableSystem:OnInit(entity)
    self.entity = entity -- 所属实体
    self.variables = {} -- 新的变量存储结构
    
    -- 自动从实体中获取variables数据（如果存在）
    if entity and entity.variables then
        self:_MigrateOldData(entity.variables)
        entity.variables = self.variables -- 更新引用
    end
end

-- 基础值管理 --------------------------------------------------------

--- 设置基础值
---@param key string 变量名
---@param baseValue number 基础值
function VariableSystem:SetBaseValue(key, baseValue)
    if not self.variables[key] then
        self.variables[key] = {
            base = 0,
            sources = {}
        }
    end
    
    local oldFinalValue = self:GetVariable(key)
    self.variables[key].base = baseValue
    
    -- 触发变量变化事件
    local newFinalValue = self:GetVariable(key)
    self:TriggerVariableEvent("VariableChanged", key, oldFinalValue, newFinalValue)
end

--- 获取基础值
---@param key string 变量名
---@return number 基础值
function VariableSystem:GetBaseValue(key)
    if not self.variables[key] then
        return 0
    end
    return self.variables[key].base or 0
end

-- 来源值管理 --------------------------------------------------------

--- 设置来源值
---@param key string 变量名
---@param source string 来源标识
---@param value number 数值
---@param valueType string 类型："固定值" | "百分比"
function VariableSystem:SetSourceValue(key, source, value, valueType)
    if not self.variables[key] then
        self.variables[key] = {
            base = 0,
            sources = {}
        }
    end
    
    valueType = valueType or "固定值"
    local oldFinalValue = self:GetVariable(key)
    
    self.variables[key].sources[source] = {
        value = value,
        type = valueType
    }
    
    -- 触发变量变化事件
    local newFinalValue = self:GetVariable(key)
    self:TriggerVariableEvent("VariableChanged", key, oldFinalValue, newFinalValue)
end

--- 添加来源值（在现有基础上累加）
---@param key string 变量名
---@param source string 来源标识
---@param value number 累加数值
---@param valueType string 类型："固定值" | "百分比"
function VariableSystem:AddSourceValue(key, source, value, valueType)
    if not self.variables[key] then
        self.variables[key] = {
            base = 0,
            sources = {}
        }
    end
    
    valueType = valueType or "固定值"
    local currentValue = 0
    
    if self.variables[key].sources[source] then
        currentValue = self.variables[key].sources[source].value or 0
    end
    
    self:SetSourceValue(key, source, currentValue + value, valueType)
end

--- 移除来源
---@param key string 变量名
---@param source string 来源标识
function VariableSystem:RemoveSource(key, source)
    if not self.variables[key] or not self.variables[key].sources[source] then
        return
    end
    
    local oldFinalValue = self:GetVariable(key)
    self.variables[key].sources[source] = nil
    
    -- 触发变量变化事件
    local newFinalValue = self:GetVariable(key)
    self:TriggerVariableEvent("VariableChanged", key, oldFinalValue, newFinalValue)
end

--- 根据模式移除来源
---@param pattern string 模式字符串
function VariableSystem:RemoveSourcesByPattern(pattern)
    for varKey, varData in pairs(self.variables) do
        local sourcesToRemove = {}
        
        for sourceKey in pairs(varData.sources) do
            if string.find(sourceKey, pattern) then
                table.insert(sourcesToRemove, sourceKey)
            end
        end
        
        for _, sourceKey in ipairs(sourcesToRemove) do
            self:RemoveSource(varKey, sourceKey)
        end
    end
end

-- 变量获取（对外统一接口）--------------------------------------------------------

--- 获取变量最终计算值
---@param key string 变量名
---@param defaultValue number|nil 默认值，默认为0
---@return number 计算后的最终值
function VariableSystem:GetVariable(key, defaultValue)
    defaultValue = defaultValue or 0
    
    if not self.variables[key] then
        return defaultValue
    end
    
    -- 直接计算最终值
    return self:_CalculateFinalValue(key)
end

--- 计算最终值
---@param key string 变量名
---@return number 最终值
---@private
function VariableSystem:_CalculateFinalValue(key)
    local varData = self.variables[key]
    if not varData then
        return 0
    end
    
    local baseValue = varData.base or 0
    local flatSum = 0    -- 固定值总和
    local percentSum = 0 -- 百分比总和
    
    -- 分类累加各来源的值
    for _, sourceData in pairs(varData.sources) do
        if sourceData.type == "百分比" then
            percentSum = percentSum + sourceData.value
        else -- "固定值"
            flatSum = flatSum + sourceData.value
        end
    end
    
    -- 最终值 = 基础值 + 固定值总和 + 基础值 × (百分比总和 / 100)
    return baseValue + flatSum + (baseValue * percentSum / 100)
end

-- 兼容接口（保持向后兼容）--------------------------------------------------------

--- 设置变量（兼容接口）
---@param key string 变量名
---@param value number 变量值
function VariableSystem:SetVariable(key, value)
    self:SetBaseValue(key, value)
end

--- 增加变量值（兼容接口）
---@param key string 变量名
---@param value number 增加值
---@return number 新的变量值
function VariableSystem:AddVariable(key, value)
    local currentBase = self:GetBaseValue(key)
    self:SetBaseValue(key, currentBase + value)
    return self:GetVariable(key)
end

--- 减少变量值（兼容接口）
---@param key string 变量名
---@param value number 减少值
---@param minValue number|nil 最小值，默认无限制
---@return number 新的变量值
function VariableSystem:SubtractVariable(key, value, minValue)
    local currentBase = self:GetBaseValue(key)
    local newBase = currentBase - value
    
    if minValue and newBase < minValue then
        newBase = minValue
    end
    
    self:SetBaseValue(key, newBase)
    return self:GetVariable(key)
end

--- 乘以变量值（兼容接口）
---@param key string 变量名
---@param multiplier number 乘数
---@return number 新的变量值
function VariableSystem:MultiplyVariable(key, multiplier)
    local currentBase = self:GetBaseValue(key)
    self:SetBaseValue(key, currentBase * multiplier)
    return self:GetVariable(key)
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
---@param source string|nil 来源标识，默认为"UNKNOWN"
function VariableSystem:ApplyVariableValue(variableName, value, source)
    source = source or "UNKNOWN"
    local parsed = self:ParseVariableName(variableName)
    
    if parsed then
        -- 三段式变量处理
        local valueType = (parsed.method == "百分比") and "百分比" or "固定值"
        
        if parsed.operation == "加成" or parsed.operation == "计数" then
            self:AddSourceValue(variableName, source, value, valueType)
        else
            self:SetSourceValue(variableName, source, value, valueType)
        end
    else
        -- 不是三段式格式，默认设置为基础值
        self:SetBaseValue(variableName, value)
    end
end

-- 变量管理工具方法 --------------------------------------------------------

--- 检查变量是否存在
---@param key string 变量名
---@return boolean
function VariableSystem:HasVariable(key)
    return self.variables[key] ~= nil
end

--- 获取所有变量的最终值
---@return table<string, number>
function VariableSystem:GetAllVariables()
    local result = {}
    for key in pairs(self.variables) do
        result[key] = self:GetVariable(key)
    end
    return result
end

--- 获取变量的来源详情
---@param key string 变量名
---@return table|nil 来源详情
function VariableSystem:GetVariableSources(key)
    if not self.variables[key] then
        return nil
    end
    
    return {
        base = self.variables[key].base,
        sources = self.variables[key].sources,
        finalValue = self:GetVariable(key)
    }
end

--- 清空所有变量
function VariableSystem:ClearAllVariables()
    local oldVariables = self:GetAllVariables()
    
    self.variables = {}
    
    -- 触发清空事件
    for k, v in pairs(oldVariables) do
        self:TriggerVariableEvent("VariableRemoved", k, v, nil)
    end
end

--- 移除变量
---@param key string 变量名或部分名
function VariableSystem:RemoveVariable(key)
    local keysToRemove = {}
    local removedVars = {}

    for k, _ in pairs(self.variables) do
        if string.find(k, key) then
            table.insert(keysToRemove, k)
            removedVars[k] = self:GetVariable(k)
        end
    end

    for _, k in ipairs(keysToRemove) do
        self.variables[k] = nil
        
        -- 触发变量移除事件
        self:TriggerVariableEvent("VariableRemoved", k, removedVars[k], nil)
    end
end

-- 条件检查 --------------------------------------------------------

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

-- 变量计算工具 --------------------------------------------------------

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

-- 模式匹配操作 --------------------------------------------------------

--- 根据模式匹配获取变量
---@param pattern string 模式字符串
---@return table<string, number> 匹配的变量
function VariableSystem:GetVariablesByPattern(pattern)
    local matches = {}
    for key in pairs(self.variables) do
        if string.find(key, pattern) then
            matches[key] = self:GetVariable(key)
        end
    end
    return matches
end

--- 根据模式匹配设置变量基础值
---@param pattern string 模式字符串
---@param value number 设置的值
function VariableSystem:SetVariablesByPattern(pattern, value)
    for key in pairs(self.variables) do
        if string.find(key, pattern) then
            self:SetBaseValue(key, value)
        end
    end
end

--- 根据模式匹配增加变量基础值
---@param pattern string 模式字符串
---@param value number 增加的值
function VariableSystem:AddVariablesByPattern(pattern, value)
    for key in pairs(self.variables) do
        if string.find(key, pattern) then
            local currentBase = self:GetBaseValue(key)
            self:SetBaseValue(key, currentBase + value)
        end
    end
end

-- 序列化与持久化 --------------------------------------------------------

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


return VariableSystem