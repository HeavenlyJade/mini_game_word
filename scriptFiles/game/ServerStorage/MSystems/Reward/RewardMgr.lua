-- RewardMgr.lua
-- 奖励系统管理器 - 管理所有玩家的奖励实例

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local Reward = require(ServerStorage.MSystems.Reward.Reward) ---@type Reward
local RewardCloudDataMgr = require(ServerStorage.MSystems.Reward.RewardCloudDataMgr) ---@type RewardCloudDataMgr
local PlayerRewardDispatcher = require(ServerStorage.MiniGameMgr.PlayerRewardDispatcher) ---@type PlayerRewardDispatcher

---@class RewardMgr
local RewardMgr = {
    -- 在线玩家奖励实例缓存
    playerRewards = {}, ---@type table<number, Reward>
    
    -- 更新定时器
    updateTimer = nil, ---@type Timer
    
    -- 保存定时器
    saveTimer = nil, ---@type Timer
}

-- ==================== 初始化 ====================
function RewardMgr.Init()
    --gg.log("初始化奖励系统管理器")
    RewardMgr.StartUpdateTimer()
    -- 移除定时存盘功能，现在使用统一的定时存盘机制
    -- RewardMgr.StartSaveTimer()
end

--- 启动更新定时器
function RewardMgr.StartUpdateTimer()
    if RewardMgr.updateTimer then
        return
    end
    
    RewardMgr.updateTimer = SandboxNode.New("Timer", game.WorkSpace) ---@type Timer
    RewardMgr.updateTimer.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE
    RewardMgr.updateTimer.Name = "RewardMgr_UpdateTimer"
    RewardMgr.updateTimer.Delay = 1
    RewardMgr.updateTimer.Loop = true
    RewardMgr.updateTimer.Interval = 1  -- 每秒执行
    RewardMgr.updateTimer.Callback = function()
        RewardMgr.UpdateAllOnlineTime()
    end
    RewardMgr.updateTimer:Start()
end

-- 移除定时存盘功能，现在使用统一的定时存盘机制
-- --- 启动保存定时器
-- function RewardMgr.StartSaveTimer()
--     if RewardMgr.saveTimer then
--         return
--     end
--     
--     RewardMgr.saveTimer = SandboxNode.New("Timer", game.WorkSpace) ---@type Timer
--     RewardMgr.saveTimer.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE
--     RewardMgr.saveTimer.Name = "RewardMgr_SaveTimer"
--     RewardMgr.saveTimer.Delay = 60
--     RewardMgr.saveTimer.Loop = true
--     RewardMgr.saveTimer.Interval = 60  -- 每60秒保存
--     RewardMgr.saveTimer.Callback = function()
--         RewardMgr.SaveAllPlayerData()
--     end
--     RewardMgr.saveTimer:Start()
-- end

-- ==================== 玩家管理 ====================

