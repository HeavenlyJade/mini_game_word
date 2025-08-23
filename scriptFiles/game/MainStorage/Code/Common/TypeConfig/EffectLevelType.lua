-- EffectLevelType.lua
-- 效果等级配置类型类 - 封装效果等级的元数据和行为逻辑

local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class LevelEffectData
---@field level number 等级
---@field effectValue number 效果数值

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
    -- 基础配置信息
    self.configName = data['配置名称'] or ''
    self.configDesc = data['配置描述'] or ''
    
    -- 等级效果列表
    self.levelEffects = {}
    if data['等级效果列表'] then
        for _, effectData in ipairs(data['等级效果列表']) do
            table.insert(self.levelEffects, {
                level = effectData['等级'] or 1,
                effectValue = effectData['效果数值'] or 0
            })
        end
    end
    
    -- 特殊宠物效果列表
    self.specialPetEffects = {}
    if data['特殊宠物效果列表'] then
        for _, petEffectData in ipairs(data['特殊宠物效果列表']) do
            table.insert(self.specialPetEffects, {
                petId = petEffectData['宠物ID'] or '',
                effectValue = petEffectData['效果数值'] or 0
            })
        end
    end
    
    -- 计算最大等级
    self.maxLevel = self:CalculateMaxLevel()
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

return EffectLevelType
