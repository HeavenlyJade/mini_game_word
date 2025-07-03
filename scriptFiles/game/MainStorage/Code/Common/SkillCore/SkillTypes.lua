--- 技能系统类型定义文件
--- 按照9模块架构设计，为每个模块提供对应的数据结构
--- V109 miniw-haima

---@class SkillTypes
local SkillTypes = {}

--[[
===================================
核心枚举类型定义
===================================
]]

--- 技能类型枚举
---@enum SkillType
SkillTypes.SkillType = {
    ACTIVE = "active",              -- 主动技能
    PASSIVE = "passive",            -- 被动技能
    ITEM = "item",                  -- 物品技能
    BUFF = "buff",                  -- BUFF效果
    AURA = "aura"                   -- 光环技能
}

--- 目标类型枚举
---@enum TargetType
SkillTypes.TargetType = {
    SELF = "self",                  -- 自身
    ALLY = "ally",                  -- 盟友
    ENEMY = "enemy",                -- 敌人
    NEUTRAL = "neutral",            -- 中立
    ALL = "all",                    -- 所有
    GROUND = "ground",              -- 地面位置
    CORPSE = "corpse"               -- 尸体
}

--- 施法类型枚举
---@enum CastType
SkillTypes.CastType = {
    INSTANT = "instant",            -- 瞬发
    CHANNELED = "channeled",        -- 引导
    CAST = "cast",                  -- 吟唱
    CHARGE = "charge",              -- 蓄力
    TOGGLE = "toggle"               -- 开关
}

--- 效果类型枚举
---@enum EffectType
SkillTypes.EffectType = {
    DAMAGE = "damage",              -- 伤害
    HEAL = "heal",                  -- 治疗
    BUFF = "buff",                  -- 增益
    DEBUFF = "debuff",              -- 减益
    SUMMON = "summon",              -- 召唤
    TELEPORT = "teleport",          -- 传送
    TRANSFORM = "transform",        -- 变身
    CONTROL = "control"             -- 控制
}

--- 伤害类型枚举
---@enum DamageType
SkillTypes.DamageType = {
    PHYSICAL = "physical",          -- 物理伤害
    MAGICAL = "magical",            -- 魔法伤害
    FIRE = "fire",                  -- 火焰伤害
    ICE = "ice",                    -- 冰霜伤害
    LIGHTNING = "lightning",        -- 雷电伤害
    POISON = "poison",              -- 毒素伤害
    HOLY = "holy",                  -- 神圣伤害
    DARK = "dark"                   -- 暗黑伤害
}

--- 资源类型枚举
---@enum ResourceType
SkillTypes.ResourceType = {
    MANA = "mana",                  -- 法力值
    STAMINA = "stamina",            -- 体力值
    HEALTH = "health",              -- 生命值
    RAGE = "rage",                  -- 怒气值
    ENERGY = "energy",              -- 能量值
    CHARGE = "charge",              -- 充能次数
    ITEM = "item",                  -- 物品消耗
    GOLD = "gold"                   -- 金币消耗
}

--[[
===================================
模块1：前置条件检查相关类型
===================================
]]

--- 资源消耗配置
---@class ResourceCost
---@field type ResourceType 资源类型
---@field amount number|string 消耗数量(支持公式)
---@field percentage boolean 是否按百分比消耗
SkillTypes.ResourceCost = {}

--- 前置条件配置
---@class PreCondition
---@field resourceCosts ResourceCost[] 资源消耗列表
---@field cooldowns table<string, number> 冷却时间要求
---@field levelRequirements table<string, number> 等级要求
---@field stateRequirements string[] 状态要求
---@field equipmentRequirements string[] 装备要求
---@field positionRequirements table 位置要求
---@field environmentRequirements table 环境要求
---@field buffRequirements string[] BUFF要求
---@field customConditions table[] 自定义条件
SkillTypes.PreCondition = {}

--[[
===================================
模块2：目标选择验证相关类型
===================================
]]

--- 目标选择配置
---@class TargetConfig
---@field targetType TargetType 目标类型
---@field selectionType string 选择类型 ("single"|"multi"|"area"|"chain"|"random")
---@field maxTargets number 最大目标数量
---@field range number 选择范围
---@field filters TargetFilter[] 目标过滤器
---@field priority string 优先级规则 ("nearest"|"farthest"|"lowest_hp"|"highest_hp")
---@field requiresLineOfSight boolean 是否需要视线
---@field canTargetSelf boolean 是否可以选择自己
---@field canTargetDead boolean 是否可以选择死亡目标
SkillTypes.TargetConfig = {}

