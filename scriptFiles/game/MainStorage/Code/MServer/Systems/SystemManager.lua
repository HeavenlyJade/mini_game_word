local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.Code.Common.Untils.MGlobal) ---@type gg
local ClassMgr = require(MainStorage.Code.Common.Untils.ClassMgr) ---@type ClassMgr

-- 引入各个系统
local TagSystem = require(MainStorage.Code.MServer.Systems.TagSystem) ---@type TagSystem
local BuffSystem = require(MainStorage.Code.MServer.Systems.BuffSystem) ---@type BuffSystem
local CooldownSystem = require(MainStorage.Code.MServer.Systems.CooldownSystem) ---@type CooldownSystem
local VariableSystem = require(MainStorage.Code.MServer.Systems.VariableSystem) ---@type VariableSystem
local StatSystem = require(MainStorage.Code.MServer.Systems.StatSystem) ---@type StatSystem
local BattleSystem = require(MainStorage.Code.MServer.Systems.BattleSystem) ---@type BattleSystem

---@class SystemManager 系统管理器
---@field entity any 所属实体
---@field tagSystem TagSystem 词条系统
---@field buffSystem BuffSystem BUFF系统
---@field cooldownSystem CooldownSystem 冷却系统
---@field variableSystem VariableSystem 变量系统
---@field statSystem StatSystem 属性系统
---@field battleSystem BattleSystem 战斗系统
local SystemManager = ClassMgr.Class("SystemManager")

-- 初始化系统管理器
function SystemManager:OnInit(entity)
    self.entity = entity
    
    -- 创建各个系统实例
    self.tagSystem = TagSystem.New()
    self.buffSystem = BuffSystem.New(entity)
    self.cooldownSystem = CooldownSystem.New(entity)
    self.variableSystem = VariableSystem.New(entity)
    self.statSystem = StatSystem.New(entity)
    self.battleSystem = BattleSystem.New(entity)
    
    -- 将系统引用添加到实体上（兼容性）
    if entity then
        entity.tagSystem = self.tagSystem
        entity.buffSystem = self.buffSystem
        entity.cooldownSystem = self.cooldownSystem
        entity.variableSystem = self.variableSystem
        entity.statSystem = self.statSystem
        entity.battleSystem = self.battleSystem
    end
end

-- 词条系统代理方法 --------------------------------------------------------

--- 获取词条
---@param id string 词条ID
---@return EquipingTag|nil
function SystemManager:GetTag(id)
    return self.tagSystem:GetTag(id)
end

--- 添加词条处理器
---@param equipingTag EquipingTag 词条对象
function SystemManager:AddTagHandler(equipingTag)
    return self.tagSystem:AddTagHandler(equipingTag)
end

--- 移除词条处理器
---@param id string 词条ID
function SystemManager:RemoveTagHandler(id)
    return self.tagSystem:RemoveTagHandler(id)
end

--- 触发词条
---@param key string 触发键
---@param target any 目标
---@param castParam any|nil 施法参数
---@param ... any 额外参数
function SystemManager:TriggerTags(key, target, castParam, ...)
    return self.tagSystem:TriggerTags(key, self.entity, target, castParam, ...)
end

-- BUFF系统代理方法 --------------------------------------------------------

--- 添加BUFF
---@param buff ActiveBuff BUFF对象
function SystemManager:AddBuff(buff)
    return self.buffSystem:AddBuff(buff)
end

--- 移除BUFF
---@param buffId string BUFF ID
---@param triggerEvent boolean|nil 是否触发事件
function SystemManager:RemoveBuff(buffId, triggerEvent)
    return self.buffSystem:RemoveBuff(buffId, triggerEvent)
end

--- 获取BUFF堆叠数
---@param keyword string|nil BUFF关键字
---@return number 堆叠数
function SystemManager:GetBuffStacks(keyword)
    return self.buffSystem:GetBuffStacks(keyword)
end

