-- /scriptFiles/game/MainStorage/Code/Common/TypeConfig/LevelType.lua
-- 负责将 LevelConfig.lua 中的原始关卡数据，封装成程序中使用的Level对象。

local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)
local RewardManager = require(MainStorage.Code.GameReward.RewardManager) --[[@type RewardManager]]

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

    -- 游戏开始指令
    self.gameStartCommands = data["游戏开始指令"] or {}
    -- 游戏结算指令
    self.gameEndCommands = data["游戏结算指令"] or {}

    -- 【新增】缓存计算器实例
    self._calculator = nil

    -- 调试信息：显示关卡配置加载结果
    local gg = require(game:GetService("MainStorage").Code.Untils.MGlobal)
    --gg.log(string.format("LevelType 初始化完成 - 关卡: %s, 基础奖励数: %d, 每米得分: %.1f",self.name, #self.baseRewards, self.scorePerMeter))
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

return LevelType