--- 目标过滤器
---@class TargetFilter
---@field filterType string 过滤器类型
---@field parameters table 过滤器参数
---@field isExclusive boolean 是否排他性过滤
SkillTypes.TargetFilter = {}

--[[
===================================
模块3：施法前摇阶段相关类型
===================================
]]

--- 施法配置
---@class CastConfig
---@field castType CastType 施法类型
---@field castTime number 施法时间(秒)
---@field canMove boolean 施法时是否可以移动
---@field canRotate boolean 施法时是否可以转向
---@field interruptible boolean 是否可以被打断
---@field requiresFacing boolean 是否需要面向目标
---@field chargeStages table[] 蓄力阶段配置(仅蓄力技能)
---@field channelTicks number 引导技能跳数(仅引导技能)
---@field animationConfig table 动画配置
---@field soundConfig table 音效配置
SkillTypes.CastConfig = {}

--[[
===================================
模块4：效果计算相关类型
===================================
]]

--- 效果计算配置
---@class EffectCalculation
---@field baseValue number|string 基础数值(支持公式)
---@field scalingFactors table<string, number> 属性加成系数
---@field levelScaling string 等级加成公式
---@field randomRange table 随机范围 {min, max}
---@field criticalConfig table 暴击配置
---@field resistanceConfig table 抗性配置
---@field damageType DamageType 伤害类型(仅伤害效果)
---@field healType string 治疗类型(仅治疗效果)
SkillTypes.EffectCalculation = {}

--[[
===================================
模块5：作用于目标相关类型
===================================
]]

--- 技能效果配置
---@class SkillEffect
---@field effectType EffectType 效果类型
---@field calculation EffectCalculation 计算配置
---@field duration number 持续时间(秒)
---@field stackable boolean 是否可叠加
---@field maxStacks number 最大叠加层数
---@field immunityConfig table 免疫配置
---@field reflectionConfig table 反射配置
---@field absorptionConfig table 吸收配置
---@field areaConfig table 范围效果配置
---@field dotConfig table 持续伤害配置
---@field hotConfig table 持续治疗配置
SkillTypes.SkillEffect = {}

--[[
===================================
模块6：特效表现相关类型
===================================
]]

--- 特效表现配置
---@class VFXConfig
---@field casterEffects table[] 施法者特效
---@field targetEffects table[] 目标特效
---@field projectileEffects table[] 弹道特效
---@field areaEffects table[] 范围特效
---@field connectionEffects table[] 连接特效
---@field soundEffects table[] 音效配置
---@field cameraEffects table[] 摄像机效果
---@field uiEffects table[] UI反馈效果
---@field screenEffects table[] 屏幕效果
SkillTypes.VFXConfig = {}

--[[
===================================
模块7：后置处理相关类型
===================================
]]

--- 后置处理配置
---@class PostProcessConfig
---@field triggerPassiveSkills boolean 是否触发被动技能
---@field updateStatistics boolean 是否更新统计
---@field updateQuests boolean 是否更新任务进度
---@field updateAchievements boolean 是否检查成就
---@field comboConfig table 连击配置
---@field hatredConfig table 仇恨值配置
---@field combatStateConfig table 战斗状态配置
---@field experienceConfig table 经验获得配置
---@field lootConfig table 掉落处理配置
---@field chainSkillConfig table 连锁技能配置
SkillTypes.PostProcessConfig = {}

--[[
===================================
模块8：状态更新相关类型
===================================
]]

--- 状态更新配置
---@class StateUpdateConfig
---@field cooldownUpdates table<string, number> 冷却时间更新
---@field resourceUpdates ResourceCost[] 资源更新
---@field buffUpdates table[] BUFF状态更新
---@field attributeUpdates table[] 属性重新计算
---@field uiUpdates table[] UI界面更新
---@field networkSync boolean 是否需要网络同步
---@field logConfig table 日志记录配置
---@field statisticsConfig table 数据统计配置
SkillTypes.StateUpdateConfig = {}

--[[
===================================
模块9：条件分支相关类型
===================================
]]

--- 条件分支配置
---@class BranchConfig
---@field successBranch table 成功分支
---@field failureBranch table 失败分支
---@field criticalBranch table 暴击分支
---@field immuneBranch table 免疫分支
---@field reflectBranch table 反射分支
---@field absorbBranch table 吸收分支
---@field triggerBranch table 触发分支
---@field chainBranch table 连锁分支
---@field evolutionBranch table 进化分支
---@field customBranches table[] 自定义分支
SkillTypes.BranchConfig = {}

--[[
===================================
核心技能数据结构
===================================
]]

