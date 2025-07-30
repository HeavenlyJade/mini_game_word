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

--- 计算玩家可执行某个天赋动作的最大次数 (使用正确的GetVariable)
---@param player table 玩家对象
---@param talentConfig table 天赋配置
---@param currentTalentLevel number 当前天赋等级
---@return number maxActions可以执行的最大次数
local function CalculateMaxTalentActionExecutions(player, talentConfig, currentTalentLevel)
    if not player or not talentConfig or not talentConfig:IsTalentAchievement() or currentTalentLevel == 0 then
        return 0
    end

    if not talentConfig.actionCostType or not talentConfig.actionCostType.CostList or #talentConfig.actionCostType.CostList == 0 then
        gg.log("警告: 天赋 " .. talentConfig.name .. " 没有找到有效的 actionCostType 配置。")
        return 0
    end

    local BagMgr = require(ServerStorage.MSystems.Bag.BagMgr) ---@type BagMgr
    local playerBag = BagMgr.GetPlayerBag(player.uin)
    
    -- 1. 一次性计算出动作等级1的所有消耗
    local costsForLevel1 = talentConfig:GetActionCosts(1, player:GetConsumableData(), playerBag)
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
    for _, costConfigItem in ipairs(talentConfig.actionCostType.CostList) do
        local resourceName = costConfigItem.Name
        local resourceSource = costConfigItem.Source
        
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
    local talentConfig = ConfigLoader.GetAchievement(talentId)
    if not talentConfig then
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
        local baseCosts = talentConfig:GetActionCosts(i, playerData, playerBag)
        
        -- 2. 获取该等级对应的效果值（即执行次数/乘数）
        local executionCount = talentConfig:GetLevelEffectValue(i)

        if executionCount and type(executionCount) == "number" and executionCount > 0 then
            -- 3. 根据业务逻辑，将基础消耗乘以执行次数，得到最终消耗
            local finalCosts = {}
            for _, costInfo in ipairs(baseCosts) do
                table.insert(finalCosts, {
                    item = costInfo.item,
                    amount = costInfo.amount * executionCount
                })
            end
            costsByLevel[i] = finalCosts
        else
            gg.log(string.format("警告: 天赋 '%s' 等级 %d 的效果值(执行次数)无效或未配置, 无法计算消耗。", talentConfig.name, i))
            costsByLevel[i] = {} -- 返回空消耗
        end
    end
    
    -- 计算最大可执行次数
    local maxExecutions = CalculateMaxTalentActionExecutions(player, talentConfig, currentTalentLevel)
    gg.log(string.format("玩家 %s 的天赋 '%s' 最大可执行次数为: %d", playerId, talentId, maxExecutions))

    -- 计算最大执行次数的总消耗
    local maxExecutionTotalCost = 0 -- 改为数值
    if maxExecutions > 0 then
        local singleActionCosts = talentConfig:GetActionCosts(1, player:GetConsumableData(), playerBag)
        if singleActionCosts and #singleActionCosts > 0 then
            -- 假设“重生”只有一个消耗项
            local costInfo = singleActionCosts[1]
            if costInfo then
                maxExecutionTotalCost = (costInfo.amount or 0) * maxExecutions
            end
        end
    end

    -- 新增：获取玩家当前拥有的相关资源数量，并返回给客户端
    local playerResources = {}
    if talentConfig.actionCostType and talentConfig.actionCostType.CostList then
        for _, costConfigItem in ipairs(talentConfig.actionCostType.CostList) do
            local resourceName = costConfigItem.Name
            local resourceSource = costConfigItem.Source
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
        playerResources = playerResources -- 新增：玩家资源数据
    }

    AchievementEventManager.SendSuccessResponse(uin, AchievementEventConfig.RESPONSE.GET_REBIRTH_LEVEL_RESPONSE, responseData)
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
    local talentConfig = ConfigLoader.GetAchievement(talentId)
    if not talentConfig or not talentConfig:IsTalentAchievement() then
        return
    end

    -- 2. 计算效果 (奖励)
    local effectValue = talentConfig:GetLevelEffectValue(targetLevel)
    if not effectValue or effectValue <= 0 then
        gg.log("计算效果值为0或无效，操作终止", effectValue)
        return
    end
    gg.log(string.format("天赋动作'%s'等级%d的效果计算结果为: %s", talentId, targetLevel, tostring(effectValue)))

    -- 3. 计算消耗 (成本)
    local costs = talentConfig:GetUpgradeCosts(targetLevel, player.variableSystem)
    gg.log("计算出的消耗:", costs)

    -- 4. 检查并扣除消耗
    local BagMgr = require(ServerStorage.MSystems.Bag.BagMgr) ---@type BagMgr
    if not BagMgr.HasItemsByCosts(player, costs) then
        gg.log("执行天赋动作材料不足:", costs)
        return
    end
    if not BagMgr.RemoveItemsByCosts(player, costs) then
        gg.log("扣除天赋动作材料失败:", costs)
        return
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
    local talentConfig = ConfigLoader.GetAchievement(talentId)
    if not talentConfig or not talentConfig:IsTalentAchievement() then
        return
    end

    local BagMgr = require(ServerStorage.MSystems.Bag.BagMgr) ---@type BagMgr
    local totalActions = 0
    local totalEffectApplied = 0

    -- 循环执行，直到不满足条件
    while true do
        local currentTalentLevel = AchievementMgr.GetTalentLevel(playerId, talentId)
        local targetLevel = totalActions + 1 -- 在这个循环里，我们总是尝试执行下一个等级

        if currentTalentLevel < targetLevel then
            gg.log("最大化重生结束: 资格不足。当前天赋等级", currentTalentLevel, "目标动作等级", targetLevel)
            break
        end

        local costs = talentConfig:GetUpgradeCosts(targetLevel, player.variableSystem)
        if not BagMgr.HasItemsByCosts(player, costs) then
            gg.log("最大化重生结束: 材料不足。")
            break
        end

        if not BagMgr.RemoveItemsByCosts(player, costs) then
            gg.log("扣除材料失败。")
            break -- 避免死循环
        end

        local effectValue = talentConfig:GetLevelEffectValue(targetLevel)
        local effectConfig = talentConfig:GetLevelEffect(targetLevel)
        if effectConfig and effectConfig["效果字段名称"] then
            local variableName = effectConfig["效果字段名称"]
            player.variableSystem:Add(variableName, effectValue)
            totalEffectApplied = totalEffectApplied + effectValue
        end
        
        totalActions = totalActions + 1
        gg.log(string.format("执行第 %d 次重生成功", totalActions))
    end

    if totalActions > 0 then
        -- 至少成功了一次，发送成功响应并同步背包
        local responseData = {
            success = true,
            talentId = talentId,
            executedLevel = totalActions, -- 返回执行的总次数
            effectApplied = totalEffectApplied,
        }
        AchievementEventManager.SendSuccessResponse(uin, AchievementEventConfig.RESPONSE.PERFORM_TALENT_ACTION_RESPONSE, responseData)

        local bag = BagMgr.GetPlayerBag(player.uin)
        if bag then
            bag:SyncToClient()
        end
        gg.log(string.format("最大化重生完成，共执行 %d 次", totalActions))
    else
        -- 一次都未成功，发送失败响应
        gg.log(string.format("最大化重生未执行任何一次", talentId))
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
