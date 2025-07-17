local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr 
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local ServerScheduler = require(MainStorage.Code.MServer.Scheduler.ServerScheduler) ---@type ServerScheduler

---@class ActiveBuff 激活的BUFF
---@field id string BUFF ID
---@field spell any 技能对象
---@field stack number 堆叠数
---@field duration number 持续时间
---@field startTime number 开始时间
---@field source any 来源实体
---@field target any 目标实体

---@class BuffSystem BUFF系统
---@field activeBuffs table<string, ActiveBuff> 激活的BUFF
---@field entity any 所属实体
local BuffSystem = ClassMgr.Class("BuffSystem")

-- 初始化BUFF系统
function BuffSystem:OnInit(entity)
    self.activeBuffs = {} -- 激活的BUFF
    self.entity = entity -- 所属实体
end

-- BUFF管理 --------------------------------------------------------

--- 添加BUFF
---@param buff ActiveBuff BUFF对象
function BuffSystem:AddBuff(buff)
    -- 检查是否已存在相同BUFF
    if self.activeBuffs[buff.id] then
        local existingBuff = self.activeBuffs[buff.id]
        -- 如果可以堆叠，增加堆叠数
        if buff.spell and buff.spell.stackable then
            existingBuff.stack = existingBuff.stack + buff.stack
            existingBuff.duration = buff.duration -- 刷新持续时间
            existingBuff.startTime = gg.GetTimeStamp()
        else
            -- 不可堆叠，刷新持续时间
            existingBuff.duration = buff.duration
            existingBuff.startTime = gg.GetTimeStamp()
        end
    else
        -- 新增BUFF
        buff.startTime = gg.GetTimeStamp()
        self.activeBuffs[buff.id] = buff
        
        -- 触发BUFF开始事件
        self:TriggerBuffEvent("BuffStart", buff)
    end
    
    -- 设置BUFF移除定时器
    if buff.duration > 0 then
        ServerScheduler.add(function()
            self:RemoveBuff(buff.id)
        end, buff.duration, nil, "buff_" .. buff.id .. "_" .. (self.entity.uuid or ""))
    end
end

--- 移除BUFF
---@param buffId string BUFF ID
---@param triggerEvent boolean|nil 是否触发事件，默认true
function BuffSystem:RemoveBuff(buffId, triggerEvent)
    triggerEvent = triggerEvent == nil and true or triggerEvent
    
    local buff = self.activeBuffs[buffId]
    if buff then
        self.activeBuffs[buffId] = nil
        
        -- 取消定时器
        ServerScheduler.remove("buff_" .. buffId .. "_" .. (self.entity.uuid or ""))
        
        -- 触发BUFF结束事件
        if triggerEvent then
            self:TriggerBuffEvent("BuffEnd", buff)
        end
    end
end

--- 获取BUFF
---@param buffId string BUFF ID
---@return ActiveBuff|nil
function BuffSystem:GetBuff(buffId)
    return self.activeBuffs[buffId]
end

--- 获取BUFF堆叠数
---@param keyword string|nil BUFF关键字，nil表示获取所有BUFF堆叠数
---@return number 堆叠数
function BuffSystem:GetBuffStacks(keyword)
    local stacks = 0

    if not keyword or keyword == "" then
        -- 获取所有BUFF的堆叠数
        for _, buff in pairs(self.activeBuffs) do
            stacks = stacks + buff.stack
        end
    else
        -- 获取特定关键字的BUFF堆叠数
        for _, buff in pairs(self.activeBuffs) do
            if buff.spell and buff.spell.spellName and string.find(buff.spell.spellName, keyword) then
                stacks = stacks + buff.stack
            elseif string.find(buff.id, keyword) then
                stacks = stacks + buff.stack
            end
        end
    end

    return stacks
end

--- 检查是否有指定BUFF
---@param buffId string BUFF ID
---@return boolean
function BuffSystem:HasBuff(buffId)
    return self.activeBuffs[buffId] ~= nil
end

--- 获取所有BUFF
---@return table<string, ActiveBuff>
function BuffSystem:GetAllBuffs()
    return self.activeBuffs
end

--- 清空所有BUFF
---@param triggerEvent boolean|nil 是否触发事件，默认true
function BuffSystem:ClearAllBuffs(triggerEvent)
    triggerEvent = triggerEvent == nil and true or triggerEvent
    
    for buffId in pairs(self.activeBuffs) do
        self:RemoveBuff(buffId, triggerEvent)
    end
end

