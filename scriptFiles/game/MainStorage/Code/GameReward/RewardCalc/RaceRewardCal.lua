local MainStorage = game:GetService("MainStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)
local RewardBase = require(MainStorage.Code.GameReward.RewardBase) ---@type RewardBase
local gg = require(MainStorage.Code.Untils.MGlobal)

---@class RaceRewardCal : RewardBase
---@field distanceMultiplier number 距离奖励乘数
local RaceRewardCal = ClassMgr.Class("RaceRewardCal", RewardBase)

function RaceRewardCal:OnInit()
    self.super.OnInit(self, "飞车挑战赛")
    self.distanceMultiplier = 0 -- 默认无距离奖励
end

--- 【重写】为飞车挑战赛提供专用变量
---@param playerData table 玩家数据
---@param levelInstance LevelType 关卡实例
---@return table<string, any> 扩展的变量上下文
function RaceRewardCal:BuildVariableContext(playerData, levelInstance)
    -- 先获取基础变量
    local context = self.super.BuildVariableContext(self, playerData, levelInstance)
    
    -- 添加飞车挑战赛专用变量
    context.distance = playerData.distance or 0        -- 飞行距离
    context.speed = playerData.speed or 0               -- 平均速度
    context.crashCount = playerData.crashCount or 0     -- 碰撞次数
    context.comboCount = playerData.comboCount or 0     -- 连击数
    
    -- 计算衍生变量
    if context.raceTime and context.raceTime > 0 then
        context.avgSpeed = context.distance / context.raceTime
    else
        context.avgSpeed = 0
    end
    
    -- 排名相关的计算变量
    context.rankBonus = math.max(0, (context.totalPlayers - context.rank + 1)) -- 排名加成
    context.isWinner = (context.rank == 1) and 1 or 0  -- 是否第一名
    
    return context
end

--- 【重写】计算基础奖励，使用新的公式计算器
---@param playerData table 玩家数据 {rank, distance, ...}
---@param levelInstance LevelType 关卡实例
---@return table<string, number> 基础奖励 {物品名称: 数量}
function RaceRewardCal:CalcBaseReward(playerData, levelInstance)
    if not self:ValidateLevel(levelInstance) or not self:ValidatePlayerData(playerData) then
        return {}
    end

    local baseRewardsResult = {}
    local baseRewardDefs = levelInstance.baseRewards

    if not baseRewardDefs or type(baseRewardDefs) ~= "table" then
        return {}
    end

    for _, rewardDef in ipairs(baseRewardDefs) do
        local itemName = rewardDef["奖励物品"]
        local formula = rewardDef["奖励公式"]

        if itemName and formula then
            -- 使用重构后的、继承自基类的公式计算器
            local amount = self:EvaluateFormula(formula, playerData, levelInstance)
            if amount and amount > 0 then
                baseRewardsResult[itemName] = (baseRewardsResult[itemName] or 0) + math.floor(amount)
            end
        end
    end

    return baseRewardsResult
end

--- 【新增】计算实时奖励
---@param playerData table 玩家数据 {rank, distance, ...}
---@param levelInstance LevelType 关卡实例
---@return table<string, number> 实时奖励 {物品名称: 数量}
function RaceRewardCal:CalcRealTimeRewards(playerData, levelInstance)
    if not self:ValidateLevel(levelInstance) or not self:ValidatePlayerData(playerData) then
        return {}
    end

    local realTimeRewardsResult = {}
    local realTimeRewardRules = levelInstance:GetRealTimeRewardRules()

    if not realTimeRewardRules or #realTimeRewardRules == 0 then
        return {}
    end

    -- 遍历所有实时奖励规则
    for _, rule in ipairs(realTimeRewardRules) do
        local triggerCondition = rule.triggerCondition
        local rewardItem = rule.rewardItem
        local rewardFormula = rule.rewardFormula

        if triggerCondition and rewardItem and rewardFormula then
            -- 检查是否满足触发条件
            if self:CheckRealTimeRewardTrigger(triggerCondition, playerData, levelInstance) then
                -- 计算奖励数量
                local amount = self:_calculateRealTimeRewardAmount(rewardFormula, playerData, levelInstance)
                if amount and amount > 0 then
                    realTimeRewardsResult[rewardItem] = (realTimeRewardsResult[rewardItem] or 0) + math.floor(amount)
                end
            end
        end
    end

    return realTimeRewardsResult
end

--- 【新增】检查实时奖励触发条件
---@param condition string 触发条件字符串（例如：distance>=300000）
---@param playerData table 玩家数据
---@param levelInstance LevelType 关卡实例
---@return boolean 是否满足触发条件
function RaceRewardCal:CheckRealTimeRewardTrigger(condition, playerData, levelInstance)
    if not condition or not playerData then
        return false
    end

    -- 构建变量上下文
    local context = self:BuildVariableContext(playerData, levelInstance)
    
    -- 解析条件字符串
    local field, operator, value = string.match(condition, "([%w_]+)([<>=!]+)(.+)")
    
    if not field or not operator or not value then
        return false
    end
    
    -- 获取字段值
    local fieldValue = context[field]
    if fieldValue == nil then
        return false
    end
    
    -- 转换为数值进行比较
    local numValue = tonumber(value)
    local numFieldValue = tonumber(fieldValue)
    
    if numValue == nil or numFieldValue == nil then
        return false
    end
    
    -- 根据操作符进行比较
    if operator == ">=" then
        return numFieldValue >= numValue
    elseif operator == "<=" then
        return numFieldValue <= numValue
    elseif operator == "==" or operator == "=" then
        return numFieldValue == numValue
    elseif operator == ">" then
        return numFieldValue > numValue
    elseif operator == "<" then
        return numFieldValue < numValue
    elseif operator == "!=" then
        return numFieldValue ~= numValue
    end
    
    return false
end

--- 【新增】计算实时奖励数量
---@param rewardFormula string|number 奖励公式或固定数值
---@param playerData table 玩家数据
---@param levelInstance LevelType 关卡实例
---@return number|nil 奖励数量
function RaceRewardCal:_calculateRealTimeRewardAmount(rewardFormula, playerData, levelInstance)
    if not rewardFormula then
        return nil
    end
    
    -- 如果是数字，直接返回
    if type(rewardFormula) == "number" then
        return rewardFormula
    end
    
    -- 如果是字符串，使用公式计算器
    if type(rewardFormula) == "string" then
        return self:EvaluateFormula(rewardFormula, playerData, levelInstance)
    end
    
    return nil
end

--- 【新增】获取实时奖励规则信息（用于调试和日志）
---@param levelInstance LevelType 关卡实例
---@return table 实时奖励规则信息
function RaceRewardCal:GetRealTimeRewardRulesInfo(levelInstance)
    if not levelInstance then
        return {}
    end
    
    local rulesInfo = {}
    local realTimeRewardRules = levelInstance:GetRealTimeRewardRules()
    
    if realTimeRewardRules then
        for i, rule in ipairs(realTimeRewardRules) do
            table.insert(rulesInfo, {
                index = i,
                triggerCondition = rule.triggerCondition,
                rewardItem = rule.rewardItem,
                rewardFormula = rule.rewardFormula
            })
        end
    end
    
    return rulesInfo
end

--- 获取飞车挑战赛的排名奖励
---@param playerData table 玩家数据 {rank, ...}
---@param levelInstance LevelType 关卡实例
---@return table[]|nil 排名奖励列表 {{物品=string, 数量=number}, ...}
function RaceRewardCal:CalcRankReward(playerData, levelInstance)
    if not self:ValidateLevel(levelInstance) or not self:ValidatePlayerData(playerData) then
        return nil
    end

    local allRankRewards = levelInstance.rankRewards
    if not allRankRewards then return nil end

    local rankName = string.format("第%d名", playerData.rank)
    return allRankRewards[rankName]
end

return RaceRewardCal