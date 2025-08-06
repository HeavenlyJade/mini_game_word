--- 奖励系统事件管理器
--- 负责处理客户端与奖励系统的所有交互事件
--- V109 miniw-haima

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local RewardMgr = require(ServerStorage.MSystems.Reward.RewardMgr) ---@type RewardMgr
local RewardEvent = require(MainStorage.Code.Event.RewardEvent) ---@type RewardEvent

---@class RewardEventManager
local RewardEventManager = {}

-- ==================== 事件注册 ====================

--- 初始化事件管理器
function RewardEventManager.Init()
    gg.log("奖励事件管理器初始化...")
    
    -- 注册客户端请求事件
    RewardEventManager.RegisterClientEvents()
    
    gg.log("奖励事件管理器初始化完成")
end

--- 注册客户端请求事件
function RewardEventManager.RegisterClientEvents()
    local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
    
    -- 获取在线奖励数据
    ServerEventManager.Subscribe(RewardEvent.REQUEST.GET_ONLINE_REWARD_DATA, function(evt)
        RewardEventManager.HandleGetOnlineRewardData(evt.player, evt)
    end)
    
    -- 领取单个在线奖励
    ServerEventManager.Subscribe(RewardEvent.REQUEST.CLAIM_ONLINE_REWARD, function(evt)
        RewardEventManager.HandleClaimOnlineReward(evt.player, evt)
    end)
    
    -- 一键领取所有在线奖励
    ServerEventManager.Subscribe(RewardEvent.REQUEST.CLAIM_ALL_ONLINE_REWARDS, function(evt)
        RewardEventManager.HandleClaimAllOnlineRewards(evt.player, evt)
    end)
    
    -- 获取红点状态
    ServerEventManager.Subscribe(RewardEvent.REQUEST.GET_RED_DOT_STATUS, function(evt)
        RewardEventManager.HandleGetRedDotStatus(evt.player, evt)
    end)
    
    -- 切换奖励配置
    ServerEventManager.Subscribe(RewardEvent.REQUEST.SWITCH_CONFIG, function(evt)
        RewardEventManager.HandleSwitchConfig(evt.player, evt)
    end)
end

-- ==================== 事件处理函数 ====================

--- 处理获取在线奖励数据请求
---@param player MPlayer 玩家对象
---@param evt table 事件数据
function RewardEventManager.HandleGetOnlineRewardData(player, evt)
    if not player or not player.uin then
        RewardEventManager.SendErrorResponse(player, RewardEvent.RESPONSE.ONLINE_REWARD_DATA, "玩家对象无效")
        return
    end
    
    local status = RewardMgr.GetPlayerOnlineRewardStatus(player.uin)
    if not status then
        RewardEventManager.SendErrorResponse(player, RewardEvent.RESPONSE.ONLINE_REWARD_DATA, "奖励数据未加载")
        return
    end
    
    -- 发送成功响应
    gg.network_channel:fireClient(player.uin, {
        cmd = RewardEvent.RESPONSE.ONLINE_REWARD_DATA,
        success = true,
        data = status,
        errorMsg = nil
    })
    
    gg.log(string.format("玩家 %s 获取在线奖励数据", player.name))
end

--- 处理领取单个在线奖励请求
---@param player MPlayer 玩家对象
---@param evt table 事件数据
function RewardEventManager.HandleClaimOnlineReward(player, evt)
    if not player or not player.uin then
        RewardEventManager.SendErrorResponse(player, RewardEvent.RESPONSE.CLAIM_REWARD_RESULT, "玩家对象无效")
        return
    end
    
    local index = evt and evt.index
    if not index or type(index) ~= "number" then
        RewardEventManager.SendErrorResponse(player, RewardEvent.RESPONSE.CLAIM_REWARD_RESULT, "无效的奖励索引")
        return
    end
    
    -- 领取奖励
    local success, errorMsg = RewardMgr.ClaimOnlineReward(player, index)
    
    if success then
        -- 获取奖励内容用于响应
        local rewardInstance = RewardMgr.GetPlayerReward(player.uin)
        local reward = rewardInstance and rewardInstance.onlineConfig:GetRewardByIndex(index)
        
        -- 发送成功响应
        gg.network_channel:fireClient(player.uin, {
            cmd = RewardEvent.RESPONSE.CLAIM_REWARD_RESULT,
            success = true,
            index = index,
            reward = reward and reward.rewardItems,
            errorMsg = nil
        })
        
        -- 通知其他客户端（多端同步）
        RewardEventManager.NotifyRewardClaimed(player, "online", index, reward and reward.rewardItems)
        
        gg.log(string.format("玩家 %s 领取在线奖励 %d", player.name, index))
    else
        RewardEventManager.SendErrorResponse(player, RewardEvent.RESPONSE.CLAIM_REWARD_RESULT, errorMsg or "领取失败")
    end
