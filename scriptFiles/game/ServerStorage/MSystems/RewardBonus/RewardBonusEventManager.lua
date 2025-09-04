-- RewardBonusEventManager.lua
-- 奖励加成事件管理器（静态类）
-- 负责处理客户端请求和服务器响应事件

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local CardIcon = require(MainStorage.Code.Common.Icon.card_icon) ---@type CardIcon
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local RewardBonusEvent = require(MainStorage.Code.Event.RewardBonusEvent) ---@type RewardBonusEvent
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig

-- 引入相关系统
local RewardBonusMgr = require(ServerStorage.MSystems.RewardBonus.RewardBonusMgr) ---@type RewardBonusMgr
local MPlayer = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer
local PartnerEventManager = require(ServerStorage.MSystems.Pet.EventManager.PartnerEventManager) ---@type PartnerEventManager

---@class RewardBonusEventManager
local RewardBonusEventManager = {}

-- 初始化事件管理器
function RewardBonusEventManager.Init()
    -- 注册网络事件处理器
    RewardBonusEventManager.RegisterNetworkHandlers()
end

-- 注册网络事件处理器
function RewardBonusEventManager.RegisterNetworkHandlers()
    -- 获取奖励加成数据
    ServerEventManager.Subscribe(RewardBonusEvent.REQUEST.GET_REWARD_BONUS_DATA, function(evt)
        RewardBonusEventManager.HandleGetRewardBonusData(evt)
    end, 100)
    
    -- 领取指定等级奖励
    ServerEventManager.Subscribe(RewardBonusEvent.REQUEST.CLAIM_TIER_REWARD, function(evt)
        RewardBonusEventManager.HandleClaimTierReward(evt)
    end, 100)
    
    gg.log("奖励加成事件处理器注册完成")
end

-- 事件处理函数 --------------------------------------------------------

--- 处理获取奖励加成数据请求
---@param evt table 事件对象
function RewardBonusEventManager.HandleGetRewardBonusData(evt)
    gg.log("处理获取奖励加成数据请求", evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    
    if not player then
        return
    end
    
    -- 获取所有配置状态
    local status = RewardBonusMgr.GetPlayerAllConfigsStatus(player.uin)
    RewardBonusEventManager.SyncPlayerRewardData(player.uin)
end


--- 处理领取指定等级奖励请求
---@param evt table 事件对象
function RewardBonusEventManager.HandleClaimTierReward(evt)
    gg.log("处理领取指定等级奖励请求", evt)
    local player = PartnerEventManager.ValidatePlayer(evt)
    local args = evt.args or {}
    
    if not player then
        return
    end
    
    local configName = args.configName
    local uniqueId = args.uniqueId
    
    if not configName then
        gg.log("配置名称不能为空", player.name)
        return
    end
    
    if not uniqueId then
        gg.log("奖励等级唯一ID不能为空", player.name, configName)
        return
    end
    
    -- 领取奖励
    local success, errorMsg = RewardBonusMgr.ClaimTierReward(player, configName, uniqueId)
    
    if success then
        gg.log("奖励领取成功", player.name, configName, uniqueId)

        
        -- 同步奖励数据到客户端
        RewardBonusEventManager.SyncPlayerRewardData(player.uin)
        
        -- 发送奖励获得通知
        RewardBonusEventManager.SendRewardAcquiredNotification(player.uin, configName, uniqueId, "奖励加成")
        
    else
        gg.log("奖励领取失败", player.name, configName, uniqueId, errorMsg)
    end
end



-- 通知函数 --------------------------------------------------------

--- 同步玩家奖励数据到客户端
---@param uin number 玩家ID
function RewardBonusEventManager.SyncPlayerRewardData(uin)
    -- 获取所有配置状态
    local status = RewardBonusMgr.GetPlayerAllConfigsStatus(uin)
    
    if status then
        -- 发送数据同步通知
        gg.network_channel:fireClient(uin, {
            cmd = RewardBonusEvent.NOTIFY.DATA_SYNC,
            configs = status.configs,
        })
        
        gg.log("已同步奖励加成数据给玩家", uin)
    else
        gg.log("同步奖励加成数据失败", uin)
    end
end

--- 发送奖励获得通知
---@param uin number 玩家ID
---@param configName string 配置名称
---@param uniqueId string 奖励等级唯一ID
---@param source string 来源描述
function RewardBonusEventManager.SendRewardAcquiredNotification(uin, configName, uniqueId, source)
    -- 发送奖励已领取通知
    gg.network_channel:fireClient(uin, {
        cmd = RewardBonusEvent.NOTIFY.REWARD_CLAIMED,
        configName = configName,
        uniqueId = uniqueId,
        reward = {} -- 具体奖励信息由客户端从数据同步中获取
    })
    
    -- 播放物品获得音效
    local itemGetSound = CardIcon.soundResources["物品获得音效"]
    if itemGetSound then
        gg.network_channel:fireClient(uin, {
            cmd = "PlaySound",
            soundAssetId = itemGetSound
        })
    end
    
    gg.log("已发送奖励获得通知给玩家", uin, configName, uniqueId)
end


return RewardBonusEventManager