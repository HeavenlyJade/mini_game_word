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
---@field _calculator RewardBase 缓存的奖励计算器实例
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

    -- 【新增】缓存计算器实例
    self._calculator = nil

    -- 调试信息：显示关卡配置加载结果
    local gg = require(game:GetService("MainStorage").Code.Untils.MGlobal)
    --gg.log(string.format("LevelType 初始化完成 - 关卡: %s, 基础奖励数: %d, 每米得分: %.1f, 实时奖励规则数: %d",self.name, #self.baseRewards, self.scorePerMeter, #self.realTimeRewardRules))
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

return LevelType
