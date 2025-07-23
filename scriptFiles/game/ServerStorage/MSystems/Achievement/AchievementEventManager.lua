-- AchievementEventManager.lua
-- 成就事件管理器 - 简化版，适配新的聚合架构

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local AchievementEventConfig = require(MainStorage.Code.Event.AchievementEvent) ---@type AchievementEventConfig
local AchievementMgr = require(ServerStorage.MSystems.Achievement.AchievementMgr) ---@type AchievementMgr

---@class AchievementEventManager
local AchievementEventManager = {}

-- 初始化事件管理器
function AchievementEventManager.Init()
    AchievementEventManager.RegisterNetworkHandlers()
    gg.log("AchievementEventManager 初始化完成")
end

-- 注册网络事件处理器
function AchievementEventManager.RegisterNetworkHandlers()
    -- 获取成就列表
    ServerEventManager.Subscribe(AchievementEventConfig.REQUEST.GET_LIST, function(event)
        AchievementEventManager.HandleGetAchievementList(event)
    end, 100)
    
    -- 升级天赋成就
    ServerEventManager.Subscribe(AchievementEventConfig.REQUEST.UPGRADE_TALENT, function(event)
        AchievementEventManager.HandleUpgradeTalent(event)
    end, 100)
    
    -- 获取天赋等级
    ServerEventManager.Subscribe("AchievementRequest_GetTalentLevel", function(event)
        AchievementEventManager.HandleGetTalentLevel(event)
    end, 100)
    
end

-- 处理获取成就列表请求
function AchievementEventManager.HandleGetAchievementList(event)
    local uin = event.uin
    local playerId = uin
    
    
    -- 获取玩家成就实例
    local playerAchievement = AchievementMgr.server_player_achievement_data[playerId]
    
    if not playerAchievement then
        AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.ERROR,
            AchievementEventConfig.ERROR_CODES.PLAYER_NOT_FOUND)
        return
    end
    
    -- 构建响应数据
    local talentData = playerAchievement:GetAllTalentData()
    local normalAchievements = playerAchievement:GetAllNormalAchievements()
    
    local responseData = {
        talents = {},
        normalAchievements = {},
        totalTalentCount = playerAchievement:GetTalentCount(),
        totalNormalCount = playerAchievement:GetUnlockedNormalAchievementCount()
    }
    
    -- 构建天赋列表
    for talentId, talentInfo in pairs(talentData) do
        responseData.talents[talentId] = {
            talentId = talentId,
            currentLevel = talentInfo.currentLevel,
            unlockTime = talentInfo.unlockTime
        }
    end
    
    -- 构建普通成就列表
    for achievementId, achievementInfo in pairs(normalAchievements) do
        responseData.normalAchievements[achievementId] = {
            achievementId = achievementId,
            unlocked = achievementInfo.unlocked,
            unlockTime = achievementInfo.unlockTime
        }
    end
    
    -- 发送响应
    AchievementEventManager.SendSuccessResponse(uin, AchievementEventConfig.RESPONSE.LIST_RESPONSE, responseData)
end

