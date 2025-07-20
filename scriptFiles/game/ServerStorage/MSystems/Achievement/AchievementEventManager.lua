-- AchievementEventManager.lua
-- 成就事件管理器 - 处理客户端和服务端之间的成就相关事件通信

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local AchievementEventConfig = require(MainStorage.Code.Event.AchievementEvent) ---@type AchievementEventConfig

---@class AchievementEventManager
local AchievementEventManager = {}

-- 使用EventAchievement配置中的事件定义
AchievementEventManager.EVENTS = AchievementEventConfig
AchievementEventManager.ERROR_CODES = AchievementEventConfig.ERROR_CODES

-- 初始化事件管理器
function AchievementEventManager.Init()
    -- 注册网络事件处理器
    AchievementEventManager.RegisterNetworkHandlers()
    gg.log("AchievementEventManager 初始化完成")
end

-- 注册网络事件处理器
function AchievementEventManager.RegisterNetworkHandlers()
    -- 获取成就列表
    ServerEventManager.Subscribe(AchievementEventConfig.REQUEST.GET_LIST, function(event)
        AchievementEventManager.HandleGetAchievementList(event)
    end, 100)
    
    -- 获取成就详情
    ServerEventManager.Subscribe(AchievementEventConfig.REQUEST.GET_DETAIL, function(event)
        AchievementEventManager.HandleGetAchievementDetail(event)
    end, 100)
    
    -- 升级天赋成就
    ServerEventManager.Subscribe(AchievementEventConfig.REQUEST.UPGRADE_TALENT, function(event)
        AchievementEventManager.HandleUpgradeTalent(event)
    end, 100)
    
    -- 获取升级预览
    ServerEventManager.Subscribe(AchievementEventConfig.REQUEST.GET_UPGRADE_PREVIEW, function(event)
        AchievementEventManager.HandleGetUpgradePreview(event)
    end, 100)
    
    -- 同步数据请求
    ServerEventManager.Subscribe(AchievementEventConfig.REQUEST.SYNC_DATA, function(event)
        AchievementEventManager.HandleSyncData(event)
    end, 100)
    
    gg.log("AchievementEventManager 网络事件注册完成")
end

-- 处理获取成就列表请求
function AchievementEventManager.HandleGetAchievementList(event)
    local uin = event.uin
    local params = event.args or {}
    
    gg.log("处理获取成就列表请求:", uin, gg.table2str(params))
    
    -- 获取玩家实例
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local player = serverDataMgr.getPlayerByUin(uin)
    
    if not player then
        AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.ERROR, 
            AchievementEventConfig.ERROR_CODES.PLAYER_NOT_FOUND)
        return
    end
    
    -- 获取成就管理器
    local AchievementMgr = require(ServerStorage.MSystems.Achievement.AchievementMgr)
    
    -- 获取成就数据
    local syncData = AchievementMgr.GetPlayerSyncData(tostring(uin))
    
    -- 构建响应数据
    local responseData = {
        achievements = syncData.achievements,
        totalCount = syncData.totalCount,
        talentCount = 0,
        normalCount = 0,
    }
    
    -- 统计天赋和普通成就数量
    for _, achievement in pairs(syncData.achievements) do
        if achievement.type == AchievementEventConfig.ACHIEVEMENT_TYPE.TALENT then
            responseData.talentCount = responseData.talentCount + 1
        else
            responseData.normalCount = responseData.normalCount + 1
        end
    end
    
    -- 发送响应
    AchievementEventManager.SendSuccessResponse(uin, AchievementEventConfig.RESPONSE.LIST_RESPONSE, responseData)
end