--- 检查是否有指定BUFF
---@param buffId string BUFF ID
---@return boolean
function SystemManager:HasBuff(buffId)
    return self.buffSystem:HasBuff(buffId)
end

-- 冷却系统代理方法 --------------------------------------------------------

--- 获取冷却时间
---@param reason string 冷却原因
---@param target any|nil 目标对象
---@return number 剩余冷却时间
function SystemManager:GetCooldown(reason, target)
    return self.cooldownSystem:GetCooldown(reason, target)
end

--- 检查是否在冷却中
---@param reason string 冷却原因
---@param target any|nil 目标对象
---@return boolean 是否在冷却中
function SystemManager:IsCoolingdown(reason, target)
    return self.cooldownSystem:IsCoolingdown(reason, target)
end

--- 设置冷却时间
---@param reason string 冷却原因
---@param time number 冷却时间
---@param target any|nil 目标对象
function SystemManager:SetCooldown(reason, time, target)
    return self.cooldownSystem:SetCooldown(reason, time, target)
end

--- 清除目标冷却
---@param reason string|nil 冷却原因
function SystemManager:ClearTargetCooldowns(reason)
    return self.cooldownSystem:ClearTargetCooldowns(reason)
end

-- 变量系统代理方法 --------------------------------------------------------

--- 设置变量
---@param key string 变量名
---@param value number 变量值
function SystemManager:SetVariable(key, value)
    return self.variableSystem:SetVariable(key, value)
end

--- 获取变量
---@param key string 变量名
---@param defaultValue number|nil 默认值
---@return number 变量值
function SystemManager:GetVariable(key, defaultValue)
    return self.variableSystem:GetVariable(key, defaultValue)
end

--- 增加变量值
---@param key string 变量名
---@param value number 增加值
---@return number 新的变量值
function SystemManager:AddVariable(key, value)
    return self.variableSystem:AddVariable(key, value)
end

--- 移除变量
---@param key string 变量名或部分名
function SystemManager:RemoveVariable(key)
    return self.variableSystem:RemoveVariable(key)
end

-- 属性系统代理方法 --------------------------------------------------------

--- 添加属性
---@param statName string 属性名
---@param amount number 属性值
---@param source string|nil 来源
---@param refresh boolean|nil 是否刷新
function SystemManager:AddStat(statName, amount, source, refresh)
    return self.statSystem:AddStat(statName, amount, source, refresh)
end

--- 获取属性值
---@param statName string 属性名
---@param sources string[]|nil 来源列表
---@param triggerTags boolean|nil 是否触发词条
---@param castParam any|nil 施法参数
---@return number 属性值
function SystemManager:GetStat(statName, sources, triggerTags, castParam)
    return self.statSystem:GetStat(statName, sources, triggerTags, castParam)
end

--- 重置属性
---@param source string 来源ID
function SystemManager:ResetStats(source)
    return self.statSystem:ResetStats(source)
end

--- 刷新属性
function SystemManager:RefreshStats()
    return self.statSystem:RefreshStats()
end

-- 战斗系统代理方法 --------------------------------------------------------

--- 攻击目标
---@param victim any 目标对象
---@param baseDamage number 基础伤害
---@param source string|nil 伤害来源
---@param castParam any|nil 施法参数
---@return any 战斗结果
function SystemManager:Attack(victim, baseDamage, source, castParam)
    return self.battleSystem:Attack(victim, baseDamage, source, castParam)
end

--- 获取敌对组列表
---@return number[]
function SystemManager:GetEnemyGroups()
    return self.battleSystem:GetEnemyGroups()
end

--- 检查是否为敌人
---@param target any 目标对象
---@return boolean
function SystemManager:IsEnemy(target)
    return self.battleSystem:IsEnemy(target)
end

--- 获取最近的敌人
---@param maxDistance number|nil 最大搜索距离
---@return any|nil 最近的敌人
function SystemManager:GetNearestEnemy(maxDistance)
    return self.battleSystem:GetNearestEnemy(maxDistance)
end

-- 系统管理 --------------------------------------------------------

