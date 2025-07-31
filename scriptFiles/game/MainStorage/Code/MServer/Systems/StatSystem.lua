local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager

-- 属性触发类型映射
local TRIGGER_STAT_TYPES = {
    ["生命"] = function(entity, value)
        if entity.SetMaxHealth then
            entity:SetMaxHealth(value)
        end
    end,
    ["速度"] = function(entity, value)
        if entity.actor then
            entity.actor.Movespeed = value
        end
    end,
    ["攻击"] = function(entity, value)
        -- 攻击力变化时的逻辑
        if entity._attackCache ~= nil then
            entity._attackCache = value
        end
    end,
    ["防御"] = function(entity, value)
        -- 防御力变化时的逻辑
    end,
    ["魔法"] = function(entity, value)
        -- 魔法力变化时的逻辑
        if entity.SetMaxMana then
            entity:SetMaxMana(value)
        end
    end
}

---@class StatSystem 属性管理系统
---@field stats table<string, table<string, number>> 属性存储 [source][statName] = value
---@field entity any 所属实体
local StatSystem = ClassMgr.Class("StatSystem")

-- 初始化属性系统
function StatSystem:OnInit(entity)
    self.stats = {} -- 属性存储
    self.entity = entity -- 所属实体
end

-- 属性管理 --------------------------------------------------------

--- 添加属性
---@param statName string 属性名
---@param amount number 属性值
---@param source string|nil 来源，默认为"BASE"
---@param refresh boolean|nil 是否刷新，默认为true
function StatSystem:AddStat(statName, amount, source, refresh)
    if not amount then
        return
    end
    source = source or "BASE"
    refresh = refresh == nil and true or refresh

    if not self.stats[source] then
        self.stats[source] = {}
    end

    if not self.stats[source][statName] then
        self.stats[source][statName] = 0
    end

    local oldValue = self:GetStat(statName)
    self.stats[source][statName] = self.stats[source][statName] + amount

    if refresh then
        self:TriggerStatRefresh(statName, oldValue, self:GetStat(statName))
    end
end

--- 设置属性
---@param statName string 属性名
---@param amount number 属性值
---@param source string|nil 来源，默认为"BASE"
---@param refresh boolean|nil 是否刷新，默认为true
function StatSystem:SetStat(statName, amount, source, refresh)
    source = source or "BASE"
    refresh = refresh == nil and true or refresh

    if not self.stats[source] then
        self.stats[source] = {}
    end

    local oldValue = self:GetStat(statName)
    self.stats[source][statName] = amount

    if refresh then
        self:TriggerStatRefresh(statName, oldValue, self:GetStat(statName))
    end
end

--- 获取属性值
---@param statName string 属性名
---@param sources string[]|nil 来源列表，nil表示所有来源
---@param triggerTags boolean|nil 是否触发词条，默认为true
---@param castParam any|nil 施法参数
---@return number 属性值
function StatSystem:GetStat(statName, sources, triggerTags, castParam)
    local amount = 0
    triggerTags = triggerTags == nil and true or triggerTags

    -- 遍历所有来源的属性
    for source, statMap in pairs(self.stats) do
        if not sources or self:TableContains(sources, source) then
            if statMap[statName] then
                amount = amount + statMap[statName]
            end
        end
    end

    -- 触发词条影响属性（如果实体有词条系统）
    if triggerTags and self.entity.tagSystem then
        local tagHandlers = self.entity.tagSystem:GetTagHandlers(statName)
        if tagHandlers then
            -- 创建战斗对象来计算属性修正
            local Battle = require(MainStorage.Code.MServer.Battle)
            if Battle then
                local battle = Battle.New(self.entity, self.entity, statName)
                battle:AddModifier("BASE", "增加", amount)
                self.entity.tagSystem:TriggerTags(statName, self.entity, castParam, battle)
                amount = battle:GetFinalDamage()
            end
        end
    end

    return amount
end

