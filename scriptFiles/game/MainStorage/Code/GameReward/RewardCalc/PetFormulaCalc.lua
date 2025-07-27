-- PetFormulaCalc.lua
-- 宠物公式计算器 - 继承自RewardBase，专门用于计算宠物携带效果和相关公式

local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local RewardBase = require(MainStorage.Code.GameReward.RewardBase) ---@type RewardBase
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class PetFormulaCalc : RewardBase
local PetFormulaCalc = ClassMgr.Class("PetFormulaCalc", RewardBase)

function PetFormulaCalc:OnInit()
    self.calcType = "宠物公式计算器"
end

--- 重写构建变量上下文 - 为宠物计算提供专用变量
---@param petData table 宠物数据 {starLevel, level, ...}
---@param petConfig PetType|nil 宠物配置（可选）
---@return table<string, any> 变量上下文
function PetFormulaCalc:BuildVariableContext(petData, petConfig)
    -- 获取基础变量上下文
    local context = self.super.BuildVariableContext(self, petData, petConfig or {})
    
    -- 添加宠物计算专用变量
    context.S_LVL = petData.starLevel or 1        -- 星级
    context.STAR_LEVEL = petData.starLevel or 1   -- 星级（别名）
    context.PET_LEVEL = petData.level or 1        -- 宠物等级
    context.LVL = petData.level or 1              -- 等级（别名）
    context.RARITY = petData.rarity or "N"        -- 稀有度
    
    -- 可能用于复杂计算的衍生变量
    context.TOTAL_POWER = (context.S_LVL * 10) + context.PET_LEVEL -- 总战力
    context.STAR_BONUS = context.S_LVL * 0.1                       -- 星级基础加成
    
    return context
end

--- 计算宠物携带效果数值
---@param formula string 效果公式（如"S_LVL*0.2"）
---@param starLevel number 当前星级
---@param petLevel number|nil 宠物等级（可选）
---@param petConfig PetType|nil 宠物配置（可选）
---@return number|nil 计算结果
function PetFormulaCalc:CalculateEffectValue(formula, starLevel, petLevel, petConfig)
    if not formula or not starLevel then
        return nil
    end
    
    -- 构建计算数据
    local petData = {
        starLevel = starLevel,
        level = petLevel or 1,
        rarity = petConfig and petConfig.rarity or "N"
    }
    
    -- 使用父类的公式计算方法
    local result = self:EvaluateFormula(formula, petData, petConfig or {})
    
    if result and type(result) == "number" then
        return result
    end
    
    return nil
end

--- 批量计算不同星级的效果值（用于预览星级效果）
---@param formula string 效果公式
---@param startStar number 起始星级
---@param endStar number 结束星级
---@param petLevel number|nil 宠物等级
---@param petConfig PetType|nil 宠物配置
---@return table<number, number> 星级->效果值的映射表
function PetFormulaCalc:CalculateEffectRange(formula, startStar, endStar, petLevel, petConfig)
    local results = {}
    
    for star = startStar, endStar do
        local value = self:CalculateEffectValue(formula, star, petLevel, petConfig)
        if value then
            results[star] = value
        end
    end
    
    return results
end

--- 验证宠物数据
---@param petData table 宠物数据
---@return boolean 是否有效
function PetFormulaCalc:ValidatePlayerData(petData)
    if not petData then
        gg.log("错误: [PetFormulaCalc] 宠物数据为空")
        return false
    end
    
    if not petData.starLevel or type(petData.starLevel) ~= "number" or petData.starLevel < 1 then
        gg.log("错误: [PetFormulaCalc] 星级数据无效:", petData.starLevel)
        return false
    end
    
    return true
end

--- 验证配置数据
---@param config any 配置数据
---@return boolean 是否有效
function PetFormulaCalc:ValidateConfig(config)
    -- 对于宠物公式计算，配置是可选的
    return true
end

--- 空实现 - 宠物公式计算不需要基础奖励
function PetFormulaCalc:CalcBaseReward(petData, config)
    return {}
end

--- 空实现 - 宠物公式计算不需要排名奖励
function PetFormulaCalc:CalcRankReward(petData, config)
    return {}
end

return PetFormulaCalc