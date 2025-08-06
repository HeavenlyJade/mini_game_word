-- RewardMgr.lua
-- 奖励系统管理器 - 管理所有玩家的奖励实例

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local Reward = require(ServerStorage.MSystems.Reward.Reward) ---@type Reward
local RewardCloudDataMgr = require(ServerStorage.MSystems.Reward.RewardCloudDataMgr) ---@type RewardCloudDataMgr

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

--- 启动保存定时器
function RewardMgr.StartSaveTimer()
    if RewardMgr.saveTimer then
        return
    end
    
    RewardMgr.saveTimer = SandboxNode.New("Timer", game.WorkSpace) ---@type Timer
    RewardMgr.saveTimer.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE
    RewardMgr.saveTimer.Name = "RewardMgr_SaveTimer"
    RewardMgr.saveTimer.Delay = 60
    RewardMgr.saveTimer.Loop = true
    RewardMgr.saveTimer.Interval = 60  -- 每60秒保存
    RewardMgr.saveTimer.Callback = function()
        RewardMgr.SaveAllPlayerData()
    end
    RewardMgr.saveTimer:Start()
end

-- ==================== 玩家管理 ====================

--- 玩家上线处理
---@param player MPlayer 玩家对象
function RewardMgr.OnPlayerJoin(player)
    if not player or not player.uin then
        --gg.log("错误: 玩家对象无效")
        return
    end
    
    local uin = player.uin
    --gg.log(string.format("玩家 %d 上线，加载奖励数据...", uin))
    
    -- 从云端加载数据
    local ret, savedData = RewardCloudDataMgr.ReadPlayerRewardData(uin)
    
    -- 创建奖励实例
    local rewardInstance = Reward.New(uin, savedData)
    RewardMgr.playerRewards[uin] = rewardInstance
    
    -- 发送初始数据给客户端
    RewardMgr.SyncDataToClient(player)
    
    --gg.log(string.format("玩家 %d 奖励系统初始化完成", uin))
end

--- 玩家离线处理
---@param uin number 玩家ID
function RewardMgr.OnPlayerLeave(uin)
    local rewardInstance = RewardMgr.playerRewards[uin]
    if not rewardInstance then
        return
    end
    
    --gg.log(string.format("玩家 %d 离线，保存奖励数据...", uin))
    
    -- 保存数据到云端
    local saveData = rewardInstance:GetSaveData()
    RewardCloudDataMgr.SavePlayerRewardData(uin, saveData)
    
    -- 清除缓存
    RewardMgr.playerRewards[uin] = nil
    
    --gg.log(string.format("玩家 %d 奖励数据已保存", uin))
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
                gg.log(string.format("玩家 %d 有新的奖励可领取！在线时长: %d -> %d, 可领取数量: %d -> %d", 
                    uin, oldOnlineTime, newOnlineTime, oldAvailableCount, newAvailableCount))
                
                -- 通知客户端更新
                local player = RewardMgr.GetPlayer(uin)
                if player then
                    RewardMgr.NotifyAvailableReward(player)
                    gg.log(string.format("已通知玩家 %d 有新的可领取奖励", uin))
                else
                    gg.log(string.format("警告：找不到玩家 %d 的对象，无法发送通知", uin))
                end
            else
                gg.log(string.format("玩家 %d 在线时长更新: %d -> %d, 可领取数量: %d (无变化)", 
                    uin, oldOnlineTime, newOnlineTime, newAvailableCount))
            end
        else
            gg.log(string.format("玩家 %d 在线时长更新: %d -> %d, 暂无可领取奖励", 
                uin, oldOnlineTime, newOnlineTime))
        end
    end
    
    if updateCount > 0 then
        gg.log(string.format("在线时长更新完成：处理了 %d 个玩家，其中 %d 个有可领取奖励", updateCount, availableCount))
    end
end

-- ==================== 奖励操作 ====================

--- 领取在线奖励
---@param player MPlayer 玩家对象
---@param index number 奖励索引
---@return boolean 是否成功
---@return string|nil 错误信息
function RewardMgr.ClaimOnlineReward(player, index)
    if not player or not player.uin then
        return false, "玩家对象无效"
    end
    
    local rewardInstance = RewardMgr.playerRewards[player.uin]
    if not rewardInstance then
        return false, "奖励数据未加载"
    end
    
    -- 领取奖励
    local rewardItem, errorMsg = rewardInstance:ClaimOnlineReward(index)
    if not rewardItem then
        return false, errorMsg or "领取失败"
    end
    
    -- 发放奖励物品
    local success = RewardMgr.GiveRewardToPlayer(player, rewardItem)
    if not success then
        -- 回滚（从已领取列表中移除）
        local claimedList = rewardInstance.onlineData.claimedIndices
        for i = #claimedList, 1, -1 do
            if claimedList[i] == index then
                table.remove(claimedList, i)
                break
            end
        end
        return false, "发放奖励失败"
    end
    
    --gg.log(string.format("玩家 %s 领取在线奖励 %d", player.name, index))
    
    -- 同步数据到客户端
    RewardMgr.SyncDataToClient(player)
    
    return true
end

