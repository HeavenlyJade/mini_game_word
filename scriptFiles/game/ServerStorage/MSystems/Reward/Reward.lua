-- Reward.lua
-- 玩家奖励数据类 - 专注于在线奖励功能

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local RewardType = require(MainStorage.Code.Common.TypeConfig.RewardType) ---@type RewardType
local CommandManager = require(ServerStorage.CommandSys.MCommandMgr) ---@type CommandManager

---@class Reward : Class
---@field uin number 玩家ID
---@field onlineData table 在线奖励数据
---@field onlineConfig RewardType 在线奖励配置
---@field lastUpdateTime number 最后更新时间
local Reward = ClassMgr.Class("Reward")

--- 执行指令字符串
---@param player MPlayer 目标玩家
---@param commandStr string 指令字符串
local function executeCommand(player, commandStr)
    if not commandStr or commandStr == "" then
        return
    end

    -- 直接使用CommandManager执行所有指令
    CommandManager.ExecuteCommand(commandStr, player, true)
end

--- 初始化
---@param uin number 玩家ID
---@param data table|nil 已有数据（从云端加载）
function Reward:OnInit(uin, data)
    self.uin = uin
    self.lastUpdateTime = gg.GetTimeStamp()
    
    if data and data.online then
        -- 从已有数据加载
        self.onlineData = data.online
    else
        -- 创建默认数据
        self.onlineData = self:CreateDefaultOnlineData()
    end
    
    -- 加载配置
    self:LoadOnlineConfig()
end

--- 加载在线奖励配置
function Reward:LoadOnlineConfig()
    local RewardConfig = require(MainStorage.Code.Common.Config.RewardConfig)
    local configData = RewardConfig.Data[self.onlineData.configName]
    
    if configData then
        self.onlineConfig = RewardType.New(configData)
        --gg.log(string.format("玩家 %d 加载在线奖励配置: %s", self.uin, self.onlineData.configName))
    else
        --gg.log(string.format("错误: 找不到在线奖励配置: %s", self.onlineData.configName))
    end
end

--- 创建默认在线奖励数据
---@return table 默认数据
function Reward:CreateDefaultOnlineData()
    return {
        configName = "在线奖励初级",      -- 使用的配置名称
        currentRound = 1,                 -- 当前轮次
        todayOnlineTime = 0,              -- 今日在线时长（秒）
        roundOnlineTime = 0,              -- 本轮在线时长（秒）
        claimedIndices = {},              -- 已领取的奖励索引
        lastLoginDate = os.date("%Y-%m-%d") -- 最后登录日期
    }
end

--- 更新在线时长
---@param deltaTime number 增加的时间（秒）
function Reward:UpdateOnlineTime(deltaTime)
    local currentDate = os.date("%Y-%m-%d")
    
    -- 检查日期变化，重置每日时长
    if self.onlineData.lastLoginDate ~= currentDate then
        self.onlineData.todayOnlineTime = 0
        self.onlineData.lastLoginDate = currentDate
        gg.log(string.format("玩家 %d 新的一天，重置每日在线时长", self.uin))
    end
    
    -- 获取更新前的状态
    local oldRoundTime = self.onlineData.roundOnlineTime
    local oldAvailableCount = #self:GetAvailableOnlineRewards()
    
    -- 更新时长
    self.onlineData.todayOnlineTime = self.onlineData.todayOnlineTime + deltaTime
    self.onlineData.roundOnlineTime = self.onlineData.roundOnlineTime + deltaTime
    
    -- 获取更新后的状态
    local newRoundTime = self.onlineData.roundOnlineTime
    local newAvailableCount = #self:GetAvailableOnlineRewards()
    
    -- 检查是否有新的奖励变为可领取
    if newAvailableCount > oldAvailableCount then
        gg.log(string.format("玩家 %d 在线时长更新: %d -> %d, 新奖励可领取！可领取数量: %d -> %d", 
            self.uin, oldRoundTime, newRoundTime, oldAvailableCount, newAvailableCount))
        
        -- 打印可领取的奖励详情
        local availableRewards = self:GetAvailableOnlineRewards()
        for _, index in ipairs(availableRewards) do
            local reward = self.onlineConfig:GetRewardByIndex(index)
            if reward then
                gg.log(string.format("  - 奖励 %d: 时间节点 %d 秒 (%s)", 
                    index, reward.timeNode, self.onlineConfig:FormatTime(reward.timeNode)))
            end
        end
    else
        gg.log(string.format("玩家 %d 在线时长更新: %d -> %d, 可领取数量: %d (无变化)", 
            self.uin, oldRoundTime, newRoundTime, newAvailableCount))
    end
    
    self.lastUpdateTime = gg.GetTimeStamp()
