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
    ServerEventManager.Subscribe(AchievementEventConfig.REQUEST.GET_TALENT_LEVEL, function(event)
        AchievementEventManager.HandleGetTalentLevel(event)
    end, 100)

    -- 新增：处理执行天赋动作的请求
    ServerEventManager.Subscribe(AchievementEventConfig.REQUEST.PERFORM_TALENT_ACTION, function(event)
        AchievementEventManager.HandlePerformTalentAction(event)
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
        return
    end
    
    -- 获取玩家实例
    local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
    local player = MServerDataManager.getPlayerByUin(playerId)
    if not player then
        return
    end
    
    -- 获取天赋配置
    local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
    local talentConfig = ConfigLoader.GetAchievement(talentId)
    if not talentConfig or not talentConfig:IsTalentAchievement() then
        return
    end
    
    -- 记录升级前等级
    local oldLevel = AchievementMgr.GetTalentLevel(playerId, talentId)
    
    -- 检查是否已达最大等级
    if oldLevel >= talentConfig:GetMaxLevel() then
        return
    end
    
    -- 【关键】检查和扣除升级消耗
    local costs = talentConfig:GetUpgradeCosts(oldLevel)
    local BagMgr = require(ServerStorage.MSystems.Bag.BagMgr) ---@type BagMgr
    if not BagMgr.HasItemsByCosts(player, costs) then
        gg.log("升级材料不足:", costs,oldLevel)
        return
    end
    if not BagMgr.RemoveItemsByCosts(player, costs) then
        gg.log("扣除材料失败:", costs)
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
        -- AchievementEventManager.SendErrorResponse(uin, "AchievementResponse_GetTalentLevel",
        --     AchievementEventConfig.ERROR_CODES.INVALID_PARAMETERS)
        return
    end
    
    local talentLevel = AchievementMgr.GetTalentLevel(playerId, talentId)
    
    local responseData = {
        talentId = talentId,
        currentLevel = talentLevel
    }
    
    AchievementEventManager.SendSuccessResponse(uin, AchievementEventConfig.RESPONSE.GET_TALENT_LEVEL_RESPONSE, responseData)
end


--- 新增：处理执行天赋动作请求
---@param event table 事件对象
function AchievementEventManager.HandlePerformTalentAction(event)
    local playerNode = event.player
    local uin = playerNode.uin
    local playerId = uin
    local args = event.args or {}
    local talentId = args.talentId
    local targetLevel = args.targetLevel

    if not talentId or not targetLevel or targetLevel <= 0 then
        return AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.PERFORM_TALENT_ACTION_RESPONSE, AchievementEventConfig.ERROR_CODES.INVALID_PARAMETERS)
    end
    gg.log("处理天赋动作请求:", talentId, "等级:", targetLevel)

    local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
    local player = MServerDataManager.getPlayerByUin(playerId)
    if not player then
        return AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.PERFORM_TALENT_ACTION_RESPONSE, AchievementEventConfig.ERROR_CODES.PLAYER_NOT_FOUND)
    end

    -- 1. 校验资格
    local currentTalentLevel = AchievementMgr.GetTalentLevel(playerId, talentId)
    if currentTalentLevel < targetLevel then
        gg.log("资格不足: 当前天赋等级", currentTalentLevel, "目标动作等级", targetLevel)
        return AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.PERFORM_TALENT_ACTION_RESPONSE, AchievementEventConfig.ERROR_CODES.INSUFFICIENT_MATERIALS) -- 复用一个相近的错误码
    end

    local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
    local talentConfig = ConfigLoader.GetAchievement(talentId)
    if not talentConfig or not talentConfig:IsTalentAchievement() then
        return AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.PERFORM_TALENT_ACTION_RESPONSE, AchievementEventConfig.ERROR_CODES.ACHIEVEMENT_NOT_FOUND)
    end

    -- 2. 计算效果 (奖励)
    local effectValue = talentConfig:GetLevelEffectValue(targetLevel)
    if not effectValue or effectValue <= 0 then
        gg.log("计算效果值为0或无效，操作终止", effectValue)
        return AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.PERFORM_TALENT_ACTION_RESPONSE, AchievementEventConfig.ERROR_CODES.SYSTEM_ERROR)
    end
    gg.log(string.format("天赋动作'%s'等级%d的效果计算结果为: %s", talentId, targetLevel, tostring(effectValue)))

    -- 3. 计算消耗 (成本)
    local costs = talentConfig:GetUpgradeCosts(targetLevel, player.variableSystem)
    gg.log("计算出的消耗:", costs)

    -- 4. 检查并扣除消耗
    local BagMgr = require(ServerStorage.MSystems.Bag.BagMgr) ---@type BagMgr
    if not BagMgr.HasItemsByCosts(player, costs) then
        gg.log("执行天赋动作材料不足:", costs)
        return AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.PERFORM_TALENT_ACTION_RESPONSE, AchievementEventConfig.ERROR_CODES.INSUFFICIENT_MATERIALS)
    end
    if not BagMgr.RemoveItemsByCosts(player, costs) then
        gg.log("扣除天赋动作材料失败:", costs)
        return AchievementEventManager.SendErrorResponse(uin, AchievementEventConfig.RESPONSE.PERFORM_TALENT_ACTION_RESPONSE, AchievementEventConfig.ERROR_CODES.SYSTEM_ERROR)
    end
    
    -- 5. 应用效果
    -- 这里我们假设效果是增加某个玩家变量，变量名在效果配置中定义
    local effectConfig = talentConfig:GetLevelEffect(targetLevel)
    if effectConfig and effectConfig["效果字段名称"] then
        local variableName = effectConfig["效果字段名称"]
        player.variableSystem:Add(variableName, effectValue)
        gg.log(string.format("成功为玩家 %s 的变量 %s 增加了 %s", playerId, variableName, effectValue))
    else
        gg.log(string.format("警告：天赋 %s 的等级 %d 效果配置不正确，未找到'效果字段名称'", talentId, targetLevel))
    end
    
    -- 6. 发送成功响应
    local responseData = {
        success = true,
        talentId = talentId,
        executedLevel = targetLevel,
        effectApplied = effectValue,
    }
    AchievementEventManager.SendSuccessResponse(uin, AchievementEventConfig.RESPONSE.PERFORM_TALENT_ACTION_RESPONSE, responseData)

    -- 同步背包变化到客户端
    local bag = BagMgr.GetPlayerBag(player.uin)
    if bag then
        bag:SyncToClient()
    end
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
    gg.network_channel:fireClient(uin, {
        cmd = eventName,
        data = data
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

--- 新增：向客户端通知所有初始成就数据
---@param uin number 玩家UIN
function AchievementEventManager.NotifyAllDataToClient(uin)
    local AchievementMgr = require(ServerStorage.MSystems.Achievement.AchievementMgr) ---@type AchievementMgr
    local playerAchievement = AchievementMgr.server_player_achievement_data[uin]
    
    if not playerAchievement then
        gg.log("警告: 玩家", uin, "的天赋成就数据不存在，跳过天赋数据同步")
        return
    end

    -- 1. 同步完整的天赋和成就列表
    local talentData = playerAchievement:GetAllTalentData()
    local normalAchievements = playerAchievement:GetAllNormalAchievements()

    local achievementResponseData = {
        talents = {},
        normalAchievements = {},
        totalTalentCount = playerAchievement:GetTalentCount(),
        totalNormalCount = playerAchievement:GetUnlockedNormalAchievementCount()
    }

    for talentId, talentInfo in pairs(talentData) do
        achievementResponseData.talents[talentId] = {
            talentId = talentId,
            currentLevel = talentInfo.currentLevel,
            unlockTime = talentInfo.unlockTime
        }
    end

    for achievementId, achievementInfo in pairs(normalAchievements) do
        achievementResponseData.normalAchievements[achievementId] = {
            achievementId = achievementId,
            unlocked = achievementInfo.unlocked,
            unlockTime = achievementInfo.unlockTime
        }
    end

    gg.network_channel:fireClient(uin, {
        cmd = AchievementEventConfig.RESPONSE.LIST_RESPONSE,
        data = achievementResponseData
    })
    gg.log("已主动同步天赋成就数据到客户端:", uin, "天赋数量:", achievementResponseData)

    -- 2. 为RebirthGui主动推送'重生'天赋的等级
    local rebirthTalentLevel = playerAchievement:GetTalentLevel("重生")
    gg.network_channel:fireClient(uin, {
        cmd = AchievementEventConfig.RESPONSE.GET_REBIRTH_LEVEL_RESPONSE,
        data = {
            talentId = "重生",
            currentLevel = rebirthTalentLevel
        }
    })
    gg.log("已为RebirthGui主动同步'重生'天赋等级:", rebirthTalentLevel)
end


return AchievementEventManager