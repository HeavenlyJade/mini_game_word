local MainStorage = game:GetService("MainStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)
local RewardBase = require(MainStorage.Code.GameReward.RewardBase) ---@type RewardBase
local gg = require(MainStorage.Code.Untils.MGlobal)

---@class RaceRewardCal : RewardBase
---@field distanceMultiplier number 距离奖励乘数
local RaceRewardCal = ClassMgr.Class("RaceRewardCal", RewardBase)

---@private
--- 安全地评估一个公式字符串
---@param formula string 从配置中读取的公式
---@param playerData table 包含变量所需数据的玩家数据
---@param levelInstance LevelType 关卡实例，用于获取关卡级别的变量
---@return number|nil 计算结果或在失败时返回nil
function RaceRewardCal:_evaluateRewardFormula(formula, playerData, levelInstance)
    if not formula or not playerData or not levelInstance then return nil end

    -- 【修正】恢复默认值，确保即使 playerData 中缺少某些字段，公式计算也不会因 nil 值而失败
    local variables = {
        distance = playerData.distance or 0,
        rank = playerData.rank or 1,
        scorePerMeter = levelInstance.scorePerMeter or 1.0,
        playerName = playerData.playerName or "",
        raceTime = levelInstance.raceTime or 60,
        minPlayers = levelInstance.minPlayers or 1,
        maxPlayers = levelInstance.maxPlayers or 8
    }

    -- 将公式中的变量名替换为实际数值
    local result = formula
    for varName, varValue in pairs(variables) do
        result = string.gsub(result, varName, tostring(varValue))
    end
    
    -- 【修正】使用项目提供的 gg.eval 函数进行安全计算，以替换被沙盒环境禁用的 load()
    local success, calculatedValue = pcall(function()
        return gg.eval(result)
    end)

    if not success or type(calculatedValue) ~= "number" then
        gg.log(string.format("错误: [RaceRewardCal] 执行公式 '%s' 时出错: %s", result, tostring(calculatedValue)))
        return nil
    end

    return calculatedValue
end

function RaceRewardCal:OnInit()
    -- "飞车挑战赛" 是这个计算器的业务名称，将用于匹配配置
    self.super.OnInit(self, "飞车挑战赛")
    self.distanceMultiplier = 0 -- 默认无距离奖励
end

--- 计算飞车挑战赛的基础奖励
---@param playerData table 玩家数据 {rank, distance, ...}
---@param levelInstance LevelType 关卡实例
---@return table<string, number> 基础奖励 {物品名称: 数量}
function RaceRewardCal:CalcBaseReward(playerData, levelInstance)
    if not self:ValidateLevel(levelInstance) or not self:ValidatePlayerData(playerData) then
        return {}
    end

    local baseRewardsResult = {}
    -- 从 LevelType 实例中获取原始的基础奖励配置
    local baseRewardDefs = levelInstance.baseRewards

    if not baseRewardDefs or type(baseRewardDefs) ~= "table" then
        return {}
    end

    -- 遍历所有基础奖励定义
    for _, rewardDef in ipairs(baseRewardDefs) do
        local itemName = rewardDef["奖励物品"]
        local formula = rewardDef["奖励公式"]

        if itemName and formula then
            -- 【核心变化】调用自身的私有方法进行计算
            local amount = self:_evaluateRewardFormula(formula, playerData, levelInstance)
            if amount and amount > 0 then
                -- 累加同名物品的奖励
                baseRewardsResult[itemName] = (baseRewardsResult[itemName] or 0) + math.floor(amount)
            end
        end
    end

    return baseRewardsResult
end

--- 获取飞车挑战赛的排名奖励
---@param playerData table 玩家数据 {rank, ...}
---@param levelInstance LevelType 关卡实例
---@return table[]|nil 排名奖励列表 {{物品=string, 数量=number}, ...}
function RaceRewardCal:CalcRankReward(playerData, levelInstance)
    -- 【修正】此方法是计算逻辑的实现者, 而不是委托者。
    if not self:ValidateLevel(levelInstance) or not self:ValidatePlayerData(playerData) then
        return nil
    end

    -- 直接从 levelInstance 中获取预处理好的排名奖励数据
    local allRankRewards = levelInstance.rankRewards
    if not allRankRewards then return nil end

    -- 使用玩家的排名进行查找
    local rankName = string.format("第%d名", playerData.rank)
    return allRankRewards[rankName]
end

return RaceRewardCal