end

--- 处理一键领取所有在线奖励请求
---@param player MPlayer 玩家对象
---@param evt table 事件数据
function RewardEventManager.HandleClaimAllOnlineRewards(player, evt)
    if not player or not player.uin then
        RewardEventManager.SendErrorResponse(player, RewardEvent.RESPONSE.CLAIM_ALL_RESULT, "玩家对象无效")
        return
    end
    
    -- 一键领取
    local successCount = RewardMgr.ClaimAllOnlineRewards(player)
    
    if successCount > 0 then
        -- 获取所有领取的奖励详情
        local rewardInstance = RewardMgr.GetPlayerReward(player.uin)
        local allRewards = {}
        
        if rewardInstance then
            for i = 1, successCount do
                local reward = rewardInstance.onlineConfig:GetRewardByIndex(i)
                if reward then
                    table.insert(allRewards, {
                        index = i,
                        reward = reward.rewardItems
                    })
                end
            end
        end
        
        -- 发送成功响应
        gg.network_channel:fireClient(player.uin, {
            cmd = RewardEvent.RESPONSE.CLAIM_ALL_RESULT,
            success = true,
            count = successCount,
            rewards = allRewards,
            errorMsg = nil
        })
        
        gg.log(string.format("玩家 %s 一键领取 %d 个在线奖励", player.name, successCount))
    else
        RewardEventManager.SendErrorResponse(player, RewardEvent.RESPONSE.CLAIM_ALL_RESULT, "没有可领取的奖励")
    end
end

--- 处理获取红点状态请求
---@param player MPlayer 玩家对象
---@param evt table 事件数据
function RewardEventManager.HandleGetRedDotStatus(player, evt)
    if not player or not player.uin then
        RewardEventManager.SendErrorResponse(player, RewardEvent.RESPONSE.RED_DOT_STATUS, "玩家对象无效")
        return
    end
    
    local hasAvailable = RewardMgr.HasAvailableReward(player.uin)
    
    -- 发送响应
    gg.network_channel:fireClient(player.uin, {
        cmd = RewardEvent.RESPONSE.RED_DOT_STATUS,
        hasAvailable = hasAvailable
    })
end

--- 处理切换配置请求
---@param player MPlayer 玩家对象
---@param evt table 事件数据
function RewardEventManager.HandleSwitchConfig(player, evt)
    if not player or not player.uin then
        RewardEventManager.SendErrorResponse(player, RewardEvent.RESPONSE.SWITCH_CONFIG_RESULT, "玩家对象无效")
        return
    end
    
    local configName = evt and evt.configName
    if not configName or type(configName) ~= "string" then
        RewardEventManager.SendErrorResponse(player, RewardEvent.RESPONSE.SWITCH_CONFIG_RESULT, "无效的配置名称")
        return
    end
    
    -- 切换配置
    local success = RewardMgr.SwitchPlayerConfig(player.uin, configName)
    
    if success then
        -- 发送成功响应
        gg.network_channel:fireClient(player.uin, {
            cmd = RewardEvent.RESPONSE.SWITCH_CONFIG_RESULT,
            success = true,
            newConfig = configName,
            errorMsg = nil
        })
        
        gg.log(string.format("玩家 %s 切换奖励配置为: %s", player.name, configName))
    else
        RewardEventManager.SendErrorResponse(player, RewardEvent.RESPONSE.SWITCH_CONFIG_RESULT, "切换配置失败")
    end
end

-- ==================== 通知函数 ====================

