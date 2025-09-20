-- /scriptFiles/game/MainStorage/Code/Common/TypeConfig/LevelType.lua
-- 负责将 LevelConfig.lua 中的原始关卡数据，封装成程序中使用的Level对象。

local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)
local RewardManager = require(MainStorage.Code.GameReward.RewardManager) --[[@type RewardManager]]

---@class RealTimeRewardRule
---@field ruleId string 规则唯一标识
---@field triggerCondition string 触发条件（例如：distance>=300000）
---@field rewardItem string 奖励物品名称
---@field rewardFormula string|number 奖励公式或固定数值

---@class LevelBonusVariableItem
---@field 变量名称 string 加成变量的名称
---@field 变量属性 string 变量属性（如：玩家变量、全局变量等）
---@field 作用目标 string 作用目标（如：金币、经验等）
---@field 加成方式 string 加成方式（如：最终乘法、固定加成等）
---@field 加成数值 number 加成数值

---@class LevelType : Class
---@field id string 关卡的唯一ID (来自配置的Key)
---@field name string 关卡名字
---@field levelName string 关卡名称
---@field defaultGameMode string 默认玩法模式 (例如 "RaceGameMode")
---@field minPlayers number 最少人数
---@field maxPlayers number 最多人数
---@field scorePerMeter number 每米得分数
---@field raceTime number 比赛时长(秒)
---@field prepareTime number 准备时间(秒)
---@field victoryCondition string 胜利条件
---@field baseRewards table 基础奖励列表
---@field rankRewards table<string, table> 排名奖励字典 (名次 -> 奖励配置)
---@field realTimeRewardRules RealTimeRewardRule[] 实时奖励规则列表
---@field gameStartCommands table<string> 游戏开始指令列表
---@field gameEndCommands table<string> 游戏结算指令列表
---@field sceneConfig string 场景配置名称
---@field bonusVariables LevelBonusVariableItem[] 关卡加成变量列表
---@field _calculator RewardBase 缓存的奖励计算器实例
---@field _bonusVariableMap table<string, LevelBonusVariableItem> 按变量名称分组的加成变量映射
local LevelType = ClassMgr.Class("LevelType")

function LevelType:OnInit(data)
    -- 基础信息
    self.id = data["ID"] or ""
    self.name = data["名字"] or ""
    self.levelName = data["关卡名称"] or ""
    self.defaultGameMode = data["默认玩法"] or ""
    self.minPlayers = data["最少人数"] or 1
    self.maxPlayers = data["最多人数"] or 8
    self.scorePerMeter = data["每米得分数"] or 1.0

    -- 玩法规则 - 转换为直接属性
    local gameplayRules = data["玩法规则"] or {}
    self.raceTime = gameplayRules["比赛时长"] or 60
    self.prepareTime = gameplayRules["准备时间"] or 10
    self.victoryCondition = gameplayRules["胜利条件"]

    -- 基础奖励单独存储
    self.baseRewards = data["基础奖励"] or {}

    -- rankRewards专门存储排名奖励: 排名名称 -> 奖励配置
    self.rankRewards = {}
    local rankRewards = data["排名奖励"] or {}

    -- 将排名奖励转换为字典格式
    for _, rankReward in ipairs(rankRewards) do
        local rank = rankReward["名次"] or 0
        local rankName = string.format("第%d名", rank)
        self.rankRewards[rankName] = rankReward["奖励列表"] or {}
    end

    -- 【新增】实时奖励规则
    self.realTimeRewardRules = {}
    local realTimeRewards = data["实时奖励规则"] or {}
    
    for _, rewardRule in ipairs(realTimeRewards) do
        table.insert(self.realTimeRewardRules, {
            ruleId = rewardRule["规则ID"] or "",
            triggerCondition = rewardRule["触发条件"] or "",
            rewardItem = rewardRule["奖励物品"] or "",
            rewardFormula = rewardRule["奖励公式"] or 0
        })
    end

    -- 游戏开始指令
    self.gameStartCommands = data["游戏开始指令"] or {}
    -- 游戏结算指令
    self.gameEndCommands = data["游戏结算指令"] or {}

    -- 场景配置
    self.sceneConfig = data["场景配置"] or ""

    -- 【新增】关卡加成变量列表
    self.bonusVariables = data["加成变量列表"] or {}
    
    -- 【新增】构建加成变量映射表，用于快速查找特定变量名称的加成配置
    self._bonusVariableMap = {}
    for _, bonusVar in ipairs(self.bonusVariables) do
        local varName = bonusVar["变量名称"]
        if varName and varName ~= "" then
            self._bonusVariableMap[varName] = bonusVar
        end
    end

    -- 【新增】缓存计算器实例
    self._calculator = nil

