-- LotteryType.lua
-- 抽奖类型配置类，用于解析和管理各种抽奖配置

local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class LotteryRewardItem
---@field rewardType string 奖励类型（物品/宠物/伙伴/翅膀/尾迹）
---@field item string|nil 物品名称（当rewardType为"物品"时）
---@field wingConfig string|nil 翅膀配置名称（当rewardType为"翅膀"时）
---@field petConfig string|nil 宠物配置名称（当rewardType为"宠物"时）
---@field partnerConfig string|nil 伙伴配置名称（当rewardType为"伙伴"时）
---@field trailConfig string|nil 尾迹配置名称（当rewardType为"尾迹"时）
---@field amount number 数量
---@field weight number 权重

---@class LotteryCost
---@field costItem string 消耗物品
---@field costAmount number 消耗数量

---@class LotteryType : Class
---@field name string 名字
---@field configName string 配置名称
---@field description string 描述
---@field lotteryType string 抽奖类型
---@field level string 级别
---@field rewardPool LotteryRewardItem[] 奖励池
---@field singleCost LotteryCost 单次消耗
---@field fiveCost LotteryCost 五连消耗
---@field tenCost LotteryCost 十连消耗
---@field isEnabled boolean 是否启用
---@field cooldownTime number 冷却时间
---@field dailyLimit number 每日次数限制
---@field totalWeight number 总权重
---@field New fun(data:table):LotteryType
local LotteryType = ClassMgr.Class("LotteryType")

function LotteryType:OnInit(data)
    -- 基础信息
    self.name = data["名字"] or "未知抽奖"
    self.configName = data["配置名称"] or "未知配置"
    self.description = data["描述"] or ""
    self.lotteryType = data["抽奖类型"] or "未知类型"
    self.level = data["级别"] or "初级"
    
    -- 解析奖励池
    self.rewardPool = {}
    self.totalWeight = 0
    self:ParseRewardPool(data["奖励池"] or {})
    
    -- 解析消耗配置
    self.singleCost = self:ParseCost(data["单次消耗"] or {})
    self.fiveCost = self:ParseCost(data["五连消耗"] or {})
    self.tenCost = self:ParseCost(data["十连消耗"] or {})
    
    -- 其他配置
    self.isEnabled = data["是否启用"] or false
    self.cooldownTime = data["冷却时间"] or 0
    self.dailyLimit = data["每日次数限制"] or -1
end

--- 解析奖励池
---@param rawPool table 原始奖励池数据
function LotteryType:ParseRewardPool(rawPool)
    for _, rewardData in ipairs(rawPool) do
        local reward = {
            rewardType = rewardData["奖励类型"] or "物品",
            item = rewardData["物品"],
            wingConfig = rewardData["翅膀配置"],
            petConfig = rewardData["宠物配置"],
            partnerConfig = rewardData["伙伴配置"],
            trailConfig = rewardData["尾迹配置"],
            amount = rewardData["数量"] or 1,
            weight = rewardData["权重"] or 0,
        }
        
        table.insert(self.rewardPool, reward)
        self.totalWeight = self.totalWeight + reward.weight
    end
end

--- 解析消耗配置
---@param costData table 消耗数据
---@return LotteryCost 解析后的消耗配置
function LotteryType:ParseCost(costData)
    return {
        costItem = costData["消耗物品"] or "金币",
        costAmount = costData["消耗数量"] or 0,
    }
end

--- 根据权重随机选择奖励
---@return LotteryRewardItem|nil 选中的奖励
function LotteryType:RandomSelectReward()
    if self.totalWeight <= 0 then
        return nil
    end
    
    local randomWeight = math.random() * self.totalWeight
    local currentWeight = 0
    
    for _, reward in ipairs(self.rewardPool) do
        currentWeight = currentWeight + reward.weight
        if randomWeight <= currentWeight then
            return reward
        end
    end
    
    -- 兜底返回最后一个奖励
    return self.rewardPool[#self.rewardPool]
end

--- 获取指定类型的消耗
---@param drawType string 抽奖类型（single/five/ten）
---@return LotteryCost 对应的消耗配置
function LotteryType:GetCost(drawType)
    if drawType == "single" then
        return self.singleCost
    elseif drawType == "five" then
        return self.fiveCost
    elseif drawType == "ten" then
        return self.tenCost
    end
    return nil
end

--- 检查是否启用
---@return boolean 是否启用
function LotteryType:IsEnabled()
    return self.isEnabled
end

--- 检查是否有冷却时间
---@return boolean 是否有冷却
function LotteryType:HasCooldown()
    return self.cooldownTime > 0
end

--- 检查是否有每日限制
---@return boolean 是否有每日限制
function LotteryType:HasDailyLimit()
    return self.dailyLimit > 0
end

--- 获取奖励池大小
---@return number 奖励池大小
function LotteryType:GetRewardPoolSize()
    return #self.rewardPool
end

--- 获取总权重
---@return number 总权重
function LotteryType:GetTotalWeight()
    return self.totalWeight
end

--- 获取抽奖类型
---@return string 抽奖类型
function LotteryType:GetLotteryType()
    return self.lotteryType
end

--- 获取级别
---@return string 级别
function LotteryType:GetLevel()
    return self.level
end

--- 获取配置名称
---@return string 配置名称
function LotteryType:GetConfigName()
    return self.configName
end

--- 获取描述
---@return string 描述
function LotteryType:GetDescription()
    return self.description
end

return LotteryType
