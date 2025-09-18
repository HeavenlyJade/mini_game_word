-- LotterySystem.lua
-- 抽奖系统核心数据类，处理玩家抽奖逻辑和状态管理

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local LotteryCloudDataMgr = require(ServerStorage.MSystems.Lottery.LotteryCloudDataMgr) ---@type LotteryCloudDataMgr

---@class LotterySystem : Class
---@field playerUin number 玩家ID
---@field lotteryPools table<string, LotteryPoolData> 各抽奖池数据
---@field drawHistory LotteryRecord[] 抽奖历史记录
---@field totalDrawCount number 总抽奖次数
---@field poolStats table<string, LotteryPoolStats> 抽奖池统计数据
local LotterySystem = ClassMgr.Class("LotterySystem")

function LotterySystem:OnInit(playerUin, data)
    self.playerUin = playerUin
    
    if data then
        self.lotteryPools = data.lotteryPools or {}
        self.drawHistory = data.drawHistory or {}
        self.totalDrawCount = data.totalDrawCount or 0
        self.poolStats = data.poolStats or {}
    else
        self.lotteryPools = {}
        self.drawHistory = {}
        self.totalDrawCount = 0
        self.poolStats = {}
    end
end

--- 获取指定抽奖池的数据
---@param poolName string 抽奖池名称
---@return LotteryPoolData 抽奖池数据
function LotterySystem:GetPoolData(poolName)
    if not self.lotteryPools[poolName] then
        self.lotteryPools[poolName] = {
            poolName = poolName,
            totalDraws = 0,
            pityCount = 0,
            lastDrawTime = 0,
        }
    end
    return self.lotteryPools[poolName]
end

--- 检查是否可以进行抽奖
---@param poolName string 抽奖池名称
---@param drawType string 抽奖类型（single/five/ten）
---@return boolean, string 是否可以抽奖，错误信息
function LotterySystem:CanDraw(poolName, drawType)
    ----gg.log("=== LotterySystem:CanDraw 开始 ===")
    ----gg.log("抽奖池:", poolName, "抽奖类型:", drawType)
    
    -- 获取抽奖配置
    ----gg.log("开始获取抽奖配置，ConfigLoader类型:", type(ConfigLoader))
    local lotteryConfig = ConfigLoader.GetLottery(poolName)
    ----gg.log("ConfigLoader.GetLottery调用结果:", lotteryConfig)
    
    if not lotteryConfig then
        ----gg.log("错误：抽奖池配置不存在，poolName:", poolName)
        return false, "抽奖池配置不存在"
    end
    
    -- 检查是否启用
    if not lotteryConfig:IsEnabled() then
        ----gg.log("错误：抽奖池未启用")
        return false, "抽奖池未启用"
    end
    
    -- 检查冷却时间
    if lotteryConfig:HasCooldown() then
        local poolData = self:GetPoolData(poolName)
        local currentTime = os.time()
        if currentTime - poolData.lastDrawTime < lotteryConfig.cooldownTime then
            ----gg.log("错误：抽奖冷却中")
            return false, "抽奖冷却中"
        end
    end
    
    -- 检查每日限制
    if lotteryConfig:HasDailyLimit() then
        local poolData = self:GetPoolData(poolName)
        local today = os.date("%Y%m%d")
        local lastDrawDate = os.date("%Y%m%d", poolData.lastDrawTime)
        
        -- 如果是新的一天，重置计数
        if today ~= lastDrawDate then
            poolData.dailyDrawCount = 0
        end
        
        local drawCount = drawType == "single" and 1 or (drawType == "five" and 5 or 10)
        if (poolData.dailyDrawCount or 0) + drawCount > lotteryConfig.dailyLimit then
            ----gg.log("错误：超过每日抽奖限制")
            return false, "超过每日抽奖限制"
        end
    end
    
    ----gg.log("抽奖检查通过")
    ----gg.log("=== LotterySystem:CanDraw 完成 ===")
    return true, ""
end

