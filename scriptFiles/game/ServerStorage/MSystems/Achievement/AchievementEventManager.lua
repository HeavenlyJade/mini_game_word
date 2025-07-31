-- AchievementEventManager.lua
-- 成就事件管理器 - 简化版，适配新的聚合架构

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local AchievementEventConfig = require(MainStorage.Code.Event.AchievementEvent) ---@type AchievementEventConfig
local AchievementMgr = require(ServerStorage.MSystems.Achievement.AchievementMgr) ---@type AchievementMgr
local BaseUntils = require(ServerStorage.ServerUntils.BaseUntils) ---@type BaseUntils

---@class AchievementEventManager
local AchievementEventManager = {}

-- 辅助方法 --------------------------------------------------------

--- 计算玩家可执行某个天赋动作的最大次数 (使用正确的GetVariable)
---@param player table 玩家对象
---@param AchievementTypeIns AchievementType 天赋配置
---@param currentTalentLevel number 当前天赋等级
---@return number maxActions可以执行的最大次数
local function CalculateMaxTalentActionExecutions(player, AchievementTypeIns, currentTalentLevel)
    gg.log("CalculateMaxTalentActionExecutions",player, AchievementTypeIns, currentTalentLevel,AchievementTypeIns.actionCostType)
    if not player or not AchievementTypeIns or not AchievementTypeIns:IsTalentAchievement() or currentTalentLevel == 0 then
        return 0
    end

    if not AchievementTypeIns.actionCostType  then
        gg.log("警告: 天赋 " .. AchievementTypeIns.name .. " 没有找到有效的 actionCostType 配置。")
        return 0
    end
    local BagMgr = require(ServerStorage.MSystems.Bag.BagMgr) ---@type BagMgr
    local playerBag = BagMgr.GetPlayerBag(player.uin)
    local playerConsumableData = player:GetConsumableData()
    -- 1. 一次性计算出动作等级1的所有消耗
    local costsForLevel1 = AchievementTypeIns:GetActionCosts(1, playerConsumableData, playerBag)
    gg.log("costsForLevel1",costsForLevel1,playerConsumableData)
    if not costsForLevel1 or #costsForLevel1 == 0 then
        gg.log("警告: 无法计算天赋动作等级1的消耗，无法计算最大次数。")
        return 0
    end

    -- 将消耗列表转为映射表以便快速查找
    local costsMap = {}
    for _, cost in ipairs(costsForLevel1) do
        costsMap[cost.item] = cost.amount
    end

    local maxExecutions = math.huge

    -- 2. 遍历配置中定义的所有消耗类型，找出限制最大的那个（瓶颈）
    for _, costConfigItem in ipairs(AchievementTypeIns.actionCostType.CostList) do
        local resourceName = costConfigItem.Name
        local resourceSource = costConfigItem.CostType

        local singleCostAmount = costsMap[resourceName]

        if singleCostAmount and singleCostAmount > 0 then
            -- 3. 根据配置的来源(Source)，获取玩家拥有的资源总量
            local playerTotalAmount = 0
            if resourceSource == "玩家变量" then
                -- 使用正确的 GetVariable 方法
                if player.variableSystem then
                    playerTotalAmount = player.variableSystem:GetVariable(resourceName) or 0
                end
            else -- 默认为背包物品
                if playerBag then
                    playerTotalAmount = playerBag:GetItemAmount(resourceName)
                end
            end

            -- 4. 计算此单一资源能支持的最大次数
            local maxForThisResource = math.floor(playerTotalAmount / singleCostAmount)

            -- 5. 更新全局最大次数，取当前和新计算出的最小值
            maxExecutions = math.min(maxExecutions, maxForThisResource)
        end
    end

    -- 如果maxExecutions从未被更新（例如所有消耗都为0），则返回0
    if maxExecutions == math.huge then
        return 0
    end

    return maxExecutions
end

--- 计算天赋动作消耗
---@param AchievementTypeIns AchievementType 天赋配置
---@param targetLevel number 目标等级
---@param player table 玩家对象
---@return table|nil 消耗列表，失败时返回nil
local function CalculateTalentActionCosts(AchievementTypeIns, targetLevel, player)
    if not AchievementTypeIns or not player then
        return nil
    end

    local BagMgr = require(ServerStorage.MSystems.Bag.BagMgr) ---@type BagMgr
    local playerBag = BagMgr.GetPlayerBag(player.uin)
    local playerConsumableData = player:GetConsumableData()
    local costs = AchievementTypeIns:GetActionCosts(targetLevel, playerConsumableData, playerBag)
    return costs
