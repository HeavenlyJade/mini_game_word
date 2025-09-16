-- RewardType.lua
-- 奖励类型配置类，用于解析和管理各种奖励配置

local MainStorage = game:GetService('MainStorage')
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class RewardItem
---@field type string 奖励类型（物品/宠物/伙伴/翅膀）
---@field amount number 数量
---@field itemName string|nil 物品名称（当type为"物品"时）
---@field petConfig string|nil 宠物配置名称（当type为"宠物"时）
---@field partnerConfig string|nil 伙伴配置名称（当type为"伙伴"时）
---@field wingConfig string|nil 翅膀配置名称（当type为"翅膀"时）
---@field displayUI string|nil 显示UI（空字符串将被转换为nil）
---@field description string|nil 奖励描述（空字符串将被转换为nil）
---@field specialNote string|nil 特殊标注（空字符串将被转换为nil）

---@class RewardEntry
---@field index number 奖励索引
---@field timeNode number|nil 时间节点（秒，用于在线奖励）
---@field day number|nil 天数（用于七日登录）
---@field activityId string|nil 活动ID（用于活动奖励）
---@field exchangeId string|nil 兑换ID（用于兑换奖励）
---@field rewardItems RewardItem 奖励内容
---@field costItems table[]|nil 消耗物品列表（用于兑换奖励）
---@field dailyLimit number|nil 每日限制（用于兑换奖励）
---@field totalLimit number|nil 总限制（用于兑换奖励）
---@field claimCommand string|nil 临取执行指令

---@class RewardType : Class
---@field configName string 配置名称
---@field description string 描述
---@field rewardType string 奖励类型（在线奖励/七日登录/活动奖励/兑换奖励）
---@field resetCycle string 重置周期
---@field rewardList RewardEntry[] 奖励列表
---@field maxTimeNode number 最大时间节点（用于在线奖励）
---@field totalRewards number 奖励总数
---@field New fun(data:table):RewardType
local RewardType = ClassMgr.Class("RewardType")

function RewardType:OnInit(data)
    -- 基础信息
    self.configName = data["配置名称"] or "未知配置"
    self.description = data["描述"] or ""
    self.rewardType = data["奖励类型"] or "在线奖励"
    self.resetCycle = data["重置周期"] or "临取全部"
    
    -- 奖励列表（根据不同类型解析）
    self.rewardList = {}
    self:ParseRewardList(data["奖励列表"] or {})
    
    -- 缓存一些常用数据
    self.maxTimeNode = 0  -- 最大时间节点（用于在线奖励）
    self.totalRewards = 0  -- 奖励总数
    self:CacheData()
end

--- 解析奖励列表
---@param rawList table 原始奖励列表
function RewardType:ParseRewardList(rawList)
    for index, rewardData in ipairs(rawList) do
        local reward = {
            index = index,  -- 奖励索引
            timeNode = rewardData["时间节点"],  -- 时间节点（秒）
            day = rewardData["天数"],  -- 天数（用于七日登录）
            activityId = rewardData["活动ID"],  -- 活动ID（用于活动奖励）
            exchangeId = rewardData["兑换ID"],  -- 兑换ID（用于兑换奖励）
            
            -- 奖励内容
            rewardItems = self:ParseRewardItem(rewardData["奖励物品"]),
            
            -- 兑换相关
            costItems = self:ParseCostItems(rewardData["消耗物品"]),
            dailyLimit = rewardData["每日限制"],
            totalLimit = rewardData["总限制"],
            
            -- 临取执行指令
            claimCommand = rewardData["临取执行指令"],
        }
        
        table.insert(self.rewardList, reward)
    end
end