--- 通知数据同步
---@param player MPlayer 玩家对象
---@param status table 在线奖励状态
function RewardEventManager.NotifyDataSync(player, status)
    if not player then
        return
    end
    
    -- 使用与 PartnerEventManager 相同的方式发送事件
    gg.network_channel:fireClient(player.uin, {
        cmd = RewardEvent.NOTIFY.DATA_SYNC,
        onlineStatus = status,
        hasAvailable = RewardMgr.HasAvailableReward(player.uin)
    })
    
    gg.log(string.format("已发送数据同步通知给玩家 %d", player.uin))
end

--- 通知新奖励可领取
---@param player MPlayer 玩家对象
function RewardEventManager.NotifyNewAvailable(player)
    if not player then
        return
    end
    
    -- 获取可领取的奖励索引
    local rewardInstance = RewardMgr.GetPlayerReward(player.uin)
    local availableIndices = {}
    
    if rewardInstance then
        availableIndices = rewardInstance:GetAvailableOnlineRewards()
    end
    
    local eventData = {
        hasAvailable = #availableIndices > 0,
        availableIndices = availableIndices,
        onlineTime = rewardInstance and rewardInstance.onlineData.roundOnlineTime or 0
    }
    
    gg.log(string.format("服务端准备发送新奖励可领取通知给玩家 %d，事件名: %s，数据: %s", 
        player.uin, RewardEvent.NOTIFY.NEW_AVAILABLE, table.concat(availableIndices, ", ")))
    
    -- 使用与 PartnerEventManager 相同的方式发送事件
    gg.network_channel:fireClient(player.uin, {
        cmd = RewardEvent.NOTIFY.NEW_AVAILABLE,
        hasAvailable = eventData.hasAvailable,
        availableIndices = eventData.availableIndices,
        onlineTime = eventData.onlineTime
    })
    
    gg.log(string.format("已发送新奖励可领取通知给玩家 %d，可领取索引: %s", 
        player.uin, table.concat(availableIndices, ", ")))
end

--- 通知奖励已领取（多端同步）
---@param player MPlayer 玩家对象
---@param rewardType string 奖励类型
---@param index number 奖励索引
---@param reward table 奖励内容
function RewardEventManager.NotifyRewardClaimed(player, rewardType, index, reward)
    if not player then
        return
    end
    
    -- 使用与 PartnerEventManager 相同的方式发送事件
    gg.network_channel:fireClient(player.uin, {
        cmd = RewardEvent.NOTIFY.REWARD_CLAIMED,
        type = rewardType,
        index = index,
        reward = reward
    })
end

--- 通知轮次重置
---@param player MPlayer 玩家对象
---@param newRound number 新轮次
---@param reason string 重置原因
function RewardEventManager.NotifyRoundReset(player, newRound, reason)
    if not player then
        return
    end
    
    gg.network_channel:fireClient(player.uin, {
        cmd = RewardEvent.NOTIFY.ROUND_RESET,
        newRound = newRound,
        reason = reason or "all_claimed"
    })
end

--- 通知每日重置
---@param player MPlayer 玩家对象
---@param date string 日期
---@param date todayOnlineTime 今日在线时长
function RewardEventManager.NotifyDailyReset(player, date, todayOnlineTime)
    if not player then
        return
    end
    
    gg.network_channel:fireClient(player.uin, {
        cmd = RewardEvent.NOTIFY.DAILY_RESET,
        date = date,
        todayOnlineTime = todayOnlineTime or 0
    })
end

-- ==================== 工具函数 ====================

--- 发送错误响应
---@param player MPlayer 玩家对象
---@param eventName string 事件名称
---@param errorMsg string 错误信息
function RewardEventManager.SendErrorResponse(player, eventName, errorMsg)
    gg.network_channel:fireClient(player.uin, {
        cmd = eventName,
        success = false,
        errorMsg = errorMsg
    })
    
    gg.log(string.format("奖励事件错误: %s", errorMsg))
end

--- 清理事件管理器
function RewardEventManager.Cleanup()
    -- 这里可以添加清理逻辑，比如取消事件注册等
    gg.log("奖励事件管理器已清理")
end

return RewardEventManager