end



--- 应用天赋动作效果
---@param AchievementTypeIns table 天赋配置
---@param player table 玩家对象
---@param playerId string 玩家ID
---@return boolean 是否成功应用效果
local function ApplyTalentActionEffects(AchievementTypeIns, player, playerId)
    if not AchievementTypeIns or not player then
        return false
    end

    local actionCostType = AchievementTypeIns.actionCostType ---@type ActionCostType
    if not actionCostType then
        gg.log(string.format("警告：天赋 %s 没有配置 actionCostType，无法应用效果", AchievementTypeIns.id))
        return false
    end

    local successCount = actionCostType:ApplyAllEffects(player, playerId)
    return successCount > 0
end

--- 计算多次天赋动作的总消耗
---@param AchievementTypeIns table 天赋配置
---@param player table 玩家对象
---@param executionCount number 执行次数
---@return table|nil 总消耗列表，失败时返回nil
local function CalculateTotalTalentActionCosts(AchievementTypeIns, player, executionCount)
    if not AchievementTypeIns or not player or executionCount <= 0 then
        return nil
    end

    local BagMgr = require(ServerStorage.MSystems.Bag.BagMgr) ---@type BagMgr
    local playerBag = BagMgr.GetPlayerBag(player.uin)

    -- 计算单次消耗
    local singleCosts = AchievementTypeIns:GetActionCosts(1, player:GetConsumableData(), playerBag)
    if not singleCosts or #singleCosts == 0 then
        return nil
    end

    -- 计算总消耗
    local totalCosts = {}
    for _, cost in ipairs(singleCosts) do
        table.insert(totalCosts, {
            item = cost.item,
            amount = cost.amount * executionCount,
            costType = cost.costType -- 确保传递costType
        })
    end

    gg.log("计算出的总消耗:", totalCosts, "执行次数:", executionCount)
    return totalCosts
end

--- 同步背包到客户端
---@param player table 玩家对象
local function SyncBagToClient(player)
    if not player then
        return
    end

    local BagMgr = require(ServerStorage.MSystems.Bag.BagMgr) ---@type BagMgr
    local bag = BagMgr.GetPlayerBag(player.uin)
    if bag then
        bag:SyncToClient()
    end
end


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

    -- 天赋消耗执行
    ServerEventManager.Subscribe(AchievementEventConfig.REQUEST.PERFORM_TALENT_ACTION, function(event)
        AchievementEventManager.HandlePerformTalentAction(event)
    end, 100)

    -- 新增：处理执行最大化天赋动作的请求
    ServerEventManager.Subscribe(AchievementEventConfig.REQUEST.PERFORM_MAX_TALENT_ACTION, function(event)
        AchievementEventManager.HandlePerformMaxTalentAction(event)
    end, 100)

end

-- 处理获取成就列表请求
function AchievementEventManager.HandleGetAchievementList(event)
    local uin = event.uin
    local playerId = uin


    -- 获取玩家成就实例
    local playerAchievement = AchievementMgr.server_player_achievement_data[playerId]

    if not playerAchievement then
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

-- 处理升级天赋成就请求
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
    local AchievementTypeIns = ConfigLoader.GetAchievement(talentId)
    if not AchievementTypeIns or not AchievementTypeIns:IsTalentAchievement() then
        return
    end

    -- 记录升级前等级
    local oldLevel = AchievementMgr.GetTalentLevel(playerId, talentId)

    -- 检查是否已达最大等级
    if oldLevel >= AchievementTypeIns:GetMaxLevel() then
        return
    end

    -- 【关键】检查和扣除升级消耗
    local costs = AchievementTypeIns:GetUpgradeCosts(oldLevel)
    gg.log("升级消耗:", costs)
    if not BaseUntils.CheckCosts(player, costs) then
        gg.log("升级材料不足:", costs,oldLevel)
        return
    end
    if not BaseUntils.DeductCosts(player, costs) then
        gg.log("扣除材料失败:", costs)
        return
    end
    -- 同步背包变化到客户端
    SyncBagToClient(player)

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
    end
end


