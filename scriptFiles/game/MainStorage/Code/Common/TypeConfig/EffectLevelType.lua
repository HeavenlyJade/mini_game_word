-- EffectLevelType.lua
-- 效果等级配置类型类 - 封装效果等级的元数据和行为逻辑

local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ActionCosteRewardCal = require(MainStorage.Code.GameReward.RewardCalc.ActionCosteRewardCal) ---@type ActionCosteRewardCal

---@class LevelEffectData
---@field level number 等级
---@field effectValue number 效果数值
---@field conditionType string|nil 条件类型
---@field conditionFormula string|nil 条件公式
---@field effectFormula string|nil 效果公式

---@class SpecialPetEffectData
---@field petId string 宠物ID
---@field effectValue number 效果数值

---@class EffectLevelType : Class
---@field configName string 配置名称
---@field configDesc string 配置描述
---@field levelEffects LevelEffectData[] 等级效果列表
---@field specialPetEffects SpecialPetEffectData[] 特殊宠物效果列表
---@field maxLevel number 最大等级
local EffectLevelType = ClassMgr.Class("EffectLevelType")

--- 初始化效果等级配置类型
---@param data table 配置数据
function EffectLevelType:OnInit(data)
    gg.log("=== EffectLevelType:OnInit 开始 ===")
    gg.log("原始配置数据:", data)
    
    -- 基础配置信息
    self.configName = data['配置名称'] or ''
    self.configDesc = data['配置描述'] or ''
    gg.log("配置名称:", self.configName)
    gg.log("配置描述:", self.configDesc)
    
    -- 等级效果列表
    self.levelEffects = {}
    if data['等级效果列表'] then
        gg.log("等级效果列表数量:", #data['等级效果列表'])
        for i, effectData in ipairs(data['等级效果列表']) do
            gg.log(string.format("--- 处理等级效果%d ---", i))
            gg.log("原始数据:", effectData)
            
            -- 处理空字符串转换为nil
            local conditionType = effectData['条件类型']
            if conditionType == '' then conditionType = nil end
            
            local conditionFormula = effectData['条件公式']
            if conditionFormula == '' then conditionFormula = nil end
            
            local effectFormula = effectData['效果公式']
            if effectFormula == '' then effectFormula = nil end
            
            local processedEffect = {
                level = effectData['等级'] or 1,
                effectValue = effectData['效果数值'] or 0,
                conditionType = conditionType,
                conditionFormula = conditionFormula,
                effectFormula = effectFormula
            }
            
            gg.log("处理后数据:", processedEffect)
            table.insert(self.levelEffects, processedEffect)
        end
    else
        gg.log("警告：没有等级效果列表配置")
    end
    
    -- 特殊宠物效果列表
    self.specialPetEffects = {}
    if data['特殊宠物效果列表'] then
        gg.log("特殊宠物效果列表数量:", #data['特殊宠物效果列表'])
        for i, petEffectData in ipairs(data['特殊宠物效果列表']) do
            gg.log(string.format("--- 处理特殊宠物效果%d ---", i))
            gg.log("宠物ID:", petEffectData['宠物ID'])
            gg.log("效果数值:", petEffectData['效果数值'])
            
            table.insert(self.specialPetEffects, {
                petId = petEffectData['宠物ID'] or '',
                effectValue = petEffectData['效果数值'] or 0
            })
        end
    else
        gg.log("没有特殊宠物效果列表配置")
    end
    
    -- 计算最大等级
    self.maxLevel = self:CalculateMaxLevel()
    gg.log("计算出的最大等级:", self.maxLevel)
    
    gg.log("=== EffectLevelType:OnInit 结束 ===")
end

--- 计算最大等级
---@return number 最大等级
function EffectLevelType:CalculateMaxLevel()
    local maxLevel = 0
    for _, effect in ipairs(self.levelEffects) do
        if effect.level > maxLevel then
            maxLevel = effect.level
        end
    end
    return maxLevel
end

--- 获取配置名称
---@return string 配置名称
function EffectLevelType:GetConfigName()
    return self.configName
end

--- 获取配置描述
---@return string 配置描述
function EffectLevelType:GetConfigDesc()
    return self.configDesc
end

--- 获取最大等级
---@return number 最大等级
function EffectLevelType:GetMaxLevel()
    return self.maxLevel
end

--- 获取指定等级的效果数值
---@param level number 等级
---@return number|nil 效果数值，如果等级不存在则返回nil
function EffectLevelType:GetEffectValue(level)
    if not self.levelEffects or #self.levelEffects == 0 then
        return nil
    end
    
    for _, effect in ipairs(self.levelEffects) do
        if effect.level == level then
            return effect.effectValue
        end
    end
    return nil
end

--- 获取指定等级的效果数据
---@param level number 等级
---@return LevelEffectData|nil 效果数据，如果等级不存在则返回nil
function EffectLevelType:GetLevelEffect(level)
    if not self.levelEffects or #self.levelEffects == 0 then
        return nil
    end
    
    for _, effect in ipairs(self.levelEffects) do
        if effect.level == level then
            return effect
        end
    end
    return nil
end

--- 获取所有等级效果
---@return LevelEffectData[] 等级效果列表
function EffectLevelType:GetAllLevelEffects()
    return self.levelEffects
end

--- 获取特殊宠物效果
---@return SpecialPetEffectData[] 特殊宠物效果列表
function EffectLevelType:GetSpecialPetEffects()
    return self.specialPetEffects
end

--- 获取指定宠物的特殊效果
---@param petId string 宠物ID
---@return SpecialPetEffectData|nil 特殊宠物效果数据
function EffectLevelType:GetSpecialPetEffect(petId)
    if not self.specialPetEffects or #self.specialPetEffects == 0 then
        return nil
    end
    
    for _, petEffect in ipairs(self.specialPetEffects) do
        if petEffect.petId == petId then
            return petEffect
        end
    end
    return nil
end

--- 检查指定等级是否存在
---@param level number 等级
---@return boolean 是否存在
function EffectLevelType:HasLevel(level)
    return self:GetEffectValue(level) ~= nil
end

--- 检查是否有特殊宠物效果
---@return boolean 是否有特殊宠物效果
function EffectLevelType:HasSpecialPetEffects()
    return self.specialPetEffects and #self.specialPetEffects > 0
end

--- 获取等级数量
---@return number 等级数量
function EffectLevelType:GetLevelCount()
    return self.levelEffects and #self.levelEffects or 0
end

--- 获取特殊宠物效果数量
---@return number 特殊宠物效果数量
function EffectLevelType:GetSpecialPetEffectCount()
    return self.specialPetEffects and #self.specialPetEffects or 0
end

--- 验证等级是否有效
---@param level number 等级
---@return boolean 是否有效
function EffectLevelType:IsValidLevel(level)
    return level > 0 and level <= self.maxLevel
end

--- 获取等级范围
---@return number, number 最小等级, 最大等级
function EffectLevelType:GetLevelRange()
    if not self.levelEffects or #self.levelEffects == 0 then
        return 0, 0
    end
    
    local minLevel = self.levelEffects[1].level
    local maxLevel = self.levelEffects[1].level
    
    for _, effect in ipairs(self.levelEffects) do
        if effect.level < minLevel then
            minLevel = effect.level
        end
        if effect.level > maxLevel then
            maxLevel = effect.level
        end
    end
    
    return minLevel, maxLevel
end

--- 获取指定等级的条件类型
---@param level number 等级
---@return string|nil 条件类型，如果等级不存在则返回nil
function EffectLevelType:GetConditionType(level)
    local effect = self:GetLevelEffect(level)
    return effect and effect.conditionType or nil
end

--- 获取指定等级的条件公式
---@param level number 等级
---@return string|nil 条件公式，如果等级不存在则返回nil
function EffectLevelType:GetConditionFormula(level)
    local effect = self:GetLevelEffect(level)
    return effect and effect.conditionFormula or nil
end

--- 获取指定等级的效果公式
---@param level number 等级
---@return string|nil 效果公式，如果等级不存在则返回nil
function EffectLevelType:GetEffectFormula(level)
    local effect = self:GetLevelEffect(level)
    return effect and effect.effectFormula or nil
end

--- 检查指定等级是否有条件
---@param level number 等级
---@return boolean 是否有条件
function EffectLevelType:HasCondition(level)
    local effect = self:GetLevelEffect(level)
    return effect and (effect.conditionType ~= nil or effect.conditionFormula ~= nil)
end

--- 检查指定等级是否有效果公式
---@param level number 等级
---@return boolean 是否有效果公式
function EffectLevelType:HasEffectFormula(level)
    local effect = self:GetLevelEffect(level)
    return effect and effect.effectFormula ~= nil
end


-- 在 EffectLevelType 类中添加以下方法：

--- 获取或创建计算器实例
---@return ActionCosteRewardCal
function EffectLevelType:_GetCalculator()
    if not self.calculator then
        self.calculator = ActionCosteRewardCal.New()
    end
    return self.calculator
end

--- 计算玩家满足条件的所有效果配置
---@param playerData table 玩家数据
---@param bagData table 背包数据
---@param externalContext table|nil 外部上下文
---@return table[] 满足条件的效果配置列表，每个元素包含 {index=索引, effectValue=效果数值, levelEffect=原始配置}
function EffectLevelType:CalculateMatchingEffects(playerData, bagData, externalContext)
    local matchingEffects = {}
    
    gg.log("=== EffectLevelType:CalculateMatchingEffects 开始 ===")
    gg.log("配置名称:", self.configName)
    gg.log("等级效果数量:", self.levelEffects and #self.levelEffects or 0)
    gg.log("玩家数据:", playerData)
    gg.log("背包数据:", bagData)
    gg.log("外部上下文:", externalContext)
    
    if not self.levelEffects or #self.levelEffects == 0 then
        gg.log("警告：没有等级效果配置，返回空列表")
        return matchingEffects
    end
    
    for index, levelEffect in ipairs(self.levelEffects) do
        gg.log(string.format("--- 处理第%d个等级效果 ---", index))
        gg.log("等级:", levelEffect.level)
        gg.log("效果数值:", levelEffect.effectValue)
        gg.log("条件类型:", levelEffect.conditionType)
        gg.log("条件公式:", levelEffect.conditionFormula)
        gg.log("效果公式:", levelEffect.effectFormula)
        
        local conditionMet = false
        
        if levelEffect.conditionType == '公式' and levelEffect.conditionFormula then
            gg.log("使用公式条件计算...")
            -- 使用 ActionCosteRewardCal 计算公式条件
            local calculator = self:_GetCalculator()
            local result = calculator:_CalculateValue(levelEffect.conditionFormula, playerData, bagData, externalContext)
            conditionMet = (result == true)
            gg.log("公式计算结果:", result, "条件满足:", conditionMet)
            
        elseif levelEffect.conditionType == '数值' then
            gg.log("使用数值条件，直接满足")
            -- 数值类型直接返回true（或者可以根据具体业务逻辑调整）
            conditionMet = true
            
        elseif not levelEffect.conditionType or levelEffect.conditionType == '' then
            gg.log("无条件类型，默认满足")
            -- 没有条件类型，默认满足
            conditionMet = true
        end
        
        if conditionMet then
            gg.log(string.format("条件满足，添加效果配置 - 索引:%d, 效果数值:%s", index, tostring(levelEffect.effectValue)))
            table.insert(matchingEffects, {
                index = index,
                effectValue = levelEffect.effectValue,
                levelEffect = levelEffect
            })
        else
            gg.log(string.format("条件不满足，跳过效果配置 - 索引:%d", index))
        end
    end
    
    gg.log("=== 最终结果 ===")
    gg.log("满足条件的效果数量:", #matchingEffects)
    for i, effect in ipairs(matchingEffects) do
        gg.log(string.format("效果%d: 索引=%d, 效果数值=%s", i, effect.index, tostring(effect.effectValue)))
    end
    gg.log("=== EffectLevelType:CalculateMatchingEffects 结束 ===")
    
    return matchingEffects
end

--- 获取效果数值最大的配置索引
---@param playerData table 玩家数据
---@param bagData table 背包数据
---@param externalContext table|nil 外部上下文
---@return number|nil 最大效果数值对应的索引，如果没有满足条件的配置则返回nil
function EffectLevelType:GetMaxEffectIndex(playerData, bagData, externalContext)
    gg.log("=== EffectLevelType:GetMaxEffectIndex 开始 ===")
    gg.log("配置名称:", self.configName)
    
    local matchingEffects = self:CalculateMatchingEffects(playerData, bagData, externalContext)
    
    if #matchingEffects == 0 then
        gg.log("没有满足条件的效果配置，返回nil")
        return nil
    end
    
    local maxEffectValue = matchingEffects[1].effectValue
    local maxIndex = matchingEffects[1].index
    
    gg.log("初始最大效果值:", maxEffectValue, "对应索引:", maxIndex)
    
    for i, effect in ipairs(matchingEffects) do
        gg.log(string.format("比较效果%d: 索引=%d, 效果数值=%s", i, effect.index, tostring(effect.effectValue)))
        if effect.effectValue > maxEffectValue then
            gg.log(string.format("发现更大的效果值: %s > %s，更新最大值", tostring(effect.effectValue), tostring(maxEffectValue)))
            maxEffectValue = effect.effectValue
            maxIndex = effect.index
        end
    end
    
    gg.log("最终结果: 最大效果值=", maxEffectValue, "对应索引=", maxIndex)
    gg.log("=== EffectLevelType:GetMaxEffectIndex 结束 ===")
    
    return maxIndex
end

return EffectLevelType