-- 处理获取成就详情请求
function AchievementEventManager.HandleGetAchievementDetail(event)
    local uin = event.uin
    local params = event.args or {}
    local achievementId = params.achievementId
    
    gg.log("处理获取成就详情请求:", uin, achievementId)
    
    if not achievementId or achievementId == "" then
        AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.ERROR,
            AchievementEventConfig.ERROR_CODES.INVALID_PARAMETERS)
        return
    end
    
    -- 获取玩家实例
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local player = serverDataMgr.getPlayerByUin(uin)
    
    if not player then
        AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.ERROR,
            AchievementEventConfig.ERROR_CODES.PLAYER_NOT_FOUND)
        return
    end
    
    -- 获取成就管理器
    local AchievementMgr = require(ServerStorage.MSystems.Achievement.AchievementMgr)
    local achievement = AchievementMgr.GetPlayerAchievement(tostring(uin), achievementId)
    
    if not achievement then
        AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.ERROR,
            AchievementEventConfig.ERROR_CODES.ACHIEVEMENT_NOT_FOUND)
        return
    end
    
    -- 构建详情数据
    local responseData = {
        achievement = achievement:GetSyncData(),
        effects = achievement:GetCurrentEffect(),
        upgradeInfo = {},
    }
    
    -- 如果是天赋成就，添加升级信息
    if achievement:IsTalentAchievement() then
        responseData.upgradeInfo = {
            canUpgrade = achievement:CanUpgrade(player),
            currentLevel = achievement:GetCurrentLevel(),
            maxLevel = achievement.achievementType:GetMaxLevel(),
        }
    end
    
    -- 发送响应
    AchievementEventManager.SendSuccessResponse(uin, AchievementEventConfig.RESPONSE.DETAIL_RESPONSE, responseData)
end

-- 处理升级天赋成就请求
function AchievementEventManager.HandleUpgradeTalent(event)
    local uin = event.uin
    local params = event.args or {}
    local achievementId = params.achievementId
    
    gg.log("处理升级天赋成就请求:", uin, achievementId)
    
    if not achievementId or achievementId == "" then
        AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.ERROR,
            AchievementEventConfig.ERROR_CODES.INVALID_PARAMETERS)
        return
    end
    
    -- 获取玩家实例
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local player = serverDataMgr.getPlayerByUin(uin)
    
    if not player then
        AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.ERROR,
            AchievementEventConfig.ERROR_CODES.PLAYER_NOT_FOUND)
        return
    end
    
    -- 获取成就管理器
    local AchievementMgr = require(ServerStorage.MSystems.Achievement.AchievementMgr)
    local achievement = AchievementMgr.GetPlayerAchievement(tostring(uin), achievementId)
    
    if not achievement then
        AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.ERROR,
            AchievementEventConfig.ERROR_CODES.ACHIEVEMENT_NOT_FOUND)
        return
    end
    
    if not achievement:IsTalentAchievement() then
        AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.ERROR,
            AchievementEventConfig.ERROR_CODES.NORMAL_ACHIEVEMENT_CANNOT_UPGRADE)
        return
    end
    
    -- 记录升级前状态
    local oldLevel = achievement:GetCurrentLevel()
    
    -- 执行升级
    local success = AchievementMgr.UpgradeAchievement(player, achievementId)
    
    if success then
        local newLevel = achievement:GetCurrentLevel()
        
        -- 构建响应数据
        local responseData = {
            achievementId = achievementId,
            oldLevel = oldLevel,
            newLevel = newLevel,
            appliedEffects = achievement:GetCurrentEffect(),
            consumedMaterials = {}, -- TODO: 记录实际消耗的材料
        }
        
        -- 发送升级成功响应
        AchievementEventManager.SendSuccessResponse(uin, AchievementEventConfig.RESPONSE.UPGRADE_RESPONSE, responseData)
        
        -- 发送升级通知
        AchievementEventManager.SendUpgradeNotification(uin, achievementId, achievement.achievementType.name, oldLevel, newLevel)
        
    else
        -- 判断失败原因
        if achievement:GetCurrentLevel() >= achievement.achievementType:GetMaxLevel() then
            AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.ERROR,
                AchievementEventConfig.ERROR_CODES.TALENT_ALREADY_MAX_LEVEL)
        elseif not achievement:CanUpgrade(player) then
            AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.ERROR,
                AchievementEventConfig.ERROR_CODES.INSUFFICIENT_MATERIALS)
        else
            AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.ERROR,
                AchievementEventConfig.ERROR_CODES.TALENT_CANNOT_UPGRADE)
        end
    end
end

