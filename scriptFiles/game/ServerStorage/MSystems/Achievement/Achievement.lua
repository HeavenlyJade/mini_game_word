-- Achievement.lua
-- 成就实例类 - 表示玩家已解锁的成就状态和业务逻辑

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local AchievementRewardCal = require(MainStorage.Code.GameReward.RewardCalc.AchievementRewardCal) ---@type AchievementRewardCal
local MPlayer             = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer

---@class Achievement : Class
---@field achievementType AchievementType AchievementType配置引用
---@field playerId string 所属玩家ID
---@field unlockTime number 解锁时间戳
---@field currentLevel number 当前等级（天赋成就用，普通成就为1）
local Achievement = ClassMgr.Class("Achievement")

--- 初始化成就实例
---@param achievementType AchievementType 成就类型配置
---@param playerId string 玩家ID
---@param unlockTime number|nil 解锁时间戳，默认为当前时间
---@param currentLevel number|nil 初始等级，默认为1
function Achievement:OnInit(achievementType, playerId, unlockTime, currentLevel)
    self.achievementType = achievementType
    self.playerId = playerId
    self.unlockTime = unlockTime or os.time()
    self.currentLevel = currentLevel or 1
    
    -- 初始化天赋成就的奖励计算器
    self._rewardCalculator = AchievementRewardCal.New()
end

--- 是否为天赋成就
---@return boolean
function Achievement:IsTalentAchievement()
    return self.achievementType:IsTalentAchievement()
end

--- 获取当前等级
---@return number
function Achievement:GetCurrentLevel()
    return self.currentLevel
end

--- 是否可以升级（仅天赋成就）
---@param player table 玩家实例
---@return boolean
function Achievement:CanUpgrade(player)
    if not self:IsTalentAchievement() then
        return false
    end
    
    -- 检查是否已达到最大等级
    if self.currentLevel >= self.achievementType:GetMaxLevel() then
        return false
    end
    
    -- 检查升级条件
    local upgradeConditions = self.achievementType.upgradeConditions
    if not upgradeConditions then
        return true
    end
    
    -- 检查每个升级条件
    for _, condition in ipairs(upgradeConditions) do
        local itemName = condition["消耗物品"]
        local costFormula = condition["消耗数量"]
        
        if itemName and costFormula and costFormula ~= "" then
            -- 计算所需消耗数量
            local requiredAmount = self._rewardCalculator:CalculateUpgradeCost(
                costFormula, 
                self.currentLevel, 
                self.achievementType
            )
            
            if requiredAmount and requiredAmount > 0 then
                -- 通过玩家背包检查是否有足够的物品
                if not player:CanConsumeItem(itemName, requiredAmount) then
                    return false
                end
            end
        end
    end
    
    return true
end

--- 执行升级（仅天赋成就）
---@param player table 玩家实例
---@return boolean 升级是否成功
function Achievement:Upgrade(player)
    if not self:CanUpgrade(player) then
        return false
    end
    
    -- 消耗升级材料
    local upgradeConditions = self.achievementType.upgradeConditions
    if upgradeConditions then
        for _, condition in ipairs(upgradeConditions) do
            local itemName = condition["消耗物品"]
            local costFormula = condition["消耗数量"]
            
            if itemName and costFormula and costFormula ~= "" then
                local requiredAmount = self._rewardCalculator:CalculateUpgradeCost(
                    costFormula, 
                    self.currentLevel, 
                    self.achievementType
                )
                
                if requiredAmount and requiredAmount > 0 then
                    -- 通过玩家背包系统消耗物品
                    player:ConsumeItem(itemName, requiredAmount)
                end
            end
        end
    end
    
    -- 提升等级
    self.currentLevel = self.currentLevel + 1
    
    -- 应用新等级的效果
    self:ApplyEffects(player)
    
    gg.log(string.format("玩家 %s 成就 %s 升级至 %d 级", 
        self.playerId, self.achievementType.id, self.currentLevel))
    
    return true
end

--- 获取当前等级效果
---@return table|nil
function Achievement:GetCurrentEffect()
    if not self:IsTalentAchievement() then
        -- 普通成就使用解锁奖励
        return self.achievementType.unlockRewards
    end
    
    -- 天赋成就获取当前等级的效果
    return self.achievementType:GetLevelEffect(self.currentLevel)
end

