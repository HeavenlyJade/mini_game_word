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
    context.flay_dist = playerData.distance or 0       -- 兼容旧配置
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

--- 【简化】重写计算基础奖励，使用新的公式计算器
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