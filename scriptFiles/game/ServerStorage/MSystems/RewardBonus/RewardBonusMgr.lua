-- RewardBonusMgr.lua
-- 奖励加成系统管理器 - 管理所有玩家的奖励加成实例
-- 参考RewardMgr实现

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local RewardBonus = require(ServerStorage.MSystems.RewardBonus.RewardBonus) ---@type RewardBonus
local RewardBonusCloudDataMgr = require(ServerStorage.MSystems.RewardBonus.RewardBonusCloudDataMgr) ---@type RewardBonusCloudDataMgr
local PlayerRewardDispatcher = require(ServerStorage.MiniGameMgr.PlayerRewardDispatcher) ---@type PlayerRewardDispatcher

---@class RewardBonusMgr
local RewardBonusMgr = {
    -- 在线玩家奖励加成实例缓存
    playerRewardBonuses = {}, ---@type table<number, RewardBonus>
}

-- ==================== 初始化 ====================
function RewardBonusMgr.Init()
    gg.log("初始化奖励加成系统管理器")
end

-- ==================== 玩家管理 ====================

--- 玩家上线处理
---@param player MPlayer 玩家对象
---@return boolean 是否成功加载
function RewardBonusMgr.OnPlayerJoin(player)
    if not player or not player.uin then
        gg.log("错误：无效的玩家对象")
        return false
    end

    local uin = player.uin
    
    -- 避免重复加载
    if RewardBonusMgr.playerRewardBonuses[uin] then
        gg.log("警告：玩家奖励加成已存在", uin)
        return true
    end

    gg.log("玩家上线，加载奖励加成数据", uin)

    -- 从云端加载数据
    local ret, cloudData = RewardBonusCloudDataMgr.LoadPlayerData(uin)
    if ret ~= 0 then
        gg.log("警告：加载奖励加成数据失败，使用默认数据", uin)
    end

    -- 创建RewardBonus实例
    local rewardBonusInstance = RewardBonus.New(uin, cloudData)
    if not rewardBonusInstance then
        gg.log("错误：创建奖励加成实例失败", uin)
        return false
    end

    -- 缓存实例
    RewardBonusMgr.playerRewardBonuses[uin] = rewardBonusInstance

    -- 同步数据到客户端
    RewardBonusMgr.SyncDataToClient(player)

    gg.log("玩家奖励加成数据加载完成", uin)
    return true
end

--- 玩家下线处理
---@param player MPlayer 玩家对象
function RewardBonusMgr.OnPlayerLeave(player)
    if not player or not player.uin then
        return
    end

    local uin = player.uin
    gg.log("玩家下线，清理奖励加成数据", uin)

    -- 保存数据
    RewardBonusMgr.SavePlayerData(uin)

    -- 移除缓存
    RewardBonusMgr.playerRewardBonuses[uin] = nil

    gg.log("玩家奖励加成数据已清理", uin)
end

-- ==================== 奖励领取 ====================

--- 领取指定配置的指定等级奖励
---@param player MPlayer 玩家对象
---@param configName string 配置名称
---@param uniqueId string 奖励等级唯一ID
---@return boolean 是否成功
---@return string|nil 错误信息
function RewardBonusMgr.ClaimTierReward(player, configName, uniqueId)
    if not player or not player.uin then
        return false, "无效玩家"
    end

    local uin = player.uin
    local rewardBonusInstance = RewardBonusMgr.playerRewardBonuses[uin]
    if not rewardBonusInstance then
        return false, "奖励加成数据未加载"
    end

    -- 领取奖励
    local success, message, rewardItems = rewardBonusInstance:ClaimTierReward(configName, uniqueId)
    if not success then
        return false, message or "领取失败"
    end
    if not rewardItems then
        return false, "奖励物品列表为空"
    end
    -- 发放奖励物品
    local giveSuccess = PlayerRewardDispatcher.DispatchRewards(player, rewardItems)
    
    if giveSuccess then
        -- 立即保存数据
        RewardBonusMgr.SavePlayerRewardBonusData(uin)
        
        -- 同步数据到客户端
        RewardBonusMgr.SyncDataToClient(player)
        
        return true, "领取成功"
    else
        return false, "奖励发放失败"
    end
end


-- ==================== 状态查询 ====================

--- 获取玩家指定配置的状态
---@param uin number 玩家ID
---@param configName string 配置名称
---@return table|nil 配置状态信息
function RewardBonusMgr.GetPlayerConfigStatus(uin, configName)
    local rewardBonusInstance = RewardBonusMgr.playerRewardBonuses[uin]
    if not rewardBonusInstance then
        return nil
    end

    return rewardBonusInstance:GetConfigStatus(configName)
end

--- 获取玩家所有配置状态
---@param uin number 玩家ID
---@return table|nil 所有配置状态
function RewardBonusMgr.GetPlayerAllConfigsStatus(uin)
    local rewardBonusInstance = RewardBonusMgr.playerRewardBonuses[uin]
    if not rewardBonusInstance then
        return nil
    end

    return rewardBonusInstance:GetAllConfigsStatus()
end

-- ==================== 数据同步 ====================

--- 同步数据到客户端
---@param player MPlayer 玩家对象
function RewardBonusMgr.SyncDataToClient(player)
    if not player or not player.uin then
        return
    end

    local status = RewardBonusMgr.GetPlayerAllConfigsStatus(player.uin)
    if not status then
        return
    end

    -- 发送数据到客户端
    local RewardBonusEvent = require(MainStorage.Code.Event.RewardBonusEvent) ---@type RewardBonusEvent
    gg.network_channel:fireClient(player.uin, {
        cmd = RewardBonusEvent.RESPONSE.REWARD_BONUS_DATA,
        success = true,
        data = status,
        errorMsg = nil
    })

    gg.log("已同步奖励加成数据给玩家", player.uin)
end



-- ==================== 数据保存 ====================


--- 保存指定玩家数据
---@param uin number 玩家ID
---@return boolean 是否成功
function RewardBonusMgr.SavePlayerData(uin)
    local rewardBonusInstance = RewardBonusMgr.playerRewardBonuses[uin]
    if not rewardBonusInstance then
        return false
    end

    local cloudData = rewardBonusInstance:GetCloudData()
    return RewardBonusCloudDataMgr.SavePlayerData(uin, cloudData)
end

-- ==================== 工具函数 ===================

--- 重置玩家指定配置的数据
---@param uin number 玩家ID
---@param configName string 配置名称
---@return boolean 是否成功
function RewardBonusMgr.ResetPlayerConfig(uin, configName)
    local rewardBonusInstance = RewardBonusMgr.playerRewardBonuses[uin]
    if not rewardBonusInstance then
        return false
    end

    rewardBonusInstance:ResetConfig(configName)

    -- 同步到客户端
    local player = RewardBonusMgr.GetPlayer(uin)
    if player then
        RewardBonusMgr.SyncDataToClient(player)
    end

    return true
end

return RewardBonusMgr