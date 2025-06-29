local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.Code.Common.Untils.MGlobal) ---@type gg
local ClassMgr = require(MainStorage.Code.Common.Untils.ClassMgr) ---@type ClassMgr

---@class CooldownSystem 冷却系统
---@field cd_list table<string, number> 全局冷却列表
---@field cooldownTarget table<string, table<number, number>> 目标相关冷却列表
---@field entity any 所属实体
local CooldownSystem = ClassMgr.Class("CooldownSystem")

-- 初始化冷却系统
function CooldownSystem:OnInit(entity)
    self.cd_list = {} -- 全局冷却列表
    self.cooldownTarget = {} -- 目标相关冷却列表
    self.entity = entity -- 所属实体
end

-- 冷却管理 --------------------------------------------------------

--- 获取冷却时间
---@param reason string 冷却原因
---@param target any|nil 目标对象
---@return number 剩余冷却时间（秒）
function CooldownSystem:GetCooldown(reason, target)
    if target then
        -- 检查目标相关的冷却
        if self.cooldownTarget[reason] then
            local targetId = self:GetTargetId(target)
            if self.cooldownTarget[reason][targetId] then
                local remainingTime = self.cooldownTarget[reason][targetId] - gg.GetTimeStamp()
                return remainingTime > 0 and remainingTime or 0
            end
        end
    end

    -- 检查全局冷却
    if self.cd_list[reason] then
        local remainingTime = self.cd_list[reason] - gg.GetTimeStamp()
        return remainingTime > 0 and remainingTime or 0
    end

    return 0
end

--- 检查是否在冷却中
---@param reason string 冷却原因
---@param target any|nil 目标对象
---@return boolean 是否在冷却中
function CooldownSystem:IsCoolingdown(reason, target)
    return self:GetCooldown(reason, target) > 0
end

--- 设置冷却时间
---@param reason string 冷却原因
---@param time number 冷却时间(秒)
---@param target any|nil 目标对象
function CooldownSystem:SetCooldown(reason, time, target)
    if target then
        -- 设置目标相关的冷却
        if not self.cooldownTarget[reason] then
            self.cooldownTarget[reason] = {}
        end
        local targetId = self:GetTargetId(target)
        self.cooldownTarget[reason][targetId] = gg.GetTimeStamp() + time
    else
        -- 设置全局冷却
        self.cd_list[reason] = gg.GetTimeStamp() + time
    end
end

--- 清除冷却
---@param reason string|nil 冷却原因，nil表示清除所有冷却
---@param target any|nil 目标对象，nil表示清除全局冷却
function CooldownSystem:ClearCooldown(reason, target)
    if reason then
        if target then
            -- 清除特定目标的特定冷却
            if self.cooldownTarget[reason] then
                local targetId = self:GetTargetId(target)
                self.cooldownTarget[reason][targetId] = nil
            end
        else
            -- 清除特定的全局冷却
            self.cd_list[reason] = nil
        end
    else
        if target then
            -- 清除特定目标的所有冷却
            local targetId = self:GetTargetId(target)
            for cooldownReason in pairs(self.cooldownTarget) do
                if self.cooldownTarget[cooldownReason][targetId] then
                    self.cooldownTarget[cooldownReason][targetId] = nil
                end
            end
        else
            -- 清除所有冷却
            self.cd_list = {}
            self.cooldownTarget = {}
        end
    end
end

--- 清除目标冷却
---@param reason string|nil 冷却原因，nil表示清除所有
function CooldownSystem:ClearTargetCooldowns(reason)
    if reason then
        self.cooldownTarget[reason] = nil
    else
        self.cooldownTarget = {}
    end
end

--- 减少冷却时间
---@param reason string 冷却原因
---@param reduceTime number 减少时间（秒）
---@param target any|nil 目标对象
function CooldownSystem:ReduceCooldown(reason, reduceTime, target)
    if target then
        -- 减少目标相关冷却
        if self.cooldownTarget[reason] then
            local targetId = self:GetTargetId(target)
            if self.cooldownTarget[reason][targetId] then
                self.cooldownTarget[reason][targetId] = self.cooldownTarget[reason][targetId] - reduceTime
                if self.cooldownTarget[reason][targetId] <= gg.GetTimeStamp() then
                    self.cooldownTarget[reason][targetId] = nil
                end
            end
        end
    else
        -- 减少全局冷却
        if self.cd_list[reason] then
            self.cd_list[reason] = self.cd_list[reason] - reduceTime
            if self.cd_list[reason] <= gg.GetTimeStamp() then
                self.cd_list[reason] = nil
            end
        end
    end
end