-- 处理获取天赋等级请求
function AchievementEventManager.HandleGetTalentLevel(event)
    gg.log("HandleGetTalentLevel", event)
    local uin = event.player.uin
    local params = event.args or {}
    local talentId = params.talentId
    local playerId = uin

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
    local AchievementTypeIns = ConfigLoader.GetAchievement(talentId)
    if not AchievementTypeIns then
        return
    end

    local currentTalentLevel = AchievementMgr.GetTalentLevel(playerId, talentId)
    local costsByLevel = {}

    local BagMgr = require(ServerStorage.MSystems.Bag.BagMgr) ---@type BagMgr
    local playerBag = BagMgr.GetPlayerBag(player.uin)

    -- 计算每个可执行等级的消耗
    local playerData = player:GetConsumableData()

    for i = 1, currentTalentLevel do
        -- 1. 先获取配置的基础消耗值
        local baseCosts = AchievementTypeIns:GetActionCosts(i, playerData, playerBag)

        -- 2. 获取该等级对应的效果值（即执行次数/乘数）
        local LevelEffectTable = AchievementTypeIns:GetLevelEffectValue(i)
        if LevelEffectTable and #LevelEffectTable > 0 then
            -- 3. 根据业务逻辑，将基础消耗乘以执行次数，得到最终消耗
            local finalCosts = {}
            for _, effectInfo in ipairs(LevelEffectTable) do
                local effectValue = effectInfo["数值"]
                for _, costInfo in ipairs(baseCosts) do
                    table.insert(finalCosts, {
                        item = costInfo.item,
                        amount = costInfo.amount * effectValue,
                        effectType = effectInfo["效果类型"],
                        effectName = effectInfo["效果字段名称"],
                        effectValue = effectValue, -- 把效果值也传给客户端
                        costType = costInfo.costType -- 传递costType
                    })
                end
            end
            costsByLevel[i] = finalCosts
        else
            gg.log(string.format("警告: 天赋 '%s' 等级 %d 的效果值(执行次数)无效或未配置, 无法计算消耗。", AchievementTypeIns.name, i))
            costsByLevel[i] = {} -- 返回空消耗
        end
    end

    -- 计算最大可执行次数
    local maxExecutions = CalculateMaxTalentActionExecutions(player, AchievementTypeIns, currentTalentLevel)
    gg.log(string.format("玩家 %s 的天赋 '%s' 最大可执行次数为: %d", playerId, talentId, maxExecutions))

    -- 计算最大执行次数的总消耗
    local maxExecutionTotalCost = 0 -- 改为数值
    if maxExecutions > 0 then
        local singleActionCosts = AchievementTypeIns:GetActionCosts(1, player:GetConsumableData(), playerBag)
        if singleActionCosts and #singleActionCosts > 0 then
            local costInfo = singleActionCosts[1]
            if costInfo then
                maxExecutionTotalCost = (costInfo.amount or 0) * maxExecutions
            end
        end
    end

    -- 新增：获取玩家当前拥有的相关资源数量，并返回给客户端
    local playerResources = {}
    if AchievementTypeIns.actionCostType and AchievementTypeIns.actionCostType.CostList then
        for _, costConfigItem in ipairs(AchievementTypeIns.actionCostType.CostList) do
            local resourceName = costConfigItem.Name
            local resourceSource = costConfigItem.CostType
            local playerTotalAmount = 0
            if resourceSource == "玩家变量" then
                if player.variableSystem then
                    playerTotalAmount = player.variableSystem:GetVariable(resourceName) or 0
                end
            else -- 默认为背包物品
                if playerBag then
                    playerTotalAmount = playerBag:GetItemAmount(resourceName)
                end
            end
            playerResources[resourceName] = playerTotalAmount
        end
    end

    local responseData = {
        talentId = talentId,
        currentLevel = currentTalentLevel,
        costsByLevel = costsByLevel,
        maxExecutions = maxExecutions,
        maxExecutionTotalCost = maxExecutionTotalCost,
        playerResources = playerResources 
    }

    AchievementEventManager.SendSuccessResponse(uin, AchievementEventConfig.RESPONSE.GET_REBIRTH_LEVEL_RESPONSE, responseData)
end