--- 解析单个奖励物品
---@param itemData table 奖励物品数据
---@return RewardItem|nil 解析后的奖励物品
function RewardType:ParseRewardItem(itemData)
    if not itemData then
        return nil
    end
    
    
    -- 将空字符串标准化为nil，避免下游逻辑误判
    local function normalizeEmptyToNil(v)
        if v == "" then
            return nil
        end
        return v
    end

    local rewardType = itemData["奖励类型"] or "物品"
    local reward = {
        type = rewardType,
        amount = itemData["数量"] or 1,
        -- 直接在物品层收集显示UI与描述，并做空串->nil处理
        displayUI = normalizeEmptyToNil(itemData["显示UI"]),
        description = normalizeEmptyToNil(itemData["奖励描述"]),
        specialNote = normalizeEmptyToNil(itemData["特殊标注"]),
    }
    
    -- 调试：打印解析后的数据
    
    -- 根据奖励类型设置具体内容
    if rewardType == "物品" then
        reward.itemName = itemData["物品"]
    elseif rewardType == "宠物" then
        reward.petConfig = itemData["宠物配置"]
    elseif rewardType == "伙伴" then
        reward.partnerConfig = itemData["伙伴配置"]
    elseif rewardType == "翅膀" then
        reward.wingConfig = itemData["翅膀配置"]
    end
    
    return reward
end

--- 解析消耗物品（用于兑换奖励）
---@param costData table 消耗物品数据
---@return table[]|nil 解析后的消耗列表
function RewardType:ParseCostItems(costData)
    if not costData then
        return nil
    end
    
    local costs = {}
    for itemName, amount in pairs(costData) do
        table.insert(costs, {
            itemName = itemName,
            amount = amount
        })
    end
    
    return #costs > 0 and costs or nil
end

--- 缓存常用数据
function RewardType:CacheData()
    self.totalRewards = #self.rewardList
    
    -- 如果是在线奖励，计算最大时间节点
    if self.rewardType == "在线奖励" then
        for _, reward in ipairs(self.rewardList) do
            if reward.timeNode and reward.timeNode > self.maxTimeNode then
                self.maxTimeNode = reward.timeNode
            end
        end
    end
end

--- 获取指定索引的奖励
---@param index number 奖励索引
---@return RewardEntry|nil 奖励数据
function RewardType:GetRewardByIndex(index)
    return self.rewardList[index]
end

--- 获取指定时间节点的奖励（在线奖励专用）
---@param timeNode number 时间节点（秒）
---@return RewardEntry|nil 奖励数据
function RewardType:GetRewardByTimeNode(timeNode)
    if self.rewardType ~= "在线奖励" then
        return nil
    end
    
    for _, reward in ipairs(self.rewardList) do
        if reward.timeNode == timeNode then
            return reward
        end
    end
    return nil
end

--- 获取指定天数的奖励（七日登录专用）
---@param day number 天数
---@return RewardEntry|nil 奖励数据
function RewardType:GetRewardByDay(day)
    if self.rewardType ~= "七日登录" then
        return nil
    end
    
    for _, reward in ipairs(self.rewardList) do
        if reward.day == day then
            return reward
        end
    end
    return nil
end