--- 获取所有冷却信息
---@return table 冷却信息
function CooldownSystem:GetAllCooldowns()
    local cooldowns = {}
    local currentTime = gg.GetTimeStamp()
    
    -- 全局冷却
    for reason, endTime in pairs(self.cd_list) do
        local remaining = endTime - currentTime
        if remaining > 0 then
            cooldowns[reason] = {
                type = "global",
                remaining = remaining
            }
        end
    end
    
    -- 目标冷却
    for reason, targets in pairs(self.cooldownTarget) do
        for targetId, endTime in pairs(targets) do
            local remaining = endTime - currentTime
            if remaining > 0 then
                cooldowns[reason .. "_" .. targetId] = {
                    type = "target",
                    reason = reason,
                    targetId = targetId,
                    remaining = remaining
                }
            end
        end
    end
    
    return cooldowns
end

--- 清理过期的冷却
function CooldownSystem:CleanupExpiredCooldowns()
    local currentTime = gg.GetTimeStamp()
    
    -- 清理全局冷却
    local expiredGlobal = {}
    for reason, endTime in pairs(self.cd_list) do
        if endTime <= currentTime then
            table.insert(expiredGlobal, reason)
        end
    end
    for _, reason in ipairs(expiredGlobal) do
        self.cd_list[reason] = nil
    end
    
    -- 清理目标冷却
    for reason, targets in pairs(self.cooldownTarget) do
        local expiredTargets = {}
        for targetId, endTime in pairs(targets) do
            if endTime <= currentTime then
                table.insert(expiredTargets, targetId)
            end
        end
        for _, targetId in ipairs(expiredTargets) do
            targets[targetId] = nil
        end
        
        -- 如果该原因下没有目标了，移除整个原因
        if next(targets) == nil then
            self.cooldownTarget[reason] = nil
        end
    end
end

--- 检查是否有任何冷却
---@return boolean
function CooldownSystem:HasAnyCooldown()
    -- 检查全局冷却
    local currentTime = gg.GetTimeStamp()
    for _, endTime in pairs(self.cd_list) do
        if endTime > currentTime then
            return true
        end
    end
    
    -- 检查目标冷却
    for _, targets in pairs(self.cooldownTarget) do
        for _, endTime in pairs(targets) do
            if endTime > currentTime then
                return true
            end
        end
    end
    
    return false
end

--- 获取最长的冷却时间
---@return number, string 最长冷却时间和原因
function CooldownSystem:GetLongestCooldown()
    local longestTime = 0
    local longestReason = ""
    local currentTime = gg.GetTimeStamp()
    
    -- 检查全局冷却
    for reason, endTime in pairs(self.cd_list) do
        local remaining = endTime - currentTime
        if remaining > longestTime then
            longestTime = remaining
            longestReason = reason
        end
    end
    
    -- 检查目标冷却
    for reason, targets in pairs(self.cooldownTarget) do
        for targetId, endTime in pairs(targets) do
            local remaining = endTime - currentTime
            if remaining > longestTime then
                longestTime = remaining
                longestReason = reason .. "_" .. targetId
            end
        end
    end
    
    return longestTime, longestReason
end

-- 工具方法 --------------------------------------------------------

--- 获取目标ID
---@param target any 目标对象
---@return number
function CooldownSystem:GetTargetId(target)
    if target and target.actor and target.actor.InstanceID then
        return target.actor.InstanceID
    elseif target and target.uuid then
        return target.uuid
    elseif type(target) == "number" then
        return target
    else
        return 0
    end
end

--- 获取冷却进度（0-1）
---@param reason string 冷却原因
---@param target any|nil 目标对象
---@param totalTime number 总冷却时间
---@return number 进度（0-1）
function CooldownSystem:GetCooldownProgress(reason, target, totalTime)
    if totalTime <= 0 then
        return 1
    end
    
    local remaining = self:GetCooldown(reason, target)
    return math.max(0, (totalTime - remaining) / totalTime)
end

--- 设置最小冷却时间（如果当前冷却更短则更新）
---@param reason string 冷却原因
---@param time number 冷却时间(秒)
---@param target any|nil 目标对象
function CooldownSystem:SetMinCooldown(reason, time, target)
    local currentCooldown = self:GetCooldown(reason, target)
    if currentCooldown < time then
        self:SetCooldown(reason, time, target)
    end
end

--- 设置最大冷却时间（如果当前冷却更长则不更新）
---@param reason string 冷却原因
---@param time number 冷却时间(秒)
---@param target any|nil 目标对象
function CooldownSystem:SetMaxCooldown(reason, time, target)
    local currentCooldown = self:GetCooldown(reason, target)
    if currentCooldown == 0 or currentCooldown > time then
        self:SetCooldown(reason, time, target)
    end
end

-- 静态方法 --------------------------------------------------------

--- 创建新的冷却系统实例
---@param entity any 所属实体
---@return CooldownSystem
function CooldownSystem.New(entity)
    local instance = CooldownSystem()
    instance:OnInit(entity)
    return instance
end

return CooldownSystem 