-- 处理升级天赋成就请求（修复版本，包含资源检查和扣除）
function AchievementEventManager.HandleUpgradeTalent(event)
    gg.log("HandleUpgradeTalent",event)
    local env_player = event.player
    local uin = env_player.uin

    local params = event.args
    local talentId = params.talentId
    local playerId = uin
    
    gg.log("处理升级天赋成就请求:", playerId, talentId)
    
    if not talentId or talentId == "" then
        AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.ERROR,
            AchievementEventConfig.ERROR_CODES.INVALID_PARAMETERS)
        return
    end
    
    -- 获取玩家实例
    local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
    local player = MServerDataManager.getPlayerByUin(playerId)
    if not player then
        AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.ERROR,
            AchievementEventConfig.ERROR_CODES.PLAYER_NOT_FOUND)
        return
    end
    
    -- 获取天赋配置
    local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
    local talentConfig = ConfigLoader.GetAchievement(talentId)
    if not talentConfig or not talentConfig:IsTalentAchievement() then
        AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.ERROR,
            AchievementEventConfig.ERROR_CODES.ACHIEVEMENT_NOT_FOUND)
        return
    end
    
    -- 记录升级前等级
    local oldLevel = AchievementMgr.GetTalentLevel(playerId, talentId)
    
    -- 检查是否已达最大等级
    if oldLevel >= talentConfig:GetMaxLevel() then
        AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.ERROR,
            AchievementEventConfig.ERROR_CODES.TALENT_ALREADY_MAX_LEVEL)
        return
    end
    
    -- 【关键】检查和扣除升级消耗
    local costs = talentConfig:GetUpgradeCosts(oldLevel)
    local BagMgr = require(ServerStorage.MSystems.Bag.BagMgr) ---@type BagMgr
    if not BagMgr.HasItemsByCosts(player, costs) then
        gg.log("升级材料不足:", costs,oldLevel)
        AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.ERROR, AchievementEventConfig.ERROR_CODES.INSUFFICIENT_MATERIALS)
        return
    end
    if not BagMgr.RemoveItemsByCosts(player, costs) then
        gg.log("扣除材料失败:", costs)
        AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.ERROR, AchievementEventConfig.ERROR_CODES.INSUFFICIENT_MATERIALS)
        return
    end
    -- 同步背包变化到客户端
    local bag = BagMgr.GetPlayerBag(player.uin)
    if bag then
        bag:SyncToClient()
    end
    
    -- 执行升级（确保成功，因为前面已经检查过所有条件）
    local upgradeSuccess = AchievementMgr.UpgradeTalent(playerId, talentId)
    
    if upgradeSuccess then
        local newLevel = AchievementMgr.GetTalentLevel(playerId, talentId)
        
        -- 构建响应数据
        local responseData = {
            talentId = talentId,
            oldLevel = oldLevel,
            newLevel = newLevel,
            upgradeTime = os.time()
        }
        
        -- 发送升级成功响应
        AchievementEventManager.SendSuccessResponse(uin, AchievementEventConfig.RESPONSE.UPGRADE_RESPONSE, responseData)
        
        -- 发送升级通知
        AchievementEventManager.SendUpgradeNotification(uin, talentId, oldLevel, newLevel)
        
        gg.log("天赋升级成功:", playerId, talentId, oldLevel, "->", newLevel)
        
    else
        -- 理论上不应该到这里，因为前面已经检查过所有条件
        gg.log("警告：天赋升级意外失败:", playerId, talentId)
        AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.ERROR,
            AchievementEventConfig.ERROR_CODES.SYSTEM_ERROR)
    end
end


-- 处理获取天赋等级请求
function AchievementEventManager.HandleGetTalentLevel(event)
    local uin = event.uin
    local params = event.args or {}
    local talentId = params.talentId
    local playerId = uin
    
    if not talentId or talentId == "" then
        AchievementEventManager.SendErrorResponse(uin, "AchievementResponse_GetTalentLevel",
            AchievementEventConfig.ERROR_CODES.INVALID_PARAMETERS)
        return
    end
    
    local talentLevel = AchievementMgr.GetTalentLevel(playerId, talentId)
    
    local responseData = {
        talentId = talentId,
        currentLevel = talentLevel
    }
    
    AchievementEventManager.SendSuccessResponse(uin, "AchievementResponse_GetTalentLevel", responseData)
end

-- 业务通知方法 --------------------------------------------------------

--- 发送天赋升级通知
---@param uin number 玩家UIN
---@param talentId string 天赋ID
---@param oldLevel number 旧等级
---@param newLevel number 新等级
function AchievementEventManager.SendUpgradeNotification(uin, talentId, oldLevel, newLevel)
    local notificationData = {
        talentId = talentId,
        oldLevel = oldLevel,
        newLevel = newLevel,
        upgradeTime = os.time()
    }
    
    gg.network_channel:fireClient(uin, {
        cmd = AchievementEventConfig.NOTIFY.TALENT_UPGRADED,
        data = notificationData
    })
    gg.log("发送天赋升级通知:", uin, talentId, oldLevel, "->", newLevel)
end

--- 发送成就解锁通知
---@param uin number 玩家UIN
---@param achievementId string 成就ID
function AchievementEventManager.SendUnlockNotification(uin, achievementId)
    local notificationData = {
        achievementId = achievementId,
        unlockTime = os.time()
    }
    
    gg.network_channel:fireClient(uin, {
        cmd = AchievementEventConfig.NOTIFY.ACHIEVEMENT_UNLOCKED,
        data = notificationData
    })
    gg.log("发送成就解锁通知:", uin, achievementId)
end

-- 通用响应方法 --------------------------------------------------------

--- 发送成功响应
---@param uin number 玩家UIN
---@param eventName string 响应事件名
---@param data table 响应数据
function AchievementEventManager.SendSuccessResponse(uin, eventName, data)
    local response = {
        success = true,
        data = data,
        errorCode = AchievementEventConfig.ERROR_CODES.SUCCESS
    }
    gg.network_channel:fireClient(uin, {
        cmd = eventName,
        data = response
    })
end

--- 发送错误响应
---@param uin number 玩家UIN
---@param eventName string 响应事件名
---@param errorCode number 错误码
function AchievementEventManager.SendErrorResponse(uin, eventName, errorCode)
    local response = {
        success = false,
        data = {},
        errorCode = errorCode
    }
    gg.network_channel:fireClient(uin, {
        cmd = eventName,
        data = response
    })
    gg.log("发送成就错误响应:", uin, eventName, errorCode)
end

return AchievementEventManager