--- 重置属性
---@param source string 来源ID
function StatSystem:ResetStats(source)
    if self.stats[source] then
        local oldStats = {}
        for statName, value in pairs(self.stats[source]) do
            oldStats[statName] = self:GetStat(statName)
        end

        self.stats[source] = nil

        -- 触发属性变化
        for statName, oldValue in pairs(oldStats) do
            self:TriggerStatRefresh(statName, oldValue, self:GetStat(statName))
        end
    end
end

--- 刷新属性（触发实体属性更新）
function StatSystem:RefreshStats()
    if not self.entity then return end

    -- 重置装备属性
    self:ResetStats("EQUIP")

    -- 遍历所有需要触发的属性类型并刷新
    for statName, triggerFunc in pairs(TRIGGER_STAT_TYPES) do
        local value = self:GetStat(statName)
        triggerFunc(self.entity, value)
    end
end

--- 移除特定属性
---@param statName string 属性名
---@param source string|nil 来源，nil表示所有来源
function StatSystem:RemoveStat(statName, source)
    if source then
        if self.stats[source] and self.stats[source][statName] then
            local oldValue = self:GetStat(statName)
            self.stats[source][statName] = nil
            self:TriggerStatRefresh(statName, oldValue, self:GetStat(statName))
        end
    else
        -- 移除所有来源的该属性
        local oldValue = self:GetStat(statName)
        for src in pairs(self.stats) do
            if self.stats[src][statName] then
                self.stats[src][statName] = nil
            end
        end
        self:TriggerStatRefresh(statName, oldValue, self:GetStat(statName))
    end
end

--- 获取属性来源详情
---@param statName string 属性名
---@return table<string, number> 各来源的属性值
function StatSystem:GetStatSources(statName)
    local sources = {}
    for source, statMap in pairs(self.stats) do
        if statMap[statName] then
            sources[source] = statMap[statName]
        end
    end
    return sources
end

--- 获取所有属性
---@param source string|nil 指定来源，nil表示所有来源的总和
---@return table<string, number>
function StatSystem:GetAllStats(source)
    if source then
        return self.stats[source] or {}
    else
        local allStats = {}
        local processedStats = {}

        for _, statMap in pairs(self.stats) do
            for statName in pairs(statMap) do
                if not processedStats[statName] then
                    allStats[statName] = self:GetStat(statName)
                    processedStats[statName] = true
                end
            end
        end

        return allStats
    end
end

--- 复制属性到另一个来源
---@param fromSource string 源来源
---@param toSource string 目标来源
function StatSystem:CopyStats(fromSource, toSource)
    if self.stats[fromSource] then
        if not self.stats[toSource] then
            self.stats[toSource] = {}
        end

        for statName, value in pairs(self.stats[fromSource]) do
            self.stats[toSource][statName] = value
        end

        -- 触发刷新
        self:RefreshStats()
    end
end

--- 合并属性来源
---@param fromSource string 源来源
---@param toSource string 目标来源
---@param removeFrom boolean|nil 是否移除源来源，默认false
function StatSystem:MergeStats(fromSource, toSource, removeFrom)
    if self.stats[fromSource] then
        if not self.stats[toSource] then
            self.stats[toSource] = {}
        end

        for statName, value in pairs(self.stats[fromSource]) do
            if not self.stats[toSource][statName] then
                self.stats[toSource][statName] = 0
            end
            self.stats[toSource][statName] = self.stats[toSource][statName] + value
        end

        if removeFrom then
            self.stats[fromSource] = nil
        end

        -- 触发刷新
        self:RefreshStats()
    end
end

-- 属性计算 --------------------------------------------------------

--- 获取属性百分比修正
---@param statName string 属性名
---@param baseValue number 基础值
---@return number 修正后的值
function StatSystem:GetStatWithPercent(statName, baseValue)
    local flatValue = self:GetStat(statName)
    local percentValue = self:GetStat(statName .. "_PERCENT") / 100
    return baseValue + flatValue + (baseValue * percentValue)
end

--- 获取属性总和
---@param statNames string[] 属性名列表
---@return number 总和
function StatSystem:GetStatSum(statNames)
    local sum = 0
    for _, statName in ipairs(statNames) do
        sum = sum + self:GetStat(statName)
    end
    return sum
end

