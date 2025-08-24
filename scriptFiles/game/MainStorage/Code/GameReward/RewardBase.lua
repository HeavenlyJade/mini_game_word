local MainStorage = game:GetService("MainStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)
local gg = require(MainStorage.Code.Untils.MGlobal)

---@class RewardBase : Class
---@field calcType string 计算器类型名称
local RewardBase = ClassMgr.Class("RewardBase")

--- 初始化奖励计算器
---@param calcType string 计算器类型（如"飞车挑战赛"）
function RewardBase:OnInit(calcType)
    self.calcType = calcType or "未知计算器"
end

--- 【新增】构建变量上下文 - 子类可重写以提供特定变量
---@param playerData table 玩家数据
---@param levelInstance LevelType 关卡实例
---@return table<string, any> 变量映射表
function RewardBase:BuildVariableContext(playerData, levelInstance)
    -- 基础变量（所有计算器都支持）
    return {
        -- 玩家相关
        rank = playerData.rank or 1,
        uin = playerData.uin or 0,
        playerName = playerData.playerName or "",

        -- 关卡相关（从 levelInstance 获取）
        minPlayers = levelInstance.minPlayers or 1,
        maxPlayers = levelInstance.maxPlayers or 8,
        totalPlayers = #(levelInstance.participants or {}),
        raceTime = levelInstance.raceTime or 60,
        prepTime = levelInstance.prepareTime or 10,
    }
end

--- 【重构】安全地计算公式
---@param formula string|number 公式字符串或直接数值
---@param playerData table 玩家数据
---@param levelInstance LevelType 关卡实例
---@return number|nil 计算结果
function RewardBase:EvaluateFormula(formula, playerData, levelInstance)
    if not formula or not playerData or not levelInstance then return nil end

    if type(formula) == "number" then return formula end
    if type(formula) ~= "string" then formula = tostring(formula) end

    local context = self:BuildVariableContext(playerData, levelInstance)
    local processedFormula = self:_ReplaceVariables(formula, context)

    if not processedFormula then
        --gg.log(string.format("错误: [%s] 变量替换失败，公式: %s", self.calcType, formula))
        return nil
    end

    local success, result = pcall(function() return gg.eval(processedFormula) end)

    if not success or type(result) ~= "number" then
        --gg.log(string.format("错误: [%s] 公式计算失败 '%s' -> '%s': %s",self.calcType, formula, processedFormula, tostring(result)))
        return nil
    end

    return result
end

--- 【新增】安全的变量替换，支持完整单词匹配
---@param formula string 原始公式
---@param context table<string, any> 变量上下文
---@return string|nil 处理后的公式
function RewardBase:_ReplaceVariables(formula, context)
    local result = formula

    local sortedVars = {}
    for varName, _ in pairs(context) do table.insert(sortedVars, varName) end
    table.sort(sortedVars, function(a, b) return #a > #b end)

    for _, varName in ipairs(sortedVars) do
        local varValue = context[varName]
        if type(varValue) == "number" then
            varValue = tostring(varValue)
        elseif type(varValue) ~= "string" then
            --gg.log(string.format("警告: [%s] 变量 '%s' 的值类型无效: %s", self.calcType, varName, type(varValue)))
            return nil
        end
        result = string.gsub(result, "%f[%w_]" .. varName .. "%f[^%w_]", varValue)
    end

    return result
end

--- 计算基础奖励（子类必须重写）
---@param playerData table 玩家数据 {rank, distance, ...}
---@param levelInstance LevelType 关卡实例，包含所有配置
---@return table<string, number>|nil 基础奖励 {物品名称: 数量}
function RewardBase:CalcBaseReward(playerData, levelInstance)
    --gg.log(string.format("警告: 计算器 %s 未实现 CalcBaseReward 方法", self.calcType))
    return nil
end

--- 计算排名奖励（子类必须重写）
---@param playerData table 玩家数据
---@param levelInstance LevelType 关卡实例，包含所有配置
---@return table[]|nil 排名奖励列表 {{物品: string, 数量: number}}
function RewardBase:CalcRankReward(playerData, levelInstance)
    --gg.log(string.format("警告: 计算器 %s 未实现 CalcRankReward 方法", self.calcType))
    return nil
end

--- 验证关卡实例有效性
---@param levelInstance LevelType 关卡实例
---@return boolean
function RewardBase:ValidateLevel(levelInstance)
    if not levelInstance or not levelInstance:Is("LevelType") then
        --gg.log(string.format("错误: %s - 无效的关卡实例(LevelType)", self.calcType))
        return false
    end
    return true
end

--- 验证玩家数据有效性
---@param playerData table 玩家数据
---@return boolean 数据是否有效
function RewardBase:ValidatePlayerData(playerData)
    if not playerData then
        --gg.log(string.format("错误: %s - 玩家数据为空", self.calcType))
        return false
    end

    if not playerData.rank or playerData.rank <= 0 then
        --gg.log(string.format("错误: %s - 玩家排名无效: %s", self.calcType, tostring(playerData.rank)))
        return false
    end

    if not playerData.uin then
        --gg.log(string.format("错误: %s - 玩家UIN无效", self.calcType))
        return false
    end

    return true
end

return RewardBase