end

--- 【新增】获取或创建并缓存奖励计算器
---@return RewardBase|nil
function LevelType:_GetCalculator()
    -- 如果已有缓存，直接返回
    if self._calculator then
        return self._calculator
    end

    -- 否则，从管理器获取一个新的实例
    local calculator = RewardManager.GetCalculator(self.defaultGameMode)
    if calculator then
        self._calculator = calculator -- 缓存实例
        return self._calculator
    end

    return nil
end

--- 获取基础奖励
---@return table
function LevelType:GetBaseRewards()
    return self.baseRewards
end

--- 获取指定排名的奖励
---@param rank number 排名 (1, 2, 3...)
---@return table|nil
function LevelType:GetRankRewards(rank)
    -- 【修正】恢复为简单的数据获取方法，不再调用计算器
    local rankName = string.format("第%d名", rank)
    return self.rankRewards[rankName]
end

--- 获取所有排名奖励规则
---@return table<string, table>
function LevelType:GetAllRankRewards()
    return self.rankRewards
end

--- 检查指定排名是否有奖励
---@param rank number 排名 (1, 2, 3...)
---@return boolean
function LevelType:HasRankReward(rank)
    local rankName = string.format("第%d名", rank)
    return self.rankRewards[rankName] ~= nil
end

--- 【新增】获取实时奖励规则列表
---@return RealTimeRewardRule[] 实时奖励规则列表
function LevelType:GetRealTimeRewardRules()
    return self.realTimeRewardRules
end

--- 【新增】获取指定索引的实时奖励规则
---@param index number 规则索引
---@return RealTimeRewardRule|nil 实时奖励规则，如果索引无效则返回nil
function LevelType:GetRealTimeRewardRule(index)
    if index and index > 0 and index <= #self.realTimeRewardRules then
        return self.realTimeRewardRules[index]
    end
    return nil
end

--- 【新增】根据规则ID获取实时奖励规则
---@param ruleId string 规则唯一标识
---@return RealTimeRewardRule|nil 实时奖励规则，如果ID不存在则返回nil
function LevelType:GetRealTimeRewardRuleById(ruleId)
    if not ruleId or ruleId == "" then
        return nil
    end
    
    for _, rule in ipairs(self.realTimeRewardRules) do
        if rule.ruleId == ruleId then
            return rule
        end
    end
    return nil
end

--- 【新增】检查指定规则ID是否存在
---@param ruleId string 规则唯一标识
---@return boolean 是否存在
function LevelType:HasRealTimeRewardRule(ruleId)
    return self:GetRealTimeRewardRuleById(ruleId) ~= nil
end

--- 【新增】检查是否有实时奖励规则
---@return boolean 是否有实时奖励规则
function LevelType:HasRealTimeRewardRules()
    return self.realTimeRewardRules and #self.realTimeRewardRules > 0
end

--- 【新增】获取实时奖励规则数量
---@return number 实时奖励规则数量
function LevelType:GetRealTimeRewardRuleCount()
    return self.realTimeRewardRules and #self.realTimeRewardRules or 0
end

--- 【新增】检查指定条件是否满足实时奖励触发条件
---@param condition string 触发条件字符串（例如：distance>=300000）
---@param playerData table 玩家数据，包含distance等字段
---@return boolean 是否满足触发条件
function LevelType:CheckRealTimeRewardTrigger(condition, playerData)
    if not condition or not playerData then
        return false
    end
    
    -- 获取奖励计算器来处理条件检查
    local calculator = self:_GetCalculator() ---@type RaceRewardCal
    if calculator and calculator.CheckRealTimeRewardTrigger then
        return calculator:CheckRealTimeRewardTrigger(condition, playerData, self)
    end
    
    -- 如果没有专门的检查方法，使用简单的条件解析
    return false
end