--- 更新BUFF（检查过期）
function BuffSystem:UpdateBuffs()
    local currentTime = gg.GetTimeStamp()
    local expiredBuffs = {}
    
    for buffId, buff in pairs(self.activeBuffs) do
        if buff.duration > 0 and (currentTime - buff.startTime) >= buff.duration then
            table.insert(expiredBuffs, buffId)
        end
    end
    
    -- 移除过期的BUFF
    for _, buffId in ipairs(expiredBuffs) do
        self:RemoveBuff(buffId)
    end
end

--- 获取BUFF剩余时间
---@param buffId string BUFF ID
---@return number 剩余时间（秒），-1表示永久BUFF，0表示不存在
function BuffSystem:GetBuffRemainingTime(buffId)
    local buff = self.activeBuffs[buffId]
    if not buff then
        return 0
    end
    
    if buff.duration <= 0 then
        return -1 -- 永久BUFF
    end
    
    local currentTime = gg.GetTimeStamp()
    local remaining = buff.duration - (currentTime - buff.startTime)
    return math.max(0, remaining)
end

--- 延长BUFF持续时间
---@param buffId string BUFF ID
---@param additionalTime number 额外时间（秒）
function BuffSystem:ExtendBuff(buffId, additionalTime)
    local buff = self.activeBuffs[buffId]
    if buff and buff.duration > 0 then
        buff.duration = buff.duration + additionalTime
        
        -- 重新设置定时器
        ServerScheduler.remove("buff_" .. buffId .. "_" .. (self.entity.uuid or ""))
        ServerScheduler.add(function()
            self:RemoveBuff(buffId)
        end, self:GetBuffRemainingTime(buffId), nil, "buff_" .. buffId .. "_" .. (self.entity.uuid or ""))
    end
end

--- 减少BUFF堆叠数
---@param buffId string BUFF ID
---@param reduceCount number 减少数量，默认1
function BuffSystem:ReduceBuffStack(buffId, reduceCount)
    reduceCount = reduceCount or 1
    local buff = self.activeBuffs[buffId]
    
    if buff then
        buff.stack = buff.stack - reduceCount
        if buff.stack <= 0 then
            self:RemoveBuff(buffId)
        end
    end
end

--- 设置BUFF堆叠数
---@param buffId string BUFF ID
---@param stackCount number 堆叠数
function BuffSystem:SetBuffStack(buffId, stackCount)
    local buff = self.activeBuffs[buffId]
    if buff then
        if stackCount <= 0 then
            self:RemoveBuff(buffId)
        else
            buff.stack = stackCount
        end
    end
end

-- 事件系统 --------------------------------------------------------

--- 触发BUFF事件
---@param eventType string 事件类型
---@param buff ActiveBuff BUFF对象
function BuffSystem:TriggerBuffEvent(eventType, buff)
    local evt = {
        eventType = eventType,
        entity = self.entity,
        buff = buff
    }
    ServerEventManager.Publish("BuffEvent", evt)
end

-- 工具方法 --------------------------------------------------------

--- 获取BUFF总数
---@return number
function BuffSystem:GetBuffCount()
    local count = 0
    for _ in pairs(self.activeBuffs) do
        count = count + 1
    end
    return count
end

--- 获取特定类型的BUFF列表
---@param buffType string BUFF类型
---@return ActiveBuff[]
function BuffSystem:GetBuffsByType(buffType)
    local buffs = {}
    for _, buff in pairs(self.activeBuffs) do
        if buff.spell and buff.spell.buffType == buffType then
            table.insert(buffs, buff)
        end
    end
    return buffs
end

--- 检查是否有某类型的BUFF
---@param buffType string BUFF类型
---@return boolean
function BuffSystem:HasBuffType(buffType)
    for _, buff in pairs(self.activeBuffs) do
        if buff.spell and buff.spell.buffType == buffType then
            return true
        end
    end
    return false
end

-- 静态方法 --------------------------------------------------------

--- 创建新的BUFF系统实例
---@param entity any 所属实体
---@return BuffSystem
function BuffSystem.New(entity)
    local instance = BuffSystem()
    instance:OnInit(entity)
    return instance
end

--- 创建BUFF对象
---@param id string BUFF ID
---@param spell any 技能对象
---@param stack number 堆叠数，默认1
---@param duration number 持续时间，默认0（永久）
---@param source any 来源实体
---@param target any 目标实体
---@return ActiveBuff
function BuffSystem.CreateBuff(id, spell, stack, duration, source, target)
    return {
        id = id,
        spell = spell,
        stack = stack or 1,
        duration = duration or 0,
        startTime = 0,
        source = source,
        target = target
    }
end

return BuffSystem 