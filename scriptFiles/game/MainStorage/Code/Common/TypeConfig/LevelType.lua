-- /scriptFiles/game/MainStorage/Code/Common/TypeConfig/LevelType.lua
-- 负责将 LevelConfig.lua 中的原始关卡数据，封装成程序中使用的Level对象。

local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)

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
    
    -- 调试信息：显示关卡配置加载结果
    local gg = require(game:GetService("MainStorage").Code.Untils.MGlobal)
    gg.log(string.format("LevelType 初始化完成 - 关卡: %s, 基础奖励数: %d, 每米得分: %.1f", 
           self.name, #self.baseRewards, self.scorePerMeter))
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

--- 结算基础奖励
---@param playerData table 玩家数据，包含飞行距离等信息 {distance: number, rank: number, ...}
---@return table<string, number> 奖励结果，格式为 {["物品名"] = 数量, ...}
function LevelType:CalculateBaseRewards(playerData)
    local rewards = {}
    
    if not self.baseRewards or #self.baseRewards == 0 then
        return rewards -- 如果没有配置基础奖励，返回空表
    end
    
    local gg = require(game:GetService("MainStorage").Code.Untils.MGlobal)
    
    gg.log(string.format("LevelType: 开始计算基础奖励，配置项数量: %d", #self.baseRewards))
    
    for _, rewardConfig in ipairs(self.baseRewards) do
        local itemName = rewardConfig["奖励物品"] or rewardConfig["物品"] -- 兼容两种字段名
        local calculationMethod = rewardConfig["计算方式"] or "固定数量"
        local fixedAmount = rewardConfig["固定数量"] or rewardConfig["数量"] or 0
        local formula = rewardConfig["奖励公式"] or ""
        
        if itemName and itemName ~= "" then
            local finalAmount = 0
            
            -- 根据计算方式确定最终奖励数量
            if calculationMethod == "固定数量" then
                finalAmount = fixedAmount
            elseif calculationMethod == "飞车挑战赛" then
                -- 飞车挑战赛特殊计算：基础奖励 + 距离奖励
                local baseAmount = fixedAmount or 20
                local distance = playerData.distance or 0
                local distanceBonus = math.floor(distance * (self.scorePerMeter or 1.0))
                finalAmount = baseAmount + distanceBonus
            elseif calculationMethod == "公式计算" and formula ~= "" then
                -- 使用公式计算（这里可以扩展更复杂的公式解析）
                finalAmount = self:_evaluateRewardFormula(formula, playerData)
            else
                -- 默认使用固定数量
                finalAmount = fixedAmount
            end
            
            -- 确保奖励数量不为负数
            finalAmount = math.max(0, math.floor(finalAmount))
            
            -- 累加同类型物品的奖励
            if rewards[itemName] then
                rewards[itemName] = rewards[itemName] + finalAmount
            else
                rewards[itemName] = finalAmount
            end
            
            gg.log(string.format("LevelType: 奖励计算 - %s: %d (方式: %s)", itemName, finalAmount, calculationMethod))
        end
    end
    
    local rewardCount = 0
    for _ in pairs(rewards) do rewardCount = rewardCount + 1 end
    gg.log(string.format("LevelType: 基础奖励计算完成，最终奖励项目数: %d", rewardCount))
    
    return rewards
end

--- 内部方法：计算奖励公式（使用强大的 gg.eval 解析器）
--- 支持的变量：distance(飞行距离), rank(排名), scorePerMeter(每米得分), playerName(玩家名), 
--- raceTime(比赛时长), minPlayers(最少人数), maxPlayers(最多人数)
--- 
--- 支持的操作符：+ - * / ^ ( )
--- 支持的函数：max(a,b,...), min(a,b,...), clamp(value,min,max)
--- 支持中文符号：，（）－×÷ 等会自动转换为英文
--- 
--- 示例公式：
---   "20 + distance * 0.5" -> 基础20 + 距离*0.5
---   "max(10, 100 - rank * 15)" -> 排名奖励，最低保底10
---   "clamp(distance * 0.3, 5, 50)" -> 距离奖励，最低5最高50
---   "20 + distance^1.2 / 10" -> 使用幂运算的非线性奖励
---   "min(50，距离×0.5)" -> 支持中文符号（自动转换）
---@param formula string 奖励公式字符串
---@param playerData table 玩家数据
---@return number 计算结果
function LevelType:_evaluateRewardFormula(formula, playerData)
    local gg = require(game:GetService("MainStorage").Code.Untils.MGlobal)
    
    -- 准备变量表，确保安全的变量访问
    local variables = {
        distance = playerData.distance or 0,
        rank = playerData.rank or 1,
        scorePerMeter = self.scorePerMeter or 1.0,
        -- 扩展更多可用变量
        playerName = playerData.playerName or "",
        raceTime = self.raceTime or 60,
        minPlayers = self.minPlayers or 1,
        maxPlayers = self.maxPlayers or 8
    }
    
    -- 使用模式匹配进行安全的变量替换，确保只替换完整的变量名
    local result = formula
    for varName, varValue in pairs(variables) do
        -- 使用边界匹配确保只替换完整的变量名
        local pattern = "%f[%w_]" .. varName .. "%f[^%w_]"
        result = string.gsub(result, pattern, tostring(varValue))
    end
    
    -- 使用新的 gg.eval 函数进行安全计算
    local calculatedValue = gg.eval(result)
    
    -- 确保返回值为非负数
    if type(calculatedValue) == "number" and calculatedValue >= 0 then
        return calculatedValue
    else
        -- 只在计算失败时记录错误日志
        gg.log(string.format("LevelType: 公式计算失败 - %s", formula))
        return 0
    end
end

return LevelType 