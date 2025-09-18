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
---@field pityList table[] 保底配置列表
---@field singleCost LotteryCost 单次消耗
---@field fiveCost LotteryCost 五连消耗
---@field tenCost LotteryCost 十连消耗
---@field isEnabled boolean 是否启用
---@field cooldownTime number 冷却时间
---@field dailyLimit number 每日次数限制
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
    self:ParseRewardPool(data["奖励池"] or {})
    
    -- 解析保底配置列表（可选）
    self.pityList = {}
    self:ParsePityList(data["保底配置列表"] or {})
    
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
    end
end

--- 解析保底配置列表
---@param rawList table 原始保底列表数据
function LotteryType:ParsePityList(rawList)
    for _, pityData in ipairs(rawList) do
        local cfg = {
            rewardType = pityData["奖励类型"] or "物品",
            requiredDraws = pityData["需要抽奖次数"] or 0,
            item = pityData["物品"],
            wingConfig = pityData["翅膀配置"],
            petConfig = pityData["宠物配置"],
            partnerConfig = pityData["伙伴配置"],
            trailConfig = pityData["尾迹配置"],
            amount = pityData["数量"] or 1,
        }
        table.insert(self.pityList, cfg)
    end

    table.sort(self.pityList, function(a, b)
        return (a.requiredDraws or 0) < (b.requiredDraws or 0)
    end)
end

--- 是否存在保底配置列表
---@return boolean 有无保底
function LotteryType:HasPityList()
    return self.pityList ~= nil and #self.pityList > 0
end

--- 获取保底配置列表（若无则返回空表）
---@return table[] 保底配置列表
function LotteryType:GetPityList()
    return self.pityList or {}
end

--- 判断指定奖励是否为保底奖励
---@param reward table 抽中的奖励（需包含 rewardType 及对应配置字段）
---@return boolean 是否为保底奖励
function LotteryType:IsPityReward(reward)
    if not reward or not self.pityList or #self.pityList == 0 then
        return false
    end

    local function fieldEquals(a, b)
        if a == nil and b == nil then return true end
        return a == b
    end

    for _, pity in ipairs(self.pityList) do
        if (pity.rewardType or "") == (reward.rewardType or "") then
            local sameItem = fieldEquals(pity.item, reward.item)
            local sameWing = fieldEquals(pity.wingConfig, reward.wingConfig)
            local samePet = fieldEquals(pity.petConfig, reward.petConfig)
            local samePartner = fieldEquals(pity.partnerConfig, reward.partnerConfig)
            local sameTrail = fieldEquals(pity.trailConfig, reward.trailConfig)

            local typeMatched = false
            if reward.rewardType == "物品" then
                typeMatched = sameItem
            elseif reward.rewardType == "翅膀" then
                typeMatched = sameWing
            elseif reward.rewardType == "宠物" then
                typeMatched = samePet
            elseif reward.rewardType == "伙伴" then
                typeMatched = samePartner
            elseif reward.rewardType == "尾迹" then
                typeMatched = sameTrail
            end

            if typeMatched then
                return true
            end
        end
    end

    return false
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
    if #self.rewardPool == 0 then
        return nil
    end
    
    -- 计算总权重
    local totalWeight = 0
    for _, reward in ipairs(self.rewardPool) do
        totalWeight = totalWeight + reward.weight
    end
    
    if totalWeight <= 0 then
        return nil
    end
    
    local randomWeight = math.random() * totalWeight
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
    local totalWeight = 0
    for _, reward in ipairs(self.rewardPool) do
        totalWeight = totalWeight + (reward.weight or 0)
    end
    return totalWeight
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

--- 计算并格式化奖励项的概率显示
---@param rewardItem LotteryRewardItem 奖励项
---@return string 格式化后的概率文本
function LotteryType:GetFormattedProbability(rewardItem)
    if not rewardItem then
        return "0%"
    end
    
    local weight = rewardItem.weight or 0
    local probability = weight
    -- 格式化概率显示：如果是整数则去掉小数点
    if math.floor(probability) == probability then
        return string.format("%d%%", probability)
    else
        return string.format("%.1f%%", probability)
    end
end

return LotteryType
