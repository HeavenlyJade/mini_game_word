-- SkillTypes.lua
-- 定义技能的数据结构类

local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr

---@class SkillType:Class
---@field name string 技能名 (唯一ID)
---@field displayName string 显示名
---@field maxLevel number 最大等级
---@field description string 技能描述
---@field detail string 技能详细
---@field icon string 技能图标
---@field quality string 技能品级
---@field cooldown number 冷却时间
---@field castTime number 施法时间
---@field isInterruptible boolean 可被打断
---@field disablesMovement boolean 施法时禁止移动
---@field baseDamage any 基础伤害 (可能是数字或字符串公式)
---@field damageType string 伤害类型
---@field statModifiers table 属性修改
---@field targetMode string 目标模式
---@field targetSelectionType string 选择类型
---@field maxRange number 最大距离
---@field New fun(data:table):SkillType
local SkillType = ClassMgr.Class("SkillType")

-- 从原始配置数据初始化技能类型对象
function SkillType:OnInit(data)
    -- 基本信息
    self.name = data["技能名"] or "Unknown Skill"
    self.displayName = data["显示名"] or self.name
    self.maxLevel = data["最大等级"] or 1
    self.description = data["技能描述"] or ""
    self.detail = data["技能详细"] or ""
    self.icon = data["技能图标"] or ""
    self.quality = data["技能品级"] or "普通"

    -- 条件与消耗
    self.prerequisites = data["前置条件"] or {}
    
    -- 施法属性
    self.cooldown = data["冷却时间"] or 0
    self.castType = data["施法类型"] or "瞬发"
    self.castTime = data["施法时间"] or 0
    self.isInterruptible = data["可被打断"] or false
    self.disablesMovement = data["禁止移动"] or false
    
    -- 效果
    self.baseDamage = data["基础伤害"] or 0
    self.baseHeal = data["基础治疗"] or 0
    self.damageType = data["伤害类型"] or "物理"
    self.elementType = data["元素类型"] or "无"
    self.statModifiers = data["属性修改"] or {}
    self.statModifierDuration = data["属性修改持续时间"] or 0
    
    -- 目标选择
    self.targetMode = data["目标模式"] or "自己"
    self.targetSelectionType = data["选择类型"] or "单体"
    self.maxRange = data["最大距离"] or 0
    self.maxTargets = data["最大目标数"] or 1
    self.radius = data["范围半径"] or 0

    -- 其他
    self.upgradeMaterials = data["升级所需素材"] or {}
    self.effects = data["技能特效"] or nil
end

function SkillType:GetToStringParams()
    return {
        name = self.name,
        displayName = self.displayName,
        level = self.maxLevel
    }
end

return SkillType