--- 执行单次随机抽奖（调试版本）
---@param lotteryConfig LotteryType 抽奖配置
---@return LotteryRewardItem 抽中的奖励
function LotterySystem:RandomDraw(lotteryConfig)
    local totalWeight = lotteryConfig:GetTotalWeight()
    local randomWeight = gg.rand_int(totalWeight)
    
    gg.log("=== 随机抽奖调试开始 ===")
    gg.log("总权重:", totalWeight, "类型:", type(totalWeight))
    gg.log("随机权重:", randomWeight, "类型:", type(randomWeight))
    gg.log("奖励池大小:", #lotteryConfig.rewardPool)
    
    local currentWeight = 0
    for i, rewardItem in ipairs(lotteryConfig.rewardPool) do
        local prevWeight = currentWeight
        currentWeight = currentWeight + rewardItem.weight
        
        local rewardName = rewardItem.partnerConfig or rewardItem.petConfig or 
                          rewardItem.wingConfig or rewardItem.item or "未知"
        
        gg.log(string.format("奖励%d: %s %s 权重:%.1f 区间:[%.1f,%.1f) 累计:%.1f", 
               i, rewardItem.rewardType, rewardName, 
               rewardItem.weight, prevWeight, currentWeight, currentWeight))
        
        -- 详细判断过程
        local condition = randomWeight < currentWeight
        gg.log(string.format("  判断: %d < %.1f = %s", randomWeight, currentWeight, tostring(condition)))
        
        if condition then
            gg.log("*** 命中奖励", i, ":", rewardItem.rewardType, rewardName)
            gg.log("=== 随机抽奖调试结束 ===")
            return rewardItem
        else
            gg.log("  跳过，继续下一个")
        end
    end
    
    -- 如果到达这里，说明没有命中任何奖励
    gg.log("⚠️ 警告：没有命中任何奖励，使用兜底逻辑")
    gg.log("最终currentWeight:", currentWeight)
    gg.log("randomWeight vs totalWeight:", randomWeight, "vs", totalWeight)
    
    local lastReward = lotteryConfig.rewardPool[#lotteryConfig.rewardPool]
    local lastName = lastReward.partnerConfig or lastReward.petConfig or 
                    lastReward.wingConfig or lastReward.item or "未知"
    gg.log("兜底返回:", lastReward.rewardType, lastName)
    gg.log("=== 随机抽奖调试结束 ===")
    
    return lastReward
end

--- 检查保底机制
---@param poolName string 抽奖池名称
---@param lotteryConfig LotteryType 抽奖配置
---@return LotteryRewardItem|nil 保底奖励
function LotterySystem:CheckPity(poolName, lotteryConfig)
    local poolData = self:GetPoolData(poolName)
    
    -- 检查配置中是否有保底设置
    for _, rewardItem in ipairs(lotteryConfig.rewardPool) do
        if rewardItem.isPity and poolData.pityCount >= (rewardItem.pityLimit or 50) then
            -- 触发保底
            poolData.pityCount = 0  -- 重置保底计数
            return rewardItem
        end
    end
    
    return nil
end

--- 执行抽奖
---@param poolName string 抽奖池名称
---@param drawType string 抽奖类型（single/five/ten）
---@return table 抽奖结果
function LotterySystem:PerformDraw(poolName, drawType)
    --gg.log("=== LotterySystem:PerformDraw 开始 ===")
    --gg.log("抽奖池:", poolName, "抽奖类型:", drawType)
    
    -- 检查是否可以抽奖
    --gg.log("开始检查是否可以抽奖...")
    local canDraw, errorMsg = self:CanDraw(poolName, drawType)
    if not canDraw then
        --gg.log("抽奖检查失败:", errorMsg)
        return {
            success = false,
            errorMsg = errorMsg
        }
    end
    --gg.log("抽奖检查通过")
    
    -- 获取抽奖配置
    --gg.log("开始获取抽奖配置...")
    local lotteryConfig = ConfigLoader.GetLottery(poolName)
    if not lotteryConfig then
        --gg.log("错误：抽奖配置不存在，poolName:", poolName)
        return {
            success = false,
            errorMsg = "抽奖配置不存在"
        }
    end
    --gg.log("抽奖配置获取成功")
    
    local poolData = self:GetPoolData(poolName)
    
    -- 确定抽奖次数
    local drawCount = drawType == "single" and 1 or (drawType == "five" and 5 or 10)
    local rewards = {}
    local currentTime = os.time()
    
    gg.log("开始执行", drawCount, "次抽奖...")
    
    -- 执行多次抽奖
    for i = 1, drawCount do
        local reward
        
        -- 检查是否触发保底
        local pityReward = self:CheckPity(poolName, lotteryConfig)
        if pityReward then
            reward = pityReward
            gg.log("第", i, "次抽奖触发保底")
        else
            -- 正常随机抽奖
            reward = self:RandomDraw(lotteryConfig)
            poolData.pityCount = poolData.pityCount + 1
            gg.log("第", i, "次抽奖正常随机")
        end
        
        gg.log("第" .. i .. "次抽奖结果:")
        gg.log("  - 奖励类型:", reward.rewardType)
        gg.log("  - 奖励名称:", self:GetRewardName(reward))
        gg.log("  - 数量: " .. reward.amount)
        gg.log("  - 权重: " .. reward.weight)
        gg.log("  - 稀有度: " .. (reward.rarity or "N"))
        
        -- 构建奖励记录
        local record = {
            poolName = poolName,
            rewardType = reward.rewardType,
            rewardName = self:GetRewardName(reward),
            quantity = reward.amount,
            rarity = reward.rarity or "N",
            drawTime = currentTime,
            isPity = pityReward ~= nil
        }
        
        table.insert(rewards, record)
        table.insert(self.drawHistory, record)
    end
    
    -- 更新抽奖数据
    poolData.totalDraws = poolData.totalDraws + drawCount
    poolData.lastDrawTime = currentTime
    poolData.dailyDrawCount = (poolData.dailyDrawCount or 0) + drawCount
    self.totalDrawCount = self.totalDrawCount + drawCount
    
    -- 获取消耗配置
    local cost = lotteryConfig:GetCost(drawType)
    local totalCost = cost and cost.costAmount or 0
    
    -- 更新统计数据
    -- LotteryCloudDataMgr.UpdatePoolStats(self.playerUin, poolName, totalCost, rewards)
    
    --gg.log("抽奖完成，获得", #rewards, "个奖励，总消耗:", totalCost)
    --gg.log("=== LotterySystem:PerformDraw 完成 ===")
    
    return {
        success = true,
        rewards = rewards,
        totalCost = totalCost,
        costType = cost and cost.costItem or "",
        pityProgress = poolData.pityCount
    }
end

--- 获取奖励名称
---@param reward LotteryRewardItem 奖励项
---@return string 奖励名称
function LotterySystem:GetRewardName(reward)
    if reward.item then
        return reward.item
    elseif reward.petConfig then
        return reward.petConfig
    elseif reward.partnerConfig then
        return reward.partnerConfig
    elseif reward.wingConfig then
        return reward.wingConfig
    elseif reward.trailConfig then
        return reward.trailConfig
    end
    return "未知奖励"
end

--- 获取抽奖池保底进度
---@param poolName string 抽奖池名称
---@return number 保底进度
function LotterySystem:GetPityProgress(poolName)
    local poolData = self:GetPoolData(poolName)
    return poolData.pityCount
end

--- 获取抽奖历史记录
---@param poolName string|nil 抽奖池名称（nil为全部）
---@param limit number|nil 限制条数
---@return LotteryRecord[] 历史记录
function LotterySystem:GetDrawHistory(poolName, limit)
    local history = {}
    
    for _, record in ipairs(self.drawHistory) do
        if not poolName or record.poolName == poolName then
            table.insert(history, record)
        end
    end
    
    -- 按时间倒序排列
    table.sort(history, function(a, b)
        return a.drawTime > b.drawTime
    end)
    
    -- 限制条数
    if limit and #history > limit then
        local limitedHistory = {}
        for i = 1, limit do
            table.insert(limitedHistory, history[i])
        end
        return limitedHistory
    end
    
    return history
end

--- 获取抽奖池统计数据
---@param poolName string 抽奖池名称
---@return LotteryPoolStats|nil 统计数据
function LotterySystem:GetPoolStats(poolName)
    return LotteryCloudDataMgr.GetPoolStats(self.playerUin, poolName)
end

--- 获取玩家数据用于存储
---@return PlayerLotteryData 玩家抽奖数据
function LotterySystem:GetData()
    return {
        lotteryPools = self.lotteryPools,
        drawHistory = self.drawHistory,
        totalDrawCount = self.totalDrawCount,
        poolStats = self.poolStats
    }
end

--- 清空抽奖历史（保留统计数据）
---@param poolName string|nil 抽奖池名称（nil为全部）
function LotterySystem:ClearHistory(poolName)
    if poolName then
        -- 清除指定抽奖池的历史
        local newHistory = {}
        for _, record in ipairs(self.drawHistory) do
            if record.poolName ~= poolName then
                table.insert(newHistory, record)
            end
        end
        self.drawHistory = newHistory
    else
        -- 清除全部历史
        self.drawHistory = {}
    end
end

return LotterySystem