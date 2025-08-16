
local MainStorage = game:GetService("MainStorage")

local gg = require(MainStorage.Code.Untils.MGlobal)
-- EventPlayerConfig is no longer needed here for the map key
-- local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig

--[[
    RewardManager是奖励计算系统的核心协调器和统一入口。
]]
---@class RewardManager
-- RewardManager 充当一个静态的"计算器注册表"或"提供者"。
-- 它的唯一职责是根据玩法名称，创建并返回一个对应的奖励计算器实例。
local RewardManager = {}

-- 计算器类映射表
-- Key: 玩法名称字符串 (来自 LevelType.defaultGameMode)
-- Value: 预加载的计算器类
local CALCULATOR_CLASSES = {
    ['飞车挑战赛'] = require(MainStorage.Code.GameReward.RewardCalc.RaceRewardCal),
    ['成就天赋'] = require(MainStorage.Code.GameReward.RewardCalc.AchievementRewardCal), -- 新增
    ['宠物公式'] = require(MainStorage.Code.GameReward.RewardCalc.PetFormulaCalc), -- 新增
}

--- 根据玩法名称，获取一个奖励计算器的实例
---@param gameModeName string 玩法名称, e.g., "飞车挑战赛"
---@return RewardBase|nil
function RewardManager.GetCalculator(gameModeName)
    if not gameModeName then
        --gg.log("错误: [RewardManager] 获取计算器失败，玩法名称(gameModeName)为空。")
        return nil
    end

    local CalculatorClass = CALCULATOR_CLASSES[gameModeName]
    if not CalculatorClass then
        --gg.log(string.format("错误: [RewardManager] 找不到与玩法 '%s' 匹配的计算器类。", gameModeName))
        return nil
    end

    -- 使用pcall安全地创建实例
    local success, calculatorInstance = pcall(function()
        return CalculatorClass.New()
    end)

    if not success or not calculatorInstance then
        --gg.log(string.format("错误: [RewardManager] 在为玩法 '%s' 创建计算器实例时出错: %s", gameModeName, tostring(calculatorInstance)))
        return nil
    end

    return calculatorInstance
end

--- 计算奖励的统一入口函数
---@param playerData table 包含玩家信息的表 (例如 {uin, name, rank, distance})
---@param rewardConfig table 关卡配置表, e.g., LevelConfig.Data['飞车关卡初级']
---@return table|nil 包含基础奖励和排名奖励的表: {base: table, rank: table}
function RewardManager.CalculateRewards(playerData, rewardConfig)
    if not rewardConfig or not rewardConfig['默认玩法'] then
        --gg.log("错误: [RewardManager] 计算奖励失败，奖励配置(rewardConfig)或'默认玩法'字段无效。")
        return nil
    end

    -- 从配置中提取 '默认玩法' 作为 calcType
    local calcType = rewardConfig['默认玩法']
    local calculator = RewardManager.GetCalculator(calcType)

    if not calculator then
        -- GetCalculator 中已记录日志
        return nil
    end
    -- 验证数据和配置的有效性
    if not calculator:ValidatePlayerData(playerData) or not calculator:ValidateConfig(rewardConfig) then
        return nil
    end

    -- 分别计算基础奖励和排名奖励
    local baseRewards = calculator:CalcBaseReward(playerData, rewardConfig) or {}
    local rankRewards = calculator:CalcRankReward(playerData, rewardConfig) or {}


    return {
        base = baseRewards,
        rank = rankRewards,
    }
end

return RewardManager