--- 获取属性乘积
---@param statNames string[] 属性名列表
---@return number 乘积
function StatSystem:GetStatProduct(statNames)
    local product = 1
    for _, statName in ipairs(statNames) do
        product = product * self:GetStat(statName)
    end
    return product
end

--- 属性条件检查
---@param statName string 属性名
---@param operator string 操作符
---@param value number 比较值
---@return boolean
function StatSystem:CheckStatCondition(statName, operator, value)
    local statValue = self:GetStat(statName)

    if operator == ">" then
        return statValue > value
    elseif operator == "<" then
        return statValue < value
    elseif operator == ">=" then
        return statValue >= value
    elseif operator == "<=" then
        return statValue <= value
    elseif operator == "==" then
        return statValue == value
    elseif operator == "!=" then
        return statValue ~= value
    else
        return false
    end
end

-- 属性模板 --------------------------------------------------------

--- 应用属性模板
---@param template table<string, number> 属性模板
---@param source string 来源
function StatSystem:ApplyStatTemplate(template, source)
    for statName, value in pairs(template) do
        self:SetStat(statName, value, source, false)
    end
    self:RefreshStats()
end

--- 移除属性模板
---@param template table<string, number> 属性模板
---@param source string 来源
function StatSystem:RemoveStatTemplate(template, source)
    for statName in pairs(template) do
        self:RemoveStat(statName, source)
    end
end

-- 事件系统 --------------------------------------------------------

--- 触发属性刷新
---@param statName string 属性名
---@param oldValue number 旧值
---@param newValue number 新值
function StatSystem:TriggerStatRefresh(statName, oldValue, newValue)
    -- 触发属性变化处理器
    if TRIGGER_STAT_TYPES[statName] then
        TRIGGER_STAT_TYPES[statName](self.entity, newValue)
    end

    -- 触发属性变化事件
    local evt = {
        entity = self.entity,
        statName = statName,
        oldValue = oldValue,
        newValue = newValue
    }
    ServerEventManager.Publish("StatChangedEvent", evt)
end

-- 工具方法 --------------------------------------------------------

--- 检查表中是否包含值
---@param tbl table 表
---@param value any 值
---@return boolean
function StatSystem:TableContains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

--- 获取属性来源数量
---@return number
function StatSystem:GetSourceCount()
    local count = 0
    for _ in pairs(self.stats) do
        count = count + 1
    end
    return count
end

--- 获取所有来源列表
---@return string[]
function StatSystem:GetAllSources()
    local sources = {}
    for source in pairs(self.stats) do
        table.insert(sources, source)
    end
    return sources
end

--- 清空所有属性
function StatSystem:ClearAllStats()
    local oldStats = self:GetAllStats()
    self.stats = {}

    -- 触发所有属性变化
    for statName, oldValue in pairs(oldStats) do
        self:TriggerStatRefresh(statName, oldValue, 0)
    end
end

--- 属性序列化
---@return string
function StatSystem:SerializeStats()
    local json = require(MainStorage.Code.Common.Untils.json)
    return json.encode(self.stats)
end

--- 属性反序列化
---@param data string
function StatSystem:DeserializeStats(data)
    local json = require(MainStorage.Code.Common.Untils.json)
    local success, stats = pcall(json.decode, data)
    if success and type(stats) == "table" then
        self.stats = stats
        self:RefreshStats()
    else
        --gg.log("属性反序列化失败: " .. tostring(data))
    end
end

-- 静态方法 --------------------------------------------------------

--- 创建新的属性系统实例
---@param entity any 所属实体
---@return StatSystem
function StatSystem.New(entity)
    local instance = StatSystem()
    instance:OnInit(entity)
    return instance
end

--- 注册新的属性触发类型
---@param statName string 属性名
---@param triggerFunc function 触发函数
function StatSystem.RegisterTriggerType(statName, triggerFunc)
    TRIGGER_STAT_TYPES[statName] = triggerFunc
end

--- 获取所有注册的触发类型
---@return table<string, function>
function StatSystem.GetTriggerTypes()
    return TRIGGER_STAT_TYPES
end

return StatSystem