--- 更新所有系统
function SystemManager:UpdateSystems()
    -- 更新BUFF系统（检查过期）
    self.buffSystem:UpdateBuffs()
    
    -- 清理过期的冷却
    self.cooldownSystem:CleanupExpiredCooldowns()
end

--- 获取系统状态
---@return table 系统状态信息
function SystemManager:GetSystemStatus()
    return {
        tags = self.tagSystem:GetTagCount(),
        buffs = self.buffSystem:GetBuffCount(),
        cooldowns = self.cooldownSystem:HasAnyCooldown(),
        variables = self.variableSystem:GetVariableCount(),
        statSources = self.statSystem:GetSourceCount()
    }
end

--- 清空所有系统
function SystemManager:ClearAllSystems()
    self.tagSystem:ClearAllTags()
    self.buffSystem:ClearAllBuffs()
    self.cooldownSystem:ClearCooldown()
    self.variableSystem:ClearAllVariables()
    self.statSystem:ClearAllStats()
end

--- 序列化系统数据
---@return table 序列化数据
function SystemManager:SerializeSystems()
    return {
        variables = self.variableSystem:SerializeVariables(),
        stats = self.statSystem:SerializeStats(),
        -- BUFF和冷却系统通常不需要持久化，因为它们是临时状态
    }
end

--- 反序列化系统数据
---@param data table 序列化数据
function SystemManager:DeserializeSystems(data)
    if data.variables then
        self.variableSystem:DeserializeVariables(data.variables)
    end
    if data.stats then
        self.statSystem:DeserializeStats(data.stats)
    end
end

-- 便捷方法 --------------------------------------------------------

--- 创建BUFF并添加
---@param id string BUFF ID
---@param spell any 技能对象
---@param stack number|nil 堆叠数
---@param duration number|nil 持续时间
---@param source any|nil 来源实体
---@param target any|nil 目标实体
function SystemManager:CreateAndAddBuff(id, spell, stack, duration, source, target)
    local buff = BuffSystem.CreateBuff(id, spell, stack, duration, source, target)
    self:AddBuff(buff)
end

--- 快速设置多个属性
---@param stats table<string, number> 属性表
---@param source string|nil 来源
function SystemManager:SetMultipleStats(stats, source)
    for statName, value in pairs(stats) do
        self.statSystem:SetStat(statName, value, source, false)
    end
    self.statSystem:RefreshStats()
end

--- 快速设置多个变量
---@param variables table<string, number> 变量表
function SystemManager:SetMultipleVariables(variables)
    for key, value in pairs(variables) do
        self.variableSystem:SetVariable(key, value)
    end
end

--- 检查多个冷却
---@param reasons string[] 冷却原因列表
---@return boolean 是否有任何冷却
function SystemManager:HasAnyCooldown(reasons)
    for _, reason in ipairs(reasons) do
        if self.cooldownSystem:IsCoolingdown(reason) then
            return true
        end
    end
    return false
end

--- 获取调试信息
---@return string 调试信息
function SystemManager:GetDebugInfo()
    local status = self:GetSystemStatus()
    return string.format(
        "SystemManager Debug Info:\n" ..
        "- Tags: %d\n" ..
        "- Buffs: %d\n" ..
        "- Has Cooldowns: %s\n" ..
        "- Variables: %d\n" ..
        "- Stat Sources: %d\n",
        status.tags,
        status.buffs,
        tostring(status.cooldowns),
        status.variables,
        status.statSources
    )
end

-- 静态方法 --------------------------------------------------------

--- 创建新的系统管理器实例
---@param entity any 所属实体
---@return SystemManager
function SystemManager.New(entity)
    local instance = SystemManager()
    instance:OnInit(entity)
    return instance
end

--- 为实体添加系统支持
---@param entity any 实体对象
---@return SystemManager 系统管理器实例
function SystemManager.AddToEntity(entity)
    local systemManager = SystemManager.New(entity)
    entity.systemManager = systemManager
    return systemManager
end

return SystemManager 