--- 新增：处理执行天赋动作请求
---@param event table 事件对象
function AchievementEventManager.HandlePerformTalentAction(event)
    local playerNode = event.player
    local uin = playerNode.uin
    local playerId = uin
    local args = event.args
    local talentId = args.talentId
    local targetLevel = args.targetLevel

    if not talentId or not targetLevel or targetLevel <= 0 then
        return
    end

    local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
    local player = MServerDataManager.getPlayerByUin(playerId)
    if not player then
        return
    end

    -- 1. 校验资格
    local currentTalentLevel = AchievementMgr.GetTalentLevel(playerId, talentId)
    if currentTalentLevel < targetLevel then
        gg.log("资格不足: 当前天赋等级", currentTalentLevel, "目标动作等级", targetLevel)
        return
    end

    local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
    local AchievementTypeIns = ConfigLoader.GetAchievement(talentId)
    if not AchievementTypeIns or not AchievementTypeIns:IsTalentAchievement() then
        return
    end

    -- 2. 计算效果 (奖励)
    local LevelEffectTable = AchievementTypeIns:GetLevelEffectValue(targetLevel)
    gg.log("LevelEffectTable",LevelEffectTable)
    if not next(LevelEffectTable)  then
        gg.log("计算效果值为0或无效，操作终止", LevelEffectTable)
        return
    end

    local costs = CalculateTalentActionCosts(AchievementTypeIns, targetLevel, player)
    if not costs then
        gg.log("计算天赋动作消耗失败")
        return
    end

    -- 4. 检查消耗
    if not BaseUntils.CheckCosts(player, costs) then
        return
    end
    
    -- 5. 扣除消耗
    if not BaseUntils.DeductCosts(player, costs) then
        gg.log("扣除材料失败:", costs)
        return
    end
    -- 6. 应用效果
    if not ApplyTalentActionEffects(AchievementTypeIns, player, playerId) then
        gg.log("应用天赋动作效果失败")
        return
    end

    -- 7. 发送成功响应
    local responseData = {
        success = true,
        talentId = talentId,
        executedLevel = targetLevel,
        LevelEffectTable = LevelEffectTable,
    }
    AchievementEventManager.SendSuccessResponse(uin, AchievementEventConfig.RESPONSE.PERFORM_TALENT_ACTION_RESPONSE, responseData)

    -- 同步背包变化到客户端
    SyncBagToClient(player)
end


--- 新增：处理最大化天赋动作请求
---@param event table 事件对象
function AchievementEventManager.HandlePerformMaxTalentAction(event)
    local playerNode = event.player
    local uin = playerNode.uin
    local playerId = uin
    local args = event.args or {}
    local talentId = args.talentId

    if not talentId then
        return
    end

    local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
    local player = MServerDataManager.getPlayerByUin(playerId)
    if not player then
        return
    end

    local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
    local AchievementTypeIns = ConfigLoader.GetAchievement(talentId)
    if not AchievementTypeIns or not AchievementTypeIns:IsTalentAchievement() then
        return
    end

    -- 1. 获取当前天赋等级
    local currentTalentLevel = AchievementMgr.GetTalentLevel(playerId, talentId)
    if currentTalentLevel < 1 then
        gg.log("最大化重生失败: 天赋等级不足，当前等级", currentTalentLevel)
        return
    end

    -- 2. 计算可执行的最大次数
    local maxExecutions = CalculateMaxTalentActionExecutions(player, AchievementTypeIns, currentTalentLevel)
    if maxExecutions <= 0 then
        gg.log("最大化重生失败: 无法计算最大执行次数或资源不足")
        return
    end

    gg.log(string.format("计算出的最大执行次数: %d", maxExecutions))

    -- 3. 计算总消耗
    local totalCosts = CalculateTotalTalentActionCosts(AchievementTypeIns, player, maxExecutions)
    if not totalCosts then
        gg.log("最大化重生失败: 无法计算总消耗")
        return
    end

    -- 4. 检查并扣除总消耗
    if not BaseUntils.CheckCosts(player, totalCosts) then
        gg.log("最大化重生失败: 检查总消耗失败")
        return
    end
    
    if not BaseUntils.DeductCosts(player, totalCosts) then
        gg.log("最大化重生失败: 扣除总消耗失败")
        return
    end

    -- 5. 计算总效果值
    local totalEffectValue = AchievementTypeIns:GetLevelEffectValue(1)[1]["数值"] * maxExecutions

    -- 6. 一次性应用所有效果
    local successCount = 0
    for i = 1, maxExecutions do
        if ApplyTalentActionEffects(AchievementTypeIns, player, playerId) then
            successCount = successCount + 1
        else
            gg.log(string.format("最大化重生：第 %d 次应用效果失败", i))
        end
    end

    -- 7. 发送成功响应
    local responseData = {
        success = true,
        talentId = talentId,
        executedLevel = maxExecutions, -- 返回执行的总次数
        effectApplied = totalEffectValue,
    }
    AchievementEventManager.SendSuccessResponse(uin, AchievementEventConfig.RESPONSE.PERFORM_TALENT_ACTION_RESPONSE, responseData)

    -- 8. 同步背包变化到客户端
    SyncBagToClient(player)

    gg.log(string.format("最大化重生完成，共执行 %d 次，成功应用效果 %d 次", maxExecutions, successCount))
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
