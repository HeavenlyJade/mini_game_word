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
    ---@type PlayerLotteryData
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
        -- 1. 获取抽奖配置
        local lotteryConfig = ConfigLoader.GetLottery(poolName)
        local pityCounters = {}
        
        -- 2. 根据配置初始化保底计数器
        if lotteryConfig and lotteryConfig:HasPityList() then
            local pityList = lotteryConfig:GetPityList()
            for _, pityCfg in ipairs(pityList) do
                local requiredDraws = pityCfg.requiredDraws or 0
                if requiredDraws > 0 then
                    pityCounters[requiredDraws] = 0
                end
            end
            gg.log("初始化抽奖池保底计数器:", poolName, "节点数量:", #pityList)
        end
        
        -- 3. 创建新的抽奖池数据
        self.lotteryPools[poolName] = {
            poolName = poolName,
            totalDraws = 0,
            pityCounters = pityCounters,
            lastDrawTime = 0,
            dailyDrawCount = 0,
        }
    else
        -- 4. 已存在的抽奖池数据，检查并补充保底计数器
        local poolData = self.lotteryPools[poolName]
        
        -- 如果没有保底计数器，需要初始化（兼容从云端加载的数据）
        if not poolData.pityCounters then
            local lotteryConfig = ConfigLoader.GetLottery(poolName)
            poolData.pityCounters = {}
            
            if lotteryConfig and lotteryConfig:HasPityList() then
                local pityList = lotteryConfig:GetPityList()
                for _, pityCfg in ipairs(pityList) do
                    local requiredDraws = pityCfg.requiredDraws or 0
                    if requiredDraws > 0 then
                        poolData.pityCounters[requiredDraws] = 0
                    end
                end
                gg.log("为已有抽奖池补充保底计数器:", poolName)
            end
        else
            -- 检查配置变化，补充新增的保底节点
            local lotteryConfig = ConfigLoader.GetLottery(poolName)
            if lotteryConfig and lotteryConfig:HasPityList() then
                local pityList = lotteryConfig:GetPityList()
                for _, pityCfg in ipairs(pityList) do
                    local requiredDraws = pityCfg.requiredDraws or 0
                    if requiredDraws > 0 and poolData.pityCounters[requiredDraws] == nil then
                        -- 新增的保底节点，初始化为0
                        poolData.pityCounters[requiredDraws] = 0
                        gg.log("补充新保底节点:", poolName, "次数:", requiredDraws)
                    end
                end
            end
        end
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
-- ---@param lotteryConfig LotteryType 抽奖配置
-- ---@return LotteryRewardItem 抽中的奖励
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
        -- gg.log(string.format("  判断: %d < %.1f = %s", randomWeight, currentWeight, tostring(condition)))
        
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

--- 独立概率算法的保底优化版本（候选列表 + 二次随机）
--- 独立概率算法的保底优化版本（候选列表 + 二次随机）
---@param lotteryConfig LotteryType 抽奖配置
---@return LotteryRewardItem 抽中的奖励
function LotterySystem:RandomDraw_IndependentSingleSafe(lotteryConfig)
    local totalWeight = lotteryConfig:GetTotalWeight()
    
    -- gg.log("=== 独立概率算法（候选列表版）===")
    -- gg.log("总权重:", totalWeight)
    
    local randomValue = math.random(1000)
    -- gg.log("主随机值:", randomValue)
    
    -- 收集所有满足条件的候选奖励
    local candidates = {}
    
    -- 第一阶段：收集候选
    for i, rewardItem in ipairs(lotteryConfig.rewardPool) do
        local probability = rewardItem.weight / totalWeight
        local probabilityScaled = probability * 1000
        local rewardName = rewardItem.partnerConfig or rewardItem.petConfig or 
                          rewardItem.wingConfig or rewardItem.item or "未知奖励"
        
        -- gg.log(string.format("奖励%d: %s 权重:%.1f 概率阈值:%d 随机值:%d", 
        --        i, rewardName, rewardItem.weight, math.floor(probabilityScaled), randomValue))
        
        -- 判断是否满足概率条件
        if randomValue <= probabilityScaled then
            table.insert(candidates, {
                reward = rewardItem,
                name = rewardName,
                index = i
            })
            -- gg.log("  ✓ 加入候选列表")
        else
            -- gg.log("  ✗ 未满足条件")
        end
    end
    
    -- 第二阶段：从候选中选择
    -- gg.log("候选奖励数量:", #candidates)
    
    if #candidates == 0 then
        -- 没有候选者，使用保底逻辑：从权重最高的3个奖励中随机选择
        -- gg.log("没有候选奖励，使用保底")
        
        -- 创建权重排序列表
        local sortedRewards = {}
        for i, reward in ipairs(lotteryConfig.rewardPool) do
            local rewardName = reward.partnerConfig or reward.petConfig or 
                              reward.wingConfig or reward.item or "未知奖励"
            table.insert(sortedRewards, {
                reward = reward,
                name = rewardName,
                weight = reward.weight
            })
        end
        
        -- 按权重降序排序
        table.sort(sortedRewards, function(a, b)
            return a.weight > b.weight
        end)
        
        -- 获取前3个最高权重奖励（如果不足3个则全部获取）
        local topCount = math.min(3, #sortedRewards)
        local topRewards = {}
        for i = 1, topCount do
            table.insert(topRewards, sortedRewards[i])
        end
        
        
        -- 从最高权重奖励中按权重随机选择
        local fallbackTotalWeight = 0
        for _, topReward in ipairs(topRewards) do
            fallbackTotalWeight = fallbackTotalWeight + topReward.weight
        end
        
        local fallbackRandomValue = math.random() * fallbackTotalWeight
        local fallbackCurrentWeight = 0
        
        for i, topReward in ipairs(topRewards) do
            fallbackCurrentWeight = fallbackCurrentWeight + topReward.weight
            if fallbackRandomValue <= fallbackCurrentWeight then
                -- gg.log("★ 保底选中:", topReward.name, "（权重:" .. topReward.weight .. "）")
                return topReward.reward
            end
        end
        
        -- 最终保底：返回权重最高的奖励
        return topRewards[1].reward
        
    elseif #candidates == 1 then
        -- 只有一个候选者，直接返回
        -- gg.log("★ 唯一候选奖励:", candidates[1].name)
        return candidates[1].reward
        
    else
        -- 多个候选者，按权重进行二次随机
        -- gg.log("多个候选奖励，按权重进行二次随机选择:")
        
        -- 计算候选奖励的总权重
        local candidatesTotalWeight = 0
        for i, candidate in ipairs(candidates) do
            candidatesTotalWeight = candidatesTotalWeight + candidate.reward.weight
            -- gg.log(string.format("  候选%d: %s 权重:%.1f", i, candidate.name, candidate.reward.weight))
        end
        
        -- gg.log("候选奖励总权重:", candidatesTotalWeight)
        
        -- 在候选总权重范围内生成随机值
        local candidateRandomValue = math.random() * candidatesTotalWeight
        -- gg.log("候选随机值:", candidateRandomValue)
        
        -- 轮盘选择候选奖励
        local currentWeight = 0
        for i, candidate in ipairs(candidates) do
            currentWeight = currentWeight + candidate.reward.weight
            -- gg.log(string.format("  候选%d累积权重: %.1f", i, currentWeight))
            
            if candidateRandomValue <= currentWeight then
                -- gg.log("★ 权重随机选中:", candidate.name, "（权重:" .. candidate.reward.weight .. "）")
                return candidate.reward
            end
        end
        
        -- 保底返回最后一个候选（理论上不应该到达这里）
        -- gg.log("异常：候选权重随机未命中，返回最后候选")
        return candidates[#candidates].reward
    end
end


--- 检查保底机制
---@param poolName string 抽奖池名称
---@param lotteryConfig LotteryType 抽奖配置
---@return LotteryRewardItem|nil, number|nil 保底奖励，触发的保底次数
function LotterySystem:CheckPity(poolName, lotteryConfig)
    local poolData = self:GetPoolData(poolName)

    local pityList = lotteryConfig.GetPityList and lotteryConfig:GetPityList() or {}
    if not pityList or #pityList == 0 then
        return nil, nil
    end

    -- 遍历保底规则，检查是否触发（按次数升序检查）
    for _, pityCfg in ipairs(pityList) do
        local requiredDraws = pityCfg.requiredDraws or 0
        if requiredDraws > 0 then
            local currentCount = poolData.pityCounters[requiredDraws] or 0
            if currentCount >= requiredDraws then
                -- 触发保底后，只重置该保底节点的计数器
                poolData.pityCounters[requiredDraws] = 0
                
                gg.log("触发保底:", poolName, "保底次数:", requiredDraws, "当前计数:", currentCount)

                local reward = {
                    rewardType = pityCfg.rewardType or "物品",
                    item = pityCfg.item,
                    wingConfig = pityCfg.wingConfig,
                    petConfig = pityCfg.petConfig,
                    partnerConfig = pityCfg.partnerConfig,
                    trailConfig = pityCfg.trailConfig,
                    amount = pityCfg.amount or 1,
                    weight = 0,
                    rarity = "UR",
                }
                return reward, requiredDraws
            end
        end
    end

    return nil, nil
end

function LotterySystem:UpdatePityCounters(poolData, drawCount)
    if poolData.pityCounters then
        for requiredDraws, currentCount in pairs(poolData.pityCounters) do
            poolData.pityCounters[requiredDraws] = currentCount + drawCount
        end
    end
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
    local lotteryConfig = ConfigLoader.GetLottery(poolName) ---@type LotteryType

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
    local lottery_type = lotteryConfig.lotteryType
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
            if lottery_type == "蛋蛋抽奖" then
                reward = self:RandomDraw_IndependentSingleSafe(lotteryConfig)
            else
                reward = self:RandomDraw(lotteryConfig)
            end
            self:UpdatePityCounters(poolData, 1)
        end

        -- 若抽中的奖励本身就是保底奖励，也应重置保底计数
        local isPityReward, matchedPityDraws = lotteryConfig:IsPityReward(reward)
        if isPityReward and matchedPityDraws and matchedPityDraws > 0 then
            -- 只重置匹配的保底节点计数器
            if poolData.pityCounters and poolData.pityCounters[matchedPityDraws] then
                poolData.pityCounters[matchedPityDraws] = 0
                gg.log("正常抽奖命中保底奖励，重置", matchedPityDraws, "次保底计数器")
            end
        end
        
        gg.log("第" .. i .. "次抽奖结果:")
        gg.log("   - 奖励名称:", self:GetRewardName(reward),"  - 数量: " .. reward.amount,"  - 权重: " .. reward.weight,"  - 稀有度: " .. (reward.rarity or "N"))

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
---@param requiredDraws number|nil 指定保底次数（nil返回所有进度）
---@return number|table 保底进度
function LotterySystem:GetPityProgress(poolName, requiredDraws)
    local poolData = self:GetPoolData(poolName)
    
    if not poolData.pityCounters then
        return 0
    end
    
    -- 如果指定了保底次数，返回该保底的进度
    if requiredDraws then
        return poolData.pityCounters[requiredDraws] or 0
    end
    
    -- 返回所有保底进度
    local allProgress = {}
    for required, current in pairs(poolData.pityCounters) do
        allProgress[required] = current
    end
    
    -- 如果只有一个保底节点，返回数字；否则返回表
    local count = 0
    local singleProgress = 0
    for required, current in pairs(allProgress) do
        count = count + 1
        singleProgress = current
    end
    
    if count == 1 then
        return singleProgress
    elseif count == 0 then
        return 0
    else
        return allProgress
    end
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