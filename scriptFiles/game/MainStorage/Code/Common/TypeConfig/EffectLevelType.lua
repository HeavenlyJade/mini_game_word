-- EffectLevelType.lua
-- 效果等级配置的类型定义

local ClassMgr = require(game:GetService('MainStorage').Code.Untils.ClassMgr)

---@class EffectLevelType : Class
local EffectLevelType = ClassMgr.Class("EffectLevelType")

---@param data table 效果等级配置数据
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
end

--- 获取指定等级的效果数值
---@param level number 等级
---@return number|nil 效果数值，如果等级不存在则返回nil
function EffectLevelType:GetEffectValue(level)
    for _, effect in ipairs(self.levelEffects) do
        if effect.level == level then
            return effect.effectValue
        end
    end
    return nil
end

--- 获取最大等级
---@return number 最大等级
function EffectLevelType:GetMaxLevel()
    local maxLevel = 0
    for _, effect in ipairs(self.levelEffects) do
        if effect.level > maxLevel then
            maxLevel = effect.level
        end
    end
    return maxLevel
end

--- 获取所有等级效果
---@return table 等级效果列表
function EffectLevelType:GetAllLevelEffects()
    return self.levelEffects
end

--- 获取特殊宠物效果
---@return table 特殊宠物效果列表
function EffectLevelType:GetSpecialPetEffects()
    return self.specialPetEffects
end

--- 检查指定等级是否存在
---@param level number 等级
---@return boolean 是否存在
function EffectLevelType:HasLevel(level)
    return self:GetEffectValue(level) ~= nil
end

return EffectLevelType