end

--- 获取可领取的在线奖励索引列表
---@return table 可领取的奖励索引列表
function Reward:GetAvailableOnlineRewards()
    if not self.onlineConfig then
        gg.log(string.format("玩家 %d 在线奖励配置未加载", self.uin))
        return {}
    end
    
    local availableRewards = self.onlineConfig:GetAvailableRewards(
        self.onlineData.roundOnlineTime,
        self.onlineData.claimedIndices
    )
    
    -- 调试日志：打印当前状态
    if #availableRewards > 0 then
        gg.log(string.format("玩家 %d 当前可领取奖励: 在线时长 %d 秒, 已领取 %d 个, 可领取 %d 个", 
            self.uin, self.onlineData.roundOnlineTime, #self.onlineData.claimedIndices, #availableRewards))
    end
    
    return availableRewards
end

--- 领取在线奖励
---@param index number 奖励索引
---@return table|nil 奖励内容
---@return string|nil 错误信息
function Reward:ClaimOnlineReward(index)
    gg.log("=== Reward:ClaimOnlineReward ===")
    gg.log(string.format("玩家 %d 尝试领取奖励索引: %d", self.uin, index))
    gg.log(string.format("当前在线时长: %d 秒", self.onlineData.roundOnlineTime))
    
    if not self.onlineConfig then
        gg.log("错误：配置未加载")
        return nil, "配置未加载"
    end
    
    -- 检查是否已领取
    for _, claimedIndex in ipairs(self.onlineData.claimedIndices) do
        if claimedIndex == index then
            gg.log(string.format("错误：奖励索引 %d 已领取", index))
            return nil, "奖励已领取"
        end
    end
    
    -- 获取奖励配置
    local reward = self.onlineConfig:GetRewardByIndex(index)
    if not reward then
        gg.log(string.format("错误：无效的奖励索引 %d", index))
        return nil, "无效的奖励索引"
    end
    
    gg.log(string.format("奖励配置: 时间节点 %d 秒", reward.timeNode or 0))
    
    -- 严格检查时间是否满足
    if reward.timeNode then
        if self.onlineData.roundOnlineTime < reward.timeNode then
            gg.log(string.format("错误：在线时长不足，需要 %d 秒，当前只有 %d 秒", 
                reward.timeNode, self.onlineData.roundOnlineTime))
            return nil, string.format("在线时长不足，需要 %d 秒，当前只有 %d 秒", 
                reward.timeNode, self.onlineData.roundOnlineTime)
        else
            gg.log(string.format("时间检查通过：当前时长 %d 秒 >= 需要时长 %d 秒", 
                self.onlineData.roundOnlineTime, reward.timeNode))
        end
    else
        gg.log("警告：奖励没有设置时间节点")
    end
    
    -- 记录已领取
    table.insert(self.onlineData.claimedIndices, index)
    gg.log(string.format("已将奖励索引 %d 添加到已领取列表", index))
    
    -- 检查是否需要重置（全部领取完）
    if self.onlineConfig:IsAllClaimed(self.onlineData.claimedIndices) then
        gg.log("所有奖励已领取完毕，开始重置")
        self:ResetOnlineReward()
    end
    
    -- 执行临取指令
    if reward.claimCommand and reward.claimCommand ~= "" then
        local player = self:GetPlayer()
        if player then
            gg.log(string.format("执行临取指令: %s", reward.claimCommand))
            executeCommand(player, reward.claimCommand)
        else
            gg.log("警告：找不到玩家对象，无法执行临取指令")
        end
    else
        gg.log("该奖励没有临取指令")
    end
    
    gg.log(string.format("玩家 %d 成功领取在线奖励 %d", self.uin, index))
    gg.log("=== Reward:ClaimOnlineReward 结束 ===")
    
    return reward.rewardItems
end

--- 一键领取所有可领取的在线奖励
---@return table 所有领取的奖励列表
function Reward:ClaimAllOnlineRewards()
    local availableIndices = self:GetAvailableOnlineRewards()
    local allRewards = {}
    
    for _, index in ipairs(availableIndices) do
        local reward = self:ClaimOnlineReward(index)
        if reward then
            table.insert(allRewards, {
                index = index,
                reward = reward
            })
        end
    end
    
    return allRewards
end

--- 重置在线奖励（进入下一轮）
function Reward:ResetOnlineReward()
    self.onlineData.currentRound = self.onlineData.currentRound + 1
    self.onlineData.roundOnlineTime = 0
    self.onlineData.claimedIndices = {}
    --gg.log(string.format("玩家 %d 在线奖励重置，进入第 %d 轮", self.uin, self.onlineData.currentRound))
end

--- 获取下一个奖励的剩余时间
---@return number|nil 剩余秒数，如果没有下一个奖励则返回nil
function Reward:GetNextRewardTime()
    if not self.onlineConfig then
        return nil
    end
    
    local nextTimeNode = self.onlineConfig:GetNextTimeNode(self.onlineData.roundOnlineTime)
    if nextTimeNode then
        return nextTimeNode - self.onlineData.roundOnlineTime
    end
    
    return nil
end

--- 获取在线奖励状态信息（用于UI显示）
---@return table 状态信息
function Reward:GetOnlineRewardStatus()
    local status = {
        currentRound = self.onlineData.currentRound,
        todayOnlineTime = self.onlineData.todayOnlineTime,
        roundOnlineTime = self.onlineData.roundOnlineTime,
        totalRewards = self.onlineConfig and self.onlineConfig.totalRewards or 0,
        claimedCount = #self.onlineData.claimedIndices,
        availableCount = #self:GetAvailableOnlineRewards(),
        nextRewardTime = self:GetNextRewardTime(),
        rewards = {}
    }
    
    -- 生成每个奖励的状态
    if self.onlineConfig then
        for index, reward in ipairs(self.onlineConfig.rewardList) do
            local rewardStatus = {
                index = index,
                timeNode = reward.timeNode,
                status = self:GetRewardStatus(index)  -- 0:未达成 1:可领取 2:已领取
            }
            table.insert(status.rewards, rewardStatus)
        end
    end
    
    return status
end

--- 获取单个奖励的状态
---@param index number 奖励索引
---@return number 状态: 0=未达成, 1=可领取, 2=已领取
function Reward:GetRewardStatus(index)
    -- 检查是否已领取
    for _, claimedIndex in ipairs(self.onlineData.claimedIndices) do
        if claimedIndex == index then
            return 2  -- 已领取
        end
    end
    
    -- 检查是否可领取
    if self.onlineConfig then
        local reward = self.onlineConfig:GetRewardByIndex(index)
        if reward and reward.timeNode and self.onlineData.roundOnlineTime >= reward.timeNode then
            return 1  -- 可领取
        end
    end
    
    return 0  -- 未达成
end

--- 检查是否有可领取的奖励（红点用）
---@return boolean 是否有可领取的奖励
function Reward:HasAvailableReward()
    return #self:GetAvailableOnlineRewards() > 0
end

--- 获取所有奖励的状态分类
---@return table 包含可领取、已领取、不可领取索引的分类表
function Reward:GetAllRewardStatusIndices()
    local availableIndices = {}  -- 可领取的索引
    local claimedIndices = {}    -- 已领取的索引
    local unavailableIndices = {} -- 不可领取的索引
    
    if not self.onlineConfig then
        return {
            available = availableIndices,
            claimed = claimedIndices,
            unavailable = unavailableIndices
        }
    end
    
    -- 遍历所有奖励
    for index, reward in ipairs(self.onlineConfig.rewardList) do
        local status = self:GetRewardStatus(index)
        
        if status == 1 then
            -- 可领取
            table.insert(availableIndices, index)
        elseif status == 2 then
            -- 已领取
            table.insert(claimedIndices, index)
        else
            -- 不可领取（未达成）
            table.insert(unavailableIndices, index)
        end
    end
    
    return {
        available = availableIndices,
        claimed = claimedIndices,
        unavailable = unavailableIndices
    }
end

--- 获取保存数据
---@return table 用于云存储的数据
function Reward:GetSaveData()
    return {
        online = self.onlineData
    }
end

--- 切换配置（用于活动切换等场景）
---@param configName string 新的配置名称
function Reward:SwitchConfig(configName)
    if self.onlineData.configName == configName then
        return  -- 配置相同，无需切换
    end
    
    -- 重置数据
    self.onlineData.configName = configName
    self.onlineData.currentRound = 1
    self.onlineData.roundOnlineTime = 0
    self.onlineData.claimedIndices = {}
    
    -- 重新加载配置
    self:LoadOnlineConfig()
    
    --gg.log(string.format("玩家 %d 切换在线奖励配置为: %s", self.uin, configName))
end

--- 获取玩家对象
---@return MPlayer|nil 玩家对象
function Reward:GetPlayer()
    local ServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
    return ServerDataManager.getPlayerByUin(self.uin)
end

return Reward