--- 玩家上线处理
---@param player MPlayer 玩家对象
function RewardMgr.OnPlayerJoin(player)
    if not player or not player.uin then
        --gg.log("错误: 玩家对象无效")
        return
    end
    
    local uin = player.uin
    --gg.log(string.format("=== 奖励系统初始化开始 ==="))
    --gg.log(string.format("玩家 %s (UIN:%d) 上线，开始加载奖励数据...", player.name or "未知", uin))
    
    -- 从云端加载数据
    local ret, savedData = RewardCloudDataMgr.ReadPlayerRewardData(uin)
    --gg.log(string.format("云端数据读取结果: ret=%d, 数据=%s", ret, gg.json.encode(savedData or {})))
    
    -- 创建奖励实例
    local rewardInstance = Reward.New(uin, savedData)
    RewardMgr.playerRewards[uin] = rewardInstance
    --gg.log(string.format("奖励实例创建完成，实例ID: %s", tostring(rewardInstance)))
    
    -- 打印初始数据状态
    if rewardInstance and rewardInstance.onlineData then
        local data = rewardInstance.onlineData
        --gg.log(string.format("玩家 %d 初始奖励数据:", uin))
        --gg.log(string.format("  - 配置名称: %s", data.configName or "未知"))
        --gg.log(string.format("  - 当前轮次: %d", data.currentRound or 0))
        --gg.log(string.format("  - 今日在线时长: %d 秒", data.todayOnlineTime or 0))
        --gg.log(string.format("  - 本轮在线时长: %d 秒", data.roundOnlineTime or 0))
        --gg.log(string.format("  - 已领取奖励数量: %d", #(data.claimedIndices or {})))
        --gg.log(string.format("  - 最后登录日期: %s", data.lastLoginDate or "未知"))
    end
    
    -- 发送初始数据给客户端
    RewardMgr.SyncDataToClient(player)
    --gg.log(string.format("已同步初始数据给客户端"))
    
    --gg.log(string.format("玩家 %s (UIN:%d) 奖励系统初始化完成", player.name or "未知", uin))
    --gg.log(string.format("=== 奖励系统初始化结束 ==="))
end

--- 玩家离线处理
---@param uin number 玩家ID
function RewardMgr.OnPlayerLeave(uin)
    local rewardInstance = RewardMgr.playerRewards[uin]
    if not rewardInstance then
        return
    end
        
    -- 保存数据到云端
    local saveData = rewardInstance:GetSaveData()
    RewardCloudDataMgr.SavePlayerRewardData(uin, saveData, true)
    
    -- 清除缓存
    RewardMgr.playerRewards[uin] = nil
    
    gg.log(string.format("玩家 %d 奖励数据已保存", uin))
    if saveData then
        gg.log("=== 玩家奖励完整数据开始 ===")
        gg.log(gg.printTable(saveData))
        gg.log("=== 玩家奖励完整数据结束 ===")
    end
end

-- ==================== 在线时长更新 ====================

--- 更新所有玩家的在线时长
function RewardMgr.UpdateAllOnlineTime()
    local updateCount = 0
    local availableCount = 0
    
    for uin, rewardInstance in pairs(RewardMgr.playerRewards) do
        updateCount = updateCount + 1
        
                 -- 获取更新前的状态
         local oldStatus = rewardInstance:GetOnlineRewardStatus()
         local oldOnlineTime = oldStatus and oldStatus.roundOnlineTime or 0
         local oldAvailableCount = oldStatus and oldStatus.availableCount or 0
         
         -- 更新在线时长（每秒+1）
         rewardInstance:UpdateOnlineTime(1)
         
         -- 获取更新后的状态
         local newStatus = rewardInstance:GetOnlineRewardStatus()
         local newOnlineTime = newStatus and newStatus.roundOnlineTime or 0
         local newAvailableCount = newStatus and newStatus.availableCount or 0
        
        -- 检查是否有新的可领取奖励
        if rewardInstance:HasAvailableReward() then
            availableCount = availableCount + 1
            
            -- 检查是否有新的奖励变为可领取
            if newAvailableCount > oldAvailableCount then
 
                
                -- 通知客户端更新
                local player = RewardMgr.GetPlayer(uin)
                if player then
                    RewardMgr.NotifyAvailableReward(player)
                    ----gg.log(string.format("已通知玩家 %d 有新的可领取奖励", uin))
                else
                    ----gg.log(string.format("警告：找不到玩家 %d 的对象，无法发送通知", uin))
                end
            else
     
            end
        else
        
        end
    end
    
    if updateCount > 0 then
        ----gg.log(string.format("在线时长更新完成：处理了 %d 个玩家，其中 %d 个有可领取奖励", updateCount, availableCount))
    end
end

-- ==================== 奖励操作 ====================

--- 领取在线奖励
---@param player MPlayer 玩家对象
---@param index number 奖励索引
---@return boolean 是否成功
---@return string|nil 错误信息
function RewardMgr.ClaimOnlineReward(player, index)
    --gg.log("=== RewardMgr.ClaimOnlineReward ===")
    --gg.log(string.format("玩家: %s (ID: %d)", player.name or "未知", player.uin or 0))
    --gg.log(string.format("奖励索引: %d", index))
    
    if not player or not player.uin then
        --gg.log("错误：玩家对象无效")
        return false, "玩家对象无效"
    end
    
    local rewardInstance = RewardMgr.playerRewards[player.uin]
    if not rewardInstance then
        --gg.log("错误：奖励数据未加载")
        return false, "奖励数据未加载"
    end
    
    --gg.log("开始调用Reward实例的ClaimOnlineReward方法")
    
    -- 领取奖励
    local rewardItem, errorMsg = rewardInstance:ClaimOnlineReward(index)
    if not rewardItem then
        --gg.log(string.format("奖励领取失败: %s", errorMsg or "未知错误"))
        return false, errorMsg or "领取失败"
    end
    
    --gg.log("奖励领取成功，开始发放奖励物品",rewardItem)
    
    -- 发放奖励物品
    local success = RewardMgr.GiveRewardToPlayer(player, rewardItem)
    
    if success then
        -- 立即保存奖励数据
        local rewardInstance = RewardMgr.playerRewards[player.uin]
        if rewardInstance then
            local saveData = rewardInstance:GetSaveData()
            local RewardCloudDataMgr = require(ServerStorage.MSystems.Reward.RewardCloudDataMgr) ---@type RewardCloudDataMgr
            RewardCloudDataMgr.SavePlayerRewardData(player.uin, saveData)
            --gg.log(string.format("奖励领取成功，已立即保存奖励数据: 玩家 %d, 奖励索引 %d", player.uin, index))
        end
    end
    
    --gg.log("奖励发放成功，开始同步数据到客户端")
    
    -- 同步数据到客户端
    RewardMgr.SyncDataToClient(player)
    
    --gg.log(string.format("玩家 %s 领取在线奖励 %d 完成", player.name, index))
    --gg.log("=== RewardMgr.ClaimOnlineReward 结束 ===")
    
    return true
end

--- 一键领取所有在线奖励
---@param player MPlayer 玩家对象
---@return table 成功领取的奖励列表
function RewardMgr.ClaimAllOnlineRewards(player)
    if not player or not player.uin then
        return {}
    end
    
    local rewardInstance = RewardMgr.playerRewards[player.uin]
    if not rewardInstance then
        return {}
    end
    
    -- 获取所有可领取的奖励
    local allRewards = rewardInstance:ClaimAllOnlineRewards()
    local successRewards = {}
    
    -- 发放所有奖励
    for _, rewardData in ipairs(allRewards) do
        local success = RewardMgr.GiveRewardToPlayer(player, rewardData.reward)
        if success then
            table.insert(successRewards, rewardData)
        end
    end
    
    -- 一键领取成功后立即保存奖励数据
    if #successRewards > 0 then
        local rewardInstance = RewardMgr.playerRewards[player.uin]
        if rewardInstance then
            local saveData = rewardInstance:GetSaveData()
            local RewardCloudDataMgr = require(ServerStorage.MSystems.Reward.RewardCloudDataMgr) ---@type RewardCloudDataMgr
            RewardCloudDataMgr.SavePlayerRewardData(player.uin, saveData)
            --gg.log(string.format("一键领取成功，已立即保存奖励数据: 玩家 %d, 领取数量 %d", player.uin, #successRewards))
        end
    end
    
    ------gg.log(string.format("玩家 %s 一键领取 %d 个在线奖励", player.name, #successRewards))
    
    -- 同步数据到客户端
    RewardMgr.SyncDataToClient(player)
    
    return successRewards
end

-- ==================== 奖励发放 ====================

--- 发放奖励给玩家
---@param player MPlayer 玩家对象
---@param rewardItem table 奖励物品数据
---@return boolean 是否成功
function RewardMgr.GiveRewardToPlayer(player, rewardItem)
    if not rewardItem then
        gg.log("奖励发放失败：奖励数据为空")
        return false
    end
    
    local rewardType = rewardItem.type
    local amount = rewardItem.amount or 1
    
    -- 转换为 PlayerRewardDispatcher 所需的格式
    local rewardData = {
        itemType = rewardType,
        amount = amount
    }
    
    if rewardType == "物品" then
        rewardData.itemName = rewardItem.itemName
        if not rewardData.itemName then
            gg.log("奖励发放失败：物品名称缺失")
            return false
        end
        
    elseif rewardType == "宠物" then
        rewardData.itemName = rewardItem.petConfig
        if not rewardData.itemName then
            gg.log("奖励发放失败：宠物配置缺失")
            return false
        end
        
    elseif rewardType == "伙伴" then
        rewardData.itemName = rewardItem.partnerConfig
        if not rewardData.itemName then
            gg.log("奖励发放失败：伙伴配置缺失")
            return false
        end
        
    elseif rewardType == "翅膀" then
        rewardData.itemName = rewardItem.wingConfig
        if not rewardData.itemName then
            gg.log("奖励发放失败：翅膀配置缺失")
            return false
        end
        
    else
        gg.log("奖励发放失败：不支持的奖励类型", rewardType)
        return false
    end
    
    -- 使用统一奖励分发器发放奖励
    local success, errorMsg = PlayerRewardDispatcher.DispatchRewards(player, {rewardData})
    
    if not success then
        gg.log("奖励发放失败", player.name, "错误信息", errorMsg)
    end
    
    return success
end

-- ==================== 数据查询 ====================

--- 获取玩家奖励实例
---@param uin number 玩家ID
---@return Reward|nil 奖励实例
function RewardMgr.GetPlayerReward(uin)
    return RewardMgr.playerRewards[uin]
end

--- 获取玩家在线奖励状态
---@param uin number 玩家ID
---@return table|nil 状态信息
function RewardMgr.GetPlayerOnlineRewardStatus(uin)
    local rewardInstance = RewardMgr.playerRewards[uin]
    if not rewardInstance then
        return nil
    end
    
    return rewardInstance:GetOnlineRewardStatus()
end

--- 检查玩家是否有可领取的奖励
---@param uin number 玩家ID
---@return boolean 是否有可领取的奖励
function RewardMgr.HasAvailableReward(uin)
    local rewardInstance = RewardMgr.playerRewards[uin]
    if not rewardInstance then
        return false
    end
    
    return rewardInstance:HasAvailableReward()
end

-- ==================== 数据同步 ====================

--- 同步数据到客户端
---@param player MPlayer 玩家对象
function RewardMgr.SyncDataToClient(player)
    if not player or not player.uin then
        return
    end
    
    local status = RewardMgr.GetPlayerOnlineRewardStatus(player.uin)
    if not status then
        return
    end
    
    -- 直接发送 ONLINE_REWARD_DATA 响应事件
    local RewardEvent = require(MainStorage.Code.Event.RewardEvent) ---@type RewardEvent
    gg.network_channel:fireClient(player.uin, {
        cmd = RewardEvent.RESPONSE.ONLINE_REWARD_DATA,
        success = true,
        data = status,
        errorMsg = nil
    })
    
    --gg.log(string.format("已同步奖励数据给玩家 %d", player.uin))
end

--- 通知客户端有新的可领取奖励
---@param player MPlayer 玩家对象
function RewardMgr.NotifyAvailableReward(player)
    if not player then
        ----gg.log("警告：NotifyAvailableReward 收到空的玩家对象")
        return
    end
    
    ----gg.log(string.format("正在通知玩家 %d 有新的可领取奖励", player.uin))
    
    -- 通过RewardEventManager发送新奖励可领取通知
    local RewardEventManager = require(ServerStorage.MSystems.Reward.RewardEventManager) ---@type RewardEventManager
    RewardEventManager.NotifyNewAvailable(player)
    
    ----gg.log(string.format("已发送通知给玩家 %d", player.uin))
end

-- ==================== 数据保存 ====================

-- 移除定时存盘功能，现在使用统一的定时存盘机制
-- --- 保存所有玩家数据
-- function RewardMgr.SaveAllPlayerData()
--     local count = 0
--     local dataToSave = {}
--     
--     for uin, rewardInstance in pairs(RewardMgr.playerRewards) do
--         dataToSave[uin] = rewardInstance:GetSaveData()
--         count = count + 1
--     end
--     
--     -- 批量保存
--     if count > 0 then
--         RewardCloudDataMgr.BatchSave(dataToSave)
--         ------gg.log(string.format("定时保存: 已保存 %d 个玩家的奖励数据", count))
--     end
-- end

---保存指定玩家的奖励数据（供统一存盘机制调用）
---@param uin number 玩家ID
function RewardMgr.SavePlayerRewardData(uin)
    local rewardInstance = RewardMgr.playerRewards[uin]
    if rewardInstance then
        local saveData = rewardInstance:GetSaveData()
        RewardCloudDataMgr.SavePlayerRewardData(uin, saveData)
        ----gg.log("统一存盘：已保存玩家", uin, "的奖励数据")
    end
end

--- 保存指定玩家数据
---@param uin number 玩家ID
---@return boolean 是否成功
function RewardMgr.SavePlayerData(uin)
    local rewardInstance = RewardMgr.playerRewards[uin]
    if not rewardInstance then
        return false
    end
    
    local saveData = rewardInstance:GetSaveData()
    return RewardCloudDataMgr.SavePlayerRewardData(uin, saveData)
end

-- ==================== 工具函数 ====================

--- 获取玩家对象
---@param uin number 玩家ID
---@return MPlayer|nil 玩家对象
function RewardMgr.GetPlayer(uin)
    local ServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
    return ServerDataManager.getPlayerByUin(uin)
end

--- 切换玩家的奖励配置
---@param uin number 玩家ID
---@param configName string 新的配置名称
---@return boolean 是否成功
function RewardMgr.SwitchPlayerConfig(uin, configName)
    local rewardInstance = RewardMgr.playerRewards[uin]
    if not rewardInstance then
        return false
    end
    
    rewardInstance:SwitchConfig(configName)
    
    -- 同步到客户端
    local player = RewardMgr.GetPlayer(uin)
    if player then
        RewardMgr.SyncDataToClient(player)
    end
    
    return true
end

--- 清理管理器（服务器关闭时调用）
function RewardMgr.Cleanup()
    -- 保存所有数据（使用新的统一存盘机制）
    for uin, _ in pairs(RewardMgr.playerRewards) do
        RewardMgr.SavePlayerRewardData(uin)
    end
    
    -- 停止定时器
    if RewardMgr.updateTimer then
        RewardMgr.updateTimer:Stop()
        RewardMgr.updateTimer:Destroy()
        RewardMgr.updateTimer = nil
    end
    
    -- 移除定时存盘功能，现在使用统一的定时存盘机制
    -- if RewardMgr.saveTimer then
    --     RewardMgr.saveTimer:Stop()
    --     RewardMgr.saveTimer:Destroy()
    --     RewardMgr.saveTimer = nil
    -- end
    
    -- 清空缓存
    RewardMgr.playerRewards = {}
    
    ------gg.log("奖励系统管理器已清理")
end



return RewardMgr