--- 应用效果到玩家
---@param player table 玩家实例
function Achievement:ApplyEffects(player)
    local effects = self:GetCurrentEffect()
    if not effects then
        return
    end
    
    -- 处理不同类型的成就效果
    if self:IsTalentAchievement() then
        -- 天赋成就：应用等级效果
        self:_ApplySingleEffect(effects, player)
    else
        -- 普通成就：应用解锁奖励
        for _, reward in ipairs(effects) do
            self:_ApplySingleEffect(reward, player)
        end
    end
end

--- 应用单个效果
---@param effect table 效果配置
---@param player table 玩家实例
---@private
function Achievement:_ApplySingleEffect(effect, player)
    local effectType = effect["效果类型"]
    local fieldName = effect["效果字段名称"]
    local valueFormula = effect["效果数值"]
    
    if not effectType or not fieldName then
        gg.log("成就效果配置不完整:", self.achievementType.id, effectType, fieldName)
        return
    end
    
    -- 计算效果数值
    local effectValue = self._rewardCalculator:CalculateEffectValue(
        valueFormula, 
        self.currentLevel, 
        self.achievementType
    )
    
    if not effectValue then
        gg.log("成就效果数值计算失败:", self.achievementType.id, valueFormula)
        return
    end
    
    -- 根据效果类型应用到不同系统
    if effectType == "玩家变量" then
        self:_ApplyToVariableSystem(fieldName, effectValue, player)
    elseif effectType == "玩家属性" then
        self:_ApplyToStatSystem(fieldName, effectValue, player)
    else
        gg.log("未知的效果类型:", effectType, "成就:", self.achievementType.id)
    end
end

--- 应用效果到变量系统
---@param fieldName string 变量名
---@param effectValue number 效果值
---@param player table 玩家实例
---@private
function Achievement:_ApplyToVariableSystem(fieldName, effectValue, player)
    if not player.variableSystem then
        gg.log("玩家变量系统不存在:", self.playerId)
        return
    end
    
    -- 根据变量名前缀决定应用方式
    if string.find(fieldName, "^加成_") then
        -- 加成类变量：累加效果值
        player.variableSystem:AddVariable(fieldName, effectValue)
        gg.log(string.format("成就[%s]累加变量: %s +%s", 
            self.achievementType.id, fieldName, tostring(effectValue)))
    else
        -- 其他类型变量（解锁_、配置_等）：直接设置
        player.variableSystem:SetVariable(fieldName, effectValue)
        gg.log(string.format("成就[%s]设置变量: %s = %s", 
            self.achievementType.id, fieldName, tostring(effectValue)))
    end
end

--- 应用效果到属性系统
---@param fieldName string 属性名
---@param effectValue number 效果值
---@param player table 玩家实例
---@private
function Achievement:_ApplyToStatSystem(fieldName, effectValue, player)
    if not player.statSystem then
        gg.log("玩家属性系统不存在:", self.playerId)
        return
    end
    
    -- 使用成就作为属性来源
    local source = "ACHIEVEMENT_" .. self.achievementType.id
    
    -- 添加属性（会自动触发TRIGGER_STAT_TYPES处理）
    player.statSystem:AddStat(fieldName, effectValue, source, true)
    
    gg.log(string.format("成就[%s]增加属性: %s +%s (来源:%s)", 
        self.achievementType.id, fieldName, tostring(effectValue), source))
end

--- 移除成就效果（当成就失效或天赋重置时使用）
---@param player table 玩家实例
function Achievement:RemoveEffects(player)
    if not self:IsTalentAchievement() then
        -- 普通成就解锁后不应该移除效果
        return
    end
    
    -- 天赋成就：清除属性系统中的成就效果
    if player.statSystem then
        local source = "ACHIEVEMENT_" .. self.achievementType.id
        player.statSystem:ResetStats(source)
        gg.log(string.format("移除成就[%s]的所有属性效果", self.achievementType.id))
    end
    
    -- 注意：变量系统的效果通常不移除，因为它们代表解锁状态
    -- 如果需要移除变量效果，需要在具体业务逻辑中处理
end

--- 获取保存数据格式
---@return table
function Achievement:GetSaveData()
    return {
        achievementId = self.achievementType.id,
        playerId = self.playerId,
        unlockTime = self.unlockTime,
        currentLevel = self.currentLevel
    }
end

--- 获取客户端同步数据
---@return table
function Achievement:GetSyncData()
    return {
        id = self.achievementType.id,
        name = self.achievementType.name,
        type = self.achievementType.type,
        unlockTime = self.unlockTime,
        currentLevel = self.currentLevel,
        maxLevel = self.achievementType:GetMaxLevel(),
        canUpgrade = false -- 这个需要在有玩家上下文时计算
    }
end

return Achievement