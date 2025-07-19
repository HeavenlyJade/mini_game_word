-- AchievementRewardCal.lua
-- 成就天赋公式计算器 - 继承自RewardBase，专门用于计算天赋等级效果和升级消耗

local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local RewardBase = require(MainStorage.Code.GameReward.RewardBase) ---@type RewardBase
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class AchievementRewardCal : RewardBase
local AchievementRewardCal = ClassMgr.Class("AchievementRewardCal", RewardBase)

function AchievementRewardCal:OnInit()
    -- 注意：不要手动调用super.OnInit，ClassMgr会自动处理
    self.calcType = "成就天赋计算器"
end

--- 重写构建变量上下文 - 为天赋计算提供专用变量
---@param achievementData table 成就数据 {currentLevel, maxLevel, ...}
---@param achievementType AchievementType 成就类型实例
---@return table<string, any> 变量上下文
function AchievementRewardCal:BuildVariableContext(achievementData, achievementType)
    -- 获取基础变量上下文（虽然在天赋计算中可能用不到）
    local context = self.super.BuildVariableContext(self, achievementData, achievementType)
    
    -- 添加天赋计算专用变量
    context.T_LVL = achievementData.currentLevel or 0        -- 天赋当前等级
    context.TALENT_LEVEL = achievementData.currentLevel or 0 -- 天赋等级（别名）
    context.CURRENT_LEVEL = achievementData.currentLevel or 0 -- 当前等级（别名）
    context.MAX_LEVEL = achievementData.maxLevel or 1        -- 最大等级
    context.NEXT_LEVEL = (achievementData.currentLevel or 0) + 1 -- 下一级等级
    
    -- 可能用于复杂计算的衍生变量
    context.LEVEL_PROGRESS = context.CURRENT_LEVEL / context.MAX_LEVEL -- 等级进度百分比
    context.REMAINING_LEVELS = context.MAX_LEVEL - context.CURRENT_LEVEL -- 剩余等级数
    
    return context
end

--- 计算天赋等级效果数值
---@param formula string 效果公式（如"T_LVL*2+1"）
---@param currentLevel number 当前天赋等级
---@param achievementType AchievementType|nil 成就类型（可选）
---@return number|nil 计算结果
function AchievementRewardCal:CalculateEffectValue(formula, currentLevel, achievementType)
    if not formula then
        return nil
    end
    
    -- 构建计算数据
    local achievementData = {
        currentLevel = currentLevel,
        maxLevel = achievementType and achievementType:GetMaxLevel() or 999
    }
    
    -- 使用父类的公式计算方法
    local result = self:EvaluateFormula(formula, achievementData, achievementType or {})
    
    if result and type(result) == "number" then
        return math.floor(result) -- 天赋效果通常使用整数
    end
    
    return nil
end

--- 计算天赋升级消耗
---@param formula string 消耗公式（如"T_LVL*10+50"）
---@param currentLevel number 当前天赋等级
---@param achievementType AchievementType|nil 成就类型（可选）
---@return number|nil 升级消耗数量
function AchievementRewardCal:CalculateUpgradeCost(formula, currentLevel, achievementType)
    if not formula then
        return nil
    end
    
    -- 构建计算数据（升级消耗基于当前等级计算）
    local achievementData = {
        currentLevel = currentLevel,
        maxLevel = achievementType and achievementType:GetMaxLevel() or 999
    }
    
    -- 使用父类的公式计算方法
    local result = self:EvaluateFormula(formula, achievementData, achievementType or {})
    
    if result and type(result) == "number" and result >= 0 then
        return math.floor(result) -- 消耗数量必须是非负整数
    end
    
    return nil
end

--- 批量计算多个等级的效果值（用于预览等级效果）
---@param formula string 效果公式
---@param startLevel number 起始等级
---@param endLevel number 结束等级
---@param achievementType AchievementType|nil 成就类型
---@return table<number, number> 等级->效果值的映射表
function AchievementRewardCal:CalculateEffectRange(formula, startLevel, endLevel, achievementType)
    local results = {}
    
    for level = startLevel, endLevel do
        local value = self:CalculateEffectValue(formula, level, achievementType)
        if value then
            results[level] = value
        end
    end
    
    return results
end

--- 批量计算多个等级的升级消耗（用于预览升级路径）
---@param formula string 消耗公式
---@param startLevel number 起始等级
---@param endLevel number 结束等级
---@param achievementType AchievementType|nil 成就类型
---@return table<number, number> 等级->消耗数量的映射表
function AchievementRewardCal:CalculateUpgradeCostRange(formula, startLevel, endLevel, achievementType)
    local results = {}
    
    for level = startLevel, endLevel do
        local cost = self:CalculateUpgradeCost(formula, level, achievementType)
        if cost then
            results[level] = cost
        end
    end
    
    return results
end

--- 验证天赋计算数据有效性
---@param achievementData table 成就数据
---@param achievementType any 成就类型（可以是AchievementType或简单table）
---@return boolean 数据是否有效
function AchievementRewardCal:ValidateAchievementData(achievementData, achievementType)
    if not achievementData then
        gg.log("错误: [AchievementRewardCal] 成就数据为空")
        return false
    end
    
    if not achievementData.currentLevel or achievementData.currentLevel < 0 then
        gg.log("错误: [AchievementRewardCal] 成就等级无效:", tostring(achievementData.currentLevel))
        return false
    end
    
    return true
end

--- 获取支持的变量列表（用于调试和文档）
---@return table<string, string> 变量名->描述的映射表
function AchievementRewardCal:GetSupportedVariables()
    return {
        T_LVL = "天赋当前等级（主要变量）",
        TALENT_LEVEL = "天赋等级（T_LVL的别名）",
        CURRENT_LEVEL = "当前等级（T_LVL的别名）",
        MAX_LEVEL = "最大等级",
        NEXT_LEVEL = "下一级等级",
        LEVEL_PROGRESS = "等级进度百分比（0-1）",
        REMAINING_LEVELS = "剩余可升级等级数"
    }
end

return AchievementRewardCal