--- 一键领取所有在线奖励
---@param player MPlayer 玩家对象
---@return number 成功领取的数量
function RewardMgr.ClaimAllOnlineRewards(player)
    if not player or not player.uin then
        return 0
    end
    
    local rewardInstance = RewardMgr.playerRewards[player.uin]
    if not rewardInstance then
        return 0
    end
    
    -- 获取所有可领取的奖励
    local allRewards = rewardInstance:ClaimAllOnlineRewards()
    local successCount = 0
    
    -- 发放所有奖励
    for _, rewardData in ipairs(allRewards) do
        local success = RewardMgr.GiveRewardToPlayer(player, rewardData.reward)
        if success then
            successCount = successCount + 1
        end
    end
    
    --gg.log(string.format("玩家 %s 一键领取 %d 个在线奖励", player.name, successCount))
    
    -- 同步数据到客户端
    RewardMgr.SyncDataToClient(player)
    
    return successCount
end

-- ==================== 奖励发放 ====================

--- 发放奖励给玩家
---@param player MPlayer 玩家对象
---@param rewardItem table 奖励物品数据
---@return boolean 是否成功
function RewardMgr.GiveRewardToPlayer(player, rewardItem)
    if not rewardItem then
        return false
    end
    
    local rewardType = rewardItem.type
    local amount = rewardItem.amount or 1
    
    if rewardType == "物品" then
        -- 发放普通物品
        local itemName = rewardItem.itemName
        if not itemName then
            return false
        end
        
        -- 调用背包系统添加物品
        local BagMgr = require(ServerStorage.MSystems.Bag.BagMgr) ---@type BagMgr
        return BagMgr.AddItem(player.uin, itemName, amount)
        
    elseif rewardType == "宠物" then
        -- 发放宠物
        local petConfig = rewardItem.petConfig
        if not petConfig then
            return false
        end
        
        -- 调用宠物系统
        local PetMgr = require(ServerStorage.MSystems.Pet.Mgr.PetMgr) ---@type PetMgr
        return PetMgr.AddPet(player.uin, petConfig, amount)
        
    elseif rewardType == "伙伴" then
        -- 发放伙伴
        local partnerConfig = rewardItem.partnerConfig
        if not partnerConfig then
            return false
        end
        
        -- 调用伙伴系统
        local PartnerMgr = require(ServerStorage.MSystems.Pet.Mgr.PartnerMgr) ---@type PartnerMgr
        return PartnerMgr.AddPartner(player.uin, partnerConfig, amount)
        
    elseif rewardType == "翅膀" then
        -- 发放翅膀
        local wingConfig = rewardItem.wingConfig
        if not wingConfig then
            return false
        end
        
        -- 调用翅膀系统
        local WingMgr = require(ServerStorage.MSystems.Pet.Mgr.WingMgr) ---@type WingMgr
        return WingMgr.AddWing(player.uin, wingConfig, amount)
    end
    
    return false
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
    
    -- 通过RewardEventManager发送数据同步事件
    local RewardEventManager = require(ServerStorage.MSystems.Reward.RewardEventManager) ---@type RewardEventManager
    RewardEventManager.NotifyDataSync(player, status)
    
    gg.log(string.format("已同步奖励数据给玩家 %d", player.uin))
end

--- 通知客户端有新的可领取奖励
---@param player MPlayer 玩家对象
function RewardMgr.NotifyAvailableReward(player)
    if not player then
        gg.log("警告：NotifyAvailableReward 收到空的玩家对象")
        return
    end
    
    gg.log(string.format("正在通知玩家 %d 有新的可领取奖励", player.uin))
    
    -- 通过RewardEventManager发送新奖励可领取通知
    local RewardEventManager = require(ServerStorage.MSystems.Reward.RewardEventManager) ---@type RewardEventManager
    RewardEventManager.NotifyNewAvailable(player)
    
    gg.log(string.format("已发送通知给玩家 %d", player.uin))
end

-- ==================== 数据保存 ====================

--- 保存所有玩家数据
function RewardMgr.SaveAllPlayerData()
    local count = 0
    local dataToSave = {}
    
    for uin, rewardInstance in pairs(RewardMgr.playerRewards) do
        dataToSave[uin] = rewardInstance:GetSaveData()
        count = count + 1
    end
    
    -- 批量保存
    if count > 0 then
        RewardCloudDataMgr.BatchSave(dataToSave)
        --gg.log(string.format("定时保存: 已保存 %d 个玩家的奖励数据", count))
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
    -- 保存所有数据
    RewardMgr.SaveAllPlayerData()
    
    -- 停止定时器
    if RewardMgr.updateTimer then
        RewardMgr.updateTimer:Stop()
        RewardMgr.updateTimer:Destroy()
        RewardMgr.updateTimer = nil
    end
    
    if RewardMgr.saveTimer then
        RewardMgr.saveTimer:Stop()
        RewardMgr.saveTimer:Destroy()
        RewardMgr.saveTimer = nil
    end
    
    -- 清空缓存
    RewardMgr.playerRewards = {}
    
    --gg.log("奖励系统管理器已清理")
end

RewardMgr.StartUpdateTimer()
RewardMgr.StartSaveTimer()


return RewardMgr