--- 【新增】获取所有满足条件的实时奖励
---@param playerData table 玩家数据
---@return table<string, number> 满足条件的奖励 {物品名称: 数量}
function LevelType:GetTriggeredRealTimeRewards(playerData)
    local triggeredRewards = {}
    
    if not self:HasRealTimeRewardRules() or not playerData then
        return triggeredRewards
    end
    
    -- 获取奖励计算器来处理实时奖励计算
    local calculator = self:_GetCalculator()
    if calculator and calculator.CalcRealTimeRewards then
        return calculator:CalcRealTimeRewards(playerData, self)
    end
    
    -- 如果没有专门的实时奖励计算方法，使用默认逻辑
    for _, rule in ipairs(self.realTimeRewardRules) do
        if self:CheckRealTimeRewardTrigger(rule.triggerCondition, playerData) then
            local itemName = rule.rewardItem
            local amount = rule.rewardFormula
            
            if itemName and amount then
                -- 如果奖励公式是字符串，需要计算；如果是数字，直接使用
                if type(amount) == "string" then
                    -- 使用计算器的公式计算功能
                    local calculatedAmount = self:_evaluateFormulaWithCalculator(amount, playerData)
                    if calculatedAmount and calculatedAmount > 0 then
                        triggeredRewards[itemName] = (triggeredRewards[itemName] or 0) + calculatedAmount
                    end
                elseif type(amount) == "number" and amount > 0 then
                    triggeredRewards[itemName] = (triggeredRewards[itemName] or 0) + amount
                end
            end
        end
    end
    
    return triggeredRewards
end

--- 【新增】使用计算器评估公式
---@param formula string 公式字符串
---@param playerData table 玩家数据
---@return number|nil 计算结果
function LevelType:_evaluateFormulaWithCalculator(formula, playerData)
    local calculator = self:_GetCalculator()
    if calculator and calculator.EvaluateFormula then
        return calculator:EvaluateFormula(formula, playerData, self)
    end
    
    -- 如果没有专门的公式计算器，使用简单计算
    return self:_evaluateSimpleFormula(formula, playerData)
end

--- 【新增】简单的公式计算器（用于实时奖励）
---@param formula string 公式字符串
---@param playerData table 玩家数据
---@return number|nil 计算结果
function LevelType:_evaluateSimpleFormula(formula, playerData)
    if not formula or type(formula) ~= "string" then
        return nil
    end
    
    -- 简单的公式计算，支持基本的数学运算
    -- 这里可以根据需要扩展更复杂的公式解析
    local success, result = pcall(function()
        -- 创建安全的计算环境
        local env = {
            distance = playerData.distance or 0,
            rank = playerData.rank or 0,
            time = playerData.time or 0,
            speed = playerData.speed or 0,
            -- 可以添加更多变量
        }
        
        -- 简单的数学运算
        local func = loadstring("return " .. formula)
        if func then
            setfenv(func, env)
            return func()
        end
        return nil
    end)
    
    if success and type(result) == "number" then
        return result
    end
    
    return nil
end

--- 获取玩法规则的便捷方法
---@return table
function LevelType:GetGameplayRules()
    return {
        raceTime = self.raceTime,
        prepareTime = self.prepareTime,
        victoryCondition = self.victoryCondition
    }
end

--- 获取游戏开始指令
---@return table<string>
function LevelType:GetGameStartCommands()
    return self.gameStartCommands
end

--- 获取游戏结算指令
---@return table<string>
function LevelType:GetGameEndCommands()
    return self.gameEndCommands
end

--- 获取场景配置名称
---@return string
function LevelType:GetSceneConfig()
    return self.sceneConfig
end

--- 检查是否有场景配置
---@return boolean
function LevelType:HasSceneConfig()
    return self.sceneConfig and self.sceneConfig ~= ""
end

--- 获取场景配置信息摘要
---@return table 场景配置信息摘要
function LevelType:GetSceneConfigSummary()
    return {
        hasSceneConfig = self:HasSceneConfig(),
        sceneConfigName = self.sceneConfig,
        sceneConfigType = self:HasSceneConfig() and "关卡节点奖励配置" or "无"
    }
end

--- 获取玩家限制信息
---@return number, number 最少人数, 最多人数
function LevelType:GetPlayerLimits()
    return self.minPlayers, self.maxPlayers
end

--- 检查玩家数量是否符合要求
---@param playerCount number 当前玩家数量
---@return boolean
function LevelType:IsPlayerCountValid(playerCount)
    return playerCount >= self.minPlayers and playerCount <= self.maxPlayers
end