--- 完整的技能数据配置
---@class SkillData
---@field id string 技能唯一标识
---@field name string 技能名称
---@field skillType SkillType 技能类型
---@field maxLevel number 最大等级
---@field preCondition PreCondition 前置条件配置
---@field targetConfig TargetConfig 目标选择配置
---@field castConfig CastConfig 施法配置
---@field effects SkillEffect[] 技能效果列表
---@field vfxConfig VFXConfig 特效配置
---@field postProcessConfig PostProcessConfig 后置处理配置
---@field stateUpdateConfig StateUpdateConfig 状态更新配置
---@field branchConfig BranchConfig 条件分支配置
---@field metadata table 元数据(描述、图标等)
SkillTypes.SkillData = {}

--- 技能运行时实例
---@class SkillInstance
---@field skillData SkillData 技能配置
---@field caster Entity 施法者
---@field targets Entity[] 目标列表
---@field startTime number 开始时间
---@field currentStage string 当前阶段
---@field context table 执行上下文
---@field results table 执行结果
---@field isCompleted boolean 是否完成
---@field isCancelled boolean 是否取消
SkillTypes.SkillInstance = {}

--- 技能执行结果
---@class SkillResult
---@field success boolean 是否成功
---@field errorCode number 错误码
---@field errorMessage string 错误消息
---@field affectedTargets Entity[] 受影响的目标
---@field damageDealt number 造成的伤害
---@field healingDone number 造成的治疗
---@field effectsApplied table[] 应用的效果
---@field resourcesConsumed table[] 消耗的资源
---@field triggeredEvents table[] 触发的事件
SkillTypes.SkillResult = {}

--[[
===================================
执行上下文相关类型
===================================
]]

--- 技能执行上下文
---@class SkillContext
---@field skillInstance SkillInstance 技能实例
---@field currentModule string 当前执行模块
---@field moduleResults table<string, any> 各模块执行结果
---@field globalData table 全局数据
---@field tempData table 临时数据
---@field timestamp number 当前时间戳
SkillTypes.SkillContext = {}

--- 模块执行结果
---@class ModuleResult
---@field success boolean 是否成功
---@field data any 结果数据
---@field errorCode number 错误码(失败时)
---@field errorMessage string 错误消息(失败时)
---@field nextModule string 下一个模块(可选)
---@field skipModules string[] 跳过的模块列表(可选)
SkillTypes.ModuleResult = {}

--[[
===================================
配置验证相关类型
===================================
]]

--- 配置验证结果
---@class ValidationResult
---@field isValid boolean 是否有效
---@field errors string[] 错误列表
---@field warnings string[] 警告列表
---@field suggestions string[] 建议列表
SkillTypes.ValidationResult = {}

--[[
===================================
辅助工具函数
===================================
]]

--- 创建默认的技能数据
---@param id string 技能ID
---@param skillType SkillType 技能类型
---@return SkillData
function SkillTypes.CreateDefaultSkillData(id, skillType)
    return {
        id = id,
        name = "",
        skillType = skillType,
        maxLevel = 1,
        preCondition = {},
        targetConfig = {
            targetType = SkillTypes.TargetType.ENEMY,
            selectionType = "single",
            maxTargets = 1,
            range = 100
        },
        castConfig = {
            castType = SkillTypes.CastType.INSTANT,
            castTime = 0,
            canMove = true,
            interruptible = false
        },
        effects = {},
        vfxConfig = {},
        postProcessConfig = {},
        stateUpdateConfig = {},
        branchConfig = {},
        metadata = {}
    }
end

--- 验证技能数据完整性
---@param skillData SkillData
---@return ValidationResult
function SkillTypes.ValidateSkillData(skillData)
    local result = {
        isValid = true,
        errors = {},
        warnings = {},
        suggestions = {}
    }
    
    -- 基础验证
    if not skillData.id or skillData.id == "" then
        result.isValid = false
        table.insert(result.errors, "技能ID不能为空")
    end
    
    if not skillData.skillType then
        result.isValid = false
        table.insert(result.errors, "必须指定技能类型")
    end
    
    if not skillData.effects or #skillData.effects == 0 then
        table.insert(result.warnings, "技能没有配置任何效果")
    end
    
    -- 更多验证逻辑...
    
    return result
end

--- 深度复制技能数据
---@param skillData SkillData
---@return SkillData
function SkillTypes.DeepCopySkillData(skillData)
    -- 实现深度复制逻辑
    local copy = {}
    for k, v in pairs(skillData) do
        if type(v) == "table" then
            copy[k] = SkillTypes.DeepCopySkillData(v)
        else
            copy[k] = v
        end
    end
    return copy
end

return SkillTypes 