--- 获取可领取的奖励索引列表（在线奖励）
---@param onlineTime number 在线时长（秒）
---@param claimedIndices table 已领取的索引列表
---@return number[] 可领取的索引列表
function RewardType:GetAvailableRewards(onlineTime, claimedIndices)
    if self.rewardType ~= "在线奖励" then
        return {}
    end
    
    local available = {}
    claimedIndices = claimedIndices or {}
    
    -- 创建已领取索引的快速查找表
    local claimedMap = {}
    for _, index in ipairs(claimedIndices) do
        claimedMap[index] = true
    end
    
    -- 检查每个奖励
    for index, reward in ipairs(self.rewardList) do
        if reward.timeNode and onlineTime >= reward.timeNode then
            if not claimedMap[index] then
                table.insert(available, index)
            end
        end
    end
    
    -- 调试日志：如果找到可领取的奖励，打印详细信息
    if #available > 0 then
        -- gg.log(string.format("配置 %s: 在线时长 %d 秒, 已领取 %d 个, 找到 %d 个可领取奖励", 
        --     self.configName, onlineTime, #claimedIndices, #available))
        for _, index in ipairs(available) do
            local reward = self:GetRewardByIndex(index)
            if reward then
                local formattedTime = self:FormatTime(reward.timeNode)
                -- gg.log(string.format("  - 奖励 %d: 时间节点 %d 秒 (%s)", 
                --     index, reward.timeNode, formattedTime))
            end
        end
    end
    
    return available
end

--- 获取下一个时间节点（在线奖励）
---@param currentTime number 当前在线时长（秒）
---@return number|nil 下一个时间节点，如果没有则返回nil
function RewardType:GetNextTimeNode(currentTime)
    if self.rewardType ~= "在线奖励" then
        return nil
    end
    
    local nextNode = nil
    for _, reward in ipairs(self.rewardList) do
        if reward.timeNode and reward.timeNode > currentTime then
            if not nextNode or reward.timeNode < nextNode then
                nextNode = reward.timeNode
            end
        end
    end
    
    return nextNode
end

--- 检查是否所有奖励都已领取
---@param claimedIndices table 已领取的索引列表
---@return boolean 是否全部领取
function RewardType:IsAllClaimed(claimedIndices)
    if not claimedIndices then
        return false
    end
    
    return #claimedIndices >= self.totalRewards
end

--- 是否需要重置（用于循环奖励）
---@param claimedIndices table 已领取的索引列表
---@return boolean 是否需要重置
function RewardType:ShouldReset(claimedIndices)
    -- 临取全部类型：全部领取后重置
    if self.resetCycle == "临取全部" then
        return self:IsAllClaimed(claimedIndices)
    end
    
    -- 每日重置
    if self.resetCycle == "每日" then
        return true  -- 由外部判断日期变化
    end
    
    -- 每周重置
    if self.resetCycle == "每周" then
        return true  -- 由外部判断周变化
    end
    
    return false
end

--- 格式化奖励描述（用于UI显示）
---@param reward RewardEntry 奖励数据
---@return string 格式化的描述
function RewardType:FormatRewardDescription(reward)
    if not reward or not reward.rewardItems then
        return ""
    end
    
    local item = reward.rewardItems
    local desc = ""
    
    if item.type == "物品" then
        desc = string.format("%s x%d", item.itemName or "未知物品", item.amount)
    elseif item.type == "宠物" then
        desc = string.format("宠物：%s", item.petConfig or "未知宠物")
    elseif item.type == "伙伴" then
        desc = string.format("伙伴：%s", item.partnerConfig or "未知伙伴")
    elseif item.type == "翅膀" then
        desc = string.format("翅膀：%s", item.wingConfig or "未知翅膀")
    end
    
    return desc
end

--- 格式化时间显示（秒转换为时:分:秒）
---@param seconds number 秒数
---@return string 格式化的时间字符串
function RewardType:FormatTime(seconds)
    if not seconds or seconds < 0 then
        return "00:00:00"
    end
    
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    
    -- 如果小时为0，只显示分:秒
    if hours == 0 then
        return string.format("%02d:%02d", minutes, secs)
    else
        -- 否则显示时:分:秒
        return string.format("%02d:%02d:%02d", hours, minutes, secs)
    end
end

--- 获取奖励预览数据（用于UI展示）
---@return table UI展示数据
function RewardType:GetPreviewData()
    local preview = {
        configName = self.configName,
        description = self.description,
        rewardType = self.rewardType,
        resetCycle = self.resetCycle,
        totalRewards = self.totalRewards,
        rewards = {}
    }
    
    -- 生成奖励预览列表
    for index, reward in ipairs(self.rewardList) do
        local previewItem = {
            index = index,
            description = self:FormatRewardDescription(reward),
        }
        
        -- 根据类型添加额外信息
        if self.rewardType == "在线奖励" then
            previewItem.timeRequired = self:FormatTime(reward.timeNode)
            previewItem.timeNode = reward.timeNode
        elseif self.rewardType == "七日登录" then
            previewItem.day = reward.day
        end
        
        table.insert(preview.rewards, previewItem)
    end
    
    return preview
end

--- 验证兑换消耗（兑换奖励专用）
---@param player MPlayer 玩家对象
---@param exchangeIndex number 兑换索引
---@param count number 兑换数量
---@return boolean 是否满足消耗
---@return string|nil 错误信息
function RewardType:ValidateExchangeCost(player, exchangeIndex, count)
    if self.rewardType ~= "兑换奖励" then
        return false, "不是兑换类型奖励"
    end
    
    local reward = self:GetRewardByIndex(exchangeIndex)
    if not reward then
        return false, "无效的兑换索引"
    end
    
    if not reward.costItems then
        return true  -- 没有消耗要求
    end
    

    
    return true
end

return RewardType