---@param playerData table 玩家数据，包含飞行距离等信息 {distance: number, rank: number, ...}
---@return table<string, number> 奖励结果，格式为 {["物品名"] = 数量, ...}
function LevelType:CalculateBaseRewards(playerData)
    local calculator = self:_GetCalculator()
    if not calculator then
        local gg = require(game:GetService("MainStorage").Code.Untils.MGlobal)
        --gg.log(string.format("错误: [LevelType] 无法为玩法 '%s' 获取奖励计算器。", self.defaultGameMode))
        return {}
    end

    -- 将计算任务完全委托给计算器
    return calculator:CalcBaseReward(playerData, self)
end

-- ========================================
-- 使用示例：
-- ========================================
-- 
-- -- 获取关卡实例
-- local level = LevelType.New(levelConfigData)
-- 
-- -- 获取游戏开始指令列表
-- local startCommands = level:GetGameStartCommands()
-- for i, command in ipairs(startCommands) do
--     -- 执行游戏开始指令，例如：
--     -- 设置玩家属性、激活特殊效果等
--     --gg.log(string.format("执行游戏开始指令 %d: %s", i, command))
-- end
-- 
-- -- 获取游戏结算指令列表
-- local endCommands = level:GetGameEndCommands()
-- for i, command in ipairs(endCommands) do
--     -- 执行游戏结算指令，例如：
--     -- 恢复玩家属性、清理临时状态等
--     --gg.log(string.format("执行游戏结算指令 %d: %s", i, command))
-- end
-- 
-- -- 检查是否有指令需要执行
-- if #startCommands > 0 then
--     --gg.log(string.format("关卡 %s 有 %d 条游戏开始指令", level.name, #startCommands))
-- end
-- 
-- if #endCommands > 0 then
--     --gg.log(string.format("关卡 %s 有 %d 条游戏结算指令", level.name, #endCommands))
-- end
-- 
-- -- 【新增】实时奖励规则ID系统使用示例
-- if level:HasRealTimeRewardRules() then
--     -- 获取所有实时奖励规则
--     local realTimeRules = level:GetRealTimeRewardRules()
--     for _, rule in ipairs(realTimeRules) do
--         --gg.log(string.format("实时奖励规则: ID=%s, 条件=%s, 物品=%s, 公式=%s", 
--             --rule.ruleId, rule.triggerCondition, rule.rewardItem, tostring(rule.rewardFormula)))
--     end
--     
--     -- 根据规则ID获取特定规则
--     local distance100kRule = level:GetRealTimeRewardRuleById("distance6")
--     if distance100kRule then
--         --gg.log(string.format("找到规则 distance6: 条件=%s, 奖励=%s x%s", 
--             --distance100kRule.triggerCondition, distance100kRule.rewardItem, tostring(distance100kRule.rewardFormula)))
--     end
--     
--     -- 检查特定规则是否存在
--     if level:HasRealTimeRewardRule("distance3") then
--         --gg.log("规则 distance3 存在")
--     end
-- end

-- ============================= 关卡加成变量管理 =============================

--- 【新增】获取所有关卡加成变量
---@return LevelBonusVariableItem[] 关卡加成变量列表
function LevelType:GetAllBonusVariables()
    return self.bonusVariables
end

--- 【新增】获取关卡加成变量数量
---@return number 关卡加成变量数量
function LevelType:GetBonusVariableCount()
    return #self.bonusVariables
end

--- 【新增】根据变量名称获取关卡加成变量
---@param varName string 变量名称
---@return LevelBonusVariableItem|nil 关卡加成变量配置，如果不存在则返回nil
function LevelType:GetBonusVariableByName(varName)
    if not varName or varName == "" then
        return nil
    end
    
    return self._bonusVariableMap[varName]
end

--- 【新增】检查指定变量名称是否存在
---@param varName string 变量名称
---@return boolean 是否存在
function LevelType:HasBonusVariable(varName)
    return self:GetBonusVariableByName(varName) ~= nil
end

--- 【新增】根据作用目标筛选关卡加成变量
---@param target string 作用目标（如：金币、经验等）
---@return LevelBonusVariableItem[] 匹配的关卡加成变量列表
function LevelType:GetBonusVariablesByTarget(target)
    local result = {}
    
    if not target or target == "" then
        return result
    end
    
    for _, bonusVar in ipairs(self.bonusVariables) do
        if bonusVar["作用目标"] == target then
            table.insert(result, bonusVar)
        end
    end
    
    return result
end

--- 【新增】根据加成方式筛选关卡加成变量
---@param bonusType string 加成方式（如：最终乘法、固定加成等）
---@return LevelBonusVariableItem[] 匹配的关卡加成变量列表
function LevelType:GetBonusVariablesByType(bonusType)
    local result = {}
    
    if not bonusType or bonusType == "" then
        return result
    end
    
    for _, bonusVar in ipairs(self.bonusVariables) do
        if bonusVar["加成方式"] == bonusType then
            table.insert(result, bonusVar)
        end
    end
    
    return result
end

--- 【新增】根据变量属性筛选关卡加成变量
---@param varProperty string 变量属性（如：玩家变量、全局变量等）
---@return LevelBonusVariableItem[] 匹配的关卡加成变量列表
function LevelType:GetBonusVariablesByProperty(varProperty)
    local result = {}
    
    if not varProperty or varProperty == "" then
        return result
    end
    
    for _, bonusVar in ipairs(self.bonusVariables) do
        if bonusVar["变量属性"] == varProperty then
            table.insert(result, bonusVar)
        end
    end
    
    return result
end

--- 【新增】根据目标物品获取对应的关卡加成变量配置列表
---@param targetItem string 目标物品名称（如：金币、经验等）
---@return LevelBonusVariableItem[] 匹配的关卡加成变量配置列表
function LevelType:GetBonusVariablesByTargetItem(targetItem)
    local result = {}
    
    if not targetItem or targetItem == "" then
        return result
    end
    
    for _, bonusVar in ipairs(self.bonusVariables) do
        local target = bonusVar["作用目标"]
        
        if target == targetItem then
            table.insert(result, bonusVar)
        end
    end
    
    return result
end

--- 【新增】检查指定目标物品是否有对应的关卡加成变量
---@param targetItem string 目标物品名称
---@return boolean 是否存在对应的关卡加成变量
function LevelType:HasBonusVariableForTarget(targetItem)
    if not targetItem or targetItem == "" then
        return false
    end
    
    for _, bonusVar in ipairs(self.bonusVariables) do
        if bonusVar["作用目标"] == targetItem then
            return true
        end
    end
    
    return false
end

--- 【新增】获取所有作用目标列表
---@return string[] 所有作用目标的数组
function LevelType:GetAllBonusTargets()
    local targets = {}
    local seen = {}
    
    for _, bonusVar in ipairs(self.bonusVariables) do
        local target = bonusVar["作用目标"]
        if target and target ~= "" and not seen[target] then
            table.insert(targets, target)
            seen[target] = true
        end
    end
    
    table.sort(targets)
    return targets
end

--- 【新增】获取所有加成方式列表
---@return string[] 所有加成方式的数组
function LevelType:GetAllBonusTypes()
    local types = {}
    local seen = {}
    
    for _, bonusVar in ipairs(self.bonusVariables) do
        local bonusType = bonusVar["加成方式"]
        if bonusType and bonusType ~= "" and not seen[bonusType] then
            table.insert(types, bonusType)
            seen[bonusType] = true
        end
    end
    
    table.sort(types)
    return types
end

--- 【新增】获取所有变量属性列表
---@return string[] 所有变量属性的数组
function LevelType:GetAllVariableProperties()
    local properties = {}
    local seen = {}
    
    for _, bonusVar in ipairs(self.bonusVariables) do
        local property = bonusVar["变量属性"]
        if property and property ~= "" and not seen[property] then
            table.insert(properties, property)
            seen[property] = true
        end
    end
    
    table.sort(properties)
    return properties
end

--- 【新增】验证关卡加成变量配置的完整性
---@return boolean isValid, string message 验证是否通过与提示信息
function LevelType:ValidateBonusVariables()
    local varCount = self:GetBonusVariableCount()
    local mapCount = 0
    
    -- 统计映射表中的数量
    for _ in pairs(self._bonusVariableMap) do
        mapCount = mapCount + 1
    end
    
    if varCount ~= mapCount then
        return false, string.format("关卡加成变量映射表不完整: 变量总数=%d, 映射数量=%d", varCount, mapCount)
    end
    
    -- 检查是否有重复的变量名称
    local seenNames = {}
    for _, bonusVar in ipairs(self.bonusVariables) do
        local varName = bonusVar["变量名称"]
        if varName and varName ~= "" then
            if seenNames[varName] then
                return false, string.format("发现重复的变量名称: %s", varName)
            end
            seenNames[varName] = true
        end
    end
    
    return true, "关卡加成变量配置验证通过"
end

return LevelType