-- 处理获取升级预览请求
function AchievementEventManager.HandleGetUpgradePreview(event)
    local uin = event.uin
    local params = event.args or {}
    local achievementId = params.achievementId
    
    gg.log("处理获取升级预览请求:", uin, achievementId)
    
    if not achievementId or achievementId == "" then
        AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.ERROR,
            AchievementEventConfig.ERROR_CODES.INVALID_PARAMETERS)
        return
    end
    
    -- 获取玩家实例
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local player = serverDataMgr.getPlayerByUin(uin)
    
    if not player then
        AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.ERROR,
            AchievementEventConfig.ERROR_CODES.PLAYER_NOT_FOUND)
        return
    end
    
    -- 获取成就管理器
    local AchievementMgr = require(ServerStorage.MSystems.Achievement.AchievementMgr)
    local achievement = AchievementMgr.GetPlayerAchievement(tostring(uin), achievementId)
    
    if not achievement then
        AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.ERROR,
            AchievementEventConfig.ERROR_CODES.ACHIEVEMENT_NOT_FOUND)
        return
    end
    
    if not achievement:IsTalentAchievement() then
        AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.ERROR,
            AchievementEventConfig.ERROR_CODES.NORMAL_ACHIEVEMENT_CANNOT_UPGRADE)
        return
    end
    
    local currentLevel = achievement:GetCurrentLevel()
    local previewLevel = params.previewLevel or (currentLevel + 1)
    
    -- 构建预览数据
    local responseData = {
        achievementId = achievementId,
        currentLevel = currentLevel,
        previewLevel = previewLevel,
        currentEffects = achievement:GetCurrentEffect(),
        previewEffects = achievement.achievementType:GetLevelEffect(previewLevel),
        upgradeCosts = achievement.achievementType:GetUpgradeCosts(currentLevel),
    }
    
    -- 发送响应
    AchievementEventManager.SendSuccessResponse(uin, AchievementEventConfig.RESPONSE.PREVIEW_RESPONSE, responseData)
end

-- 处理同步数据请求
function AchievementEventManager.HandleSyncData(event)
    local uin = event.uin
    
    gg.log("处理同步数据请求:", uin)
    
    -- 获取玩家实例
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local player = serverDataMgr.getPlayerByUin(uin)
    
    if not player then
        AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.ERROR,
            AchievementEventConfig.ERROR_CODES.PLAYER_NOT_FOUND)
        return
    end
    
    -- 获取成就管理器并同步数据
    local AchievementMgr = require(ServerStorage.MSystems.Achievement.AchievementMgr)
    AchievementMgr.SyncToClient(player)
end

-- 业务通知方法 --------------------------------------------------------

--- 发送成就解锁通知
---@param uin number 玩家UIN
---@param achievementId string 成就ID
---@param achievementName string 成就名称
---@param achievementType string 成就类型
function AchievementEventManager.SendUnlockNotification(uin, achievementId, achievementName, achievementType)
    local notificationData = {
        achievementId = achievementId,
        achievementName = achievementName,
        achievementType = achievementType,
        unlockTime = os.time(),
        initialLevel = 1,
        effects = {},
    }
    
    gg.network_channel:fireClient(uin, {
        cmd = AchievementEventConfig.NOTIFY.ACHIEVEMENT_UNLOCKED,
        data = notificationData
    })
    gg.log("发送成就解锁通知:", uin, achievementId, achievementName)
end

--- 发送天赋升级通知
---@param uin number 玩家UIN
---@param achievementId string 成就ID
---@param achievementName string 成就名称
---@param oldLevel number 旧等级
---@param newLevel number 新等级
function AchievementEventManager.SendUpgradeNotification(uin, achievementId, achievementName, oldLevel, newLevel)
    local notificationData = {
        achievementId = achievementId,
        achievementName = achievementName,
        oldLevel = oldLevel,
        newLevel = newLevel,
        newEffects = {},
        consumedMaterials = {},
    }
    
    gg.network_channel:fireClient(uin, {
        cmd = AchievementEventConfig.NOTIFY.TALENT_UPGRADED,
        data = notificationData
    })
    gg.log("发送天赋升级通知:", uin, achievementId, achievementName, oldLevel, "->", newLevel)
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
        message = "操作成功",
        errorCode = AchievementEventConfig.ERROR_CODES.SUCCESS,
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
---@param customMessage string|nil 自定义错误消息
function AchievementEventManager.SendErrorResponse(uin, eventName, errorCode, customMessage)
    local response = {
        success = false,
        data = {},
        message = customMessage or AchievementEventConfig.GetErrorMessage(errorCode),
        errorCode = errorCode,
    }
    gg.network_channel:fireClient(uin, {
        cmd = eventName,
        data = response
    })
    gg.log("发送成就错误响应:", uin, eventName, errorCode, response.message)
end

return AchievementEventManager